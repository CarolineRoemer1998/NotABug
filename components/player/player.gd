class_name Player
extends CharacterBody2D

@onready var fear_meter: ProgressBar = get_node_or_null("UI/FearMeter") as ProgressBar
@onready var life_meter: ProgressBar = get_node_or_null("UI/LifeMeter") as ProgressBar

@onready var timer_dash_cooldown: Timer = $TimerDashCooldown
@onready var animated_sprite_2d: AnimatedSprite2D = $Visuals/AnimatedSprite2D

@onready var timer_dash_duration: Timer = $TimerDashDuration
@export var dash_duration_in_seconds: float = 0.36
@export var dash_cooldown_in_seconds: float = 3.4

## World units per second (no parent scale — tuned for ~500px-wide maps at 480×270).
@export var speed_normal: float = 105.0
@export var speed_dash: float = 300.0

const percentage_for_scared_animations := 0.5

var current_speed := 0.0
var is_dashing := false
var dash_direction := Vector2.ZERO

@export var max_life: int = 10
@export var damage_iframe_seconds: float = 0.35
var _damage_iframe_left: float = 0.0
var _life: int = 0
var _dead: bool = false
var current_animation : String = ""

func _ready() -> void:
	add_to_group("Player")
	current_speed = speed_normal
	_life = max_life
	if life_meter != null:
		life_meter.max_value = max_life
		life_meter.value = max_life


func bind_life_meter(meter: ProgressBar) -> void:
	life_meter = meter
	if life_meter != null:
		life_meter.max_value = max_life
		life_meter.value = float(_life)

func _process(delta: float) -> void:
	if GameManager.current_game_state == GameManager.STATE.Playing:
		_damage_iframe_left = maxf(0.0, _damage_iframe_left - delta)
	if GameManager.current_game_state == GameManager.STATE.Lost \
			or GameManager.current_game_state == GameManager.STATE.Won:
		return
	handle_movement()
	handle_action_input()

func handle_movement():
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	print(input_direction)
	if input_direction != Vector2.ZERO:
		dash_direction = input_direction
	if is_dashing:
		velocity = dash_direction * current_speed
	else:
		velocity = input_direction * current_speed
	if input_direction[0] < 0:
		animated_sprite_2d.scale = Vector2(-1.0, 1.0)
	elif input_direction[0] > 0:
		animated_sprite_2d.scale = Vector2(1.0, 1.0)
	if velocity != Vector2.ZERO:
		if GameManager.current_fear / GameManager.init_fear > percentage_for_scared_animations:
			animated_sprite_2d.play("walk_scared")
		else:
			animated_sprite_2d.play("walk")
	else:
		if GameManager.current_fear / GameManager.init_fear > percentage_for_scared_animations:
			animated_sprite_2d.play("idle_scared")
		else:
			animated_sprite_2d.play("idle")
	move_and_slide()

func handle_action_input():
	if Input.is_action_just_pressed("dash"):
		if timer_dash_cooldown.time_left == 0:
			current_speed = speed_dash
			is_dashing = true
			timer_dash_cooldown.start(dash_cooldown_in_seconds)
			timer_dash_duration.start(dash_duration_in_seconds)

func _on_timer_dash_duration_timeout() -> void:
	is_dashing = false
	current_speed = speed_normal

func take_damage(amount: int) -> void:
	if _dead:
		return
	if amount <= 0:
		return
	if _damage_iframe_left > 0.0:
		return

	_damage_iframe_left = damage_iframe_seconds

	_life = maxi(0, _life - amount)
	if life_meter != null:
		if life_meter.max_value <= 0:
			life_meter.max_value = max_life
		life_meter.value = float(_life)

	if _life <= 0:
		_life = 0
		_dead = true
		_die()


func _die() -> void:
	GameManager.current_game_state = GameManager.STATE.Lost
	Signals.player_died.emit()
	collision_layer = 0
	collision_mask = 0
	if has_node("ItemDetector"):
		var idet := $ItemDetector as Area2D
		if idet:
			idet.set_deferred(&"monitoring", false)
			idet.set_deferred(&"monitorable", false)
	velocity = Vector2.ZERO
	is_dashing = false
	current_speed = speed_normal


func _on_item_detector_body_entered(item: Item) -> void:
	if item == null or not is_instance_valid(item):
		return
	# Prevent re-trigger loops when an item respawns under the player.
	if item.get_meta("collected", false):
		return
	item.set_meta("collected", true)

	# Disable collision immediately so we can't collect it again.
	item.collision_layer = 0
	item.collision_mask = 0
	if item.has_node("CollisionShape2D"):
		var cs := item.get_node("CollisionShape2D") as CollisionShape2D
		if cs:
			cs.disabled = true

	GameManager.reduce_fear(item)
	item.call_deferred("queue_free")
