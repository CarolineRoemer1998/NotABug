# Signals.gd (Global)
extends Node

## Connected: GameManager, Item, später auch Enemy
signal item_collected(item: Item)
signal player_died()
signal game_won()
