extends Control

## Shared look & button hover behavior with MainMenu (end-of-run overlays).

const BASE_W := 1280.0
const BASE_H := 720.0

const BASE_TITLE_SIZE := 88
const BASE_BTN_SIZE := 24

const BASE_MARGIN_L := 56
const BASE_MARGIN_T := 88
const BASE_MARGIN_R := 56
const BASE_MARGIN_B := 56
const BASE_SPACER_H := 52

const HOVER_SHAKES := 7

const FONT_NORMAL := preload("res://fonts&themes/j_jerami/jJerami.ttf")
const FONT_HOVER := preload("res://fonts&themes/fredoka/FredokaOne.woff2")
const HOVER_FONT_SIZE_DELTA := -3
const HOVER_LABEL_NUDGE_UP_PX := 1.0

@export var headline: String = "Game over"
@export var retry_label: String = "Try again"
@export var quit_label: String = "Quit"

@onready var _title: Label = $Content/VBox/TitleRow/Title
@onready var _retry_button: Button = $Content/VBox/RetryButton
@onready var _quit_button: Button = $Content/VBox/QuitButton
@onready var _title_top_pad: Control = $Content/VBox/TitleTopPad
@onready var _title_spacer: Control = $Content/VBox/TitleSpacer
@onready var _vbox: VBoxContainer = $Content/VBox
@onready var _content: MarginContainer = $Content

var _title_font_size: int = BASE_TITLE_SIZE
var _btn_font_size: int = BASE_BTN_SIZE


func _ready() -> void:
	_title.text = headline
	_retry_button.text = retry_label
	_quit_button.text = quit_label

	_retry_button.pressed.connect(_on_retry_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	for btn: Button in [_retry_button, _quit_button]:
		_setup_hover(btn)

	get_viewport().size_changed.connect(_on_viewport_resized)
	visibility_changed.connect(_on_visibility_changed)
	_on_viewport_resized()

	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_visibility_changed() -> void:
	if visible:
		call_deferred("_on_viewport_resized")


func _center_content() -> void:
	if not is_instance_valid(_title_top_pad) or not is_instance_valid(_vbox):
		return
	var avail_h: float = _vbox.size.y
	if avail_h <= 0.0:
		return
	var content_h := 0.0
	for child: Node in _vbox.get_children():
		var c := child as Control
		if c == null or not c.visible or c == _title_top_pad:
			continue
		content_h += c.get_combined_minimum_size().y
	_title_top_pad.custom_minimum_size.y = maxf(0.0, (avail_h - content_h) / 2.0)


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
	var origin_x := 0.0

	button.mouse_entered.connect(func() -> void:
		if tween:
			tween.kill()
		active = true
		origin_x = button.position.x
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
				origin_x + randf_range(-5.0, 5.0), 0.025)
		tween.tween_property(button, "position:x", origin_x, 0.02)
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
		button.position.x = origin_x
		button.text = orig
		button.add_theme_stylebox_override("hover", base_hover_sb)
		button.add_theme_font_override("font", FONT_NORMAL)
		button.add_theme_font_size_override("font_size", _btn_font_size)
		button.add_theme_color_override("font_color", Color(0.84, 0.75, 0.65, 1.0))
	)


func _on_viewport_resized() -> void:
	var vp := get_viewport_rect().size
	var sx := vp.x / BASE_W
	var sy := vp.y / BASE_H

	_content.add_theme_constant_override("margin_left", int(BASE_MARGIN_L * sx))
	_content.add_theme_constant_override("margin_top", int(BASE_MARGIN_T * sy))
	_content.add_theme_constant_override("margin_right", int(BASE_MARGIN_R * sx))
	_content.add_theme_constant_override("margin_bottom", int(BASE_MARGIN_B * sy))

	_title_spacer.custom_minimum_size.y = int(BASE_SPACER_H * sy)

	_title_font_size = int(clamp(BASE_TITLE_SIZE * sx, 40, 160))
	_title.add_theme_font_size_override("font_size", _title_font_size)

	_btn_font_size = int(clamp(BASE_BTN_SIZE * sx, 14, 44))
	for btn: Button in [_retry_button, _quit_button]:
		btn.add_theme_font_size_override("font_size", _btn_font_size)

	call_deferred("_center_content")


func _on_retry_pressed() -> void:
	GameManager.reset_for_new_run()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()
