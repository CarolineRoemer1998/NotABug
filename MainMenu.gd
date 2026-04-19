extends Control

const GAME_SCENE_PATH := "res://components/main/main.tscn"

const BASE_W := 1280.0
const BASE_H := 720.0

const BASE_TITLE_SIZE := 88
const BASE_BTN_SIZE   := 24

const BASE_MARGIN_L := 56
const BASE_MARGIN_T := 88
const BASE_MARGIN_R := 56
const BASE_MARGIN_B := 56
const BASE_SPACER_H := 52
const BASE_BTN_SEP  := 10

const HOVER_SHAKES := 7

@onready var _start_button:   Button          = %StartButton
@onready var _options_button: Button          = %OptionsButton
@onready var _exit_button:    Button          = %ExitButton
@onready var _title:          Label           = %Title
@onready var _title_spacer:   Control         = %TitleSpacer
@onready var _content:        MarginContainer = $Content

var _title_base_outline  := Color(0.1, 0.06, 0.04, 1.0)
var _title_glitch_outline := Color(0.65, 0.04, 0.04, 0.85)


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)

	for btn: Button in [_start_button, _options_button, _exit_button]:
		_setup_hover(btn)

	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_schedule_title_glitch()


func _schedule_title_glitch() -> void:
	# wait a calm interval, then fire one clean glitch sequence
	var t := create_tween()
	t.tween_interval(randf_range(2.8, 6.0))
	t.tween_callback(_do_title_glitch)


func _do_title_glitch() -> void:
	var t := create_tween()
	var snaps := randi_range(2, 3)

	# flash outline red at the very start
	t.tween_callback(func() -> void:
		_title.add_theme_color_override("font_outline_color", _title_glitch_outline)
	)

	for i in snaps:
		# instant snap to a horizontal offset — hold it for a short beat
		var offset := randf_range(-5.0, 5.0)
		var hold   := randf_range(0.04, 0.075)
		t.tween_property(_title, "position:x", offset, 0.0)
		t.tween_interval(hold)

	# snap back, restore outline, schedule the next glitch
	t.tween_property(_title, "position:x", 0.0, 0.0)
	t.tween_callback(func() -> void:
		_title.add_theme_color_override("font_outline_color", _title_base_outline)
		_schedule_title_glitch()
	)


func _setup_hover(button: Button) -> void:
	var orig := button.text
	var active := false
	var tween: Tween = null

	button.mouse_entered.connect(func() -> void:
		if tween:
			tween.kill()
		active = true
		button.text = orig
		button.add_theme_color_override("font_color", Color(0.84, 0.75, 0.65, 1.0))

		# rapid position jabs → snap to zero → hearts + pink
		tween = create_tween()
		for i in HOVER_SHAKES:
			tween.tween_property(button, "position:x",
				randf_range(-5.0, 5.0), 0.025)
		tween.tween_property(button, "position:x", 0.0, 0.02)
		tween.tween_callback(func() -> void:
			if active:
				button.text = "♥  " + orig + "  ♥"
				button.add_theme_color_override("font_color", Color(0.98, 0.9, 0.88, 1.0))
		)
	)

	button.mouse_exited.connect(func() -> void:
		if tween:
			tween.kill()
		active = false
		button.position.x = 0.0
		button.text = orig
		button.add_theme_color_override("font_color", Color(0.84, 0.75, 0.65, 1.0))
	)


func _on_viewport_resized() -> void:
	var vp   := get_viewport_rect().size
	var sx   := vp.x / BASE_W
	var sy   := vp.y / BASE_H

	_content.add_theme_constant_override("margin_left",   int(BASE_MARGIN_L * sx))
	_content.add_theme_constant_override("margin_top",    int(BASE_MARGIN_T * sy))
	_content.add_theme_constant_override("margin_right",  int(BASE_MARGIN_R * sx))
	_content.add_theme_constant_override("margin_bottom", int(BASE_MARGIN_B * sy))

	_title_spacer.custom_minimum_size.y = int(BASE_SPACER_H * sy)

	_title.add_theme_font_size_override(
		"font_size", int(clamp(BASE_TITLE_SIZE * sx, 40, 160)))

	for btn: Button in [_start_button, _options_button, _exit_button]:
		btn.add_theme_font_size_override(
			"font_size", int(clamp(BASE_BTN_SIZE * sx, 14, 44)))


func _on_start_pressed() -> void:
	if ResourceLoader.exists(GAME_SCENE_PATH):
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		push_error("MainMenu: missing scene at %s" % GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	print("Options: TODO")


func _on_exit_pressed() -> void:
	get_tree().quit()
