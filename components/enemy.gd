extends CharacterBody2D

const OBSTACLE_MASK: int = 16

enum State { PATROL, CHASE, LOOK }

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

@export var sight_distance: float = 200.0
@export var sight_half_angle_deg: float = 65.0
## Omnidirectional close-range alert — enemy reacts even from behind.
@export var alert_radius: float = 200.0
@export var sight_memory_time: float = 2.0
## When chasing, the enemy becomes more alert (bigger effective sight/alert).
@export var chase_sight_distance_multiplier: float = 1.35
@export var chase_alert_radius_multiplier: float = 1.15
@export var chase_tracking_grace_time: float = 1.0
@export var chase_lose_distance: float = 300.0
@export var search_time_after_los: float = 3.0
@export var min_aggro_time: float = 4.0
@export var look_around_time_after_chase: float = 2.2
@export var look_turn_interval_min: float = 0.25
@export var look_turn_interval_max: float = 0.65
@export var look_turn_speed: float = 9.0
@export var look_focus_last_known_chance: float = 0.55
@export var look_angle_jitter_deg: float = 35.0
@export var look_pause_chance: float = 0.18

## Enemy-to-enemy “soft communication”: when one enemy sees the player, it can alert
## nearby enemies to investigate the last known area (no perfect tracking).
@export var ally_alert_radius: float = 220.0
@export var ally_alert_cooldown: float = 2.0
@export var ally_investigate_time: float = 3.0

## Omnidirectional “hearing” behavior: close presence triggers a search instead of instant chase.
@export var hearing_cooldown: float = 0.7
@export var hearing_freeze_time: float = 0.55
@export var hearing_look_min: float = 0.8
@export var hearing_look_max: float = 1.6

@export var close_attack_radius: float = 70.0
@export var far_attack_radius: float = 220.0
@export var melee_adjacent: float = 22.0
@export var melee_damage: int = 1
@export var melee_range: float = 44.0

@export var melee_cooldown: float = 0.9
@export var gas_cooldown: float = 5.0
@export var ranged_cooldown: float = 1.6

@export var gas_duration: float = 10.0
@export var gas_patrol_radius: float = 72.0
@export var gas_patrol_chance: float = 0.1
@export var gas_combat_radius: float = 96.0

@export var projectile_scene: PackedScene
@export var gas_zone_scene: PackedScene

@export var debug_draw_cone: bool = true
@export var cone_color: Color = Color(1.0, 0.2, 0.9, 0.12)
@export var cone_edge_color: Color = Color(1.0, 0.2, 0.9, 0.45)

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D3
@onready var _indicator: Label = get_node_or_null("StateIndicator") as Label

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
var _in_cone: bool = false
var _aggro_hold_left: float = 0.0
var _look_left: float = 0.0
var _look_turn_left: float = 0.0
var _look_target_facing: Vector2 = Vector2.RIGHT

var _melee_cd: float = 0.0
var _gas_cd: float = 0.0
var _ranged_cd: float = 0.0
var _attack_lock: float = 0.0

var _chase_repath_timer: float = 0.0
@export var chase_repath_interval: float = 0.18

var _ally_alert_cd: float = 0.0
var _investigate_left: float = 0.0
var _investigate_pos: Vector2 = Vector2.ZERO
var _hearing_cd: float = 0.0
var _hearing_freeze_left: float = 0.0


func _ready() -> void:
	add_to_group("Enemies")
	_build_waypoints()
	far_attack_radius = minf(far_attack_radius, sight_distance)
	melee_adjacent = maxf(melee_adjacent, melee_range)
	_nav.path_desired_distance = 10.0
	_nav.target_desired_distance = 16.0
	_nav.radius = 11.0
	call_deferred("_deferred_nav_setup")


func _deferred_nav_setup() -> void:
	await get_tree().physics_frame
	if _waypoints.is_empty():
		return
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
		return
	if random_patrol and _waypoints.size() > 1:
		_waypoints.shuffle()


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_update_sight(delta)
	_update_state_from_awareness(delta)
	_update_indicator()
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
	_aggro_hold_left = maxf(0.0, _aggro_hold_left - delta)
	_ally_alert_cd = maxf(0.0, _ally_alert_cd - delta)
	_investigate_left = maxf(0.0, _investigate_left - delta)
	_hearing_cd = maxf(0.0, _hearing_cd - delta)
	_hearing_freeze_left = maxf(0.0, _hearing_freeze_left - delta)

func _update_sight(delta: float) -> void:
	var had_aggro := _has_aggro
	_last_seen_player_left += delta
	_sees_player = false
	_in_cone = false

	if player == null or not is_instance_valid(player):
		var candidates := get_tree().get_nodes_in_group("Player")
		if not candidates.is_empty() and candidates[0] is Node2D:
			player = candidates[0] as Node2D

	if player == null or not is_instance_valid(player):
		return
	_in_cone = _player_in_cone()

	if not _has_aggro and _hearing_cd <= 0.0 and _heard_player_close():
		_hearing_cd = hearing_cooldown
		_hearing_freeze_left = maxf(_hearing_freeze_left, hearing_freeze_time)
		_last_known_player_pos = player.global_position
		_search_left = maxf(_search_left, search_time_after_los)
		_look_left = maxf(_look_left, randf_range(hearing_look_min, hearing_look_max))
		_pick_new_look_target(true)

	if _can_see_player():
		_sees_player = true
		_last_seen_player_left = 0.0
		_has_aggro = true
		_aggro_hold_left = min_aggro_time
		_last_known_player_pos = player.global_position
		_search_left = search_time_after_los
		if not had_aggro:
			_broadcast_ally_alert(player.global_position)
	elif _has_aggro and _search_left > 0.0 and is_instance_valid(player):

		if _last_seen_player_left <= chase_tracking_grace_time and (_in_cone or _in_see_area):
			_last_known_player_pos = player.global_position

	if _has_aggro and _aggro_hold_left <= 0.0 and _last_seen_player_left > sight_memory_time and _search_left <= 0.0:
		var d_to_last := global_position.distance_to(_last_known_player_pos)
		var d_to_player := global_position.distance_to(player.global_position)
		var extremely_far := d_to_player > maxf(chase_lose_distance, _current_sight_distance()) * 2.0
		if d_to_last <= alert_radius or extremely_far:
			_has_aggro = false
	if had_aggro and not _has_aggro:
		_look_left = maxf(_look_left, look_around_time_after_chase)
		_pick_new_look_target(true)


func _update_state_from_awareness(delta: float) -> void:
	_look_left = maxf(0.0, _look_left - delta)
	if _has_aggro:
		state = State.CHASE
		return
	if _look_left > 0.0:
		state = State.LOOK
		return
	state = State.PATROL

func _player_in_cone() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	if dist <= 0.01:
		return true
	if dist > _current_sight_distance():
		return false
	var fwd := _facing
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.RIGHT
	var to_n := to_p / dist
	var cos_limit := cos(deg_to_rad(sight_half_angle_deg))
	return fwd.normalized().dot(to_n) >= cos_limit

func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var to_p := player.global_position - global_position
	var dist := to_p.length()
	if dist <= 0.01:
		return true

	if dist > _current_sight_distance():
		return false
	var fwd := _facing
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.RIGHT
	var to_n := to_p / dist
	var cos_limit := cos(deg_to_rad(sight_half_angle_deg))
	if fwd.normalized().dot(to_n) < cos_limit:
		return false

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
	var gscale := maxf(global_transform.get_scale().x, 0.001)
	var draw_sight := _current_sight_distance() / gscale
	var draw_alert := _current_alert_radius() / gscale

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
		pts.append(Vector2(cos(a), sin(a)) * draw_sight)
	draw_colored_polygon(pts, cone_color)
	draw_arc(Vector2.ZERO, draw_sight, dir_angle - half, dir_angle + half, 48, cone_edge_color, 2.0, true)
	draw_arc(Vector2.ZERO, draw_alert, 0.0, TAU, 32, Color(1.0, 0.6, 0.1, 0.5), 1.5, true)


func _update_combat_state() -> bool:
	if player == null or not is_instance_valid(player):
		state = State.PATROL
		return false

	if not _has_aggro:
		return false

	var dist := global_position.distance_to(player.global_position)
	_refresh_facing_from_intent(player.global_position - global_position)

	if dist <= maxf(melee_adjacent, melee_range) and _melee_cd <= 0.0:
		_do_melee()
		return true

	if dist > close_attack_radius and dist <= far_attack_radius:
		if _ranged_cd <= 0.0 and projectile_scene != null:
			var target_pos := player.global_position if _sees_player else _last_known_player_pos
			if target_pos != Vector2.ZERO and _ranged_los_ok_to(target_pos):
				_do_ranged_toward(target_pos)
				return true

	return false


func _apply_movement(delta: float) -> void:
	if not _has_aggro and _hearing_freeze_left > 0.0:
		velocity = Vector2.ZERO
		return
	match state:
		State.CHASE:
			_chase_repath_timer -= delta
			if _chase_repath_timer <= 0.0:
				_chase_repath_timer = chase_repath_interval
				_nav.target_position = _get_chase_target()
			var chase_target := _get_chase_target()
			var dist := global_position.distance_to(chase_target)
			var spd := chase_speed_aggro
			if _melee_boost_left > 0.0:
				spd = melee_boost_speed
			elif dist <= close_attack_radius:
				spd = chase_speed_close
			elif dist > close_attack_radius and dist <= far_attack_radius:
				spd = chase_speed_aggro
			else:
				spd = chase_speed
			_move_along_nav(spd, chase_target)
			_refresh_facing_from_velocity()
		State.LOOK:
			velocity = Vector2.ZERO
			_look_turn_left -= delta
			if _look_turn_left <= 0.0:
				_pick_new_look_target(false)
			if _look_target_facing.length_squared() > 0.0001:
				var t := 1.0 - exp(-look_turn_speed * delta)
				_facing = (_facing.lerp(_look_target_facing, clampf(t, 0.0, 1.0))).normalized()
				if _facing.length_squared() < 0.0001:
					_facing = Vector2.RIGHT
				if debug_draw_cone:
					queue_redraw()
		_:
			_update_patrol(delta)
			if not _waypoints.is_empty():
				var target := _waypoints[_patrol_index].global_position
				if _investigate_left > 0.0 and _investigate_pos != Vector2.ZERO:
					target = _investigate_pos
				_nav.target_position = target
				if _patrol_wait_left <= 0.0:
					_move_along_nav(patrol_speed, target)
					_refresh_facing_from_velocity()
				else:
					velocity = Vector2.ZERO


func _get_chase_target() -> Vector2:
	if player != null and is_instance_valid(player):
		if _sees_player:
			return player.global_position
		if _has_aggro and _last_seen_player_left <= chase_tracking_grace_time and (_in_cone or _in_see_area):
			return player.global_position
	if _last_known_player_pos != Vector2.ZERO:
		return _last_known_player_pos
	return global_position


func _current_sight_distance() -> float:
	if _has_aggro:
		return sight_distance * chase_sight_distance_multiplier
	return sight_distance


func _current_alert_radius() -> float:
	if _has_aggro:
		return alert_radius * chase_alert_radius_multiplier
	return alert_radius


func _heard_player_close() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= _current_alert_radius()


func _pick_new_look_target(_just_lost: bool) -> void:
	_look_turn_left = randf_range(look_turn_interval_min, look_turn_interval_max)

	if randf() < look_pause_chance:
		_look_target_facing = _facing
		return

	var base_dir := _facing
	if _just_lost or (randf() < look_focus_last_known_chance):
		var to_last := _last_known_player_pos - global_position
		if to_last.length_squared() > 0.0001:
			base_dir = to_last.normalized()

	var jitter := deg_to_rad(randf_range(-look_angle_jitter_deg, look_angle_jitter_deg))
	_look_target_facing = base_dir.rotated(jitter).normalized()
	if _look_target_facing.length_squared() < 0.0001:
		_look_target_facing = Vector2.RIGHT


func _broadcast_ally_alert(player_pos: Vector2) -> void:
	if _ally_alert_cd > 0.0:
		return
	_ally_alert_cd = ally_alert_cooldown
	if ally_alert_radius <= 0.0:
		return
	for n in get_tree().get_nodes_in_group("Enemies"):
		if n == self:
			continue
		if n is Node2D:
			var other := n as Node2D
			if other.global_position.distance_to(global_position) <= ally_alert_radius:
				if other.has_method("receive_alert"):
					other.call("receive_alert", player_pos)


func receive_alert(player_pos: Vector2) -> void:
	if _has_aggro:
		return
	_last_known_player_pos = player_pos
	_investigate_pos = player_pos
	_investigate_left = maxf(_investigate_left, ally_investigate_time)
	_look_left = maxf(_look_left, randf_range(0.5, 1.2))
	_pick_new_look_target(true)


func _update_indicator() -> void:
	if _indicator == null:
		return
	if _has_aggro:
		_indicator.visible = true
		_indicator.text = "!"
		_indicator.modulate = Color(1.0, 0.2, 0.2, 1.0)
		return
	if _look_left > 0.0 or _search_left > 0.0 or _investigate_left > 0.0:
		_indicator.visible = true
		_indicator.text = "?"
		_indicator.modulate = Color(1.0, 0.92, 0.25, 1.0)
		return
	_indicator.visible = false


func _update_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		velocity = Vector2.ZERO
		return

	var target_pos := _waypoints[_patrol_index].global_position
	if _investigate_left > 0.0 and _investigate_pos != Vector2.ZERO:
		target_pos = _investigate_pos
	var arrived := _nav.is_navigation_finished() or global_position.distance_to(target_pos) <= _nav.target_desired_distance + 6.0

	if not arrived:
		_patrol_wait_left = 0.0
		return

	if _investigate_left > 0.0 and _investigate_pos != Vector2.ZERO:
		_investigate_left = 0.0
		_investigate_pos = Vector2.ZERO
		_look_left = maxf(_look_left, randf_range(0.7, 1.4))
		_pick_new_look_target(true)
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
			_patrol_index = (_patrol_index + 1) % _waypoints.size()
			_nav.target_position = _waypoints[_patrol_index].global_position


func _pick_random_patrol_index_excluding(_exclude: int) -> int:
	var n := _waypoints.size()
	if n <= 0:
		return 0
	if n == 1:
		return 0
	return (_patrol_index + 1) % n


func _move_along_nav(speed: float, goal_global: Vector2) -> void:
	var next_pos := _nav.get_next_path_position()
	var raw := next_pos - global_position
	if raw.length_squared() < 0.0001:
		velocity = Vector2.ZERO
		return
	var dir := raw.normalized()
	if velocity.length_squared() > 4.0:
		var last_dir := velocity.normalized()
		if last_dir.length_squared() > 0.0001 and dir.dot(last_dir) < -0.15 and raw.length() < 10.0:
			dir = last_dir
		elif last_dir.length_squared() > 0.0001:
			dir = (last_dir * 0.65 + dir * 0.35).normalized()
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
		_patrol_index = (_patrol_index + 1) % _waypoints.size()
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


func _ranged_los_ok_to(target_pos: Vector2) -> bool:
	if target_pos == Vector2.ZERO:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, target_pos)
	q.exclude = [self]
	q.collision_mask = OBSTACLE_MASK
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var hit_d := global_position.distance_to(hit.position)
		var tgt_d := global_position.distance_to(target_pos)
		if hit_d < tgt_d - 3.0:
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


func _do_ranged_toward(target_pos: Vector2) -> void:
	_ranged_cd = ranged_cooldown
	_attack_lock = 0.15

	if player:
		_refresh_facing_from_intent(target_pos - global_position)

	var proj := projectile_scene.instantiate()
	var dir := (target_pos - global_position).normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	proj.global_position = global_position + dir * 12.0
	if proj.has_method("configure"):
		proj.call("configure", dir)
	get_tree().current_scene.add_child(proj)


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
