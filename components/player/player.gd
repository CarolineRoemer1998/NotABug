class_name Player
extends CharacterBody2D

@onready var fear_meter: ProgressBar = $UI/FearMeter
@onready var life_meter: ProgressBar = $UI/LifeMeter

@onready var timer_dash_cooldown: Timer = $TimerDashCooldown
var dash_cooldown_in_seconds := 3.0

@onready var timer_dash_duration: Timer = $TimerDashDuration
var dash_duration_in_seconds := 0.3

const SPEED_NORMAL := 100.0
const SPEED_DASH := 300.0

var current_speed := SPEED_NORMAL
var is_dashing := false
var dash_direction := Vector2.ZERO

func _process(delta: float) -> void:
	if GameManager.current_game_state == GameManager.STATE.Playing:
		handle_movement()
		handle_action_input()

func handle_movement():
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != Vector2.ZERO:
		dash_direction = input_direction
	if is_dashing:
		velocity = dash_direction * current_speed
	else:
		velocity = input_direction * current_speed
	move_and_slide()

func handle_action_input():
	if Input.is_action_just_pressed("dash"):
		if timer_dash_cooldown.time_left == 0:
			current_speed = SPEED_DASH
			is_dashing = true
			timer_dash_cooldown.start(dash_cooldown_in_seconds)
			timer_dash_duration.start(dash_duration_in_seconds)

func _on_timer_dash_duration_timeout() -> void:
	is_dashing = false
	current_speed = SPEED_NORMAL


func _on_item_detector_body_entered(item: Item) -> void:
	GameManager.reduce_fear(item)
	
