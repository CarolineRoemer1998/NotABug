class_name FearMeter
extends ProgressBar

func _ready() -> void:
	Signals.item_collected.connect(update_progress_bar)

func update_progress_bar(_item: Item):
	value = GameManager.current_fear
