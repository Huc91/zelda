extends Node

const MAX_DECKS: int = 3

## ── Dev flag ─────────────────────────────────────────────────────────
## Flip _DEV_OVERRIDE to true to force dev mode from the editor.
## Or launch with: ZELDA_DEV=1 godot  /  godot --dev
const _DEV_OVERRIDE: bool = false
var dev_mode: bool = _DEV_OVERRIDE \
	or OS.get_environment("ZELDA_DEV") == "1" \
	or "--dev" in OS.get_cmdline_user_args()

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

## Player money (currency).
var money: int = 10

## Path of the currently loaded map scene.
var current_map_path: String = ""

## Pickup positions already collected, keyed by map path.
var collected_pickups: Dictionary = {}  # { map_path: Array[Vector2] }

# ── Economy constants ────────────────────────────────────────────────
const PACK_COST: int        = 10
const SINGLE_BUY_MULT: int  = 8   ## singles cost PACK_COST * MULT / 5 per card
const SELL_NORMAL: int      = 1   ## sell price per extra normal card copy
const SELL_FOIL: int        = 10  ## sell price per extra foil copy
const MONEY_GRASS_MIN: int  = 1
const MONEY_GRASS_MAX: int  = 4
## Money rewards by difficulty tag.
const REWARD_BY_DIFF: Dictionary = {
	"easy":   {"min": 5,   "max": 10},
	"normal": {"min": 10,  "max": 30},
	"hard":   {"min": 50,  "max": 80},
	"boss":   {"min": 200, "max": 200},
}

signal card_battle_requested(player_first: bool, enemy: Node)
signal money_changed(new_amount: int)


func _ready() -> void:
	if player_decks.is_empty():
		_init_default_decks()
	_init_card_collection()
	if dev_mode:
		_apply_dev_mode()


## Snapshot of real player state so we can restore it when leaving dev mode.
var _saved_money: int = -1
var _saved_collection: Dictionary = {}
var _saved_foils: Dictionary = {}


func toggle_dev_mode() -> void:
	if dev_mode:
		# Restore real player state
		if _saved_money >= 0:
			money = _saved_money
			card_collection = _saved_collection.duplicate()
			foil_collection = _saved_foils.duplicate()
		dev_mode = false
	else:
		# Save real state then apply dev
		_saved_money = money
		_saved_collection = card_collection.duplicate()
		_saved_foils = foil_collection.duplicate()
		dev_mode = true
		_apply_dev_mode()
	money_changed.emit(money)


func _apply_dev_mode() -> void:
	money = 9999
	for id in CardDB.all_collectible_ids():
		card_collection[id] = 9999


func _init_card_collection() -> void:
	if not card_collection.is_empty():
		return
	# Normal players start with only their starter deck cards.
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
	if ids.is_empty() or not CardDB.deck_ids_legal(ids):
		push_warning("Active deck is invalid — falling back to starter deck.")
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


## Record that a pickup at `pos` in `map_path` has been collected.
func record_pickup(map_path: String, pos: Vector2) -> void:
	if not collected_pickups.has(map_path):
		collected_pickups[map_path] = []
	collected_pickups[map_path].append(pos)


## Returns true if the pickup at `pos` in `map_path` was already collected.
func is_pickup_collected(map_path: String, pos: Vector2) -> bool:
	var list: Array = collected_pickups.get(map_path, [])
	return pos in list


## Add money and fire signal.
func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


## Spend money; returns false if not enough.
func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
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


## Sell one extra copy; returns money received (0 if none to sell).
func sell_one_copy(card_id: String, is_foil: bool) -> int:
	if sellable_copies(card_id, is_foil) <= 0:
		return 0
	var price: int = SELL_FOIL if is_foil else SELL_NORMAL
	var dict: Dictionary = foil_collection if is_foil else card_collection
	dict[card_id] = dict.get(card_id, 0) - 1
	add_money(price)
	return price
