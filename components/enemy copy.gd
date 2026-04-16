extends CharacterBody2D

## Physics layer 5 in Project Settings — name "Obstacles", bitmask 16.
## Put wall `StaticBody2D` / `TileMap` colliders on this layer so LOS raycasts hit them.
const OBSTACLE_MASK: int = 16

enum State { PATROL, CHASE }

@export var patrol_route_parent: NodePath
@export var patrol_points: Array[Node2D] = []
@export var random_patrol: bool = true
@export var allow_diagonal_movement: bool = true
@export var Goal: Node2D

@export var patrol_speed: float = 42.0
@export var chase_speed: float = 65.0
@export var chase_speed_close: float = 48.0
@export var chase_speed_aggro: float = 43.0
@export var melee_boost_speed: float = 105.0
@export var melee_boost_time: float = 0.35
@export var patrol_wait_min: float = 0.4
@export var patrol_wait_max: float = 1.1

@export var sight_distance: float = 125.0
@export var sight_half_angle_deg: float = 34.0
@export var sight_memory_time: float = 2.5
@export var chase_lose_distance: float = 180.0
@export var search_time_after_los: float = 2.6

@export var close_attack_radius: float = 35.0
@export var far_attack_radius: float = 110.0
@export var melee_adjacent: float = 22.0
@export var melee_damage: int = 1
@export var melee_range: float = 22.0

@export var melee_cooldown: float = 0.9
@export var gas_cooldown: float = 5.0
@export var ranged_cooldown: float = 1.6

@export var gas_duration: float = 10.0
@export var gas_patrol_radius: float = 72.0
@export var gas_patrol_chance: float = 0.1

@export var projectile_scene: PackedScene
@export var gas_zone_scene: PackedScene

@export var debug_draw_cone: bool = true
@export var cone_color: Color = Color(1.0, 0.2, 0.9, 0.12)
@export var cone_edge_color: Color = Color(1.0, 0.2, 0.9, 0.45)

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D3

var state: State = State.PATROL
var player: Node2D

var _waypoints: Array[Node2D] = []
var _patrol_index: int = 0
var _last_patrol_index: int = -1
var _patrol_wait_left: float = 0.0
var _stuck_frames: int = 0

var _facing: Vector2 = Vector2.RIGHT
var _last_seen_player_left: float = 999.0
var _has_aggro: bool = false
var _melee_boost_left: float = 0.0
var _in_see_area: bool = false
var _sees_player: bool = false
var _last_known_player_pos: Vector2 = Vector2.ZERO
var _search_left: float = 0.0

var _melee_cd: float = 0.0
var _gas_cd: float = 0.0
var _ranged_cd: float = 0.0
var _attack_lock: float = 0.0

var _chase_repath_timer: float = 0.0
const CHASE_REPATH_INTERVAL: float = 0.12


func _ready() -> void:
	_build_waypoints()
	far_attack_radius = minf(far_attack_radius, sight_distance)
	# Larger values reduce wedging at tight nav corners vs the capsule collider.
	_nav.path_desired_distance = 10.0
	_nav.target_desired_distance = 16.0
	_nav.radius = 11.0
	call_deferred("_deferred_nav_setup")


func _deferred_nav_setup() -> void:
	await get_tree().physics_frame
	if _waypoints.is_empty():
		return
	if random_patrol:
		_patrol_index = _pick_random_patrol_index_excluding(-1)
	else:
		_patrol_index = 0
	_nav.target_position = _waypoints[_patrol_index].global_position


func _build_waypoints() -> void:
	_waypoints.clear()
	for n in patrol_points:
		if is_instance_valid(n):
			_waypoints.append(n)
	if _waypoints.is_empty() and patrol_route_parent != NodePath(""):
		var parent_node := get_node_or_null(patrol_route_parent)
		if parent_node:
			for c in parent_node.get_children():
				if c is Node2D:
					_waypoints.append(c as Node2D)
	if _waypoints.is_empty() and is_instance_valid(Goal):
		_waypoints.append(Goal)
	if _waypoints.is_empty():
		push_warning("Enemy: no patrol waypoints (set patrol_points, patrol_route_parent, or Goal).")


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_update_sight(delta)
	if debug_draw_cone:
		queue_redraw()

	if _attack_lock > 0.0:
		_attack_lock = maxf(0.0, _attack_lock - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		_stuck_frames = 0
		_update_animation()
		return

	if _update_combat_state():
		velocity = Vector2.ZERO
		move_and_slide()
		_stuck_frames = 0
		_update_animation()
		return

	_apply_movement(delta)
	move_and_slide()
	_update_stuck_recovery()
	_update_animation()


func _tick_cooldowns(delta: float) -> void:
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_gas_cd = maxf(0.0, _gas_cd - delta)
	_ranged_cd = maxf(0.0, _ranged_cd - delta)
	_melee_boost_left = maxf(0.0, _melee_boost_left - delta)
	_search_left = maxf(0.0, _search_left - delta)

func _update_sight(delta: float) -> void:
	_last_seen_player_left += delta
	_sees_player = false

	# Keep a best-effort player reference (DetectionArea sets it, but if that
	# doesn’t happen we try to find a player by group).
	if player == null or not is_instance_valid(player):
		var candidates := get_tree().get_nodes_in_group("Player")
		if not candidates.is_empty() and candidates[0] is Node2D:
			player = candidates[0] as Node2D

	if player == null or not is_instance_valid(player):
		return

	if _can_see_player():
		_sees_player = true
		_last_seen_player_left = 0.0
		_has_aggro = true
		_last_known_player_pos = player.global_position
		_search_left = search_time_after_los
	elif _has_aggro and _search_left > 0.0 and is_instance_valid(player):
		# Keep updating last known position while the player remains in the large
		# "See" awareness area, even if LOS is broken.
		if _in_see_area:
			_last_known_player_pos = player.global_position

	# Drop aggro if the player is far away for a while.
	if _has_aggro:
		var d := global_position.distance_to(player.global_position)
		if (not _in_see_area) and d > chase_lose_distance and _last_seen_player_left > sight_memory_time and _search_left <= 0.0:
			_has_aggro = false

func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	if dist <= 0.01:
		return true
	if dist > sight_distance:
		return false
	var fwd := _facing
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.RIGHT
	var to_n := to_p / dist
	var cos_limit := cos(deg_to_rad(sight_half_angle_deg))
	if fwd.normalized().dot(to_n) < cos_limit:
		return false

	# Confirm LOS with a ray that collides with obstacles + player.
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	q.exclude = [self]
	q.collision_mask = 1 | OBSTACLE_MASK
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	return hit.collider == player

func _draw() -> void:
	if not debug_draw_cone:
		return
	var fwd := _facing
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.RIGHT
	var half := deg_to_rad(sight_half_angle_deg)
	var dir_angle := fwd.angle()
	var steps := 28
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := dir_angle - half + (2.0 * half * t)
		pts.append(Vector2(cos(a), sin(a)) * sight_distance)
	draw_colored_polygon(pts, cone_color)
	draw_arc(Vector2.ZERO, sight_distance, dir_angle - half, dir_angle + half, 48, cone_edge_color, 2.0, true)


func _update_combat_state() -> bool:
	if player == null or not is_instance_valid(player):
		state = State.PATROL
		return false

	# Only start chasing/attacking after we’ve actually “seen” the player.
	if not _has_aggro:
		state = State.PATROL
		return false

	var dist := global_position.distance_to(player.global_position)
	_refresh_facing_from_intent(player.global_position - global_position)

	# Once aggro, we keep chasing until sight-memory expires (handled in _update_sight()).
	state = State.CHASE

	if dist <= melee_adjacent and _melee_cd <= 0.0:
		_do_melee()
		return true

	if dist > close_attack_radius and dist <= far_attack_radius:
		# Only shoot when we actually see the player (LOS).
		if _sees_player and _ranged_los_ok(dist) and _ranged_cd <= 0.0 and projectile_scene != null:
			_do_ranged()
			return true
		# If LOS is blocked but the player is still “in range”, drop a gas zone near them.
		if (not _sees_player) and _gas_cd <= 0.0 and gas_zone_scene != null:
			_do_gas_combat()
			return true

	return false


func _apply_movement(delta: float) -> void:
	match state:
		State.CHASE:
			_chase_repath_timer -= delta
			if _chase_repath_timer <= 0.0:
				_chase_repath_timer = CHASE_REPATH_INTERVAL
				_nav.target_position = _get_chase_target()
			var chase_target := _get_chase_target()
			var dist := global_position.distance_to(chase_target)
			var spd := chase_speed_aggro
			if _melee_boost_left > 0.0:
				spd = melee_boost_speed
			elif dist <= close_attack_radius:
				# Slow “pressure” chase near the player so they can still run.
				spd = chase_speed_close
			elif dist > close_attack_radius and dist <= far_attack_radius:
				# When in ranged band, keep chasing but slowly (so it can keep shooting).
				spd = chase_speed_aggro
			else:
				# Player is far; move faster to re-engage.
				spd = chase_speed
			_move_along_nav(spd, chase_target)
			_refresh_facing_from_velocity()
		_:
			_update_patrol(delta)
			if not _waypoints.is_empty():
				var target := _waypoints[_patrol_index].global_position
				_nav.target_position = target
				if _patrol_wait_left <= 0.0:
					_move_along_nav(patrol_speed, target)
					_refresh_facing_from_velocity()
				else:
					velocity = Vector2.ZERO


func _get_chase_target() -> Vector2:
	if player != null and is_instance_valid(player) and (_sees_player or _in_see_area):
		return player.global_position
	if _last_known_player_pos != Vector2.ZERO:
		return _last_known_player_pos
	return global_position


func _update_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		velocity = Vector2.ZERO
		return

	var target_pos := _waypoints[_patrol_index].global_position
	var arrived := _nav.is_navigation_finished() or global_position.distance_to(target_pos) <= _nav.target_desired_distance + 6.0

	if not arrived:
		_patrol_wait_left = 0.0
		return

	if _patrol_wait_left <= 0.0:
		_patrol_wait_left = randf_range(patrol_wait_min, patrol_wait_max)
		if randf() < gas_patrol_chance and _gas_cd <= 0.0 and gas_zone_scene != null:
			_spawn_patrol_gas()
			_gas_cd = gas_cooldown
	else:
		_patrol_wait_left -= delta
		if _patrol_wait_left <= 0.0:
			_last_patrol_index = _patrol_index
			_patrol_index = _pick_random_patrol_index_excluding(_last_patrol_index)
			_nav.target_position = _waypoints[_patrol_index].global_position


func _pick_random_patrol_index_excluding(exclude: int) -> int:
	var n := _waypoints.size()
	if n <= 0:
		return 0
	if n == 1:
		return 0
	if not random_patrol:
		return (_patrol_index + 1) % n
	var pick := randi() % n
	var guard := 0
	while pick == exclude and guard < 16:
		pick = randi() % n
		guard += 1
	return pick


func _move_along_nav(speed: float, goal_global: Vector2) -> void:
	var next_pos := _nav.get_next_path_position()
	var raw := next_pos - global_position
	if raw.length_squared() < 0.0001:
		velocity = Vector2.ZERO
		return
	var dir := raw.normalized()
	if not allow_diagonal_movement:
		var goal_dir := goal_global - global_position
		dir = _snap_cardinal(dir, goal_dir)
	velocity = dir * speed


## When the path wants a diagonal step, tie-break using the vector toward the ultimate goal
## so we do not flip X/Y every frame at corners (common cause of “stuck” jitter).
func _snap_cardinal(raw: Vector2, goal_dir: Vector2) -> Vector2:
	if raw.length_squared() < 0.0001:
		return Vector2.ZERO
	var ax := absf(raw.x)
	var ay := absf(raw.y)
	var tie := absf(ax - ay) < 0.12
	if tie and goal_dir.length_squared() > 0.0001:
		var g := goal_dir.normalized()
		if absf(g.x) >= absf(g.y):
			return Vector2(signf(g.x), 0.0)
		return Vector2(0.0, signf(g.y))
	if ax >= ay:
		return Vector2(signf(raw.x), 0.0)
	return Vector2(0.0, signf(raw.y))


func _update_stuck_recovery() -> void:
	if state == State.CHASE and player == null:
		return
	var intended := velocity.length() > 2.0
	var moved := get_real_velocity().length() > 6.0
	if intended and not moved:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	if _stuck_frames < 40:
		return
	_stuck_frames = 0
	if state == State.PATROL and not _waypoints.is_empty():
		_last_patrol_index = _patrol_index
		_patrol_index = _pick_random_patrol_index_excluding(_last_patrol_index)
		_nav.target_position = _waypoints[_patrol_index].global_position
	elif state == State.CHASE and player:
		_nav.target_position = player.global_position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))


func _refresh_facing_from_intent(to_target: Vector2) -> void:
	if to_target.length_squared() < 0.0001:
		return
	if allow_diagonal_movement:
		_facing = to_target.normalized()
	else:
		_facing = _snap_cardinal(to_target.normalized(), to_target)
	if _facing.length_squared() < 0.0001:
		_facing = Vector2.RIGHT
	if debug_draw_cone:
		queue_redraw()

func _refresh_facing_from_velocity() -> void:
	# Face the direction we're actually moving (next nav step / velocity),
	# not the final goal position. This makes the cone track cornering.
	if velocity.length_squared() < 4.0:
		return
	if allow_diagonal_movement:
		_facing = velocity.normalized()
	else:
		_facing = _snap_cardinal(velocity.normalized(), velocity)
	if _facing.length_squared() < 0.0001:
		_facing = Vector2.RIGHT
	if debug_draw_cone:
		queue_redraw()


func _ranged_los_ok(dist: float) -> bool:
	if player == null:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	q.exclude = [self]
	q.collision_mask = OBSTACLE_MASK
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var hit_d := global_position.distance_to(hit.position)
		if hit_d < dist - 3.0:
			return false
	return true


func _do_melee() -> void:
	_melee_cd = melee_cooldown
	_attack_lock = 0.25
	_melee_boost_left = melee_boost_time
	if player:
		_refresh_facing_from_intent(player.global_position - global_position)
	if _anim.sprite_frames and _anim.sprite_frames.has_animation("attackL"):
		_anim.play("attackL")
	_spawn_melee_hitbox()


func _spawn_melee_hitbox() -> void:
	if player == null:
		return

	var hitbox := Area2D.new()
	hitbox.name = "MeleeHitbox"
	hitbox.collision_layer = 8
	hitbox.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(8.0, melee_range)
	shape.shape = circle
	hitbox.add_child(shape)

	var to_player := player.global_position - global_position
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


func _do_ranged() -> void:
	_ranged_cd = ranged_cooldown
	_attack_lock = 0.15

	if player:
		_refresh_facing_from_intent(player.global_position - global_position)

	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	var dir := (player.global_position - global_position).normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	if proj.has_method("configure"):
		proj.call("configure", dir)
	get_tree().current_scene.add_child(proj)

func _do_gas_combat() -> void:
	_gas_cd = gas_cooldown
	_attack_lock = 0.2
	if player:
		_refresh_facing_from_intent(player.global_position - global_position)
	var gas := gas_zone_scene.instantiate()
	# Spawn slightly ahead of the player’s current position so it feels like an “attack” not a trail.
	var ppos := player.global_position if player else global_position
	var lead := Vector2.ZERO
	if player and player is Node2D:
		var to_p := (ppos - global_position)
		if to_p.length_squared() > 0.0001:
			lead = to_p.normalized() * 10.0
	gas.global_position = ppos + lead
	if gas.has_method("configure"):
		# Use a moderate radius in combat; patrol gas can still be larger.
		gas.call("configure", gas_duration, minf(gas_patrol_radius, 64.0))
	get_tree().current_scene.add_child(gas)


func _spawn_patrol_gas() -> void:
	if gas_zone_scene == null or _waypoints.is_empty():
		return
	_attack_lock = 0.2
	var gas := gas_zone_scene.instantiate()
	gas.global_position = _waypoints[_patrol_index].global_position
	if gas.has_method("configure"):
		gas.call("configure", gas_duration, gas_patrol_radius)
	get_tree().current_scene.add_child(gas)


func _update_animation() -> void:
	if _attack_lock > 0.0 and _anim.animation == "attackL":
		return
	if velocity.length_squared() < 4.0:
		if _anim.sprite_frames and _anim.sprite_frames.has_animation("Idle"):
			_anim.play("Idle")
		return
	if not _anim.sprite_frames:
		return
	if absf(velocity.y) > absf(velocity.x):
		if _anim.sprite_frames.has_animation("walkU"):
			_anim.play("walkU")
			_anim.flip_h = false
		elif _anim.sprite_frames.has_animation("walkD"):
			_anim.play("walkD")
			_anim.flip_h = false
	else:
		if _anim.sprite_frames.has_animation("walkD"):
			_anim.play("walkD")
			_anim.flip_h = velocity.x < 0.0


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body
		_in_see_area = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		_in_see_area = false
