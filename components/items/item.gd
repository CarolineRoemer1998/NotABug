class_name Item
extends Node2D

enum TYPE { Hat, MeleeWeapon, RangedWeapon, Shoes, Mouth, Top, Bottom } # nicht final

@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D

const ITEM : PackedScene = preload("res://components/items/item.tscn")

var item_data : ItemData

static func get_new_item(_item_data: ItemData):
	var new_item = ITEM.instantiate()
	new_item.item_data = _item_data
	return new_item

func _ready() -> void:
	set_data()
	print(name, ": ", global_position)

func set_data():
	name = item_data.item_name
	sprite_2d.texture = item_data.item_texture
