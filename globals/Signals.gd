# Signals.gd (Global)
extends Node

## Connected: GameManager, Item, später auch Enemy
signal item_collected(item: Item)
signal all_items_collected()
signal player_died()
signal game_won()
