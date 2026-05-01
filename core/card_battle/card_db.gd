class_name CardDB extends RefCounted

static var _map: Dictionary = {}
static var _ready_flag := false


static func get_card(id: String) -> Dictionary:
	_ensure_init()
	return _map.get(id, {}).duplicate(true)


static func starter_deck() -> Array:
	return _build(STARTER_DECK)


## Shuffled runtime deck from card id list. Falls back to [method starter_deck] if ids are illegal.
static func deck_from_card_ids(ids: Array) -> Array:
	if not deck_ids_legal(ids):
		push_warning("Deck ids illegal; using starter deck.")
		return starter_deck()
	return _build(ids.duplicate())


static func enemy_deck() -> Array:
	return _build(ENEMY_DECK)


## Hard cap for deck lists. Clocking (with mandatory draw on each refresh): you redraw STARTING_HAND (5) from
## the deck every time you end your turn (after pitching back). With no pitch and no permanents removing cards
## from the deck loop, a ~20-card deck empties in ~3–4 of your own end-steps after the opening hand; 30 adds ~2.
## Pitching slows that clock; playing cards to the board/GY removes them from the deck until recursion effects.
const DECK_SIZE_MAX := 30
const DECK_COPY_MAX := 2


## Returns the max copies of `card_id` allowed in one deck.
## Cards with ability "skeleton_horde" have no copy limit (up to DECK_SIZE_MAX).
static func card_copy_max(card_id: String) -> int:
	_ensure_init()
	var card: Dictionary = _map.get(card_id, {})
	if card.get("ability", "") == "skeleton_horde":
		return DECK_SIZE_MAX
	if "dark_lotus" in str(card.get("ability", "")):
		return 1
	if card.get("rarity", "") == "legendary":
		return 1
	return DECK_COPY_MAX


static func deck_ids_legal(ids: Array) -> bool:
	if ids.size() != DECK_SIZE_MAX:
		return false
	var counts: Dictionary = {}
	for id in ids:
		if typeof(id) != TYPE_STRING:
			return false
		var k: String = id
		counts[k] = counts.get(k, 0) + 1
		if counts[k] > card_copy_max(k):
			return false
	return true


static func _build(ids: Array) -> Array:
	_ensure_init()
	if not deck_ids_legal(ids):
		push_error("CardDB._build: illegal deck %s — falling back to STARTER_DECK." % str(ids.slice(0, 5)))
		return _build_raw(STARTER_DECK)
	return _build_raw(ids)


## Runtime enemy deck: never use player STARTER_DECK (skeletons) as fallback.
static func _build_enemy(ids: Array) -> Array:
	_ensure_init()
	if not deck_ids_legal(ids):
		push_error("CardDB._build_enemy: illegal deck %s — falling back to ENEMY_DECK." % str(ids.slice(0, 5)))
		return _build_raw(ENEMY_DECK.duplicate())
	return _build_raw(ids)


static func _build_raw(ids: Array) -> Array:
	_ensure_init()
	var deck: Array = []
	for id in ids:
		if _map.has(id):
			deck.append(_map[id].duplicate(true))
	deck.shuffle()
	return deck


static func _ensure_init() -> void:
	if _ready_flag: return
	_ready_flag = true
	for c in ALL_CARDS:
		_map[c["id"]] = c


## Sorted card ids usable in collection / deck builder (excludes tokens, includes promo/no_pack).
static func all_collectible_ids() -> Array[String]:
	_ensure_init()
	var out: Array[String] = []
	for c in ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if id.is_empty() or id.begins_with("token_"):
			continue
		out.append(id)
	out.sort()
	return out


## Sorted ids that can appear from random drops / packs (excludes no_pack and tokens).
static func pack_collectible_ids() -> Array[String]:
	_ensure_init()
	var out: Array[String] = []
	for c in ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if id.is_empty() or id.begins_with("token_"):
			continue
		if c.get("no_pack", false):
			continue
		out.append(id)
	out.sort()
	return out


## Roll one booster pack (5 cards). Returns Array of Dictionaries with added "foil" bool key.
## Cards 1-4: 100% common. Card 5: 50% rare | 20% epic | 2% legendary | 28% common.
## Card 5 foil chance: 0.88%.
static func roll_pack() -> Array:
	_ensure_init()
	var result: Array = []
	var common_pool: Array = _cards_by_rarity(["common"])
	var all_pool: Array = _all_collectible_cards()

	for _i in 4:
		var c: Dictionary = common_pool[randi() % common_pool.size()].duplicate(true)
		c["foil"] = false
		result.append(c)

	var card5: Dictionary = _roll_pack_fifth(all_pool).duplicate(true)
	card5["foil"] = _roll_foil()
	result.append(card5)
	return result


static func _roll_foil() -> bool:
	return randf() < 0.025


static func _roll_pack_fifth(all_pool: Array) -> Dictionary:
	## 5% legendary | 20% epic (mythic) | 50% rare | 28% common
	var r: float = randf() * 100.0
	var filtered: Array = []
	if r < 5.0:
		filtered = _cards_by_rarity(["legendary"])
	elif r < 22.0:
		filtered = _cards_by_rarity(["epic", "mythic"])
	elif r < 72.0:
		filtered = _cards_by_rarity(["rare"])
	else:
		filtered = _cards_by_rarity(["common"])
	if filtered.is_empty():
		filtered = all_pool
	return filtered[randi() % filtered.size()]


static func _cards_by_rarity(rarities: Array) -> Array:
	_ensure_init()
	var out: Array = []
	for c in ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if id.begins_with("token_"):
			continue
		if c.get("no_pack", false):
			continue
		if str(c.get("rarity", "")) in rarities:
			out.append(c)
	return out


static func _all_collectible_cards() -> Array:
	_ensure_init()
	var out: Array = []
	for c in ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if not id.begins_with("token_") and not c.get("no_pack", false):
			out.append(c)
	return out


# ── AI enemy decks (20 total, grouped by difficulty) ─────────────────
## Get a random enemy deck for the given difficulty tag.
static func enemy_deck_for_difficulty(difficulty: String) -> Array:
	_ensure_init()
	var pool: Array
	match difficulty:
		"easy": pool = EASY_DECKS
		"normal": pool = NORMAL_DECKS
		"hard": pool = HARD_DECKS
		_: pool = EASY_DECKS
	var chosen: Array = pool[randi() % pool.size()]
	return _build_enemy(chosen.duplicate())

# EASY decks (10) — low cost, few spells
const EASY_01 = [
	"demon_001", "demon_001", "demon_002", "demon_002", "demon_003", "demon_003", "demon_004", "demon_004", "demon_014", "demon_014", 
	"demon_005", "demon_005", "demon_008", "demon_008", "spell_002", "spell_002", "spell_001", "spell_001", "spell_013", "spell_026", 
	"demon_006", "demon_006", "demon_009", "demon_009", "demon_024", "demon_024", "demon_018", "demon_018", "demon_013", "demon_013"
]
const EASY_02 = [
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_018", "demon_018", "demon_006", "demon_006", 
	"demon_008", "demon_008", "demon_014", "demon_014", "spell_016", "spell_016", "spell_006", "spell_006", "spell_013", "spell_004", 
	"demon_009", "demon_009", "demon_024", "demon_024", "demon_013", "demon_013", "demon_015", "demon_015", "demon_012", "demon_012"
]
const EASY_03 = [
	"demon_002", "demon_002", "demon_003", "demon_003", "demon_005", "demon_005", "demon_008", "demon_008", "demon_011", "demon_011", 
	"demon_009", "demon_009", "demon_014", "demon_014", "spell_001", "spell_001", "spell_002", "spell_002", "spell_026", "spell_026", 
	"demon_001", "demon_001", "demon_004", "demon_004", "demon_006", "demon_006", "demon_024", "demon_024", "demon_018", "demon_018"
]
const EASY_04 = [
	"demon_001", "demon_001", "demon_004", "demon_004", "demon_018", "demon_018", "demon_003", "demon_003", "demon_006", "spell_001", 
	"spell_001", "spell_002", "spell_002", "spell_013", "spell_026", "demon_008", "demon_008", "demon_005", "demon_014", "demon_014", 
	"demon_006", "demon_009", "demon_009", "demon_024", "demon_024", "demon_013", "demon_013", "demon_015", "demon_015", "demon_012"
]
const EASY_05 = [
	"demon_003", "demon_003", "demon_001", "demon_001", "demon_002", "demon_002", "demon_004", "demon_004", "demon_009", "demon_014", 
	"demon_014", "demon_018", "spell_006", "spell_006", "spell_026", "spell_026", "spell_016", "spell_016", "demon_008", "demon_008", 
	"demon_006", "demon_006", "demon_009", "demon_024", "demon_024", "demon_018", "demon_013", "demon_013", "demon_015", "demon_015"
]
const EASY_06 = [
	"demon_001", "demon_001", "demon_006", "demon_002", "demon_002", "demon_003", "demon_003", "demon_004", "demon_004", "demon_018", 
	"demon_018", "demon_005", "demon_014", "spell_013", "spell_006", "spell_002", "spell_002", "spell_016", "spell_001", "demon_008", 
	"demon_006", "demon_009", "demon_009", "demon_014", "demon_024", "demon_024", "demon_013", "demon_013", "demon_015", "demon_015"
]
const EASY_07 = [
	"demon_024", "demon_024", "demon_001", "demon_001", "demon_003", "demon_003", "demon_002", "demon_002", "demon_018", "demon_018", 
	"demon_008", "demon_008", "demon_014", "demon_014", "spell_004", "spell_026", "spell_026", "spell_013", "spell_016", "demon_006", 
	"demon_004", "demon_004", "demon_006", "demon_009", "demon_009", "demon_013", "demon_013", "demon_015", "demon_015", "demon_012"
]
## Nest / swarm: cheap bodies, Imp Matron, Nest Warden, mana + free Imps.
const EASY_08 = [
	"demon_001", "demon_001", "demon_040", "demon_040", "demon_105", "demon_105", "demon_003", "demon_003", "demon_077", "demon_077", 
	"demon_018", "demon_018", "demon_024", "demon_024", "spell_016", "spell_016", "spell_026", "spell_026", "spell_048", "spell_048", 
	"demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009", "demon_014", "demon_014", "demon_013", "demon_013"
]
## Great Wall: taunt stack + heals and Hex to stall while chipping.
const EASY_09 = [
	"demon_011", "demon_011", "demon_009", "demon_009", "demon_091", "demon_091", "demon_108", "demon_108", "demon_014", "demon_014", 
	"demon_004", "demon_004", "spell_002", "spell_002", "spell_006", "spell_006", "spell_001", "spell_001", "spell_007", "spell_007", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_006", "demon_006", "demon_024", "demon_024", "demon_018", "demon_018"
]
## Through the line: Specters + chip damage + Tomes and mana to keep pressure.
const EASY_10 = [
	"demon_006", "demon_006", "demon_001", "demon_001", "demon_002", "demon_002", "demon_003", "demon_003", "demon_018", "demon_018", 
	"demon_024", "demon_024", "spell_001", "spell_001", "spell_026", "spell_026", "spell_048", "spell_048", "spell_016", "spell_016", 
	"demon_004", "demon_004", "demon_009", "demon_009", "demon_014", "demon_014", "demon_013", "demon_013", "demon_015", "demon_015"
]
const EASY_DECKS: Array = [EASY_01, EASY_02, EASY_03, EASY_04, EASY_05, EASY_06, EASY_07, EASY_08, EASY_09, EASY_10]

# NORMAL decks (12) — mid-range, more powerful demons, some synergies
const NORMAL_01 = [
	"demon_007", "demon_010", "demon_011", "demon_011", "demon_013", "demon_013", "demon_015", "demon_015", "demon_016", "demon_012", 
	"demon_012", "demon_017", "spell_004", "spell_004", "spell_007", "spell_007", "spell_005", "spell_005", "demon_027", "demon_027", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const NORMAL_02 = [
	"demon_011", "demon_011", "demon_009", "demon_009", "demon_012", "demon_012", "demon_010", "demon_016", "demon_016", "demon_017", 
	"demon_019", "demon_019", "spell_003", "spell_003", "spell_005", "spell_005", "spell_014", "spell_014", "demon_030", "demon_030", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_014", "demon_014"
]
const NORMAL_03 = [
	"demon_036", "demon_036", "demon_037", "demon_037", "demon_038", "demon_038", "demon_039", "demon_015", "demon_015", "demon_016", 
	"demon_013", "demon_013", "spell_011", "spell_011", "spell_007", "spell_007", "spell_004", "spell_004", "demon_040", "demon_040", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const NORMAL_04 = [
	"demon_019", "demon_019", "demon_010", "demon_016", "demon_016", "demon_020", "demon_012", "demon_012", "demon_013", "demon_013", 
	"spell_010", "spell_010", "spell_003", "spell_003", "spell_014", "spell_014", "demon_030", "demon_030", "demon_015", "demon_015", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const NORMAL_05 = [
	"demon_027", "demon_027", "demon_028", "demon_028", "demon_011", "demon_011", "demon_009", "demon_009", "demon_012", "demon_013", 
	"demon_013", "demon_017", "spell_012", "spell_012", "spell_008", "spell_003", "spell_014", "spell_014", "demon_016", "demon_030", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_014", "demon_014"
]
const NORMAL_06 = [
	"demon_024", "demon_024", "demon_025", "demon_025", "demon_007", "demon_019", "demon_018", "demon_018", "demon_013", "demon_013", 
	"demon_015", "demon_015", "spell_004", "spell_004", "spell_026", "spell_026", "spell_011", "spell_011", "demon_017", "demon_016", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const NORMAL_07 = [
	"demon_037", "demon_037", "demon_036", "demon_036", "demon_016", "demon_016", "demon_019", "demon_019", "demon_020", "demon_010", 
	"demon_012", "demon_012", "spell_010", "spell_010", "spell_007", "spell_007", "spell_015", "spell_011", "demon_039", "demon_040", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Hive: rats, wasps, beetles, Nest Warden, Beelzebub + Carrion Beetle + Wormoyf; mana / draw / bodies to cast them.
const NORMAL_08 = [
	"demon_003", "demon_003", "demon_047", "demon_022", "demon_081", "demon_096", "demon_096", "demon_104", "demon_104", "demon_105", 
	"demon_105", "spell_026", "spell_026", "spell_016", "spell_016", "spell_048", "spell_048", "spell_011", "spell_011", "spell_004", 
	"demon_001", "demon_001", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009", "demon_014", "demon_014"
]
## Leyline ramp: Channeling Plant, Elder Treant, taunts, Fallen Goddess draw, Cultist aura, mana rituals.
const NORMAL_09 = [
	"demon_089", "demon_089", "demon_094", "demon_094", "demon_009", "demon_009", "demon_091", "demon_091", "demon_007", "demon_013", 
	"demon_013", "demon_027", "demon_027", "spell_026", "spell_026", "spell_004", "spell_004", "spell_012", "spell_012", "spell_048", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_014", "demon_014"
]
## Death by a thousand cuts: Death Knell + deathrattle bodies + burn to face.
const NORMAL_10 = [
	"demon_030", "demon_030", "demon_005", "demon_005", "demon_077", "demon_077", "demon_014", "demon_014", "demon_016", "demon_016", 
	"demon_017", "demon_017", "spell_003", "spell_003", "spell_010", "spell_010", "spell_001", "spell_001", "spell_005", "spell_005", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Skies and tricks: Wasps, Goblin Assassins, Medusa, reach spells.
const NORMAL_11 = [
	"demon_096", "demon_096", "demon_036", "demon_036", "demon_019", "demon_019", "demon_020", "demon_020", "demon_010", "demon_010", 
	"demon_013", "demon_013", "spell_007", "spell_007", "spell_001", "spell_001", "spell_026", "spell_026", "spell_033", "spell_033", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Front-line buff: Cultist + Komainu auras, bruisers, cheap combat tricks.
const NORMAL_12 = [
	"demon_027", "demon_027", "demon_028", "demon_028", "demon_013", "demon_013", "demon_015", "demon_015", "demon_012", "demon_012", 
	"demon_011", "demon_011", "spell_006", "spell_006", "spell_012", "spell_012", "spell_007", "spell_007", "spell_001", "spell_001", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const NORMAL_DECKS: Array = [NORMAL_01, NORMAL_02, NORMAL_03, NORMAL_04, NORMAL_05, NORMAL_06, NORMAL_07, NORMAL_08, NORMAL_09, NORMAL_10, NORMAL_11, NORMAL_12]

# HARD decks (12) — mythics, legendaries, powerful combos
const HARD_01 = [
	"demon_021", "demon_022", "demon_023", "demon_042", "demon_043", "demon_019", "demon_019", "demon_020", "demon_016", "demon_016", 
	"demon_017", "demon_017", "spell_003", "spell_003", "spell_010", "spell_010", "spell_015", "spell_017", "demon_030", "demon_030", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const HARD_02 = [
	"demon_029", "demon_041", "demon_022", "demon_021", "demon_042", "demon_026", "demon_026", "demon_025", "demon_025", "demon_017", 
	"demon_017", "demon_016", "spell_004", "spell_017", "spell_010", "spell_010", "spell_003", "spell_003", "demon_030", "demon_030", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const HARD_03 = [
	"demon_023", "demon_021", "demon_022", "demon_042", "demon_043", "demon_039", "demon_039", "demon_020", "demon_020", "demon_016", 
	"demon_016", "demon_019", "spell_010", "spell_010", "spell_015", "spell_004", "spell_003", "spell_003", "demon_030", "demon_030", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const HARD_04 = [
	"demon_041", "demon_029", "demon_022", "demon_021", "demon_026", "demon_026", "demon_017", "demon_017", "demon_016", "demon_016", 
	"demon_019", "demon_020", "spell_017", "spell_004", "spell_010", "spell_015", "spell_003", "spell_003", "demon_030", "demon_040", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const HARD_05 = [
	"demon_023", "demon_042", "demon_043", "demon_021", "demon_022", "demon_019", "demon_019", "demon_020", "demon_017", "demon_016", 
	"demon_016", "demon_039", "spell_010", "spell_010", "spell_015", "spell_003", "spell_003", "spell_004", "demon_030", "demon_030", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const HARD_06 = [
	"demon_029", "demon_041", "demon_023", "demon_042", "demon_021", "demon_022", "demon_017", "demon_017", "demon_026", "demon_025", 
	"demon_016", "demon_016", "spell_017", "spell_004", "spell_015", "spell_010", "spell_003", "spell_003", "demon_030", "demon_040", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Burn / super-aggro: only Haste demons + direct damage spells (face, bolt, AoE burn).
## Curve is max speed: eight 1-drops (Lava Imp, Shade, Blaze Imp, Herald) + two 2-drop Amalgams.
const HARD_07 = [
	"demon_106", "demon_106", "demon_060", "demon_060", "demon_063", "demon_063", "demon_067", "demon_067", "demon_072", "demon_072", 
	"spell_001", "spell_001", "spell_005", "spell_010", "spell_010", "spell_013", "spell_026", "spell_026", "spell_033", "spell_033", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Big hive: same bug core + poison threats; Ancient Rites / Soul Barter to slam 4-drops fast.
const HARD_08 = [
	"demon_003", "demon_003", "demon_047", "demon_022", "demon_081", "demon_096", "demon_096", "demon_104", "demon_104", "demon_105", 
	"demon_105", "demon_058", "demon_058", "demon_055", "demon_055", "spell_026", "spell_026", "spell_011", "spell_011", "spell_004", 
	"demon_001", "demon_001", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009", "demon_014", "demon_014"
]
## Chaos / high-rarity: sixteen epics (draw, AoE, Pyroclasm, Wrath) + four one-of legendaries (Baphomet, Arcane Bolt, Plague, Final Hour).
## Booster copy refers to epics as "mythic"; all these high slots use rarity "epic" in data.
const HARD_09 = [
	"demon_023", "demon_026", "demon_026", "demon_046", "demon_046", "demon_081", "demon_081", "demon_052", "demon_052", "spell_004", 
	"spell_004", "spell_011", "spell_011", "spell_030", "spell_030", "spell_041", "spell_041", "spell_013", "spell_015", "spell_017", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Abyssal wave: sea epics + Seraph + Lich; recursion and burn from hand.
const HARD_10 = [
	"demon_021", "demon_088", "demon_088", "demon_092", "demon_092", "demon_083", "demon_083", "demon_070", "demon_070", "spell_008", 
	"spell_038", "spell_036", "spell_036", "spell_027", "spell_027", "spell_012", "spell_012", "spell_004", "spell_004", "spell_040", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Undying horde: Lich + wisps + undying fiends + removal and big burn.
const HARD_11 = [
	"demon_021", "demon_051", "demon_051", "demon_059", "demon_059", "demon_005", "demon_005", "demon_014", "demon_014", "demon_030", 
	"demon_030", "demon_016", "spell_008", "spell_004", "spell_003", "spell_003", "spell_010", "spell_010", "spell_005", "spell_005", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
## Colossus ramp: pitch + draw into Chimera / Tidal Terror; Fallen Goddess refills hand.
const HARD_12 = [
	"demon_043", "demon_043", "demon_083", "demon_083", "demon_026", "demon_026", "demon_025", "demon_025", "demon_024", "demon_024", 
	"demon_018", "demon_018", "demon_007", "spell_012", "spell_012", "spell_011", "spell_011", "spell_014", "spell_014", "spell_004", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]
const HARD_DECKS: Array = [HARD_01, HARD_02, HARD_03, HARD_04, HARD_05, HARD_06, HARD_07, HARD_08, HARD_09, HARD_10, HARD_11, HARD_12]

# ── meta decks (boss / hard AI archetypes) ─────────────────
## Death Ping: Death Knell rear anchor + cheap deathrattle bodies + drain-on-death engine.
const META_DEATH_PING: Array = [
	"demon_023", "demon_022", "demon_047", "demon_030", "demon_030",
	"spell_017", "demon_046", "demon_046", "demon_077", "demon_077",
	"demon_040", "demon_040", "demon_021", "demon_051", "demon_051",
	"demon_003", "demon_003", "spell_008", "spell_016", "spell_016",
]

## Tolarian Terror (meta-decks / design name): spam cheap spells to fill GY → Tidal Terror (demon_083) for free; Pyromancer AoE engine.
const META_TIDAL_TERROR: Array = [
	"spell_013", "spell_026", "spell_026", "spell_048", "spell_048",
	"spell_019", "spell_039", "demon_048", "spell_036", "spell_036",
	"demon_007", "demon_075", "demon_075", "spell_027", "spell_027",
	"spell_016", "spell_016", "spell_046", "demon_083", "demon_083",
]

## Kabba deck (from provided list): midrange shell with durable beasts, regalia pressure, and Plague reset.
const META_KABBA_DECK: Array = [
	"demon_102", "demon_102",
	"demon_104", "demon_104",
	"demon_022",
	"demon_010", "demon_010",
	"demon_029",
	"demon_019", "demon_019",
	"demon_017", "demon_017",
	"demon_028",
	"demon_012", "demon_012",
	"spell_015",
	"demon_026", "demon_026",
	"demon_008",
	"demon_126",
	"demon_020", "demon_020",
	"demon_053", "demon_053",
	"demon_069", "demon_069",
	"demon_100", "demon_100",
	"spell_008",
	"demon_021",
]

## Reanimator: discard fat demons to GY → Resurrection / Final Hour; Chaos King Dragon finisher.
const META_REANIMATOR: Array = [
	"demon_024", "demon_024", "demon_023", "demon_044", "demon_043", "demon_043",
	"spell_019", "demon_042", "demon_007", "spell_017",
	"demon_019", "demon_019", "demon_021", "spell_008",
	"demon_006", "demon_006", "demon_026", "demon_026", "demon_059", "demon_059",
]

## Return a built meta deck by archetype name. Falls back to a random hard deck if unknown.
static func meta_deck(archetype: String) -> Array:
	_ensure_init()
	match archetype:
		"death_ping": return _build_enemy(META_DEATH_PING.duplicate())
		"tidal_terror", "tolarian_terror": return _build_enemy(META_TIDAL_TERROR.duplicate())
		"kabba_deck": return _build_enemy(META_KABBA_DECK.duplicate())
		"reanimator": return _build_enemy(META_REANIMATOR.duplicate())
	push_warning("CardDB.meta_deck: unknown archetype '%s'" % archetype)
	return enemy_deck_for_difficulty("hard")

# ── test decks ─────────────────
const TEST_1 = [
	"demon_080", "demon_081", "demon_082", "demon_083", "demon_084", "demon_085", "demon_086", "demon_087", "demon_088", "demon_089", 
	"demon_090", "demon_091", "demon_092", "demon_093", "demon_094", "demon_095", "demon_096", "demon_097", "demon_098", "demon_099", 
	"demon_001", "demon_001", "demon_003", "demon_003", "demon_004", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009"
]

const CHAOS_KING = [
	"demon_044", "demon_002", "demon_013", "demon_017", "demon_024", "demon_062", "demon_063", "demon_067", "demon_072", "demon_118",
	"demon_119", "demon_001", "demon_004", "demon_007", "demon_011", "demon_015", "demon_016", "demon_018", "demon_025", "demon_030", 
	"demon_001", "demon_003", "demon_003", "demon_004", "demon_006", "demon_006", "demon_009", "demon_009", "demon_014", "demon_014"
]


# ── Player starter deck (30 cards: 15 Skeleton + 15 Skeleton Soldier) ───────
# Both skeleton types have "skeleton_horde" — no copy limit applies.
const STARTER_DECK = [
	"demon_124", "demon_124", "demon_124", "demon_124", "demon_124", "demon_124", "demon_124", "demon_124", "demon_124", "demon_124", 
	"demon_124", "demon_124", "demon_124", "demon_124", "demon_124", "demon_125", "demon_125", "demon_125", "demon_125", "demon_125", 
	"demon_125", "demon_125", "demon_125", "demon_125", "demon_125", "demon_125", "demon_125", "demon_125", "demon_125", "demon_125"
]

# ── Enemy deck (30 cards, aggressive, max 2 per id) ─────────────
const ENEMY_DECK = [
	"demon_001", "demon_001", "demon_002", "demon_002", "demon_003", "demon_003", "demon_004", "demon_004", "demon_009", "demon_009", 
	"demon_014", "demon_016", "demon_011", "demon_011", "demon_012", "demon_013", "spell_001", "spell_001", "spell_005", "spell_005", 
	"demon_006", "demon_006", "demon_014", "demon_024", "demon_024", "demon_018", "demon_018", "demon_013", "demon_015", "demon_015"
]

## Dev / stress-test list (high variance; not used as default fallback — see [method starter_deck]).
const PLAYTEST_DECK = CHAOS_KING

# All Bloodungeon cards (js/cards.js) + tokens; skeletons use demon_124/125 — 046+ are the BD expansion.
const ALL_CARDS = [
	{"id": "demon_001", "name": "Imp", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Bites ankles. Survives mostly by accident."},
	{"id": "demon_003", "name": "Plague Rat", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "poisonous", "ability_desc": "Poisonous — kills any demon it damages.", "desc": "One scratch. It never understood why that was enough."},
	{"id": "demon_018", "name": "Dusk Faerie", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "battlecry_draw_1", "ability_desc": "Battlecry: Draw 1 card.", "desc": "Leaves something useful at your door before dawn. Never stays long enough to explain."},
	{"id": "demon_002", "name": "Hellhound", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Somebody loved this dog once. Things change."},
	{"id": "demon_004", "name": "Shadow Hound", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "common", "ability": "", "ability_desc": "", "desc": "No name. No tricks. No grievances. Just teeth."},
	{"id": "demon_006", "name": "Specter", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "unblockable", "ability_desc": "Unblockable — can always attack the enemy directly.", "desc": "Walks through walls. Through guards. Through everything."},
	{"id": "demon_007", "name": "Fallen Goddess", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "legendary", "ability": "battlecry_draw_2", "ability_desc": "Battlecry: Draw 2 cards.", "desc": "She fell from grace. Drew two cards on the way down."},
	{"id": "demon_008", "name": "Wing Imp", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "rare", "ability": "aerial lifesteal", "ability_desc": "Aerial. Lifesteal — heals you for damage it deals.", "desc": "Heals you by drinking from your enemies. Effective. Uncomfortable to watch."},
	{"id": "demon_005", "name": "Bone Knight", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "common", "ability": "deathrattle_damage_2", "ability_desc": "Deathrattle: Deal 2 damage to the enemy when destroyed.", "desc": "Died doing its job. Still doing its job. Very professional."},
	{"id": "demon_011", "name": "Banshee", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 1, "hp": 5, "rarity": "common", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "It just wants to be heard. Loudly. By everyone within a mile."},
	{"id": "demon_013", "name": "Ifrit", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "common", "ability": "battlecry_aoe_1", "ability_desc": "Battlecry: Deal 1 damage to all enemy demons.", "desc": "Born of smokeless fire. Has very strong opinions about entering a room."},
	{"id": "demon_014", "name": "Mummy", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "common", "ability": "", "ability_desc": "", "desc": "Found in a back storage room. Still had the original wrapping. Nobody asked who put it there."},
	{"id": "demon_015", "name": "Crystal Crawler", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "divine_shield", "ability_desc": "Divine Shield — absorbs the first hit.", "desc": "The crystal grew around it slowly. Neither of them agreed to this arrangement."},
	{"id": "demon_009", "name": "Treant", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 2, "hp": 5, "rarity": "common", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "Peaceful tree, once. Ask the village. Nobody from the village is available to ask."},
	{"id": "demon_010", "name": "Cerberus Cat", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "", "ability_desc": "", "desc": "Three heads. None of them agree. All of them bite."},
	{"id": "demon_012", "name": "Minotaur", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 3, "hp": 6, "rarity": "common", "ability": "rage", "ability_desc": "Rage — gains +1 ATK every time it takes damage.", "desc": "Pain makes it stronger. It has known this for a long time."},
	{"id": "demon_016", "name": "Nightmare", "type": "demon", "subtype": "obscura", "cost": 4, "mana_value": 1, "atk": 5, "hp": 4, "rarity": "rare", "ability": "battlecry_damage_player_2", "ability_desc": "Battlecry: Deal 2 damage to the enemy.", "desc": "Its arrival alone causes pain."},
	{"id": "demon_017", "name": "Iron Djinn", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "rare", "ability": "battlecry_buff_all_hp", "ability_desc": "Battlecry: All your other demons gain +2 HP.", "desc": "Fortifies every ally around it. Never explains why it cares."},
	{"id": "demon_019", "name": "Horned Demon", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 4, "hp": 3, "rarity": "rare", "ability": "haste_lifesteal", "ability_desc": "Haste. Lifesteal — heals you for damage it deals.", "desc": "Gores first. Drinks the wound second."},
	{"id": "demon_020", "name": "Medusa", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 2, "hp": 5, "rarity": "rare", "ability": "battlecry_destroy_strongest", "ability_desc": "Battlecry: Destroy the highest-ATK enemy demon.", "desc": "People keep telling her she has a strong gaze. Fewer and fewer people every year."},
	{"id": "demon_021", "name": "Lich King", "type": "demon", "subtype": "obscura", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "legendary", "ability": "deathrattle_summon_zombie", "ability_desc": "Deathrattle: Summon a 2/2 Zombie when destroyed.", "desc": "Death is just a setback. It has had many setbacks. Still here."},
	{"id": "demon_022", "name": "Beelzebub", "type": "demon", "subtype": "obscura", "cost": 4, "mana_value": 1, "atk": 3, "hp": 5, "rarity": "legendary", "ability": "battlecry_summon_imps aerial", "ability_desc": "Aerial. Battlecry: Summon 2 Imps (1/1 Haste).", "desc": "Lord of Flies. Never answers messages. Always surrounded by people anyway."},
	{"id": "demon_023", "name": "Baphomet", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "legendary", "ability": "battlecry_destroy_all", "ability_desc": "Battlecry: Destroy all enemy demons.", "desc": "Dark god of annihilation."},
	{"id": "spell_009", "name": "Mana Surge", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "mana_boost", "value": 2, "ability_desc": "Gain 2 mana this turn.", "no_pack": true},
	{"id": "spell_004", "name": "Dark Pact", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "epic", "effect": "draw", "value": 2, "ability_desc": "Draw 2 cards."},
	{"id": "spell_016", "name": "Summon Familiar", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "summon_imp", "value": 0, "ability_desc": "Summon an Imp (1/1)."},
	{"id": "spell_002", "name": "Heal", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "heal", "value": 2, "ability_desc": "Restore 2 life."},
	{"id": "spell_006", "name": "Blood Shield", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "buff_hp", "value": 2, "ability_desc": "Give a friendly demon +2 HP."},
	{"id": "spell_013", "name": "Arcane Bolt", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "legendary", "effect": "damage", "value": 2, "ability_desc": "Deal 2 damage to the enemy."},
	{"id": "spell_001", "name": "Fireball", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "common", "effect": "damage", "value": 2, "ability_desc": "Deal 2 damage to the enemy."},
	{"id": "spell_007", "name": "Hex", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "debuff_atk", "value": 2, "ability_desc": "Reduce an enemy demon's ATK by 2."},
	{"id": "spell_011", "name": "Chain Lightning", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "epic", "effect": "aoe_demon_dmg", "value": 1, "ability_desc": "Deal 1 damage to all enemy demons."},
	{"id": "spell_012", "name": "Soul Harvest", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "epic", "effect": "life_per_demon", "value": 1, "ability_desc": "Gain 1 life per friendly demon."},
	{"id": "spell_015", "name": "Plague", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "legendary", "effect": "aoe_all_hp", "value": 3, "ability_desc": "All demons lose 3 HP."},
	{"id": "spell_003", "name": "Soul Drain", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "rare", "effect": "destroy", "value": 1, "ability_desc": "Destroy target enemy demon."},
	{"id": "spell_005", "name": "Inferno", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "rare", "effect": "aoe_enemy", "value": 2, "ability_desc": "Deal 2 damage to all enemy demons."},
	{"id": "spell_008", "name": "Resurrection", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "legendary", "effect": "resurrect", "value": 1, "ability_desc": "Summon target demon from your graveyard onto the battlefield."},
	{"id": "spell_010", "name": "Doom", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "rare", "effect": "damage", "value": 4, "ability_desc": "Deal 4 damage to the enemy."},
	{"id": "spell_014", "name": "Blood Moon", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "epic", "effect": "blood_moon_buff", "value": 1, "ability_desc": "All demons on the battlefield permanently gain +1/+1."},
	{"id": "spell_017", "name": "Final Hour", "type": "spell", "cost": 6, "mana_value": 1, "rarity": "legendary", "effect": "final_hour", "value": 0, "ability_desc": "Destroy all your demons, then fill all slots with random demons from your graveyard."},
	{"id": "spell_018", "name": "Soul Recall", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "legendary", "effect": "reanimate_demon", "value": 0, "ability_desc": "Put a demon from your graveyard directly onto the field.", "no_pack": true},
	{"id": "demon_024", "name": "Arcane Tome", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 2, "atk": 0, "hp": 1, "rarity": "common", "ability": "pitcher", "ability_desc": "Pitcher — pitches for 2 mana.", "desc": "Technically alive. Pitches mana. Doesn't like being rushed."},
	{"id": "demon_025", "name": "Elder Tome", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 2, "atk": 0, "hp": 1, "rarity": "rare", "ability": "pitcher battlecry_draw_1", "ability_desc": "Pitcher. Battlecry: Draw 1 card.", "desc": "An ancient grimoire. The annotations in the margins are more interesting than the text."},
	{"id": "demon_026", "name": "Thousand Eyes", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 2, "atk": 0, "hp": 1, "rarity": "epic", "ability": "pitcher battlecry_draw_2", "ability_desc": "Pitcher. Battlecry: Draw 2 cards.", "desc": "Sees everything. Draws two cards when played."},
	{"id": "demon_027", "name": "Cultist Leader", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "aura_front_atk_1", "ability_desc": "Aura: Other front row demons get +1 ATK.", "desc": "Chants drive the front line to slaughter."},
	{"id": "demon_028", "name": "Komainu", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "rare", "ability": "aura_front_hp_2", "ability_desc": "Aura: Other front row demons get +2 HP.", "desc": "Stone guardian. Its presence alone hardens allies."},
	{"id": "demon_029", "name": "Goblin King", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 0, "hp": 4, "rarity": "legendary", "ability": "aura_front_haste", "ability_desc": "Aura: Other front row demons gain Haste.", "desc": "His goblins move on his command. They move fast."},
	{"id": "demon_030", "name": "Death Knell", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "rare", "ability": "any_death_drain", "ability_desc": "Whenever any demon dies, the opponent loses 1 HP.", "desc": "Every fallen soul feeds its curse."},
	{"id": "demon_031", "name": "Left Arm of Osiris", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 0, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"...the left arm reached for mercy but found only chains.\" — Fragment I, House of Silence"},
	{"id": "demon_032", "name": "Right Arm of Osiris", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 0, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"...it struck the Council but they had already become something the old god could not harm.\" — Fragment II"},
	{"id": "demon_033", "name": "Head of Osiris", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"The god looked upon humans and knew: it was looking at itself.\" — Fragment III, Shattered Codex"},
	{"id": "demon_034", "name": "Left Leg of Osiris", "type": "demon", "subtype": "neutra", "cost": 0, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"It tried to flee. But humans had inherited the god's own speed.\" — Fragment IV"},
	{"id": "demon_035", "name": "Right Leg of Osiris", "type": "demon", "subtype": "neutra", "cost": 0, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"The war ended not with blood, but with betterment. And silence.\" — Fragment V, The Last Council"},
	{"id": "god_card", "name": "ROGER'S CARD — ◈ THE FIRST ONE ◈", "type": "demon", "subtype": "neutra", "cost": 0, "mana_value": 0, "atk": 0, "hp": 0, "rarity": "legendary", "ability": "god_card", "ability_desc": "◈ CARD KING ◈ — You are now god. The world bows to your will.", "desc": "\"I found it. I held it. I laughed. Then I hid it again, because some doors should only be opened once.\"\n— R.D. Roger, Last Entry", "no_pack": true, "set": "promo", "set_number": 2},
	{"id": "demon_126", "name": "Fenrir", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 2, "atk": 4, "hp": 4, "rarity": "legendary", "ability": "pitcher", "ability_desc": "Pitcher — pitches for 2 mana.", "desc": "Kabba's prize card. It tears through stone and silence alike.", "no_pack": true, "set": "promo", "set_number": 1},
	{"id": "demon_036", "name": "Goblin Assassin", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "battlecry_reposition_ally", "ability_desc": "Battlecry: Move one of your demons between rows.", "desc": "Slips allies into position before the enemy notices."},
	{"id": "demon_037", "name": "Goblin Mage", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "battlecry_reposition_enemy", "ability_desc": "Battlecry: Force an enemy front demon to the rear.", "desc": "Pushes enemies out of formation with a hex."},
	{"id": "demon_038", "name": "Goblin Sniper", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 1, "rarity": "common", "ability": "battlecry_rear_strike", "ability_desc": "Battlecry: Deal 1 damage to enemy for each demon in their rear row.", "desc": "One arrow per coward hiding in the back."},
	{"id": "demon_039", "name": "Mimic", "type": "demon", "subtype": "neutra", "cost": 2, "mana_value": 1, "atk": 0, "hp": 0, "rarity": "rare", "ability": "mimic_board_count", "ability_desc": "ATK and HP equal total demons on the battlefield.", "desc": "Opens its lid. Copies everything it sees."},
	{"id": "demon_040", "name": "Imp Matron", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 3, "rarity": "common", "ability": "battlecry_summon_imp", "ability_desc": "Battlecry: Summon a 1/1 Imp.", "desc": "She never fights alone."},
	{"id": "demon_041", "name": "Chaos Ouroboros", "type": "demon", "subtype": "neutra", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "legendary", "ability": "battlecry_equalize_hp", "ability_desc": "Battlecry: Set both players' HP to 5.", "desc": "The serpent that eats itself. Resets everything."},
	{"id": "demon_042", "name": "Demon Lord", "type": "demon", "subtype": "obscura", "cost": 7, "mana_value": 1, "atk": 8, "hp": 8, "rarity": "legendary", "ability": "", "ability_desc": "", "desc": "One of the great lords. Nothing soft about it."},
	{"id": "demon_043", "name": "Chimera", "type": "demon", "subtype": "neutra", "cost": 10, "mana_value": 1, "atk": 12, "hp": 12, "rarity": "epic", "ability": "", "ability_desc": "", "desc": "Three beasts. One nightmare. No weaknesses."},
	{"id": "demon_044", "name": "Chaos King Dragon", "type": "demon", "subtype": "neutra", "cost": 0, "mana_value": 1, "atk": 6, "hp": 6, "rarity": "legendary", "ability": "chaos_dragon", "ability_desc": "Special: Remove 3 Regalia & 3 Obscura cards from graveyard to summon. Battlecry: Deal 2 dmg per card in enemy graveyard.", "desc": "Cannot be summoned normally."},
	{"id": "demon_045", "name": "Twin Fury", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "rare", "ability": "double_attack", "ability_desc": "Can attack twice per turn.", "desc": "Strikes before you can breathe."},
	{"id": "demon_046", "name": "Grave Glutton", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "epic", "ability": "feed_on_death", "ability_desc": "Gains +1/+1 whenever any demon dies.", "desc": "It gorges on every fallen soul."},
	{"id": "demon_047", "name": "Carrion Beetle", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "legendary", "ability": "ally_death_mana", "ability_desc": "Whenever a friendly demon dies, gain 1 mana.", "desc": "Death is currency."},
	{"id": "demon_048", "name": "Echo Scholar", "type": "demon", "subtype": "neutra", "cost": 2, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "legendary", "ability": "battlecry_replay_spell", "ability_desc": "Battlecry: Replay the last spell in your graveyard for free.", "desc": "Every incantation echoes twice."},
	{"id": "demon_049", "name": "Shadow Raider", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 1, "rarity": "rare", "ability": "haste_face_draw", "ability_desc": "Haste. When this deals face damage, draw 1 card.", "desc": "Strikes the mind as well as the body."},
	{"id": "demon_050", "name": "Soul Collector", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 1, "hp": 5, "rarity": "rare", "ability": "any_death_draw_own_turn", "ability_desc": "On your turn: whenever any demon dies, draw 1 card (once per turn).", "desc": "Watches from the void. Learning."},
	{"id": "demon_051", "name": "Necrotic Wisp", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 0, "hp": 1, "rarity": "common", "ability": "deathrattle_buff_all", "ability_desc": "Deathrattle: Give all your other demons +1/+1.", "desc": "A tiny sacrifice that fuels the rest."},
	{"id": "demon_052", "name": "Blood Cultist", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "epic", "ability": "ally_death_lifegain", "ability_desc": "Whenever a friendly demon dies, gain 1 HP.", "desc": "Drinks deep from every death nearby."},
	{"id": "demon_053", "name": "Night Stalker", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 1, "rarity": "rare", "ability": "haste_unblockable", "ability_desc": "Haste. Unblockable.", "desc": "It does not fight. It just kills."},
	{"id": "demon_054", "name": "Lich's Familiar", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "common", "ability": "spell_lifegain", "ability_desc": "Gain 1 HP whenever you play a spell.", "desc": "Feeds on arcane energy."},
	{"id": "demon_055", "name": "Plague Bearer", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 4, "rarity": "common", "ability": "poisonous", "ability_desc": "Poisonous — kills any demon it damages.", "desc": "It reeks of the end."},
	{"id": "demon_056", "name": "Specter Assassin", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "battlecry_destroy_weak", "ability_desc": "Battlecry: Destroy an enemy demon with 3 or less HP.", "desc": "It picks off the wounded first."},
	{"id": "demon_057", "name": "Mind Shredder", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 4, "rarity": "common", "ability": "battlecry_discard_enemy", "ability_desc": "Battlecry: Enemy discards their top card.", "desc": "Tears knowledge from the mind."},
	{"id": "demon_058", "name": "Dusk Predator", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 4, "hp": 2, "rarity": "rare", "ability": "haste_poisonous", "ability_desc": "Haste. Poisonous.", "desc": "One scratch. One corpse."},
	{"id": "demon_059", "name": "Undying Fiend", "type": "demon", "subtype": "obscura", "cost": 5, "mana_value": 1, "atk": 4, "hp": 3, "rarity": "rare", "ability": "deathrattle_return_hand", "ability_desc": "Deathrattle: Return this to your hand when destroyed.", "desc": "It refuses to stay dead."},
	{"id": "demon_060", "name": "Larcenous Shade", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "face_damage_mana", "ability_desc": "When this deals face damage, gain 1 mana.", "desc": "Steals more than just HP."},
	{"id": "demon_061", "name": "Iron Warden", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "rare", "ability": "tax_spells", "ability_desc": "Enemy spells cost 1 extra mana.", "desc": "Her presence alone slows the enemy."},
	{"id": "demon_062", "name": "Kappa Samurai", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 2, "hp": 3, "rarity": "common", "ability": "battlecry_heal_3", "ability_desc": "Battlecry: Restore 3 HP.", "desc": "Blessed by the stars."},
	{"id": "demon_063", "name": "Thunder Amalgam", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Fast as a bolt."},
	{"id": "demon_064", "name": "Radiant Sentinel", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 1, "hp": 4, "rarity": "rare", "ability": "taunt_regen_2", "ability_desc": "Taunt. Restores 2 HP to itself at end of your turn.", "desc": "Endures through sheer divine will."},
	{"id": "demon_065", "name": "Star Prophet", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "legendary", "ability": "draw_pings", "ability_desc": "During your turn: whenever you draw a card (not your opening or refreshed hand), deal 1 damage to the enemy.", "desc": "Each revelation strikes like a blade."},
	{"id": "demon_066", "name": "Holy Knight", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 3, "hp": 4, "rarity": "rare", "ability": "divine_shield", "ability_desc": "Divine Shield — absorbs the first hit.", "desc": "No blade has yet drawn its blood."},
	{"id": "demon_067", "name": "Lightning Herald", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Arrives with the speed of thunder."},
	{"id": "demon_068", "name": "Macho Rooster", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "battlecry_buff_target_2_2", "ability_desc": "Battlecry: Give a random friendly demon +2/+2.", "desc": "Crows loudly and pumps up the crew."},
	{"id": "demon_069", "name": "Kamestoise", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 2, "hp": 6, "rarity": "rare", "ability": "taunt", "ability_desc": "Taunt.", "desc": "Will not yield."},
	{"id": "demon_070", "name": "Seraph", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 3, "hp": 5, "rarity": "epic", "ability": "divine_shield", "ability_desc": "Divine Shield — absorbs the first hit.", "desc": "Heaven's last line of defence."},
	{"id": "demon_071", "name": "Ember Thief", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "epic", "ability": "haste_face_mana", "ability_desc": "Haste. When this deals face damage, gain 1 mana.", "desc": "Steals breath with every strike."},
	{"id": "demon_072", "name": "Blaze Imp", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Burns bright and fast."},
	{"id": "demon_073", "name": "Lava Golem", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 2, "hp": 4, "rarity": "common", "ability": "battlecry_damage_random_2", "ability_desc": "Battlecry: Deal 2 damage to a random enemy demon.", "desc": "Erupts on arrival."},
	{"id": "demon_074", "name": "Infernal Drake", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "rage", "ability_desc": "Rage — gains +1 ATK every time it takes damage.", "desc": "Pain makes it stronger.", "no_pack": true},
	{"id": "demon_075", "name": "Pyromancer", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "rare", "ability": "spell_aoe", "ability_desc": "Whenever you play a spell, deal 1 damage to all enemy demons.", "desc": "Every word of power scorches the enemy."},
	{"id": "demon_076", "name": "Magma Titan", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "rare", "ability": "battlecry_aoe_rear_2", "ability_desc": "Battlecry: Deal 2 damage to all enemy rear row demons.", "desc": "Reaches over the front line."},
	{"id": "demon_077", "name": "Hellfire Imp", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "deathrattle_draw_1", "ability_desc": "Deathrattle: Draw 1 card when destroyed.", "desc": "Burns out fast, but leaves a gift."},
	{"id": "demon_078", "name": "Maced Troll", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 2, "hp": 3, "rarity": "common", "ability": "on_attack_buff_2", "ability_desc": "Whenever this attacks a demon, gain +2 ATK until end of turn.", "desc": "Gets faster the more it swings."},
	{"id": "demon_079", "name": "Phoenix", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "rare", "ability": "deathrattle_return_hand", "ability_desc": "Deathrattle: Return this to your hand when destroyed.", "desc": "Rises from its own ashes."},
	{"id": "demon_080", "name": "Green Mamba", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "poisonous on_kill_both_lose_life", "ability_desc": "Poisonous. When it kills a demon, both players lose 1 life.", "desc": "One bite ends everything."},
	{"id": "demon_081", "name": "Wormoyf", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 0, "hp": 1, "rarity": "epic", "ability": "wormoyf_power", "ability_desc": "Battlecry: Gains +1/+1 for each unique creature subtype across both graveyards.", "desc": "It feeds on chaos and variety."},
	{"id": "demon_082", "name": "Gajasura", "type": "demon", "subtype": "terresta", "cost": 5, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "rare", "ability": "battlecry_aoe_all_1", "ability_desc": "Battlecry: Deal 1 damage to ALL demons on the field, including your own.", "desc": "The ground cracks beneath its steps."},
	{"id": "demon_083", "name": "Tidal Terror", "type": "demon", "subtype": "terresta", "cost": 7, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "epic", "ability": "spell_cost_reduce_per_spell_gy", "ability_desc": "Costs 1 less for each spell in your graveyard (min 0).", "desc": "The tide rises with every spell cast."},
	{"id": "demon_084", "name": "Frost Mage", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "common", "ability": "battlecry_freeze_target", "ability_desc": "Battlecry: Exhaust (freeze) one enemy demon for a turn.", "desc": "A touch and the enemy slows."},
	{"id": "demon_085", "name": "Trick Wall", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 0, "hp": 6, "rarity": "rare", "ability": "divine_shield taunt", "ability_desc": "Divine Shield — absorbs the first hit. Taunt.", "desc": "It looks like an opening. It is not."},
	{"id": "demon_086", "name": "Ocean Lancer", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "unblockable", "ability_desc": "Unblockable.", "desc": "Strikes through the line where the sea meets the shore."},
	{"id": "demon_087", "name": "Leachtrio", "type": "demon", "subtype": "neutra", "cost": 2, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "common", "ability": "lifesteal", "ability_desc": "Lifesteal.", "desc": "Drains the arcane from the living."},
	{"id": "demon_088", "name": "Sea Serpent", "type": "demon", "subtype": "terresta", "cost": 7, "mana_value": 1, "atk": 6, "hp": 8, "rarity": "epic", "ability": "battlecry_freeze_all", "ability_desc": "Battlecry: Exhaust all enemy demons.", "desc": "Rises from the deep. None may stop it."},
	{"id": "demon_089", "name": "Channeling Plant", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 0, "hp": 2, "rarity": "common", "ability": "mana_per_turn", "ability_desc": "At the start of your turn, gain 1 mana.", "desc": "Roots into the ley line. Feeds power upward."},
	{"id": "demon_090", "name": "Storm Surge", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "common", "ability": "rage", "ability_desc": "Rage — gains +1 ATK every time it takes damage.", "desc": "The storm intensifies."},
	{"id": "demon_091", "name": "Giant Crab", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 0, "hp": 4, "rarity": "common", "ability": "taunt", "ability_desc": "Taunt.", "desc": "Sideways and stubborn. It will not move."},
	{"id": "demon_092", "name": "Deep Lurkers", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "epic", "ability": "unblockable_lifesteal", "ability_desc": "Unblockable. Lifesteal.", "desc": "Surface only to feed."},
	{"id": "demon_093", "name": "Mana Dryad", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "mana_per_turn", "ability_desc": "At the start of your turn, gain 1 mana.", "desc": "Channels the land's energy every turn."},
	{"id": "demon_094", "name": "Elder Treant", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "common", "ability": "mana_per_turn", "ability_desc": "At the start of your turn, gain 1 mana.", "desc": "Ancient and unyielding."},
	{"id": "demon_095", "name": "Sabertooth", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Pounces before you can react."},
	{"id": "demon_096", "name": "Giant Wasp", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "aerial", "ability_desc": "Aerial — can attack any enemy demon freely, ignoring front row.", "desc": "Strikes from above. No front line stops it."},
	{"id": "demon_097", "name": "Dinobeast", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "common", "ability": "", "ability_desc": "", "desc": "Old blood. Won't go down easy."},
	{"id": "demon_098", "name": "Pack Alpha", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "battlecry_buff_beast", "ability_desc": "Battlecry: Give all other friendly Terresta demons +1 ATK.", "desc": "Where it howls, the pack surges."},
	{"id": "demon_099", "name": "Thunderous Rex", "type": "demon", "subtype": "neutra", "cost": 5, "mana_value": 1, "atk": 5, "hp": 4, "rarity": "epic", "ability": "haste aerial", "ability_desc": "Haste. Aerial — can attack any enemy demon freely.", "desc": "It charges from above. Nothing stands in its way."},
	{"id": "demon_100", "name": "Elder Dragon", "type": "demon", "subtype": "neutra", "cost": 5, "mana_value": 1, "atk": 6, "hp": 6, "rarity": "epic", "ability": "aerial battlecry_aoe_2", "ability_desc": "Aerial. Battlecry: Deal 2 damage to all enemy demons.", "desc": "The oldest hunter. Strikes from above."},
	{"id": "demon_101", "name": "Dire Wolf", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "battlecry_buff_random_ally_1_atk", "ability_desc": "Battlecry: Give a random friendly demon +1 ATK.", "desc": "Leads the pack to victory."},
	{"id": "demon_102", "name": "Ancient Tortoise", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 1, "hp": 7, "rarity": "rare", "ability": "taunt", "ability_desc": "Taunt.", "desc": "Unmovable."},
	{"id": "demon_103", "name": "Primal Dragon", "type": "demon", "subtype": "terresta", "cost": 5, "mana_value": 1, "atk": 5, "hp": 6, "rarity": "common", "ability": "battlecry_buff_all_atk", "ability_desc": "Battlecry: All your other demons gain +1 ATK.", "desc": "Its roar inspires even the damned.", "no_pack": true},
	{"id": "demon_104", "name": "Armored Beetle", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 3, "hp": 6, "rarity": "rare", "ability": "", "ability_desc": "", "desc": "Thick shell. Hits hard. That is all."},
	{"id": "demon_105", "name": "Nest Warden", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "aerial deathrattle_summon_2_imps", "ability_desc": "Aerial. Deathrattle: Summon two 1/1 Imps when destroyed.", "desc": "Swoops down. Its young scatter when it falls."},
	{"id": "spell_019", "name": "Dark Lotus", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "legendary", "effect": "gain_mana", "value": 3, "ability": "dark_lotus", "ability_desc": "Gain 3 mana this turn. Only 1 copy allowed in a deck."},
	{"id": "spell_021", "name": "Ancient Rites", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "gain_mana", "value": 4, "ability_desc": "Gain 4 mana this turn.", "no_pack": true},
	{"id": "spell_022", "name": "Mana Convergence", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "epic", "effect": "destroy_own_get_mana", "value": 0, "ability_desc": "Destroy all your demons, gain 2 mana."},
	{"id": "spell_023", "name": "Soul Barter", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "mana_per_demon", "value": 1, "ability_desc": "Gain 1 mana per demon you control.", "no_pack": true},
	{"id": "spell_024", "name": "Rite of Power", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "mana_per_graveyard", "value": 5, "ability_desc": "Gain 1 mana per card in your graveyard (max 5).", "no_pack": true},
	{"id": "spell_025", "name": "Essence Surge", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "deal_and_gain_mana", "value": 2, "ability_desc": "Deal 2 to the enemy. Gain 2 mana.", "no_pack": true},
	{"id": "spell_026", "name": "Bolt", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "damage_random_demon", "value": 1, "ability_desc": "Deal 1 damage to a random enemy demon."},
	{"id": "spell_027", "name": "Shock", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "epic", "effect": "deal_face", "value": 1, "ability_desc": "Deal 1 damage to the enemy."},
	{"id": "spell_028", "name": "Lava Burst", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "common", "effect": "deal_face", "value": 5, "ability_desc": "Deal 5 damage to the enemy.", "no_pack": true},
	{"id": "spell_029", "name": "Volcanic Blast", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "deal_face", "value": 7, "ability_desc": "Deal 7 damage to the enemy.", "no_pack": true},
	{"id": "spell_030", "name": "Pyroclasm", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "epic", "effect": "aoe_all_2", "value": 2, "ability_desc": "Deal 2 damage to ALL demons on both sides."},
	{"id": "spell_031", "name": "Searing Touch", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "deal_face_if_low", "value": 5, "ability_desc": "Deal 5 to the enemy if they have 5 or less HP.", "no_pack": true},
	{"id": "spell_032", "name": "Fire Storm", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "aoe_enemy_and_face", "value": 3, "ability_desc": "Deal 3 to all enemy demons and to the enemy.", "no_pack": true},
	{"id": "spell_033", "name": "Chaos Bolt", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "chaos_damage", "value": 4, "ability_desc": "Deal 1–4 random damage to a random target (any player or demon)."},
	{"id": "spell_034", "name": "Death Toll", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "rare", "effect": "face_per_graveyard", "value": 1, "ability_desc": "Deal 1 damage to the enemy for each card in your graveyard.", "no_pack": true},
	{"id": "spell_035", "name": "Twin Bolt", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "common", "effect": "deal_face", "value": 4, "ability_desc": "Deal 4 damage to the enemy.", "no_pack": true},
	{"id": "spell_036", "name": "Ember Rain", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "epic", "effect": "aoe_demon_dmg", "value": 1, "ability_desc": "Deal 1 damage to all enemy demons."},
	{"id": "spell_037", "name": "Frost Nova", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "epic", "effect": "freeze_all_enemy", "value": 0, "ability_desc": "Exhaust all enemy demons for one turn."},
	{"id": "spell_038", "name": "Mind Control", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "legendary", "effect": "steal_demon", "value": 0, "ability_desc": "Take control of the weakest enemy demon."},
	{"id": "spell_039", "name": "Disruption", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "return_demon", "value": 0, "ability_desc": "Return the strongest enemy demon to their hand."},
	{"id": "spell_040", "name": "Drain Life", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "deal_face_drain", "value": 2, "ability_desc": "Deal 2 to the enemy. Gain 2 HP."},
	{"id": "spell_041", "name": "Wrath", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "epic", "effect": "destroy_all_both", "value": 0, "ability_desc": "Destroy ALL demons on both sides."},
	{"id": "spell_042", "name": "Silence", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "silence_demon", "value": 0, "ability_desc": "Remove the ability from the strongest enemy demon.", "no_pack": true},
	{"id": "spell_043", "name": "Transformation", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "transform_1_1", "value": 0, "ability_desc": "Transform target enemy demon into a 1/1 with no ability."},
	{"id": "spell_044", "name": "Frost Bolt", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "freeze_one_demon", "value": 0, "ability_desc": "Exhaust one enemy demon for a turn."},
	{"id": "spell_045", "name": "Execute", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "destroy_damaged", "value": 0, "ability_desc": "Destroy an enemy demon that has taken damage this turn."},
	{"id": "spell_046", "name": "Terror", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "destroy_low_atk", "value": 2, "ability_desc": "Destroy an enemy demon with 2 or less ATK."},
	{"id": "spell_047", "name": "Blood Draw", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "rare", "effect": "hp_for_draw", "value": 8, "ability_desc": "Lose 8 HP. Draw 2 cards."},
	{"id": "spell_048", "name": "Cantrip", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "draw", "value": 1, "ability_desc": "Draw 1 card."},
	{"id": "spell_049", "name": "Arcane Study", "type": "spell", "cost": 5, "mana_value": 1, "rarity": "common", "effect": "draw", "value": 2, "ability_desc": "Draw 2 cards."},
	{"id": "spell_050", "name": "Rally", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "buff_all_stats", "value": 1, "ability_desc": "Give all your demons +1/+1 until end of turn."},
	{"id": "spell_051", "name": "Battle Frenzy", "type": "spell", "cost": 5, "mana_value": 1, "rarity": "rare", "effect": "buff_atk_all_turn", "value": 2, "ability_desc": "Give all your demons +2 ATK until end of turn."},
	{"id": "spell_052", "name": "Divine Favor", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "buff_hp_all", "value": 1, "ability_desc": "Give all your demons +1 HP."},
	{"id": "spell_053", "name": "Spectral Shield", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "give_divine_shield", "value": 0, "ability_desc": "Give a friendly demon Divine Shield."},
	{"id": "spell_054", "name": "Battle Hardened", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "rare", "effect": "buff_target_stats", "value": 3, "ability_desc": "Give a friendly demon +3/+3."},
	{"id": "spell_055", "name": "Reanimate", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "reanimate_top", "value": 0, "ability_desc": "Summon the highest-cost demon from your graveyard.", "no_pack": true},
	{"id": "spell_056", "name": "Cursed Ground", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "debuff_atk_all", "value": 2, "ability_desc": "All enemy demons lose 2 ATK."},
	{"id": "spell_057", "name": "Arcane Mastery", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "legendary", "effect": "double_next_spell", "value": 0, "ability_desc": "Your next spell this turn is cast twice.", "no_pack": true},
	{"id": "spell_058", "name": "Soul Link", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "deal_face_drain", "value": 2, "ability_desc": "Deal 2 to the enemy. Gain 2 HP.", "no_pack": true},
	{"id": "demon_106", "name": "Lava Imp", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Born screaming from a volcanic vent."},
	{"id": "demon_107", "name": "Cinder Hound", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "haste_poisonous", "ability_desc": "Haste. Poisonous — kills any demon it damages.", "desc": "Ash in its lungs. Fire in its bite."},
	{"id": "demon_108", "name": "Parasitex", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "Clings to the front and won't let go."},
	{"id": "demon_109", "name": "Assault Skeleton", "type": "demon", "subtype": "neutra", "cost": 3, "mana_value": 1, "atk": 4, "hp": 1, "rarity": "rare", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Charges before it can be stopped."},
	{"id": "demon_110", "name": "Ember Phoenix", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "rare", "ability": "deathrattle_summon_ash_wraith", "ability_desc": "Deathrattle: Summon a 2/2 Ash Wraith when destroyed.", "desc": "Death is not the end. It never was on this island.", "no_pack": true},
	{"id": "demon_111", "name": "Volcano Lord", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "legendary", "ability": "battlecry_damage_player_2", "ability_desc": "Battlecry: Deal 2 damage to the enemy.", "desc": "\"The mountain speaks. You will not like what it says.\" — Magma King", "no_pack": true},
	{"id": "demon_112", "name": "Frost Rat", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "common", "ability": "poisonous", "ability_desc": "Poisonous — kills any demon it damages.", "desc": "Its bite freezes the blood solid.", "no_pack": true},
	{"id": "demon_113", "name": "Blizzard Imp", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Moves through snow like it is not there.", "no_pack": true},
	{"id": "demon_114", "name": "Glacier Drake", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 2, "hp": 5, "rarity": "common", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "An ancient predator. Older than the ice itself.", "no_pack": true},
	{"id": "demon_115", "name": "Frost Wraith", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "common", "ability": "unblockable", "ability_desc": "Unblockable — can always attack the enemy directly.", "desc": "Cold beyond cold. A draft that kills.", "no_pack": true},
	{"id": "demon_116", "name": "Permafrost Titan", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 7, "rarity": "rare", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "The north does not move. The north waits.", "no_pack": true},
	{"id": "demon_117", "name": "Glacial Sovereign", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 6, "hp": 4, "rarity": "legendary", "ability": "battlecry_aoe_1", "ability_desc": "Battlecry: Deal 1 damage to all enemy demons.", "desc": "\"The Final Council met here. In the cold. Before everything ended.\" — Fragment VII, Frost Inscription", "no_pack": true},
	{"id": "spell_059", "name": "Magma Burst", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "damage", "value": 5, "ability_desc": "Deal 5 damage. The volcano does not miss.", "no_pack": true},
	{"id": "spell_060", "name": "Blizzard", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "epic", "effect": "blizzard_freeze_dmg", "value": 2, "ability_desc": "Deal 2 damage to all demons and freeze all enemy demons."},
	{"id": "spell_061", "name": "Lava Shield", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "buff_hp", "value": 4, "ability_desc": "Give a friendly demon +4 HP. Hardened from within.", "no_pack": true},
	{"id": "spell_062", "name": "Toxic Cloud", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "common", "effect": "poison_all_enemy", "value": 3, "ability_desc": "Poison all enemy demons for 3 turns (1 dmg/turn).", "no_pack": true},
	{"id": "spell_063", "name": "Venom Strike", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "poison_one_enemy", "value": 4, "ability_desc": "Poison one enemy demon for 4 turns (1 dmg/turn).", "no_pack": true},
	{"id": "spell_064", "name": "Cure", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "cure_all_friendly", "value": 0, "ability_desc": "Remove all poison from your demons.", "no_pack": true},
	{"id": "spell_065", "name": "Plague Surge", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "poison_face", "value": 2, "ability_desc": "Deal 2 damage now, then 2 more each turn for 2 turns.", "no_pack": true},
	{"id": "demon_118", "name": "Spark Imp", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Born in a lightning strike. Gone in the next.", "no_pack": true},
	{"id": "demon_119", "name": "Storm Hound", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "haste_poisonous", "ability_desc": "Haste. Poisonous — kills any demon it damages.", "desc": "The thunder carries it. The lightning is its bite.", "no_pack": true},
	{"id": "demon_120", "name": "Tempest Knight", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 2, "hp": 6, "rarity": "common", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "Stands in the eye of the storm. Unmoved.", "no_pack": true},
	{"id": "demon_121", "name": "Thunder Drake", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 5, "hp": 2, "rarity": "rare", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Strikes from the clouds before you can react.", "no_pack": true},
	{"id": "demon_122", "name": "Stormcaller", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 3, "hp": 5, "rarity": "rare", "ability": "battlecry_aoe_2", "ability_desc": "Battlecry: Deal 2 damage to all enemy demons.", "desc": "\"The storm does not choose its victims. It teaches them.\" — Stormcaller IX", "no_pack": true},
	{"id": "demon_123", "name": "Thunder Sovereign", "type": "demon", "subtype": "regalia", "cost": 5, "mana_value": 1, "atk": 6, "hp": 6, "rarity": "legendary", "ability": "battlecry_damage_player_2", "ability_desc": "Battlecry: Deal 2 damage to the enemy.", "desc": "\"He who commands the storm commands all. And I command the storm.\" — Thunder Sovereign", "no_pack": true},
	{"id": "spell_066", "name": "Lightning Bolt", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "damage", "value": 6, "ability_desc": "Deal 6 damage. The sky does not warn you.", "no_pack": true},
	{"id": "spell_067", "name": "Chain Lightning", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "aoe_enemy", "value": 2, "ability_desc": "Deal 2 damage to all enemy demons. The chain never ends.", "no_pack": true},
	{"id": "spell_068", "name": "Thunder Ward", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "buff_hp", "value": 3, "ability_desc": "Give a friendly demon +3 HP. Hardened by lightning strikes.", "no_pack": true},
	# TOKENS (zelda battle)
	{"id": "token_zombie", "name": "Zombie", "type": "demon", "subtype": "obscura", "cost": 0, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "", "ability_desc": "", "desc": "A shuffling undead."},
	{"id": "token_ash_wraith", "name": "Ash Wraith", "type": "demon", "subtype": "regalia", "cost": 0, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "", "ability_desc": "", "desc": "Born from the phoenix's last breath."},
	{"id": "token_imp", "name": "Imp", "type": "demon", "subtype": "obscura", "cost": 0, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "A tiny demon."},
	# Zelda legacy skeletons (IDs moved; bloodungeon 046+ are expansion cards)
	{"id": "demon_124", "name": "Skeleton", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "skeleton_horde", "ability_desc": "Skeleton Horde — no copy limit in your deck.", "desc": "A rookie in the infernal army."},
	{"id": "demon_125", "name": "Skeleton Soldier", "type": "demon", "subtype": "neutra", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "skeleton_horde", "ability_desc": "Skeleton Horde — no copy limit in your deck.", "desc": "Frontline of the infernal army."}, ]


## ── Flavor text (Demon Summoner lore) ───────────────────────────────────────
## Shown in collection detail view when a card is clicked.
const FLAVOR_DB: Dictionary = {
	"demon_001": "Summoned before it had a name. It has not missed one.",
	"demon_002": "It has never looked back. There is nothing to see.",
	"demon_003": "One bite is enough. One refusal would have cost everything.",
	"demon_004": "No name. No grievance. It arrived ready.",
	"demon_005": "The armor stayed. The one inside departed long ago. Both still serve.",
	"demon_006": "Passes through walls, rules, and memory with equal ease.",
	"demon_007": "She fell from somewhere vast. She has not stopped falling.",
	"demon_008": "It learned to fly the day it forgot the ground.",
	"demon_009": "The roots remember a different soil.",
	"demon_010": "Three heads, one name, no opinion on either.",
	"demon_011": "The scream is the only word it has left.",
	"demon_012": "The labyrinth was not a prison. It was the last place it chose.",
	"demon_013": "Burns what it is given. Does not ask why.",
	"demon_014": "Ancient and wrapped tight. Something is preserved inside. Something else is not.",
	"demon_015": "The crystal grew around it slowly. Neither one remembers who started.",
	"demon_016": "Lives in the gap between what was permitted and what arrived.",
	"demon_017": "Granted three wishes to the wrong master. Now grants nothing at all.",
	"demon_018": "She carries something you will need. Neither of you will know what, until it arrives.",
	"demon_019": "Old enough to remember a smell from before these islands. Cannot name it.",
	"demon_020": "She turned something to stone long before the summoning. She thinks.",
	"demon_021": "Governs the dead because the living no longer require a king.",
	"demon_022": "When it speaks, it speaks in numbers. Someone, somewhere, is counting.",
	"demon_023": "Carries a symbol older than this land.",
	"demon_024": "Pages in a language predating this place. Still being translated.",
	"demon_025": "The annotations in the margins are more interesting than the text.",
	"demon_026": "Watches. Records. Carries the weight of everything it has seen.",
	"demon_027": "It leads with certainty. It has never been told where.",
	"demon_028": "Guards what it was told to guard. Never asked what was inside.",
	"demon_029": "A king of nothing, for nothing. The title stuck.",
	"demon_030": "Rings for every soul that falls. It has been needed often.",
	"demon_031": "Separated at the moment of completion. Still reaching.",
	"demon_032": "Reached for something the old texts call the Council. Found only this.",
	"demon_033": "Knows everything the body cannot act on.",
	"demon_034": "Has been walking since before anyone kept count. Toward nothing named.",
	"demon_035": "The last piece placed. The first to be sought.",
	"demon_036": "Places allies precisely. It has never been told the full plan.",
	"demon_037": "Pushes enemies where they need to be. Asks nothing.",
	"demon_038": "Watches from a distance. Has been watching longer than it knows.",
	"demon_039": "Copies what it sees. Grows from what it copies. Does not know the original.",
	"demon_040": "She never fights alone. Neither did what she came from.",
	"demon_041": "Levels everything. Begins again. Has always begun again.",
	"demon_042": "Existed before this place had rules. Rules grew up around it.",
	"demon_043": "Three beasts, one name. Someone long ago decided they were one thing.",
	"demon_044": "Called by the convergence of what was taken and what was given. It does not call itself anything.",
	"demon_045": "Strikes twice because it was built to. Asks no questions.",
	"demon_046": "Grows stronger on what others leave behind. It grows regardless.",
	"demon_047": "Every death feeds something. It learned that early.",
	"demon_048": "Hears every incantation twice. The second time it understands.",
	"demon_049": "Moves fast enough that the victim learns something they did not expect.",
	"demon_050": "Watches from the edge. Notes every loss. The count is very high.",
	"demon_051": "A small sacrifice. It was made for exactly this.",
	"demon_052": "Fed by every death nearby. There are always deaths nearby.",
	"demon_053": "Does not wait. Does not hesitate. Leaves nothing behind.",
	"demon_054": "Grows stronger with every word spoken. Something speaks constantly.",
	"demon_055": "Carries the end inside it. Has always carried it.",
	"demon_056": "Selects the wounded first. There are always wounded.",
	"demon_057": "Removes what was known. Something fills the space left behind.",
	"demon_058": "Fast. Lethal. A single purpose, perfectly executed.",
	"demon_059": "Returns every time it is destroyed. The record of it cannot be erased.",
	"demon_060": "Takes more than health with every strike. It is not sure what else it takes.",
	"demon_061": "Her presence raises the cost of everything. Including leaving.",
	"demon_062": "Blessed by something it cannot name. It is grateful anyway.",
	"demon_063": "Fast as a thought. Obedient as one too.",
	"demon_064": "Endures. Restores. Endures. That is all it knows.",
	"demon_065": "Every new truth strikes like a blow. There are many truths left.",
	"demon_066": "No blade has yet found what is underneath the shield.",
	"demon_067": "Arrives with speed. Leaves nothing.",
	"demon_068": "Loud. Enthusiastic. Does not know where the enthusiasm came from.",
	"demon_069": "Will not move. Has never been told it could.",
	"demon_070": "The last light before the dark settles. It does not know this.",
	"demon_071": "Steals something with every strike. Does not know the name of what it takes.",
	"demon_072": "Burns bright. Has always burned. Asks nothing about the before.",
	"demon_073": "Erupts on arrival. The arrival was not its idea.",
	"demon_075": "Every word of power finds the enemy. The words were written elsewhere.",
	"demon_076": "Reaches over the line drawn for it. It was always going to.",
	"demon_077": "Burns out fast. Leaves something behind. Something planned for this.",
	"demon_078": "Grows faster the more it strikes. It has struck many times before.",
	"demon_079": "Returns from ash. Has returned many times. The count is not recorded.",
	"demon_080": "One bite. Both sides bleed. It has always worked this way.",
	"demon_081": "Grows from every pattern it observes. This place is full of patterns.",
	"demon_082": "The ground cracks where it steps. It has stepped here before.",
	"demon_083": "The tide rises with each word spoken. Count the drowned. Count the words.",
	"demon_084": "A touch and something slows. What was slowed does not fully know why.",
	"demon_085": "Looks like an opening. Has always looked like an opening.",
	"demon_086": "Strikes where the water meets the shore. The shore was placed there.",
	"demon_087": "Drains something unseen from the living. Grows from the draining.",
	"demon_088": "Rises from depth. Everything stops. Something allows this, briefly.",
	"demon_089": "Roots into the ley line. Something above opens wider.",
	"demon_090": "The storm grows each time it is struck. Someone anticipated this.",
	"demon_091": "Stubborn and sideways. It has always been here.",
	"demon_092": "Surfaces only to feed. The depth it returns to has no name.",
	"demon_093": "The land gives what is needed. The land does not explain why.",
	"demon_094": "Ancient. Slow. Feeds the flow. Does not ask where it leads.",
	"demon_095": "Pounces before you have finished deciding.",
	"demon_096": "Strikes from above the line. The line was not meant for it.",
	"demon_097": "Old blood. Old purpose. No say in either.",
	"demon_098": "Where it howls, the others grow stronger. It learned this from somewhere.",
	"demon_099": "From above, nothing stops it. The air is where it belongs.",
	"demon_100": "The oldest hunter. Arrived before this place had a name.",
	"demon_101": "Leads the pack to where it was pointed.",
	"demon_102": "Has not moved in a very long time. Considers this resistance.",
	"demon_104": "Shell. Weight. Purpose. That is all it was given.",
	"demon_105": "Swoops down. When it falls, what comes next was always the plan.",
	"demon_124": "Assembled. Deployed. Disassembled. Assembled again.",
	"demon_125": "The front line. Always the front line. It has never been anything else.",
	"spell_001": "Basic. Brutal. Reliable.",
	"spell_002": "Some mercy is permitted here. Exactly enough to keep the fighting going.",
	"spell_003": "Does not kill. Reassigns.",
	"spell_004": "Both parties know the terms. Only one knows the full contract.",
	"spell_005": "Heat without origin. Damage without explanation.",
	"spell_006": "Paid in the only currency accepted here without question.",
	"spell_007": "A mark. A label. Whatever carries it fights differently now.",
	"spell_008": "Returns what was placed. Does not return what was taken.",
	"spell_009": "The channel opens briefly. Something upstream decides to allow it.",
	"spell_010": "A conclusion decided before the duel began.",
	"spell_011": "Everything it touches, it shares with the next. The last one never saw the first.",
	"spell_012": "Feeds on what the fallen leave. There is always something left.",
	"spell_013": "Simple. Fast. Beloved by those who do not ask where it comes from.",
	"spell_014": "All things grow stronger under the right conditions. Someone knows the conditions.",
	"spell_015": "Shared equally across all. There is a strange comfort in that.",
	"spell_016": "Called from the pool of the unassigned. It did not know it was waiting.",
	"spell_017": "The last word before everything changes. Spoken once. Usually.",
	"spell_018": "Nothing is ever truly gone from here.",
	"spell_019": "A gift from somewhere above. There is only one, by old agreement.",
	"spell_022": "Everything disappears. Two things open. What was given comes back first.",
	"spell_026": "A single point of force. The origin is not your concern.",
	"spell_027": "Strikes once. The point is that it was struck at all.",
	"spell_030": "Both sides. Equal. Sometimes that is the only fair outcome.",
	"spell_033": "Lands somewhere at random. Something decided where.",
	"spell_036": "Falls like weather. Something controls the weather.",
	"spell_037": "Everything stops. It has stopped before. It always starts again.",
	"spell_038": "What was the enemy's is yours now. It happens.",
	"spell_039": "Returns the strongest one to where it came from. It will be back.",
	"spell_040": "Takes from one. Gives to another. The total does not change.",
	"spell_041": "Everything destroyed. It has happened before. More than once.",
	"spell_043": "What it was, stripped away. What remains is a beginning.",
	"spell_044": "A pause, not an end. The fight always resumes.",
	"spell_045": "Finishes what was already started.",
	"spell_046": "Some were never going to last. Something knew this from the start.",
	"spell_047": "Knowledge costs. The price was decided by something that does not bleed.",
	"spell_048": "A small word. Barely a word. But it opens something.",
	"spell_049": "Sit still. Look closer. This place rewards those who do.",
	"spell_050": "Brief strength, shared and then gone.",
	"spell_051": "Power for a moment. It comes and it goes.",
	"spell_052": "A small gift to each. It is not nothing.",
	"spell_053": "Protection, for now.",
	"spell_054": "Growth through endurance. Something rewards those who last.",
	"spell_056": "Weakened, all of them. It can happen like that.",
	"spell_060": "Cold and stillness, all at once.",
	"god_card": "He got tired of being God. Left this behind somewhere. Hoped someone worth it would find it.",
	"demon_126": "A promo relic from Kabba's hoard. It pitches like a tome and bites like a god-beast.",
}

## Returns the flavor text for a card id, or empty string if none.
static func get_flavor(id: String) -> String:
	return FLAVOR_DB.get(id, "")
