extends ParallaxBackground

@onready var color_rect: ColorRect = $ParallaxLayer/ColorRect

func _ready() -> void:
	Signals.item_collected.connect(reduce_fog)

func reduce_fog(_item: Item):
	var modulate_val = (GameManager.current_fear / GameManager.init_fear)
	color_rect.modulate = Color(1,1,1,modulate_val)
	
