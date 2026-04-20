class_name FearMeter
extends ProgressBar

@onready var timer_glitch: Timer = $TimerGlitch
@onready var glitchoverlay: Sprite2D = $Glitch/Glitchoverlay

var shake_power := 0.006
var shake_color_rate := 0.006
var base_fill_color: Color

func _ready() -> void:
	Signals.item_collected.connect(update_progress_bar)

	var fill_style := get_theme_stylebox("fill") as StyleBoxFlat
	var fill_style_copy := fill_style.duplicate() as StyleBoxFlat
	add_theme_stylebox_override("fill", fill_style_copy)
	base_fill_color = fill_style_copy.bg_color + Color(-0.05, 0.1, 0.03)

	if glitchoverlay.material != null:
		glitchoverlay.material = glitchoverlay.material.duplicate()

	reset_runtime_state()
	reset_glitch_shader()

func reset_runtime_state() -> void:
	shake_power = 0.006
	shake_color_rate = 0.006

	var fill_style := get_theme_stylebox("fill") as StyleBoxFlat
	fill_style.bg_color = base_fill_color

func update_progress_bar(_item: Item) -> void:
	value = GameManager.current_fear

	var mat := glitchoverlay.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("shake_power", 0.05)
		mat.set_shader_parameter("shake_color_rate", 0.03)

	shake_power -= 0.002
	shake_color_rate -= 0.002
	timer_glitch.start()

func _on_timer_glitch_timeout() -> void:
	reset_glitch_shader()

func reset_glitch_shader() -> void:
	var mat := glitchoverlay.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("shake_power", shake_power)
	mat.set_shader_parameter("shake_rate", 1.0)
	mat.set_shader_parameter("shake_speed", 0.001)
	mat.set_shader_parameter("shake_block_size", 0.001)
	mat.set_shader_parameter("shake_color_rate", shake_color_rate)

	var fill_style := get_theme_stylebox("fill") as StyleBoxFlat
	fill_style.bg_color = base_fill_color
