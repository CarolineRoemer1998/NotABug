class_name Main
extends Node2D

@onready var dev_ui: Control = $UI/DevUI
@onready var lose_screen: Control = $UI/LoseScreen
@onready var win_screen: Control = $UI/WinScreen

@export var spawn_points : Array[Node2D]
@export var item_variants : Dictionary[ItemData, bool] # true: ItemData hat SpawnPoint zugewiesen bekommen

const ITEM : PackedScene = preload("res://components/items/item.tscn")


func _ready() -> void:
	lose_screen.visible = false
	win_screen.visible = false
	spawn_items()
	var p := $Game/Player2 as Player
	if p:
		p.bind_life_meter($UI/HUD/HealthMeter as ProgressBar)
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
	lose_screen.visible = true


func _on_game_won() -> void:
	win_screen.visible = true
