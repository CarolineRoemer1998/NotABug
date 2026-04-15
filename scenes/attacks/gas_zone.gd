extends Area2D

@export var tick_damage: int = 1
@export var tick_interval: float = 0.5
@export var debug_draw: bool = true
@export var draw_color: Color = Color(0.55, 0.95, 0.55, 0.25)

var _time_left: float = 2.5
var _bodies: Array[Node2D] = []

var _timer: Timer
var _collision_shape: CollisionShape2D


func configure(duration: float, radius: float = -1.0) -> void:
	_time_left = duration
	# `configure()` may be called immediately after `instantiate()` (before `_ready`),
	# so we must not rely on `@onready` references here.
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null and radius > 0.0 and cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = radius
	call_deferred("queue_redraw")


func _ready() -> void:
	_timer = get_node_or_null("Timer") as Timer
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D

	_timer.wait_time = tick_interval
	_timer.start()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _draw() -> void:
	if not debug_draw:
		return
	if _collision_shape == null or _collision_shape.shape == null:
		return
	if _collision_shape.shape is CircleShape2D:
		var r := (_collision_shape.shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, r, draw_color)
		# subtle edge for readability
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(draw_color.r, draw_color.g, draw_color.b, minf(0.8, draw_color.a + 0.25)), 2.0, true)


func _on_body_entered(body: Node2D) -> void:
	if not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)


func _on_timer_timeout() -> void:
	for b in _bodies:
		if is_instance_valid(b) and b.has_method("take_damage"):
			b.call("take_damage", tick_damage)
