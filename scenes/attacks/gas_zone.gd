extends Area2D

@export var tick_damage: int = 1
@export var tick_interval: float = 0.5

var _time_left: float = 2.5
var _bodies: Array[Node2D] = []

@onready var _timer: Timer = $Timer

func configure(duration: float) -> void:
	_time_left = duration

func _ready() -> void:
	_timer.wait_time = tick_interval
	_timer.start()

func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not _bodies.has(body):
		_bodies.append(body)

func _on_body_exited(body: Node2D) -> void:
	_bodies.erase(body)

func _on_timer_timeout() -> void:
	for b in _bodies:
		if is_instance_valid(b) and b.has_method("take_damage"):
			b.call("take_damage", tick_damage)
