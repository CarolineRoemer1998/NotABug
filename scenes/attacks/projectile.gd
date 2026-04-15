extends Area2D

@export var speed: float = 220.0
@export var damage: int = 1
@export var lifetime: float = 2.0

var _dir: Vector2 = Vector2.RIGHT

func configure(dir: Vector2) -> void:
	_dir = dir.normalized()
	rotation = _dir.angle()

func _physics_process(delta: float) -> void:
	global_position += _dir * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()
