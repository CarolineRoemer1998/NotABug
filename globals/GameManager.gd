# GameManager.gd (Global)
extends Node

enum STATE { Tutorial, Playing, Won, Lost }

var init_health : float = 100.0
var init_fear : float = 100.0
var current_health : float = init_health
var current_fear : float = init_fear
## 0 = none, 1 = one cosmetic, 2 = two-token combo, 3 = Alles / win
enum Phase { None, OneItem, TwoItems, AllItems }

var current_game_state: STATE = STATE.Playing

var collected_items: Array[Item] = []


func is_game_ended() -> bool:
	return current_game_state == STATE.Won or current_game_state == STATE.Lost


## Autoload survives `reload_current_scene()`; reset run state whenever the level scene loads.
func reset_for_new_run() -> void:
	current_game_state = STATE.Playing
	current_health = init_health
	current_fear = init_fear
	collected_items.clear()
	cosmetic_order.clear()
	disabled_attacks.clear()
	phase = Phase.None


## Order the player picked up Handschuhe / Trompete / Brille (max 3).
var cosmetic_order: Array[String] = []

## Which attacks are disabled by those items: "Slash", "Gas", "Distance"
var disabled_attacks: Dictionary = {}

var phase: Phase = Phase.None

const DISABLE_BY_TAG := {
	"Handschuhe": "Slash",
	"Trompete": "Gas",
	"Brille": "Distance",
}


func _ready() -> void:
	Signals.item_collected.connect(handle_item_collected)


func handle_item_collected(item: Item) -> void:
	collected_items.append(item)
	print(collected_items)
	_register_cosmetic_from_item(item)


func _register_cosmetic_from_item(item: Item) -> void:
	if item == null or not is_instance_valid(item) or item.item_data == null:
		return
	var tag := String(item.item_data.cosmetic_tag)
	if tag.is_empty() or not DISABLE_BY_TAG.has(tag):
		return
	disabled_attacks[String(DISABLE_BY_TAG[tag])] = true
	cosmetic_order.append(tag)
	_sync_phase()


func _sync_phase() -> void:
	var n := cosmetic_order.size()
	if n <= 0:
		phase = Phase.None
	elif n == 1:
		phase = Phase.OneItem
	elif n == 2:
		phase = Phase.TwoItems
	else:
		phase = Phase.AllItems


func get_equipped_cosmetic_tags() -> Dictionary:
	var d: Dictionary = {}
	for t in cosmetic_order:
		d[t] = true
	return d


func is_attack_enabled(prefix: StringName) -> bool:
	return not disabled_attacks.has(String(prefix))


func _pair_suffix(tag_a: String, tag_b: String) -> String:
	var s: Dictionary = {tag_a: true, tag_b: true}
	if s.has("Brille") and s.has("Handschuhe"):
		return "Brille_Handschuhe"
	if s.has("Brille") and s.has("Trompete"):
		return "Brille_Trompete"
	if s.has("Handschuhe") and s.has("Trompete"):
		return "Trompete_Handschuhe"
	return "Default"


func _cosmetic_suffix() -> String:
	var n := cosmetic_order.size()
	if n <= 0:
		return "Default"
	if n == 1:
		return cosmetic_order[0]
	if n == 2:
		return _pair_suffix(cosmetic_order[0], cosmetic_order[1])
	return "Alles"


## Build names like Walk_Handschuhe, Slash_Trompete_Handschuhe, Distance_Alles (matches Monster_anim.tres where present).
func get_enemy_animation_name(prefix: String) -> StringName:
	var suf := _cosmetic_suffix()
	return StringName(prefix + "_" + suf)


func reduce_fear(item: Item) -> void:
	var amount_fear_reduction := item.item_data.fear_reduction
	current_fear -= amount_fear_reduction
	current_fear = maxf(0.0, current_fear)
	if current_fear <= 0.0 \
			and current_game_state != STATE.Lost \
			and current_game_state != STATE.Won:
		current_game_state = STATE.Won
		Signals.game_won.emit()
	Signals.item_collected.emit(item)
