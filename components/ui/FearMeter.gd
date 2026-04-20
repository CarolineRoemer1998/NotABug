class_name FearMeter
extends ProgressBar

@onready var timer_glitch: Timer = $TimerGlitch
@onready var glitchoverlay: Sprite2D = $Glitch/Glitchoverlay

var shake_power := 0.006
var shake_color_rate := 0.006

func _ready() -> void:
	Signals.item_collected.connect(update_progress_bar)
	reset_glitch_shader()

func update_progress_bar(_item: Item):
	value = GameManager.current_fear
	var mat := glitchoverlay.material as ShaderMaterial
	mat.set_shader_parameter("shake_power", 0.05)
	mat.set_shader_parameter("shake_color_rate", 0.03)
	shake_power -= 0.002
	shake_color_rate -= 0.002
	timer_glitch.start()
	


func _on_timer_glitch_timeout() -> void:
	reset_glitch_shader()

func reset_glitch_shader():
	var mat := glitchoverlay.material as ShaderMaterial
	mat.set_shader_parameter("shake_power", shake_power)
	mat.set_shader_parameter("shake_rate", 1.0)
	mat.set_shader_parameter("shake_speed", 0.001)
	mat.set_shader_parameter("shake_block_size", 0.001)
	mat.set_shader_parameter("shake_color_rate", shake_color_rate)
	var fill_style := get_theme_stylebox("fill") as StyleBoxFlat
	fill_style.bg_color += Color(-0.05, 0.1, 0.03)
