class_name Item
extends StaticBody2D

enum TYPE { Hat, MeleeWeapon, RangedWeapon, Shoes, Mouth, Top, Bottom } # nicht final

@onready var sprite_2d_as_collectable_item: AnimatedSprite2D = $Visuals/Sprite2D_AsCollectableItem
@onready var sprite_2d_as_worn_by_enemy: Sprite2D = $Visuals/Sprite2D_AsWornByEnemy

const ITEM : PackedScene = preload("res://components/items/item.tscn")

var item_data : ItemData

static func get_new_item(_item_data: ItemData) -> Item:
	var new_item := ITEM.instantiate() as Item
	new_item.item_data = _item_data
	return new_item

func _ready() -> void:
	Signals.item_collected.connect(handle_item_collected)
	set_data()
	sprite_2d_as_collectable_item.play("floating")

func handle_item_collected(_item: Item):
	if _item == self:
		queue_free()

func set_data():
	name = item_data.item_name
	sprite_2d_as_collectable_item.sprite_frames = item_data.item_texture
	if item_data.wearable_texture != null:
		sprite_2d_as_worn_by_enemy.texture = item_data.wearable_texture
