class_name HealthMeter
extends ProgressBar

@onready var timer_glitch: Timer = $TimerGlitch
@onready var glitchoverlay: Sprite2D = $Sprite2D

var shake_power := 0.002
var shake_color_rate := 0.002

func _ready() -> void:
	print("_ready")
	reset_glitch_shader()

func _on_timer_glitch_timeout() -> void:
	print("_on_timer_glitch_timeout")
	reset_glitch_shader()
#
func reset_glitch_shader():
	print("reset_glitch_shader")
	var mat := glitchoverlay.material as ShaderMaterial
	mat.set_shader_parameter("shake_power", shake_power)
	mat.set_shader_parameter("shake_rate", 1.0)
	mat.set_shader_parameter("shake_speed", 0.001)
	mat.set_shader_parameter("shake_block_size", 0.001)
	mat.set_shader_parameter("shake_color_rate", shake_color_rate)



func _on_value_changed(value):
	print("_on_value_changed")
	var mat := glitchoverlay.material as ShaderMaterial
	mat.set_shader_parameter("shake_power", 0.005)
	mat.set_shader_parameter("shake_color_rate", 0.03)
	shake_power += 0.003
	shake_color_rate += 0.002
	var fill_style := get_theme_stylebox("fill") as StyleBoxFlat
	fill_style.bg_color += Color(0.4, -0.1, -0.1)
	
	timer_glitch.start()
