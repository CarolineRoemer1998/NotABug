class_name Main
extends Node2D

@onready var dev_ui: Control = $UI/DevUI
@onready var lose_screen: Control = $UI/LoseScreen
@onready var win_screen: Control = $UI/WinScreen
@onready var bgm_player = $bgm_player
@onready var fog: Node = $UI/Fog
@onready var tutorial_screen: CanvasItem = $UI/TutorialScreen

@onready var sfx_gameover: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
@onready var sfx_fail_jingle: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
@onready var sfx_win_tada: AudioStreamPlayer2D = AudioStreamPlayer2D.new()

@export var spawn_points : Array[Node2D]
@export var item_variants : Dictionary[ItemData, bool] # true: ItemData hat SpawnPoint zugewiesen bekommen

const ITEM : PackedScene = preload("res://components/items/item.tscn")


func _ready() -> void:
	GameManager.reset_for_new_run()

	#TODO BGM leiser machen mit jedem gesammelten Item?
	bgm_player.stream = preload("res://sound/407461__loyalty_freak_music__anxiety-2.mp3")
	bgm_player.play()

	# One-shot UI SFX
	sfx_gameover.name = "sfx_gameover"
	sfx_fail_jingle.name = "sfx_fail_jingle"
	sfx_win_tada.name = "sfx_win_tada"
	add_child(sfx_gameover)
	add_child(sfx_fail_jingle)
	add_child(sfx_win_tada)
	sfx_gameover.stream = preload("res://sound/585797__colorscrimsontears__gameover.wav")
	sfx_fail_jingle.stream = preload("res://sound/825292__qubodup__fail-jingle-party-horn.wav")
	sfx_win_tada.stream = preload("res://sound/850021__yoshicakes77__tada.wav")
	# Volume balance for game over
	sfx_gameover.volume_db = 2.0
	sfx_fail_jingle.volume_db = -10.0
 	
	lose_screen.visible = false
	win_screen.visible = false
	spawn_items()
	var p := $Game/Player2 as Player
	if p:
		p.bind_life_meter($UI2/HUD/HealthMeter as ProgressBar)
	if not Signals.player_died.is_connected(_on_player_died):
		Signals.player_died.connect(_on_player_died)
	if not Signals.game_won.is_connected(_on_game_won):
		Signals.game_won.connect(_on_game_won)

func spawn_items():
	for spawn in spawn_points:
		var random_item_variant = get_random_item_variant()
		if random_item_variant != null:
			var new_item = Item.get_new_item(random_item_variant)
			spawn.add_child(new_item)

func get_random_item_variant() -> ItemData:
	var available_items: Array[ItemData] = []

	for variant in item_variants.keys():
		if item_variants[variant] == false:
			available_items.append(variant)

	if available_items.is_empty():
		return null

	var random_variant: ItemData = available_items.pick_random()
	item_variants[random_variant] = true
	return random_variant

func _process(delta: float) -> void:
	handle_inputs()

func handle_inputs():
	if Input.is_action_just_pressed("end_game"):
		get_tree().quit()
	elif Input.is_action_just_pressed("reload_game"):
		get_tree().reload_current_scene()
	elif Input.is_action_just_pressed("show_or_hide_dev_tools"):
		dev_ui.visible = !dev_ui.visible


func _on_player_died() -> void:
	if bgm_player and bgm_player.playing:
		bgm_player.stop()
	if sfx_win_tada and sfx_win_tada.playing:
		sfx_win_tada.stop()
	if sfx_gameover:
		sfx_gameover.play()
	if sfx_fail_jingle:
		sfx_fail_jingle.stop()
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(sfx_fail_jingle):
			sfx_fail_jingle.play()

	# Fog / Tutorial use top_level nodes that can draw above and block clicks on siblings below.
	if fog:
		fog.visible = false
	if tutorial_screen:
		tutorial_screen.visible = false
	lose_screen.visible = true
	lose_screen.move_to_front()


func _on_game_won() -> void:
	if fog:
		fog.visible = false
	if tutorial_screen:
		tutorial_screen.visible = false
	await get_tree().create_timer(maxf(0.0, GameManager.win_delay_seconds)).timeout
	if bgm_player and bgm_player.playing:
		bgm_player.stop()
	if sfx_gameover and sfx_gameover.playing:
		sfx_gameover.stop()
	if sfx_fail_jingle and sfx_fail_jingle.playing:
		sfx_fail_jingle.stop()
	if sfx_win_tada:
		sfx_win_tada.play()
	win_screen.visible = true
	win_screen.move_to_front()
