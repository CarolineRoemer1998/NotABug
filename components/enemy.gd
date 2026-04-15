extends CharacterBody2D

enum State { WANDER, CHASE, ATTACK }

@export var move_speed: float = 85.0
@export var steer_smoothing: float = 10.0
@export var ray_length: float = 54.0
@export var danger_weight: float = 2.4
@export var reverse_penalty: float = 0.25

@export var melee_range: float = 20.0
@export var melee_damage: int = 1
@export var ranged_max_range: float = 170.0

@export var melee_cooldown: float = 0.9
@export var gas_cooldown: float = 3.5
@export var ranged_cooldown: float = 1.6

@export var gas_duration: float = 2.5

@export var projectile_scene: PackedScene
@export var gas_zone_scene: PackedScene

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D3
@onready var sensors: Node2D = $Sensors

var state: State = State.WANDER
var player: Node2D

var _desired_dir: Vector2 = Vector2.RIGHT
var _move_dir: Vector2 = Vector2.RIGHT

var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_time_left: float = 0.0

var _melee_cd_left: float = 0.0
var _gas_cd_left: float = 0.0
var _ranged_cd_left: float = 0.0

var _attack_lock_left: float = 0.0

func _ready() -> void:
	_update_ray_lengths()
	_pick_new_wander()

func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)

	if _attack_lock_left > 0.0:
		_attack_lock_left = maxf(0.0, _attack_lock_left - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_update_state(delta)
	_update_interest(delta)

	var chosen_dir := _choose_steer_dir(_desired_dir)
	if chosen_dir.length_squared() > 0.0001:
		_move_dir = _move_dir.lerp(chosen_dir, 1.0 - exp(-steer_smoothing * delta))
		if _move_dir.length_squared() > 0.0001:
			_move_dir = _move_dir.normalized()

	velocity = _move_dir * move_speed
	move_and_slide()
	_update_animation()

func _tick_cooldowns(delta: float) -> void:
	_melee_cd_left = maxf(0.0, _melee_cd_left - delta)
	_gas_cd_left = maxf(0.0, _gas_cd_left - delta)
	_ranged_cd_left = maxf(0.0, _ranged_cd_left - delta)

func _update_state(_delta: float) -> void:
	if player == null:
		state = State.WANDER
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= melee_range and _melee_cd_left <= 0.0:
		_do_melee()
		return

	if dist <= ranged_max_range:
		var los_clear := _has_line_of_sight_to_player()

		if (not los_clear) and _gas_cd_left <= 0.0 and gas_zone_scene != null:
			_do_gas()
			return

		if los_clear and _ranged_cd_left <= 0.0 and projectile_scene != null:
			_do_ranged()
			return

	state = State.CHASE

func _update_interest(delta: float) -> void:
	match state:
		State.WANDER:
			_wander_time_left -= delta
			if _wander_time_left <= 0.0:
				_pick_new_wander()
			_desired_dir = _wander_dir
		State.CHASE:
			_desired_dir = (player.global_position - global_position).normalized()
		_:
			_desired_dir = Vector2.ZERO

func _pick_new_wander() -> void:
	_wander_time_left = randf_range(0.8, 1.8)
	_wander_dir = Vector2.RIGHT.rotated(randf_range(-PI, PI)).normalized()

func _choose_steer_dir(desired_dir: Vector2) -> Vector2:
	if desired_dir.length_squared() < 0.0001:
		return Vector2.ZERO

	var sum := Vector2.ZERO

	for ray in sensors.get_children():
		if ray is not RayCast2D:
			continue
		var rc := ray as RayCast2D

		var dir := (rc.to_global(rc.target_position) - rc.global_position).normalized()
		# Map dot from [-1, 1] to [0, 1] so side directions still have some interest.
		var interest := (dir.dot(desired_dir) + 1.0) * 0.5

		var danger := 0.0
		if rc.is_colliding():
			var hit_point: Vector2 = rc.get_collision_point()
			var d := global_position.distance_to(hit_point)
			danger = clampf(1.0 - (d / maxf(0.001, ray_length)), 0.0, 1.0)

		var score := interest - danger * danger_weight
		sum += dir * score

	if sum.length_squared() < 0.0001:
		return -_move_dir if _move_dir.length_squared() > 0.0001 else desired_dir

	var candidate := sum.normalized()
	# Slightly discourage instantly reversing direction (reduces jitter in tight spaces).
	if candidate.dot(_move_dir) < -0.2:
		candidate = (candidate + _move_dir * reverse_penalty).normalized()
	return candidate

func _has_line_of_sight_to_player() -> bool:
	if player == null:
		return false

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	query.collision_mask = 16 # Obstacles
	var hit := space.intersect_ray(query)
	return hit.is_empty()

func _do_melee() -> void:
	state = State.ATTACK
	_melee_cd_left = melee_cooldown
	_attack_lock_left = 0.25
	if anim.sprite_frames.has_animation("attackL"):
		anim.play("attackL")
	_spawn_melee_hitbox()

func _spawn_melee_hitbox() -> void:
	if player == null:
		return

	var hitbox := Area2D.new()
	hitbox.name = "MeleeHitbox"
	hitbox.collision_layer = 8 # Damage
	hitbox.collision_mask = 1 # Player

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(8.0, melee_range)
	shape.shape = circle
	hitbox.add_child(shape)

	var to_player := (player.global_position - global_position)
	var offset := to_player.normalized() * minf(melee_range, to_player.length())
	hitbox.global_position = global_position + offset

	hitbox.body_entered.connect(func(body: Node2D) -> void:
		if body.has_method("take_damage"):
			body.call("take_damage", melee_damage)
	)

	get_tree().current_scene.add_child(hitbox)
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if is_instance_valid(hitbox):
			hitbox.queue_free()
	)

func _do_gas() -> void:
	state = State.ATTACK
	_gas_cd_left = gas_cooldown
	_attack_lock_left = 0.2

	var gas := gas_zone_scene.instantiate()
	gas.global_position = player.global_position
	if gas.has_method("configure"):
		gas.call("configure", gas_duration)
	get_tree().current_scene.add_child(gas)

func _do_ranged() -> void:
	state = State.ATTACK
	_ranged_cd_left = ranged_cooldown
	_attack_lock_left = 0.15

	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	var dir := (player.global_position - global_position).normalized()
	if proj.has_method("configure"):
		proj.call("configure", dir)
	get_tree().current_scene.add_child(proj)

func _update_animation() -> void:
	if state == State.ATTACK:
		return
	if velocity.length() < 1.0:
		anim.play("Idle")
		return
	anim.play("walkD")
	anim.flip_h = velocity.x < 0.0

func _update_ray_lengths() -> void:
	for ray in sensors.get_children():
		if ray is RayCast2D:
			(ray as RayCast2D).target_position = Vector2(ray_length, 0)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
