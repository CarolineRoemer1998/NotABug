class_name Main
extends Node2D

@export var spawn_points : Array[Node2D]
@export var item_variants : Dictionary[ItemData, bool] # true: ItemData hat SpawnPoint zugewiesen bekommen

const ITEM : PackedScene = preload("res://components/items/item.tscn")


func _ready() -> void:
	spawn_items()

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
