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
## All opened chest positions keyed by map path — persists across map transitions.
var opened_chests: Dictionary = {}  ## { map_path: Array[Vector2] }

## Cells where the player has already attempted soul absorption (map_path → Array[Vector2i]).
var absorbed_soul_cells: Dictionary = {}

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
## soul_id -> true; kept for save-file backward-compat but no longer enforced.
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

## Kabba boss post-duel state (persisted in save).
const KABBA_NONE: int = 0
const KABBA_MERCY_PENDING: int = 1
const KABBA_SPARED_WAITING_SCROLL: int = 2
const KABBA_SPARED_GONE: int = 3
const KABBA_KILLED_SKULL: int = 4
const KABBA_SKULL_DONE: int = 5
const POWER_TRUNKS_SOUL_ID: String = "power_trunks"
const KABBA_PROMO_CARD_ID: String = "demon_126"

var kabba_state: int = KABBA_NONE
## True after Power Trunks was granted (spare or skull absorb).
var kabba_reward_claimed: bool = false
## Map where Kabba was defeated (spare despawn + skull only apply here).
var kabba_encounter_map_path: String = ""
## Spare follow-up dialogue step (0..5, where 5 means "..." loop).
var kabba_spare_dialogue_step: int = 0
## True once Fenrir was dropped to the world by Kabba.
var kabba_fenrir_dropped: bool = false

## Hidden stat (human/boss kill vs shadow kill). May be negative.
var karma: int = 0

## Runtime overworld shadows: each { "map_path", "kind", "deck_ids", "display_name" }.
var overworld_shadows: Array = []

## duelist_id -> int state (DUELIST_ST_*).
var duelist_states: Dictionary = {}

const OVERWORLD_MAP_PATH: String = "res://data/maps/overworld.tscn"
const PLAYER_SHADOW_NAME: String = "Kuro"

const SHADOW_SPAWN_SECTOR_GRID: Array[Vector2i] = [
	Vector2i(9, 3), Vector2i(13, 5), Vector2i(13, 6), Vector2i(6, 6), Vector2i(6, 7),
	Vector2i(11, 3), Vector2i(13, 4), Vector2i(10, 5),
]

const DUELIST_ST_ALIVE: int = 0
const DUELIST_ST_MERCY_PENDING: int = 1
const DUELIST_ST_SPARED_HIDDEN: int = 2
const DUELIST_ST_KILLED_SKULL: int = 3
const DUELIST_ST_SKULL_DONE: int = 4

## Fired when a dialogue sequence ends with an event string.
signal dialogue_event(event_name: String, npc_id: String)

## Legacy: kept as empty dict so any code still referencing player_items doesn't crash.
var player_items: Dictionary = {}
## Number of unopened base set packs owned by the player.
var base_set_packs: int = 0

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
const _RARITY_POWER_POINTS: Dictionary = {
	"common": 1,
	"rare": 3,
	"epic": 5,
	"legendary": 8,
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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if not event is InputEventKey:
		return
	var k: InputEventKey = event as InputEventKey
	if not k.shift_pressed:
		return
	if k.keycode != KEY_F9 and k.physical_keycode != KEY_F9:
		return
	var on: bool = not BattleFileLogger.file_logging_enabled
	BattleFileLogger.set_file_logging_enabled(on)
	print(
		"Battle file logging: ",
		"ON (Shift+F9 to disable)" if on else "OFF (Shift+F9 to re-enable)",
	)
	get_viewport().set_input_as_handled()


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
	opened_chests.clear()
	collected_pickups.clear()
	absorbed_soul_cells.clear()
	npc_progress.clear()
	npc_flags_dismissed.clear()
	kabba_state = KABBA_NONE
	kabba_reward_claimed = false
	kabba_encounter_map_path = ""
	kabba_spare_dialogue_step = 0
	kabba_fenrir_dropped = false
	karma = 0
	overworld_shadows.clear()
	duelist_states.clear()
	CardDB.clear_runtime_cards()
	player_items.clear()
	base_set_packs = 0
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
	for id: String in SoulItemDB.all_ids():
		add_soul_to_collection(id)


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
	for id: String in SoulItemDB.all_ids():
		var data: Dictionary = SoulItemDB.get_item(id)
		var soul: SoulItem = SoulItem.new()
		soul.soul_id = id
		soul.name = str(data.get("name", id))
		soul.slot = str(data.get("slot", "green"))
		soul.description = str(data.get("description", ""))
		soul.luck_bonus = int(data.get("luck_bonus", 0))
		soul.max_hp_bonus = int(data.get("max_hp_bonus", 0))
		soul.heal_after_battle = int(data.get("heal_after_battle", 0))
		soul.initiative_bonus = int(data.get("initiative_bonus", 0))
		soul.is_weapon = bool(data.get("is_weapon", false))
		soul.sell_price = int(data.get("sell_price", 1))
		var ws: String = str(data.get("weapon_scene", ""))
		if ws != "" and ResourceLoader.exists(ws):
			var loaded: Variant = load(ws)
			if loaded != null:
				soul.weapon_scene = loaded as PackedScene
		var icon_path: String = str(data.get("icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var loaded: Variant = load(icon_path)
			if loaded != null:
				soul.icon = loaded as Texture2D
		if soul.icon == null:
			var sheet_path: String = str(data.get("icon_sheet", ""))
			if sheet_path != "" and ResourceLoader.exists(sheet_path):
				var sheet: Variant = load(sheet_path)
				if sheet != null:
					var region: Rect2 = data.get("icon_region", Rect2())
					if region.size != Vector2.ZERO:
						var atlas: AtlasTexture = AtlasTexture.new()
						atlas.atlas = sheet as Texture2D
						atlas.region = region
						soul.icon = atlas
		var hud_icon_path: String = str(data.get("hud_icon", ""))
		if hud_icon_path != "" and ResourceLoader.exists(hud_icon_path):
			var loaded_hi: Variant = load(hud_icon_path)
			if loaded_hi != null:
				soul.hud_icon = loaded_hi as Texture2D
		SOULS[id] = soul


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
	soul_collection[soul_id] = mini(int(soul_collection.get(soul_id, 0)) + 1, 99)
	soul_changed.emit()


## Sell one copy of a soul item. Returns money gained (0 if none owned).
func sell_soul_item(soul_id: String) -> int:
	var count: int = int(soul_collection.get(soul_id, 0))
	if count <= 0:
		return 0
	var soul: Variant = SOULS.get(soul_id, null)
	var price: int = 1
	if soul != null:
		price = (soul as SoulItem).sell_price
	soul_collection[soul_id] = count - 1
	add_money(price)
	soul_changed.emit()
	return price


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


func _string_card_ids_from_raw(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v: Variant in raw as Array:
		if typeof(v) == TYPE_STRING:
			out.append(v as String)
	return out


func get_battle_deck_card_ids() -> Array[String]:
	if player_decks.is_empty():
		return _string_card_ids_from_raw(CardDB.STARTER_DECK)
	battle_deck_index = clampi(battle_deck_index, 0, player_decks.size() - 1)
	var raw: Variant = player_decks[battle_deck_index].get("card_ids", [])
	var ids: Array[String] = _string_card_ids_from_raw(raw)
	if ids.is_empty() or not CardDB.deck_ids_legal(ids):
		push_warning("Active deck is invalid — falling back to starter deck.")
		return _string_card_ids_from_raw(CardDB.STARTER_DECK)
	return ids.duplicate()


## Computes deck power score based on rarity and demon efficiency.
## - rarity_power = sum(rarity points)/DECK_SIZE_MAX (baseline 1.0 for all-common legal deck)
## - raw_power = sum(demon power)/sum(demon mana), where demon power = atk + 1 if has ability
## - final_power = rarity_power * raw_power
func get_deck_power_breakdown(deck_index: int) -> Dictionary:
	if deck_index < 0 or deck_index >= player_decks.size():
		return _empty_deck_power_breakdown()
	var raw_ids: Variant = player_decks[deck_index].get("card_ids", [])
	if typeof(raw_ids) != TYPE_ARRAY:
		return _empty_deck_power_breakdown()
	return get_deck_power_breakdown_for_card_ids(raw_ids as Array)


func get_deck_power_breakdown_for_card_ids(card_ids: Array) -> Dictionary:
	var rarity_sum: int = 0
	var demon_power_sum: int = 0
	var demon_mana_sum: int = 0
	for idv: Variant in card_ids:
		if typeof(idv) != TYPE_STRING:
			continue
		var card: Dictionary = CardDB.get_card(idv as String)
		if card.is_empty():
			continue
		var rarity: String = str(card.get("rarity", "common")).to_lower()
		rarity_sum += int(_RARITY_POWER_POINTS.get(rarity, 1))
		if str(card.get("type", "")) != "demon":
			continue
		var atk: int = int(card.get("atk", 0))
		var mana: int = int(card.get("cost", 0))
		demon_power_sum += atk + _deck_card_ability_power(card)
		demon_mana_sum += mana
	var rarity_den: float = float(maxi(1, CardDB.DECK_SIZE_MAX))
	var rarity_power: float = float(rarity_sum) / rarity_den
	var raw_power: float = 0.0
	if demon_mana_sum > 0:
		raw_power = float(demon_power_sum) / float(demon_mana_sum)
	return {
		"rarity_power": rarity_power,
		"raw_power": raw_power,
		"final_power": rarity_power * raw_power,
		"rarity_sum": rarity_sum,
		"demon_power_sum": demon_power_sum,
		"demon_mana_sum": demon_mana_sum,
	}


func _empty_deck_power_breakdown() -> Dictionary:
	return {
		"rarity_power": 0.0,
		"raw_power": 0.0,
		"final_power": 0.0,
		"rarity_sum": 0,
		"demon_power_sum": 0,
		"demon_mana_sum": 0,
	}


func _deck_card_ability_power(card: Dictionary) -> int:
	var ability: String = str(card.get("ability", "")).strip_edges()
	if ability == "skeleton_horde":
		return 0
	return 0 if ability.is_empty() else 1


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


func open_chest(world_pos: Vector2, map_path: String) -> void:
	if not opened_chests.has(map_path):
		opened_chests[map_path] = []
	var list: Array = opened_chests[map_path]
	if not list.has(world_pos):
		list.append(world_pos)


func is_chest_opened(world_pos: Vector2, map_path: String) -> bool:
	return (opened_chests.get(map_path, []) as Array).has(world_pos)


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
		"opened_chests": _serialize_vec2_dict(opened_chests),
		"base_set_packs": base_set_packs,
		"kabba_state": kabba_state,
		"kabba_reward_claimed": kabba_reward_claimed,
		"kabba_encounter_map_path": kabba_encounter_map_path,
		"kabba_spare_dialogue_step": kabba_spare_dialogue_step,
		"kabba_fenrir_dropped": kabba_fenrir_dropped,
		"karma": karma,
		"overworld_shadows": overworld_shadows.duplicate(true),
		"duelist_states": duelist_states.duplicate(),
		"runtime_cards": CardDB.runtime_cards_for_save(),
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
	base_set_packs = int(data.get("base_set_packs", int(player_items.get("base_set_pack", 0))))
	player_items["base_set_pack"] = base_set_packs
	var ps: Variant = data.get("collected_pickups", {})
	if typeof(ps) == TYPE_DICTIONARY:
		collected_pickups = _deserialize_vec2_dict(ps as Dictionary)
	var lb: Variant = data.get("lit_bonfires", {})
	if typeof(lb) == TYPE_DICTIONARY:
		lit_bonfires = _deserialize_vec2_dict(lb as Dictionary)
	var oc: Variant = data.get("opened_chests", {})
	if typeof(oc) == TYPE_DICTIONARY:
		opened_chests = _deserialize_vec2_dict(oc as Dictionary)
	kabba_state = int(data.get("kabba_state", 0))
	kabba_reward_claimed = bool(data.get("kabba_reward_claimed", false))
	kabba_encounter_map_path = str(data.get("kabba_encounter_map_path", ""))
	kabba_spare_dialogue_step = int(data.get("kabba_spare_dialogue_step", 0))
	kabba_fenrir_dropped = bool(data.get("kabba_fenrir_dropped", false))
	karma = int(data.get("karma", 0))
	var os: Variant = data.get("overworld_shadows", [])
	if typeof(os) == TYPE_ARRAY:
		overworld_shadows = (os as Array).duplicate(true)
	else:
		overworld_shadows.clear()
	var dst: Variant = data.get("duelist_states", {})
	if typeof(dst) == TYPE_DICTIONARY:
		duelist_states = (dst as Dictionary).duplicate()
	else:
		duelist_states.clear()
	var rc: Variant = data.get("runtime_cards", [])
	if typeof(rc) == TYPE_ARRAY:
		CardDB.load_runtime_cards_from_save(rc as Array)
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


## Mark a tile cell as soul-absorbed so it can't be attempted again this session.
func record_soul_absorb(map_path: String, cell: Vector2i) -> void:
	if not absorbed_soul_cells.has(map_path):
		absorbed_soul_cells[map_path] = []
	var arr: Array = absorbed_soul_cells[map_path]
	if not arr.has(cell):
		arr.append(cell)


## Returns true if this cell has already been soul-absorbed this session.
func has_absorbed_soul(map_path: String, cell: Vector2i) -> bool:
	return (absorbed_soul_cells.get(map_path, []) as Array).has(cell)


## Grants Power Trunks once (Kabba spare or skull). Returns true if newly granted.
func try_grant_kabba_power_trunks_reward(include_promo_card: bool = true) -> bool:
	if kabba_reward_claimed:
		return false
	kabba_reward_claimed = true
	add_soul_to_collection(POWER_TRUNKS_SOUL_ID)
	var soul: SoulItem = SOULS.get(POWER_TRUNKS_SOUL_ID, null) as SoulItem
	if soul != null:
		var slot_empty: bool = false
		match soul.slot:
			"red":
				slot_empty = equipped_soul_red == ""
			"blue":
				slot_empty = equipped_soul_blue == ""
			"green":
				slot_empty = equipped_soul_green == ""
		if slot_empty:
			equip_soul(POWER_TRUNKS_SOUL_ID)
	if include_promo_card:
		collect_card(KABBA_PROMO_CARD_ID, false)
	return true


## After spare: remove Kabba on next camera room transition (same map).
func apply_kabba_spare_despawn_if_pending(map_path: String) -> void:
	if kabba_state != KABBA_SPARED_WAITING_SCROLL:
		return
	if kabba_encounter_map_path != "" and map_path != kabba_encounter_map_path:
		return
	kabba_state = KABBA_SPARED_GONE
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group("kabba_boss"):
		if is_instance_valid(n):
			n.queue_free()


## Clear all tried soul cells on rest so each cell can be attempted once per rest cycle.
func reset_tried_souls() -> void:
	absorbed_soul_cells.clear()


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


func add_base_set_pack(amount: int = 1) -> void:
	if amount <= 0:
		return
	base_set_packs += amount
	player_items["base_set_pack"] = base_set_packs


func consume_base_set_pack() -> bool:
	if base_set_packs <= 0:
		return false
	base_set_packs -= 1
	player_items["base_set_pack"] = base_set_packs
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


func add_karma(delta: int) -> void:
	karma += delta


func snapshot_active_deck_ids() -> Array[String]:
	return get_battle_deck_card_ids()


func remove_overworld_shadow_uid(uid: String) -> void:
	for i: int in range(overworld_shadows.size() - 1, -1, -1):
		if str((overworld_shadows[i] as Dictionary).get("uid", "")) == uid:
			overworld_shadows.remove_at(i)
			return


func enqueue_overworld_shadow(display_name: String, deck_ids: Array) -> void:
	var ids: Array[String] = []
	for v: Variant in deck_ids:
		if typeof(v) == TYPE_STRING:
			ids.append(v as String)
	if ids.is_empty():
		ids = snapshot_active_deck_ids()
	var kinds: Array[String] = ["octorok", "moblin", "knuckle"]
	var kind: String = kinds[randi() % kinds.size()]
	overworld_shadows.append({
		"uid": str(Time.get_ticks_usec()) + "_" + str(randi()),
		"map_path": OVERWORLD_MAP_PATH,
		"kind": kind,
		"deck_ids": ids,
		"display_name": display_name,
	})


func pick_overworld_shadow_spawn_cell(map: Map) -> Vector2i:
	var cs: Vector2 = GridCamera.CELL_SIZE
	for _attempt in range(120):
		var sec: Vector2i = SHADOW_SPAWN_SECTOR_GRID[randi() % SHADOW_SPAWN_SECTOR_GRID.size()]
		var wx: float = randf_range(sec.x * cs.x + 12.0, (sec.x + 1.0) * cs.x - 12.0)
		var wy: float = randf_range(sec.y * cs.y + 12.0, (sec.y + 1.0) * cs.y - 12.0)
		var cell: Vector2i = map.local_to_map(Vector2(wx, wy))
		if map.is_walkable_cell(cell):
			return cell
	var fb_sec: Vector2i = SHADOW_SPAWN_SECTOR_GRID[0]
	var approx: Vector2i = map.local_to_map(Vector2(
		float(fb_sec.x) * cs.x + cs.x * 0.5,
		float(fb_sec.y) * cs.y + cs.y * 0.5
	))
	for r: int in range(0, 10):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var try_cell: Vector2i = approx + Vector2i(dx, dy)
				if map.is_walkable_cell(try_cell):
					return try_cell
	return approx


func card_ids_from_built_deck(built: Array) -> Array[String]:
	var ids: Array[String] = []
	for cv: Variant in built:
		if typeof(cv) != TYPE_DICTIONARY:
			continue
		var s: String = str((cv as Dictionary).get("id", ""))
		if not s.is_empty():
			ids.append(s)
	return ids


func _promo_skeleton_id_for_name(enemy_name: String) -> String:
	var slug: String = enemy_name.to_lower()
	var cleaned: String = ""
	for i: int in range(slug.length()):
		var ch: String = slug[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			cleaned += ch
		elif ch == " " or ch == "_":
			cleaned += "_"
	if cleaned.is_empty():
		cleaned = "duelist"
	return "promo_sk_%s_%d" % [cleaned, absi(enemy_name.hash())]


func make_duellist_promo_skeleton_card(enemy_name: String) -> String:
	var base: Dictionary = CardDB.get_card("demon_125")
	if base.is_empty():
		base = CardDB.get_card("demon_124")
	var cid: String = _promo_skeleton_id_for_name(enemy_name)
	if not CardDB.get_card(cid).is_empty():
		return cid
	var card: Dictionary = base.duplicate(true)
	card["id"] = cid
	card["name"] = "%s Skeleton" % enemy_name
	card["atk"] = int(card.get("atk", 2)) + 1
	card["hp"] = int(card.get("hp", 2)) + 1
	card["rarity"] = "legendary"
	card["set"] = "promo"
	card["set_number"] = 99
	card["no_pack"] = true
	card["desc"] = "A legendary echo of a fallen duelist."
	card["ability"] = str(base.get("ability", ""))
	card["ability_desc"] = str(base.get("ability_desc", ""))
	CardDB.register_runtime_card(card)
	return cid


## Skull absorb: 2%% promo skeleton; else 15%% random card from deck_ids; else nothing. Always consume skull.
func try_duelist_skull_absorb(deck_ids: Array[String], enemy_name: String) -> Dictionary:
	var roll: float = randf()
	if roll < 0.02:
		var pid: String = make_duellist_promo_skeleton_card(enemy_name)
		collect_card(pid, false)
		return {"message": "Absorbed — legendary card!", "consume": true}
	if roll < 0.02 + 0.15:
		if deck_ids.is_empty():
			return {"message": "Nothing left here.", "consume": true}
		var pick: String = deck_ids[randi() % deck_ids.size()]
		collect_card(pick, false)
		return {"message": "Absorbed a card echo.", "consume": true}
	return {"message": "The skull crumbles to dust.", "consume": true}


func apply_post_kill_world_rules(enemy: Node, was_human_or_boss_kill: bool) -> void:
	if not is_instance_valid(enemy):
		return
	var deck_src: Array = []
	if enemy.has_method("get_battle_deck"):
		deck_src = enemy.call("get_battle_deck") as Array
	var ids: Array[String] = card_ids_from_built_deck(deck_src)
	if ids.is_empty() and enemy.has_method("get_shadow_source_deck_ids"):
		ids = _string_card_ids_from_raw(enemy.call("get_shadow_source_deck_ids"))
	if ids.is_empty() and "difficulty" in enemy:
		var fallback: Array = CardDB.enemy_deck_for_difficulty(str(enemy.difficulty))
		ids = card_ids_from_built_deck(fallback)
	if ids.is_empty():
		return
	if was_human_or_boss_kill:
		add_karma(-4)
	var label: String = "Unknown"
	if enemy.has_method("get_name_label"):
		label = str(enemy.call("get_name_label"))
	enqueue_overworld_shadow("%s Shadow" % label, ids)


func apply_shadow_defeat_karma() -> void:
	add_karma(1)


func instantiate_overworld_shadow_actor(entry: Dictionary) -> Node:
	var kind: String = str(entry.get("kind", "octorok"))
	var scene: PackedScene
	match kind:
		"moblin":
			scene = preload("res://data/actors/enemies/shadow_moblin.tscn")
		"knuckle":
			scene = preload("res://data/actors/enemies/shadow_iron_knuckle.tscn")
		_:
			scene = preload("res://data/actors/enemies/shadow_octorok.tscn")
	var node: Node = scene.instantiate()
	var deck_raw: Variant = entry.get("deck_ids", [])
	var ids: Array[String] = []
	if typeof(deck_raw) == TYPE_ARRAY:
		for x: Variant in deck_raw:
			if typeof(x) == TYPE_STRING:
				ids.append(x)
	var dname: String = str(entry.get("display_name", "Shadow"))
	var u: String = str(entry.get("uid", ""))
	if node.has_method("setup_overworld_shadow"):
		node.call("setup_overworld_shadow", ids, dname, u)
	return node
