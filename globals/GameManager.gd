# GameManager.gd (Global)
extends Node

enum STATE { Tutorial, Playing, Won, Lost }

var current_health : float = 100.0
var current_fear : float = 100.0

var current_game_state : STATE = STATE.Tutorial

var collected_items : Array[Item] = []
