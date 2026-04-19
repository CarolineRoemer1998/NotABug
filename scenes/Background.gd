class_name Background
extends Node2D

@onready var normal_components: Node2D = $Visuals/NormalComponents

func _ready() -> void:
	Signals.item_collected.connect(reduce_fog)
	reduce_fog(null)

func reduce_fog(_item: Item):
	var modulate_val = 1-(GameManager.current_fear / GameManager.init_fear)
	normal_components.modulate = Color(1,1,1,modulate_val)
	
