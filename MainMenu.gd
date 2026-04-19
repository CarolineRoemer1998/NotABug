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

const FONT_NORMAL := preload("res://fonts&themes/j_jerami/jJerami.ttf")
const FONT_HOVER  := preload("res://fonts&themes/fredoka/FredokaOne.woff2")
const HOVER_FONT_SIZE_DELTA := -3

const HOVER_LABEL_NUDGE_UP_PX := 1.0

const TITLE_GLITCH_SNAPS_MIN := 4
const TITLE_GLITCH_SNAPS_MAX := 6
const TITLE_GLITCH_HOLD_MIN := 0.06
const TITLE_GLITCH_HOLD_MAX := 0.11
const TITLE_GLITCH_FONT_SIZE_DELTA := -8

const TITLE_HOVER_RIGHT_PX := -50.0
const TITLE_HOVER_UP_PX := 20.0

@onready var _start_button:   Button          = %StartButton
@onready var _options_button: Button          = %OptionsButton
@onready var _exit_button:    Button          = %ExitButton
@onready var _title:          Label           = %Title
@onready var _title_top_pad:  Control         = %TitleTopPad
@onready var _title_left_pad: Control         = %TitleLeftPad
@onready var _title_spacer:   Control         = %TitleSpacer
@onready var _content:        MarginContainer = $Content

var _title_base_outline  := Color(0.1, 0.06, 0.04, 1.0)
var _title_glitch_outline := Color(0.65, 0.04, 0.04, 0.85)

var _title_font_size: int = BASE_TITLE_SIZE
var _btn_font_size: int = BASE_BTN_SIZE

var _title_top_pad_base := 0.0
var _title_left_pad_base := 0.0
var _title_hover_active := false


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)

	for btn: Button in [_start_button, _options_button, _exit_button]:
		_setup_hover(btn)

	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_schedule_title_glitch()

	_title.mouse_entered.connect(func() -> void:
		_title_hover_active = true
		_apply_title_hover_offsets()
	)
	_title.mouse_exited.connect(func() -> void:
		_title_hover_active = false
		_apply_title_hover_offsets()
	)


func _apply_title_hover_offsets() -> void:
	if not is_instance_valid(_title_top_pad) or not is_instance_valid(_title_left_pad):
		return

	if _title_hover_active:
		_title_top_pad.custom_minimum_size.y = maxf(0.0, _title_top_pad_base - TITLE_HOVER_UP_PX)
		_title_left_pad.custom_minimum_size.x = _title_left_pad_base + TITLE_HOVER_RIGHT_PX
	else:
		_title_top_pad.custom_minimum_size.y = _title_top_pad_base
		_title_left_pad.custom_minimum_size.x = _title_left_pad_base


func _schedule_title_glitch() -> void:
	var t := create_tween()
	t.tween_interval(randf_range(2.8, 6.0))
	t.tween_callback(_do_title_glitch)


func _do_title_glitch() -> void:
	var t := create_tween()
	var snaps := randi_range(TITLE_GLITCH_SNAPS_MIN, TITLE_GLITCH_SNAPS_MAX)

	t.tween_callback(func() -> void:
		_title.add_theme_font_override("font", FONT_HOVER)
		_title.add_theme_font_size_override(
			"font_size", maxi(12, _title_font_size + TITLE_GLITCH_FONT_SIZE_DELTA))
		_title.add_theme_color_override("font_outline_color", _title_glitch_outline)
	)

	for i in snaps:
		var offset := randf_range(-5.0, 5.0)
		var hold   := randf_range(TITLE_GLITCH_HOLD_MIN, TITLE_GLITCH_HOLD_MAX)
		t.tween_property(_title, "position:x", offset, 0.0)
		t.tween_interval(hold)

	t.tween_property(_title, "position:x", 0.0, 0.0)
	t.tween_callback(func() -> void:
		_title.add_theme_font_override("font", FONT_NORMAL)
		_title.add_theme_font_size_override("font_size", _title_font_size)
		_title.add_theme_color_override("font_outline_color", _title_base_outline)
		_schedule_title_glitch()
	)


func _stylebox_nudge_label_up(base: StyleBoxEmpty, up_px: float) -> StyleBoxEmpty:
	var sb := base.duplicate() as StyleBoxEmpty
	if up_px <= 0.0:
		return sb
	sb.content_margin_top = maxf(0.0, sb.content_margin_top - up_px)
	sb.content_margin_bottom = sb.content_margin_bottom + up_px
	return sb


func _setup_hover(button: Button) -> void:
	var orig := button.text
	var active := false
	var tween: Tween = null
	var base_hover_sb := button.get_theme_stylebox("hover").duplicate() as StyleBoxEmpty

	button.mouse_entered.connect(func() -> void:
		if tween:
			tween.kill()
		active = true
		button.text = orig
		button.add_theme_stylebox_override(
			"hover", _stylebox_nudge_label_up(base_hover_sb, HOVER_LABEL_NUDGE_UP_PX))
		button.add_theme_font_override("font", FONT_HOVER)
		button.add_theme_font_size_override(
			"font_size", maxi(12, _btn_font_size + HOVER_FONT_SIZE_DELTA))
		button.add_theme_color_override("font_color", Color(0.84, 0.75, 0.65, 1.0))

		tween = create_tween()
		for i in HOVER_SHAKES:
			tween.tween_property(button, "position:x",
				randf_range(-5.0, 5.0), 0.025)
		tween.tween_property(button, "position:x", 0.0, 0.02)
		tween.tween_callback(func() -> void:
			if active:
				button.text = orig + "  ♥"
				button.add_theme_color_override("font_color", Color(0.98, 0.9, 0.88, 1.0))
		)
	)

	button.mouse_exited.connect(func() -> void:
		if tween:
			tween.kill()
		active = false
		button.position.x = 0.0
		button.text = orig
		button.add_theme_stylebox_override("hover", base_hover_sb)
		button.add_theme_font_override("font", FONT_NORMAL)
		button.add_theme_font_size_override("font_size", _btn_font_size)
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

	_title_font_size = int(clamp(BASE_TITLE_SIZE * sx, 40, 160))
	_title.add_theme_font_size_override("font_size", _title_font_size)

	_title_top_pad_base = 0.0
	_title_left_pad_base = 0.0
	if is_instance_valid(_title_top_pad):
		_title_top_pad_base = _title_top_pad.custom_minimum_size.y
	if is_instance_valid(_title_left_pad):
		_title_left_pad_base = _title_left_pad.custom_minimum_size.x
	_apply_title_hover_offsets()

	_btn_font_size = int(clamp(BASE_BTN_SIZE * sx, 14, 44))
	for btn: Button in [_start_button, _options_button, _exit_button]:
		btn.add_theme_font_size_override("font_size", _btn_font_size)


func _on_start_pressed() -> void:
	if ResourceLoader.exists(GAME_SCENE_PATH):
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		push_error("MainMenu: missing scene at %s" % GAME_SCENE_PATH)


func _on_options_pressed() -> void:
	print("Options: TODO")


func _on_exit_pressed() -> void:
	get_tree().quit()
