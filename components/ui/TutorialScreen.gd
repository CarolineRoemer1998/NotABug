class_name TutorialScreen
extends Control

func _process(delta: float) -> void:
	if GameManager.current_game_state == GameManager.STATE.Tutorial:
		if Input.is_action_just_pressed("accept"):
			visible = false
			GameManager.current_game_state = GameManager.STATE.Playing
	if GameManager.current_game_state == GameManager.STATE.Playing:
		visible = false
		
