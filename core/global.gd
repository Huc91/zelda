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

## card_id -> owned normal copies.
var card_collection: Dictionary = {}

## card_id -> owned foil copies.
var foil_collection: Dictionary = {}

## Player rupies (currency).
var rupies: int = 200

# ── Economy constants ────────────────────────────────────────────────
const PACK_COST: int        = 100
const SINGLE_BUY_MULT: int  = 8   ## singles cost PACK_COST * MULT / 5 per card
const SELL_NORMAL: int      = 12  ## sell price per extra normal card copy
const SELL_FOIL: int        = 120 ## sell price per extra foil copy
const RUPIES_GRASS_MIN: int = 5
const RUPIES_GRASS_MAX: int = 20
## Rupie rewards by difficulty tag.
const REWARD_BY_DIFF: Dictionary = {
	"easy":   {"min": 8,  "max": 20},
	"normal": {"min": 18, "max": 40},
	"hard":   {"min": 35, "max": 80},
}

signal card_battle_requested(player_first: bool, enemy: Node)
signal rupies_changed(new_amount: int)


func _ready() -> void:
	if player_decks.is_empty():
		_init_default_decks()
	_init_card_collection()


func _init_card_collection() -> void:
	if not card_collection.is_empty():
		return
	# Everyone starts with 0. Give 2x copies of each STARTER_DECK card.
	for id in CardDB.all_collectible_ids():
		card_collection[id] = 0
	var counts: Dictionary = {}
	for id in CardDB.STARTER_DECK:
		counts[id] = counts.get(id, 0) + 1
	for id in counts:
		card_collection[id] = counts[id]


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


## Add rupies and fire signal.
func add_rupies(amount: int) -> void:
	rupies += amount
	rupies_changed.emit(rupies)


## Spend rupies; returns false if not enough.
func spend_rupies(amount: int) -> bool:
	if rupies < amount:
		return false
	rupies -= amount
	rupies_changed.emit(rupies)
	return true


## Add a card to collection (foil or normal).
func collect_card(card_id: String, is_foil: bool) -> void:
	if is_foil:
		foil_collection[card_id] = foil_collection.get(card_id, 0) + 1
	else:
		card_collection[card_id] = card_collection.get(card_id, 0) + 1


## Returns how many extra copies can be sold (over 2 owned).
func sellable_copies(card_id: String, is_foil: bool) -> int:
	var dict: Dictionary = foil_collection if is_foil else card_collection
	return maxi(0, dict.get(card_id, 0) - 2)


## Sell one extra copy; returns rupies received (0 if none to sell).
func sell_one_copy(card_id: String, is_foil: bool) -> int:
	if sellable_copies(card_id, is_foil) <= 0:
		return 0
	var price: int = SELL_FOIL if is_foil else SELL_NORMAL
	var dict: Dictionary = foil_collection if is_foil else card_collection
	dict[card_id] = dict.get(card_id, 0) - 1
	add_rupies(price)
	return price
