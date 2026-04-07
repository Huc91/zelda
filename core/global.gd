extends Node

const MAX_DECKS: int = 5

var Item = {
	Sword = preload("res://data/items/sword.tres")
}

## True while a card battle overlay is active (overworld inventory blocked).
var in_battle: bool = false

## Saved deck slots: each `{ "name": String, "color": String, "card_ids": Array[String] }`.
var player_decks: Array[Dictionary] = []

## Index into [member player_decks] used when starting a card battle.
var battle_deck_index: int = 0

## card_id -> owned copies (deck editor + / − limits vs [constant CardDB.DECK_COPY_MAX]).
var card_collection: Dictionary = {}

signal card_battle_requested(player_first: bool, enemy: Node)


func _ready() -> void:
	if player_decks.is_empty():
		_init_default_decks()
	_init_card_collection()


func _init_card_collection() -> void:
	if not card_collection.is_empty():
		return
	for id in CardDB.all_collectible_ids():
		card_collection[id] = 6


func _init_default_decks() -> void:
	player_decks.append(_make_deck_entry("Starter deck", "black"))


func _make_deck_entry(deck_name: String, color: String) -> Dictionary:
	return {
		"name": deck_name,
		"color": color,
		"card_ids": CardDB.STARTER_DECK.duplicate(),
	}


func try_add_new_deck() -> bool:
	if player_decks.size() >= MAX_DECKS:
		return false
	var colors: Array[String] = ["black", "green", "orange", "blue"]
	var c: String = colors[player_decks.size() % colors.size()]
	var n: int = player_decks.size() + 1
	player_decks.append(_make_deck_entry("Deck %d" % n, c))
	return true


func set_battle_deck_index(i: int) -> void:
	if player_decks.is_empty():
		return
	battle_deck_index = clampi(i, 0, player_decks.size() - 1)


func get_battle_deck_card_ids() -> Array:
	if player_decks.is_empty():
		return CardDB.STARTER_DECK.duplicate()
	battle_deck_index = clampi(battle_deck_index, 0, player_decks.size() - 1)
	var raw: Variant = player_decks[battle_deck_index].get("card_ids", [])
	var ids: Array = []
	if typeof(raw) == TYPE_ARRAY:
		ids = raw
	if ids.is_empty():
		return CardDB.STARTER_DECK.duplicate()
	return ids.duplicate()


func apply_deck_edit(deck_index: int, deck_name: String, card_ids: Array) -> void:
	if deck_index < 0 or deck_index >= player_decks.size():
		return
	var name_trim: String = deck_name.strip_edges().left(12)
	if name_trim.is_empty():
		name_trim = "Deck"
	player_decks[deck_index]["name"] = name_trim
	player_decks[deck_index]["card_ids"] = card_ids.duplicate()


func notify_deck_removed_at(removed_index: int) -> void:
	if battle_deck_index > removed_index:
		battle_deck_index -= 1
	battle_deck_index = clampi(battle_deck_index, 0, maxi(0, player_decks.size() - 1))


func request_card_battle(player_first: bool, enemy: Node) -> void:
	card_battle_requested.emit(player_first, enemy)
