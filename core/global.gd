extends Node

const SoulItem = preload("res://core/soul_item.gd")

const MAX_DECKS: int = 3

## ── Dev flag ─────────────────────────────────────────────────────────
## Flip _DEV_OVERRIDE to true to force dev mode from the editor.
## Or launch with: ZELDA_DEV=1 godot  /  godot --dev
const _DEV_OVERRIDE: bool = false
var dev_mode: bool = _DEV_OVERRIDE \
	or OS.get_environment("ZELDA_DEV") == "1" \
	or "--dev" in OS.get_cmdline_user_args()

## True while a card battle overlay is active (overworld inventory blocked).
var in_battle: bool = false

## Player HP. Reaching 0 triggers game over. 12 HP = 3 hearts.
var player_hp: int = 12
var player_max_hp: int = 12

## World position of the last activated bonfire (null = use starting entrance).
var last_bonfire_position = null
## Map path where the last bonfire was activated.
var last_bonfire_map: String = ""
## All lit bonfire positions keyed by map path — persists across map transitions.
var lit_bonfires: Dictionary = {}  ## { map_path: Array[Vector2] }

## Backward-compat: emitted alongside hp_changed.
signal lives_changed(new_lives: int)
signal hp_changed(new_hp: int, max_hp: int)

## Soul catalogue — populated in _init_souls().
var SOULS: Dictionary = {}

## Equipped soul IDs per slot (empty string = none).
var equipped_soul_red: String = ""
var equipped_soul_blue: String = ""
var equipped_soul_green: String = ""

## soul_id -> count owned.
var soul_collection: Dictionary = {}
## soul_id -> true; can only catch one of each type.
var caught_souls: Dictionary = {}

signal soul_changed

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

## NPC dialogue_ids whose "!" flag has been dismissed by the player.
var npc_flags_dismissed: Dictionary = {}  # { dialogue_id: true }

## NPC dialogue sequence progress: { dialogue_id: current_sequence_index }.
var npc_progress: Dictionary = {}

## Fired when a dialogue sequence ends with an event string.
signal dialogue_event(event_name: String, npc_id: String)

## Legacy: kept as empty dict so any code still referencing player_items doesn't crash.
var player_items: Dictionary = {}

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
signal bonfire_rested


func _ready() -> void:
	_init_souls()
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


## Wipe all runtime state back to fresh-game defaults (call before starting a new game).
func reset_new_game() -> void:
	dev_mode = false
	money = 10
	player_hp = 12
	player_max_hp = 12
	equipped_soul_red = ""
	equipped_soul_blue = ""
	equipped_soul_green = ""
	soul_collection.clear()
	caught_souls.clear()
	last_bonfire_position = null
	last_bonfire_map = ""
	lit_bonfires.clear()
	collected_pickups.clear()
	player_items.clear()
	card_collection.clear()
	foil_collection.clear()
	player_decks.clear()
	battle_deck_index = 0
	in_battle = false
	_init_default_decks()
	_init_card_collection()
	money_changed.emit(money)
	hp_changed.emit(player_hp, get_effective_max_hp())
	lives_changed.emit(_hp_to_lives())


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


func _init_souls() -> void:
	var sword: SoulItem = SoulItem.new()
	sword.soul_id = "sword"
	sword.slot = "red"
	sword.name = "Soul Sword"
	sword.description = "A blade imbued with a hero's spirit."
	sword.is_weapon = true
	var sword_scene: Variant = load("res://data/actors/attacks/sword.tscn")
	if sword_scene != null:
		sword.weapon_scene = sword_scene as PackedScene
	var sword_icon: Variant = load("res://data/items/sword-icon.png")
	if sword_icon != null:
		sword.icon = sword_icon as Texture2D
	SOULS["sword"] = sword

	var stone: SoulItem = SoulItem.new()
	stone.soul_id = "stone"
	stone.slot = "blue"
	stone.name = "Stone Soul"
	stone.description = "+1 max HP."
	stone.max_hp_bonus = 1
	SOULS["stone"] = stone

	var tree: SoulItem = SoulItem.new()
	tree.soul_id = "tree"
	tree.slot = "green"
	tree.name = "Tree Soul"
	tree.description = "+4 HP healed at end of battle."
	tree.heal_after_battle = 4
	SOULS["tree"] = tree

	var flower: SoulItem = SoulItem.new()
	flower.soul_id = "flower"
	flower.slot = "green"
	flower.name = "Flower Soul"
	flower.description = "+1 Luck."
	flower.luck_bonus = 1
	SOULS["flower"] = flower


## Returns the sum of luck_bonus from all equipped souls plus foil card count, clamped 0–42.
func get_total_luck() -> int:
	var total: int = 0
	var red_soul: SoulItem = get_equipped_soul("red")
	if red_soul != null:
		total += red_soul.luck_bonus
	var blue_soul: SoulItem = get_equipped_soul("blue")
	if blue_soul != null:
		total += blue_soul.luck_bonus
	var green_soul: SoulItem = get_equipped_soul("green")
	if green_soul != null:
		total += green_soul.luck_bonus
	# Count total foil cards owned.
	for card_id: String in foil_collection:
		total += int(foil_collection.get(card_id, 0))
	return clampi(total, 0, 42)


## Returns the sum of initiative_bonus from all equipped souls.
func get_total_initiative_bonus() -> int:
	var total: int = 0
	var red_soul: SoulItem = get_equipped_soul("red")
	if red_soul != null:
		total += red_soul.initiative_bonus
	var blue_soul: SoulItem = get_equipped_soul("blue")
	if blue_soul != null:
		total += blue_soul.initiative_bonus
	var green_soul: SoulItem = get_equipped_soul("green")
	if green_soul != null:
		total += green_soul.initiative_bonus
	return total


## Roll 1–42; returns true if player is lucky (total_luck >= roll).
func roll_luck() -> bool:
	var roll: int = randi_range(1, 42)
	return get_total_luck() >= roll


## Returns player_max_hp plus any max_hp_bonus from equipped souls.
func get_effective_max_hp() -> int:
	var bonus: int = 0
	var red_soul: SoulItem = get_equipped_soul("red")
	if red_soul != null:
		bonus += red_soul.max_hp_bonus
	var blue_soul: SoulItem = get_equipped_soul("blue")
	if blue_soul != null:
		bonus += blue_soul.max_hp_bonus
	var green_soul: SoulItem = get_equipped_soul("green")
	if green_soul != null:
		bonus += green_soul.max_hp_bonus
	return player_max_hp + bonus


func _hp_to_lives() -> int:
	return ceili(float(player_hp) / 4.0)


func _emit_hp_signals() -> void:
	hp_changed.emit(player_hp, get_effective_max_hp())
	lives_changed.emit(_hp_to_lives())


func add_hp(amount: int) -> void:
	player_hp = clampi(player_hp + amount, 0, get_effective_max_hp())
	_emit_hp_signals()


func damage_hp(amount: int) -> void:
	player_hp = clampi(player_hp - amount, 0, get_effective_max_hp())
	_emit_hp_signals()


func set_hp(amount: int) -> void:
	player_hp = clampi(amount, 0, get_effective_max_hp())
	_emit_hp_signals()


func restore_lives() -> void:
	player_hp = get_effective_max_hp()
	_emit_hp_signals()


## Damage 4 HP. Returns true if player_hp has reached 0 (game over).
func lose_life() -> bool:
	damage_hp(4)
	return player_hp <= 0


## Returns the SoulItem equipped in the given slot, or null.
func get_equipped_soul(slot: String) -> SoulItem:
	var soul_id: String = ""
	if slot == "red":
		soul_id = equipped_soul_red
	elif slot == "blue":
		soul_id = equipped_soul_blue
	elif slot == "green":
		soul_id = equipped_soul_green
	if soul_id.is_empty():
		return null
	var soul: Variant = SOULS.get(soul_id, null)
	if soul == null:
		return null
	return soul as SoulItem


func equip_soul(soul_id: String) -> void:
	var soul: Variant = SOULS.get(soul_id, null)
	if soul == null:
		return
	var s: SoulItem = soul as SoulItem
	if s.slot == "red":
		equipped_soul_red = soul_id
	elif s.slot == "blue":
		equipped_soul_blue = soul_id
	elif s.slot == "green":
		equipped_soul_green = soul_id
	soul_changed.emit()
	_emit_hp_signals()


func unequip_soul(slot: String) -> void:
	if slot == "red":
		equipped_soul_red = ""
	elif slot == "blue":
		equipped_soul_blue = ""
	elif slot == "green":
		equipped_soul_green = ""
	soul_changed.emit()
	_emit_hp_signals()


func add_soul_to_collection(soul_id: String) -> void:
	soul_collection[soul_id] = int(soul_collection.get(soul_id, 0)) + 1
	soul_changed.emit()


## Returns total heal_after_battle HP from all equipped souls.
func get_heal_after_battle() -> int:
	var total: int = 0
	var red_soul: SoulItem = get_equipped_soul("red")
	if red_soul != null:
		total += red_soul.heal_after_battle
	var blue_soul: SoulItem = get_equipped_soul("blue")
	if blue_soul != null:
		total += blue_soul.heal_after_battle
	var green_soul: SoulItem = get_equipped_soul("green")
	if green_soul != null:
		total += green_soul.heal_after_battle
	return total


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


func activate_bonfire(world_pos: Vector2, map_path: String) -> void:
	last_bonfire_position = world_pos
	last_bonfire_map = map_path
	if not lit_bonfires.has(map_path):
		lit_bonfires[map_path] = []
	var list: Array = lit_bonfires[map_path]
	if not list.has(world_pos):
		list.append(world_pos)


func is_bonfire_lit(world_pos: Vector2, map_path: String) -> bool:
	var list: Array = lit_bonfires.get(map_path, [])
	return list.has(world_pos)


const SAVE_PATH: String = "user://save.json"
const SAVE_PATH_DEV: String = "user://save_dev.json"


func _active_save_path() -> String:
	return SAVE_PATH_DEV if dev_mode else SAVE_PATH


## Returns true if a normal (non-dev) save file exists.
func has_normal_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var bp = null
	if last_bonfire_position != null:
		var bpv: Vector2 = last_bonfire_position as Vector2
		bp = {"x": bpv.x, "y": bpv.y}
	var pickups_serial: Dictionary = _serialize_vec2_dict(collected_pickups)
	var data: Dictionary = {
		"money": money,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"equipped_soul_red": equipped_soul_red,
		"equipped_soul_blue": equipped_soul_blue,
		"equipped_soul_green": equipped_soul_green,
		"soul_collection": soul_collection.duplicate(),
		"caught_souls": caught_souls.duplicate(),
		"last_bonfire_position": bp,
		"last_bonfire_map": last_bonfire_map,
		"card_collection": card_collection.duplicate(),
		"foil_collection": foil_collection.duplicate(),
		"player_decks": player_decks.duplicate(true),
		"battle_deck_index": battle_deck_index,
		"collected_pickups": pickups_serial,
		"lit_bonfires": _serialize_vec2_dict(lit_bonfires),
	}
	data["dev_mode"] = dev_mode
	var f: FileAccess = FileAccess.open(_active_save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> bool:
	var path: String = _active_save_path()
	if not FileAccess.file_exists(path):
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed as Dictionary
	money = int(data.get("money", 10))
	player_hp = int(data.get("player_hp", 12))
	player_max_hp = int(data.get("player_max_hp", 12))
	equipped_soul_red = str(data.get("equipped_soul_red", ""))
	equipped_soul_blue = str(data.get("equipped_soul_blue", ""))
	equipped_soul_green = str(data.get("equipped_soul_green", ""))
	var sc: Variant = data.get("soul_collection", {})
	if typeof(sc) == TYPE_DICTIONARY:
		soul_collection = sc as Dictionary
	var cs: Variant = data.get("caught_souls", {})
	if typeof(cs) == TYPE_DICTIONARY:
		caught_souls = cs as Dictionary
	last_bonfire_map = str(data.get("last_bonfire_map", ""))
	var bp: Variant = data.get("last_bonfire_position", null)
	if bp != null and typeof(bp) == TYPE_DICTIONARY:
		last_bonfire_position = Vector2(float(bp["x"]), float(bp["y"]))
	else:
		last_bonfire_position = null
	var cc: Variant = data.get("card_collection", {})
	if typeof(cc) == TYPE_DICTIONARY:
		card_collection = cc as Dictionary
	var fc: Variant = data.get("foil_collection", {})
	if typeof(fc) == TYPE_DICTIONARY:
		foil_collection = fc as Dictionary
	var pd: Variant = data.get("player_decks", [])
	if typeof(pd) == TYPE_ARRAY and not (pd as Array).is_empty():
		player_decks.clear()
		for entry: Variant in (pd as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				player_decks.append(entry as Dictionary)
	battle_deck_index = int(data.get("battle_deck_index", 0))
	var ps: Variant = data.get("collected_pickups", {})
	if typeof(ps) == TYPE_DICTIONARY:
		collected_pickups = _deserialize_vec2_dict(ps as Dictionary)
	var lb: Variant = data.get("lit_bonfires", {})
	if typeof(lb) == TYPE_DICTIONARY:
		lit_bonfires = _deserialize_vec2_dict(lb as Dictionary)
	money_changed.emit(money)
	hp_changed.emit(player_hp, get_effective_max_hp())
	lives_changed.emit(_hp_to_lives())
	return true


func _serialize_vec2_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in src:
		var arr: Array = []
		for v: Vector2 in src[k]:
			arr.append({"x": v.x, "y": v.y})
		out[k] = arr
	return out


func _deserialize_vec2_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in src:
		var vlist: Array = []
		for entry: Variant in src[k]:
			if typeof(entry) == TYPE_DICTIONARY:
				vlist.append(Vector2(float(entry["x"]), float(entry["y"])))
		out[str(k)] = vlist
	return out


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
