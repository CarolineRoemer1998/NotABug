# GameManager.gd (Global)
extends Node

enum STATE { Tutorial, Playing, Won, Lost }

var current_health : float = 100.0
var current_fear : float = 100.0

var current_game_state : STATE = STATE.Playing # TODO: zurück zu Tutorial ändern für Export

var collected_items : Array[Item] = []

func _ready() -> void:
	Signals.item_collected.connect(handle_item_collected)

func handle_item_collected(item: Item):
	collected_items.append(item)
	print(collected_items)

func reduce_fear(item: Item):
	var amount_fear_reduction := item.item_data.fear_reduction
	current_fear -= amount_fear_reduction
	Signals.item_collected.emit(item)
