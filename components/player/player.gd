class_name Player
extends CharacterBody2D

const SPEED := 100

func _process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * SPEED
	move_and_slide()
