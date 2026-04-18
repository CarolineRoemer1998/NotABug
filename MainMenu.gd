extends Control

const GAME_SCENE_PATH := "res://components/main/main.tscn"

@onready var _start_button: Button = %StartButton
@onready var _options_button: Button = %OptionsButton
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _on_start_pressed() -> void:
	if ResourceLoader.exists(GAME_SCENE_PATH):
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		push_error("MainMenu: missing scene at %s" % GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	print("Options: TODO")


func _on_exit_pressed() -> void:
	get_tree().quit()

