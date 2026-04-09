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
const DECK_SIZE_MAX := 20
const DECK_COPY_MAX := 2


## Returns the max copies of `card_id` allowed in one deck.
## Cards with ability "skeleton_horde" have no copy limit (up to DECK_SIZE_MAX).
static func card_copy_max(card_id: String) -> int:
	_ensure_init()
	var card: Dictionary = _map.get(card_id, {})
	if card.get("ability", "") == "skeleton_horde":
		return DECK_SIZE_MAX
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


## Sorted card ids usable in collection / deck builder (excludes tokens).
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
	return randf() < 0.0088


static func _roll_pack_fifth(all_pool: Array) -> Dictionary:
	## 2% legendary | 20% epic (mythic) | 50% rare | 28% common
	var r: float = randf() * 100.0
	var filtered: Array = []
	if r < 2.0:
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
		if str(c.get("rarity", "")) in rarities:
			out.append(c)
	return out


static func _all_collectible_cards() -> Array:
	_ensure_init()
	var out: Array = []
	for c in ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if not id.begins_with("token_"):
			out.append(c)
	return out


# ── AI enemy decks (20 total, grouped by difficulty) ─────────────────
## Get a random enemy deck for the given difficulty tag.
static func enemy_deck_for_difficulty(difficulty: String) -> Array:
	_ensure_init()
	var pool: Array
	match difficulty:
		"easy":   pool = EASY_DECKS
		"normal": pool = NORMAL_DECKS
		"hard":   pool = HARD_DECKS
		_:        pool = EASY_DECKS
	var chosen: Array = pool[randi() % pool.size()]
	return _build(chosen.duplicate())

# EASY decks (7) — low cost, few spells
const EASY_01 = [
	"demon_001","demon_001","demon_002","demon_002","demon_003","demon_003",
	"demon_004","demon_004","demon_014","demon_014","demon_005","demon_005",
	"demon_008","demon_008","spell_002","spell_002","spell_001","spell_001",
	"spell_013","spell_013",
]
const EASY_02 = [
	"demon_001","demon_001","demon_003","demon_003","demon_004","demon_004",
	"demon_018","demon_018","demon_006","demon_006","demon_008","demon_008",
	"demon_014","demon_014","spell_016","spell_016","spell_006","spell_006",
	"spell_013","spell_013",
]
const EASY_03 = [
	"demon_002","demon_002","demon_003","demon_003","demon_005","demon_005",
	"demon_008","demon_008","demon_011","demon_011","demon_009","demon_009",
	"demon_014","demon_014","spell_001","spell_001","spell_002","spell_002",
	"spell_009","spell_009",
]
const EASY_04 = [
	"demon_001","demon_001","demon_004","demon_004","demon_018","demon_018",
	"demon_003","demon_003","demon_006","spell_001","spell_001","spell_002",
	"spell_002","spell_013","spell_013","demon_008","demon_008","demon_005",
	"demon_014","demon_014",
]
const EASY_05 = [
	"demon_003","demon_003","demon_001","demon_001","demon_002","demon_002",
	"demon_004","demon_004","demon_009","demon_014","demon_014","demon_018",
	"spell_006","spell_006","spell_009","spell_009","spell_016","spell_016",
	"demon_008","demon_008",
]
const EASY_06 = [
	"demon_001","demon_001","demon_001","demon_002","demon_002","demon_003",
	"demon_003","demon_004","demon_004","demon_018","demon_018","demon_005",
	"demon_014","spell_013","spell_013","spell_002","spell_002","spell_016",
	"spell_001","demon_008",
]
const EASY_07 = [
	"demon_024","demon_024","demon_001","demon_001","demon_003","demon_003",
	"demon_002","demon_002","demon_018","demon_018","demon_008","demon_008",
	"demon_014","demon_014","spell_004","spell_009","spell_009","spell_013",
	"spell_013","demon_006",
]
const EASY_DECKS: Array = [EASY_01, EASY_02, EASY_03, EASY_04, EASY_05, EASY_06, EASY_07]

# NORMAL decks (7) — mid-range, more powerful demons, some synergies
const NORMAL_01 = [
	"demon_007","demon_007","demon_011","demon_011","demon_013","demon_013",
	"demon_015","demon_015","demon_016","demon_012","demon_012","demon_017",
	"spell_004","spell_004","spell_007","spell_007","spell_005","spell_005",
	"demon_027","demon_027",
]
const NORMAL_02 = [
	"demon_011","demon_011","demon_009","demon_009","demon_012","demon_012",
	"demon_010","demon_016","demon_016","demon_017","demon_019","demon_019",
	"spell_003","spell_003","spell_005","spell_005","spell_014","spell_014",
	"demon_030","demon_030",
]
const NORMAL_03 = [
	"demon_036","demon_036","demon_037","demon_037","demon_038","demon_038",
	"demon_039","demon_015","demon_015","demon_016","demon_013","demon_013",
	"spell_011","spell_011","spell_007","spell_007","spell_004","spell_004",
	"demon_040","demon_040",
]
const NORMAL_04 = [
	"demon_019","demon_019","demon_010","demon_016","demon_016","demon_020",
	"demon_012","demon_012","demon_013","demon_013","spell_010","spell_010",
	"spell_003","spell_003","spell_014","spell_014","demon_030","demon_030",
	"demon_015","demon_015",
]
const NORMAL_05 = [
	"demon_027","demon_027","demon_028","demon_028","demon_011","demon_011",
	"demon_009","demon_009","demon_012","demon_013","demon_013","demon_017",
	"spell_012","spell_012","spell_008","spell_008","spell_014","spell_014",
	"demon_016","demon_030",
]
const NORMAL_06 = [
	"demon_024","demon_024","demon_025","demon_025","demon_007","demon_007",
	"demon_018","demon_018","demon_013","demon_013","demon_015","demon_015",
	"spell_004","spell_004","spell_009","spell_009","spell_011","spell_011",
	"demon_017","demon_016",
]
const NORMAL_07 = [
	"demon_037","demon_037","demon_036","demon_036","demon_016","demon_016",
	"demon_019","demon_019","demon_020","demon_010","demon_012","demon_012",
	"spell_010","spell_010","spell_007","spell_007","spell_015","spell_015",
	"demon_039","demon_040",
]
const NORMAL_DECKS: Array = [NORMAL_01, NORMAL_02, NORMAL_03, NORMAL_04, NORMAL_05, NORMAL_06, NORMAL_07]

# HARD decks (6) — mythics, legendaries, powerful combos
const HARD_01 = [
	"demon_021","demon_022","demon_023","demon_042","demon_043","demon_019",
	"demon_019","demon_020","demon_016","demon_016","demon_017","demon_017",
	"spell_003","spell_003","spell_010","spell_010","spell_015","spell_015",
	"demon_030","demon_030",
]
const HARD_02 = [
	"demon_029","demon_041","demon_022","demon_021","demon_042","demon_026",
	"demon_026","demon_025","demon_025","demon_017","demon_017","demon_016",
	"spell_018","spell_017","spell_010","spell_010","spell_003","spell_003",
	"demon_030","demon_030",
]
const HARD_03 = [
	"demon_023","demon_021","demon_022","demon_042","demon_043","demon_039",
	"demon_039","demon_020","demon_020","demon_016","demon_016","demon_019",
	"spell_010","spell_010","spell_015","spell_015","spell_003","spell_003",
	"demon_030","demon_030",
]
const HARD_04 = [
	"demon_041","demon_029","demon_022","demon_021","demon_026","demon_026",
	"demon_017","demon_017","demon_016","demon_016","demon_019","demon_020",
	"spell_017","spell_018","spell_010","spell_015","spell_003","spell_003",
	"demon_030","demon_040",
]
const HARD_05 = [
	"demon_023","demon_042","demon_043","demon_021","demon_022","demon_019",
	"demon_019","demon_020","demon_017","demon_016","demon_016","demon_039",
	"spell_010","spell_010","spell_015","spell_003","spell_003","spell_018",
	"demon_030","demon_030",
]
const HARD_06 = [
	"demon_029","demon_041","demon_023","demon_042","demon_021","demon_022",
	"demon_017","demon_017","demon_026","demon_025","demon_016","demon_016",
	"spell_017","spell_018","spell_015","spell_010","spell_003","spell_003",
	"demon_030","demon_040",
]
const HARD_DECKS: Array = [HARD_01, HARD_02, HARD_03, HARD_04, HARD_05, HARD_06]

# ── test decks ─────────────────
const TEST_1 = [
	"demon_080", "demon_081",
	"demon_082", "demon_083",
	"demon_084", "demon_085",
	"demon_086", "demon_087",
	"demon_088", "demon_089",
	"demon_090", "demon_091",
	"demon_092", "demon_093",
	"demon_094", "demon_095",
	"demon_096", "demon_097",
	"demon_098", "demon_099",
]

const CHAOS_KING = [
	"demon_044", "demon_044",
	"demon_013", "demon_017", "demon_024", "demon_062", "demon_063", "demon_067", "demon_072", "demon_118", "demon_119",
	"demon_001", "demon_004", "demon_007", "demon_011", "demon_015", "demon_016", "demon_018", "demon_025", "demon_030",
]


# ── Player starter deck (20 cards: 10 Skeleton + 10 Skeleton Soldier) ───────
# Both skeleton types have "skeleton_horde" — no copy limit applies.
const STARTER_DECK = [
	"demon_124", "demon_124", "demon_124", "demon_124", "demon_124",
	"demon_124", "demon_124", "demon_124", "demon_124", "demon_124",
	"demon_125", "demon_125", "demon_125", "demon_125", "demon_125",
	"demon_125", "demon_125", "demon_125", "demon_125", "demon_125",
]

# ── Enemy deck (20 cards, aggressive, max 2 per id) ─────────────
const ENEMY_DECK = [
	"demon_001", "demon_001",
	"demon_002", "demon_002",
	"demon_003", "demon_003",
	"demon_004", "demon_004",
	"demon_009", "demon_009",
	"demon_014",
	"demon_016",
	"demon_011", "demon_011",
	"demon_012", "demon_013",
	"spell_001", "spell_001",
	"spell_005", "spell_005",
]

## Dev / stress-test list (high variance; not used as default fallback — see [method starter_deck]).
const PLAYTEST_DECK = CHAOS_KING

# All Bloodungeon cards (js/cards.js) + tokens; skeletons use demon_124/125 — 046+ are the BD expansion.
const ALL_CARDS = [
	{"id": "demon_001", "name": "Imp", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "A weak little demon. Darts in fast."},
	{"id": "demon_003", "name": "Plague Rat", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "poisonous", "ability_desc": "Poisonous — kills any demon it damages.", "desc": "One scratch is enough."},
	{"id": "demon_018", "name": "Dusk Faerie", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "uncommon", "ability": "battlecry_draw_1", "ability_desc": "Battlecry: Draw 1 card.", "desc": "Worth playing for the card it brings."},
	{"id": "demon_002", "name": "Hellhound", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Bites hard and fast."},
	{"id": "demon_004", "name": "Shadow Hound", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "common", "ability": "", "ability_desc": "", "desc": "A reliable fighter with no tricks."},
	{"id": "demon_006", "name": "Specter", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "uncommon", "ability": "unblockable", "ability_desc": "Unblockable — can always attack the enemy directly.", "desc": "Slips past any defence."},
	{"id": "demon_007", "name": "Fallen Goddess", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "rare", "ability": "battlecry_draw_2", "ability_desc": "Battlecry: Draw 2 cards.", "desc": "She fell from grace. Drew two cards on the way down."},
	{"id": "demon_008", "name": "Wing Imp", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 3, "rarity": "common", "ability": "lifesteal", "ability_desc": "Lifesteal — heals you for damage it deals.", "desc": "Swoops in and drains life with every strike."},
	{"id": "demon_005", "name": "Bone Knight", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 3, "hp": 4, "rarity": "common", "ability": "deathrattle_damage_2", "ability_desc": "Deathrattle: Deal 2 damage to the enemy when destroyed.", "desc": "Even in death it strikes."},
	{"id": "demon_011", "name": "Banshee", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 1, "hp": 5, "rarity": "uncommon", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "Its wail forces every eye towards it."},
	{"id": "demon_013", "name": "Ifrit", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "uncommon", "ability": "battlecry_aoe_1", "ability_desc": "Battlecry: Deal 1 damage to all enemy demons.", "desc": "Born of smokeless fire. Scorches all on arrival."},
	{"id": "demon_014", "name": "Mummy", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "common", "ability": "", "ability_desc": "", "desc": "Wrapped tight. Hits harder than it looks."},
	{"id": "demon_015", "name": "Ice Crawler", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "uncommon", "ability": "unblockable", "ability_desc": "Unblockable — can always attack the enemy directly.", "desc": "Skitters through frozen cracks. Nothing stops it."},
	{"id": "demon_009", "name": "Treant", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 2, "hp": 5, "rarity": "uncommon", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "Ancient bark, ancient grudge. It will not move."},
	{"id": "demon_010", "name": "Cerberus", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 2, "rarity": "rare", "ability": "haste_poisonous", "ability_desc": "Haste. Poisonous — kills any demon it damages.", "desc": "Three heads, triple the danger."},
	{"id": "demon_012", "name": "Minotaur", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 3, "hp": 6, "rarity": "uncommon", "ability": "rage", "ability_desc": "Rage — gains +1 ATK every time it takes damage.", "desc": "The more it hurts, the angrier it gets."},
	{"id": "demon_016", "name": "Nightmare", "type": "demon", "subtype": "obscura", "cost": 4, "mana_value": 1, "atk": 5, "hp": 4, "rarity": "rare", "ability": "battlecry_damage_player_2", "ability_desc": "Battlecry: Deal 2 damage to the enemy.", "desc": "Its arrival alone causes pain."},
	{"id": "demon_017", "name": "Iron Djinn", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "rare", "ability": "battlecry_buff_all_atk", "ability_desc": "Battlecry: All your other demons gain +1 ATK.", "desc": "Inspires the horde."},
	{"id": "demon_019", "name": "Horned Demon", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 4, "hp": 3, "rarity": "rare", "ability": "haste_lifesteal", "ability_desc": "Haste. Lifesteal — heals you for damage it deals.", "desc": "Gores first. Drinks the wound second."},
	{"id": "demon_020", "name": "Medusa", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 5, "rarity": "rare", "ability": "battlecry_destroy_strongest", "ability_desc": "Battlecry: Destroy the highest-ATK enemy demon.", "desc": "One look kills."},
	{"id": "demon_021", "name": "Lich King", "type": "demon", "subtype": "obscura", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "mythic", "ability": "deathrattle_summon_zombie", "ability_desc": "Deathrattle: Summon a 2/2 Zombie when destroyed.", "desc": "Death is just a setback."},
	{"id": "demon_022", "name": "Beelzebub", "type": "demon", "subtype": "obscura", "cost": 4, "mana_value": 1, "atk": 3, "hp": 5, "rarity": "mythic", "ability": "battlecry_summon_imps", "ability_desc": "Battlecry: Summon 2 Imps (1/1 Haste).", "desc": "Lord of Flies — never alone."},
	{"id": "demon_023", "name": "Baphomet", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "legendary", "ability": "battlecry_destroy_all", "ability_desc": "Battlecry: Destroy all enemy demons.", "desc": "Dark god of annihilation."},
	{"id": "spell_009", "name": "Mana Surge", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "uncommon", "effect": "mana_boost", "value": 2, "ability_desc": "Gain 2 mana this turn."},
	{"id": "spell_004", "name": "Dark Pact", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "draw", "value": 2, "ability_desc": "Draw 2 cards."},
	{"id": "spell_016", "name": "Summon Familiar", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "summon_imp", "value": 0, "ability_desc": "Summon an Imp (1/1)."},
	{"id": "spell_002", "name": "Heal", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "heal", "value": 2, "ability_desc": "Restore 2 life."},
	{"id": "spell_006", "name": "Blood Shield", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "common", "effect": "buff_hp", "value": 2, "ability_desc": "Give a friendly demon +2 HP."},
	{"id": "spell_013", "name": "Arcane Bolt", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "damage", "value": 2, "ability_desc": "Deal 2 damage to the enemy."},
	{"id": "spell_001", "name": "Fireball", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "common", "effect": "damage", "value": 3, "ability_desc": "Deal 3 damage to the enemy."},
	{"id": "spell_007", "name": "Hex", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "debuff_atk", "value": 2, "ability_desc": "Reduce an enemy demon's ATK by 2."},
	{"id": "spell_011", "name": "Chain Lightning", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "aoe_demon_dmg", "value": 1, "ability_desc": "Deal 1 damage to all enemy demons."},
	{"id": "spell_012", "name": "Soul Harvest", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "life_per_demon", "value": 1, "ability_desc": "Gain 1 life per friendly demon."},
	{"id": "spell_015", "name": "Plague", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "rare", "effect": "aoe_all_hp", "value": 3, "ability_desc": "All demons lose 3 HP."},
	{"id": "spell_003", "name": "Soul Drain", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "destroy", "value": 1, "ability_desc": "Destroy an enemy demon."},
	{"id": "spell_005", "name": "Inferno", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "aoe_enemy", "value": 2, "ability_desc": "Deal 2 damage to all enemy demons."},
	{"id": "spell_008", "name": "Resurrection", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "resurrect", "value": 1, "ability_desc": "Return the top card of your discard to hand."},
	{"id": "spell_010", "name": "Doom", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "damage", "value": 4, "ability_desc": "Deal 4 damage to the enemy."},
	{"id": "spell_014", "name": "Blood Moon", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "buff_atk_all", "value": 1, "ability_desc": "All friendly demons gain +1 ATK."},
	{"id": "spell_017", "name": "Final Hour", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "legendary", "effect": "resurrect_all", "value": 0, "ability_desc": "Return all demons from your graveyard to hand."},
	{"id": "spell_018", "name": "Soul Recall", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "mythic", "effect": "reanimate_demon", "value": 0, "ability_desc": "Put a demon from your graveyard directly onto the field."},
	{"id": "demon_024", "name": "Arcane Tome", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 2, "atk": 0, "hp": 1, "rarity": "uncommon", "ability": "", "ability_desc": "", "desc": "A living book of raw mana. Pitches for 2."},
	{"id": "demon_025", "name": "Elder Tome", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 3, "atk": 0, "hp": 1, "rarity": "rare", "ability": "", "ability_desc": "", "desc": "An ancient grimoire overflowing with power. Pitches for 3."},
	{"id": "demon_026", "name": "Thousand Eyes", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 4, "atk": 0, "hp": 1, "rarity": "mythic", "ability": "", "ability_desc": "", "desc": "Sees everything. Channels it all into one enormous pitch."},
	{"id": "demon_027", "name": "Cultist Leader", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "uncommon", "ability": "aura_front_atk_1", "ability_desc": "Aura: Other front row demons get +1 ATK.", "desc": "Chants drive the front line to slaughter."},
	{"id": "demon_028", "name": "Komainu", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "uncommon", "ability": "aura_front_hp_2", "ability_desc": "Aura: Other front row demons get +2 HP.", "desc": "Stone guardian. Its presence alone hardens allies."},
	{"id": "demon_029", "name": "Goblin King", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 0, "hp": 4, "rarity": "mythic", "ability": "aura_front_haste", "ability_desc": "Aura: Other front row demons gain Haste.", "desc": "His goblins move on his command. They move fast."},
	{"id": "demon_030", "name": "Death Knell", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "rare", "ability": "any_death_drain", "ability_desc": "Whenever any demon dies, the opponent loses 1 HP.", "desc": "Every fallen soul feeds its curse."},
	{"id": "demon_031", "name": "Left Arm of Osiris", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 0, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"...the left arm reached for mercy but found only chains.\" — Fragment I, House of Silence"},
	{"id": "demon_032", "name": "Right Arm of Osiris", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 0, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"...it struck the Council but they had already become something the old god could not harm.\" — Fragment II"},
	{"id": "demon_033", "name": "Head of Osiris", "type": "demon", "subtype": "neutra", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"The god looked upon humans and knew: it was looking at itself.\" — Fragment III, Shattered Codex"},
	{"id": "demon_034", "name": "Left Leg of Osiris", "type": "demon", "subtype": "neutra", "cost": 0, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"It tried to flee. But humans had inherited the god's own speed.\" — Fragment IV"},
	{"id": "demon_035", "name": "Right Leg of Osiris", "type": "demon", "subtype": "neutra", "cost": 0, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "legendary", "ability": "osiris_piece", "ability_desc": "If you hold all 5 Osiris pieces, win instantly.", "desc": "\"The war ended not with blood, but with a card. And silence.\" — Fragment V, The Last Council"},
	{"id": "god_card", "name": "ROGER'S CARD — ◈ THE FIRST ONE ◈", "type": "demon", "subtype": "neutra", "cost": 0, "mana_value": 0, "atk": 0, "hp": 0, "rarity": "legendary", "ability": "god_card", "ability_desc": "◈ CARD KING ◈ — You are now god. The world bows to your will.", "desc": "\"I found it. I held it. I laughed. Then I hid it again, because some doors should only be opened once.\"\n— R.D. Roger, Last Entry"},
	{"id": "demon_036", "name": "Goblin Assassin", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "uncommon", "ability": "battlecry_reposition_ally", "ability_desc": "Battlecry: Move one of your demons between rows.", "desc": "Slips allies into position before the enemy notices."},
	{"id": "demon_037", "name": "Goblin Mage", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "uncommon", "ability": "battlecry_reposition_enemy", "ability_desc": "Battlecry: Force an enemy front demon to the rear.", "desc": "Pushes enemies out of formation with a hex."},
	{"id": "demon_038", "name": "Goblin Sniper", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 1, "rarity": "uncommon", "ability": "battlecry_rear_strike", "ability_desc": "Battlecry: Deal 1 damage to enemy for each demon in their rear row.", "desc": "One arrow per coward hiding in the back."},
	{"id": "demon_039", "name": "Mimic", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 0, "hp": 0, "rarity": "rare", "ability": "mimic_board_count", "ability_desc": "ATK and HP equal total demons on the battlefield.", "desc": "Opens its lid. Copies everything it sees."},
	{"id": "demon_040", "name": "Imp Matron", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 3, "rarity": "uncommon", "ability": "battlecry_summon_imp", "ability_desc": "Battlecry: Summon a 1/1 Imp.", "desc": "She never fights alone."},
	{"id": "demon_041", "name": "Chaos Ouroboros", "type": "demon", "subtype": "neutra", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "mythic", "ability": "battlecry_equalize_hp", "ability_desc": "Battlecry: Set both players' HP to 8.", "desc": "The serpent that eats itself. Resets everything."},
	{"id": "demon_042", "name": "Demon Lord", "type": "demon", "subtype": "obscura", "cost": 7, "mana_value": 1, "atk": 8, "hp": 8, "rarity": "mythic", "ability": "", "ability_desc": "", "desc": "One of the great lords. Nothing soft about it."},
	{"id": "demon_043", "name": "Chimera", "type": "demon", "subtype": "terresta", "cost": 10, "mana_value": 1, "atk": 12, "hp": 12, "rarity": "legendary", "ability": "", "ability_desc": "", "desc": "Three beasts. One nightmare. No weaknesses."},
	{"id": "demon_044", "name": "Chaos King Dragon", "type": "demon", "subtype": "obscura", "cost": 0, "mana_value": 1, "atk": 6, "hp": 6, "rarity": "legendary", "ability": "chaos_dragon", "ability_desc": "Special: Remove 3 Regalia & 3 Obscura cards from graveyard to summon. Battlecry: Deal 2 dmg per card in enemy graveyard.", "desc": "Cannot be summoned normally."},
	{"id": "demon_045", "name": "Twin Fury", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "rare", "ability": "double_attack", "ability_desc": "Can attack twice per turn.", "desc": "Strikes before you can breathe."},
	{"id": "demon_046", "name": "Grave Glutton", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "rare", "ability": "feed_on_death", "ability_desc": "Gains +1/+1 whenever any demon dies.", "desc": "It gorges on every fallen soul."},
	{"id": "demon_047", "name": "Carrion Beetle", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "uncommon", "ability": "ally_death_mana", "ability_desc": "Whenever a friendly demon dies, gain 1 mana.", "desc": "Death is currency."},
	{"id": "demon_048", "name": "Echo Scholar", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "mythic", "ability": "battlecry_replay_spell", "ability_desc": "Battlecry: Replay the last spell in your graveyard for free.", "desc": "Every incantation echoes twice."},
	{"id": "demon_049", "name": "Shadow Raider", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 1, "rarity": "rare", "ability": "haste_face_draw", "ability_desc": "Haste. When this deals face damage, draw 1 card.", "desc": "Strikes the mind as well as the body."},
	{"id": "demon_050", "name": "Soul Collector", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 1, "hp": 5, "rarity": "rare", "ability": "any_death_draw", "ability_desc": "Whenever any demon dies, draw 1 card.", "desc": "Watches from the void. Learning."},
	{"id": "demon_051", "name": "Necrotic Wisp", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 0, "hp": 1, "rarity": "uncommon", "ability": "deathrattle_buff_all", "ability_desc": "Deathrattle: Give all your other demons +1/+1.", "desc": "A tiny sacrifice that fuels the rest."},
	{"id": "demon_052", "name": "Blood Cultist", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "ally_death_lifegain", "ability_desc": "Whenever a friendly demon dies, gain 1 HP.", "desc": "Drinks deep from every death nearby."},
	{"id": "demon_053", "name": "Night Stalker", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 1, "rarity": "rare", "ability": "haste_unblockable", "ability_desc": "Haste. Unblockable.", "desc": "It does not fight. It just kills."},
	{"id": "demon_054", "name": "Lich's Familiar", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "common", "ability": "spell_lifegain", "ability_desc": "Gain 1 HP whenever you play a spell.", "desc": "Feeds on arcane energy."},
	{"id": "demon_055", "name": "Plague Bearer", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 4, "rarity": "common", "ability": "poisonous", "ability_desc": "Poisonous — kills any demon it damages.", "desc": "It reeks of the end."},
	{"id": "demon_056", "name": "Specter Assassin", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "battlecry_destroy_weak", "ability_desc": "Battlecry: Destroy an enemy demon with 3 or less HP.", "desc": "It picks off the wounded first."},
	{"id": "demon_057", "name": "Mind Shredder", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 4, "rarity": "uncommon", "ability": "battlecry_discard_enemy", "ability_desc": "Battlecry: Enemy discards their top card.", "desc": "Tears knowledge from the mind."},
	{"id": "demon_058", "name": "Dusk Predator", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 4, "hp": 2, "rarity": "rare", "ability": "haste_poisonous", "ability_desc": "Haste. Poisonous.", "desc": "One scratch. One corpse."},
	{"id": "demon_059", "name": "Undying Fiend", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 4, "hp": 3, "rarity": "rare", "ability": "deathrattle_return_hand", "ability_desc": "Deathrattle: Return this to your hand when destroyed.", "desc": "It refuses to stay dead."},
	{"id": "demon_060", "name": "Larcenous Shade", "type": "demon", "subtype": "obscura", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "uncommon", "ability": "haste_face_mana", "ability_desc": "Haste. When this deals face damage, gain 1 mana.", "desc": "Steals more than just HP."},
	{"id": "demon_061", "name": "Iron Warden", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "mythic", "ability": "tax_spells", "ability_desc": "Enemy spells cost 1 extra mana.", "desc": "Her presence alone slows the enemy."},
	{"id": "demon_062", "name": "Celestial Healer", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 2, "hp": 3, "rarity": "common", "ability": "battlecry_heal_3", "ability_desc": "Battlecry: Restore 3 HP.", "desc": "Blessed by the stars."},
	{"id": "demon_063", "name": "Thunder Drake", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Fast as a bolt."},
	{"id": "demon_064", "name": "Radiant Sentinel", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 1, "hp": 4, "rarity": "rare", "ability": "taunt_regen", "ability_desc": "Taunt. Restores 1 HP to itself at end of your turn.", "desc": "Endures through sheer divine will."},
	{"id": "demon_065", "name": "Star Prophet", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "rare", "ability": "draw_pings", "ability_desc": "Whenever you draw a card, deal 1 damage to the enemy.", "desc": "Each revelation strikes like a blade."},
	{"id": "demon_066", "name": "Holy Knight", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 3, "hp": 4, "rarity": "rare", "ability": "divine_shield", "ability_desc": "Divine Shield — absorbs the first hit.", "desc": "No blade has yet drawn its blood."},
	{"id": "demon_067", "name": "Lightning Herald", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Arrives with the speed of thunder."},
	{"id": "demon_068", "name": "Gleaming Drake", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "rare", "ability": "battlecry_aoe_1", "ability_desc": "Battlecry: Deal 1 damage to all enemy demons.", "desc": "Its wingspan blots out lesser creatures."},
	{"id": "demon_069", "name": "Angelic Guardian", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 2, "hp": 6, "rarity": "rare", "ability": "taunt", "ability_desc": "Taunt.", "desc": "Will not yield."},
	{"id": "demon_070", "name": "Seraph", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 3, "hp": 5, "rarity": "mythic", "ability": "divine_shield", "ability_desc": "Divine Shield — absorbs the first hit.", "desc": "Heaven's last line of defence."},
	{"id": "demon_071", "name": "Ember Thief", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "rare", "ability": "haste_face_mana", "ability_desc": "Haste. When this deals face damage, gain 1 mana.", "desc": "Steals breath with every strike."},
	{"id": "demon_072", "name": "Blaze Imp", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Burns bright and fast."},
	{"id": "demon_073", "name": "Lava Golem", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "uncommon", "ability": "battlecry_damage_random_2", "ability_desc": "Battlecry: Deal 2 damage to a random enemy demon.", "desc": "Erupts on arrival."},
	{"id": "demon_074", "name": "Infernal Drake", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "rage", "ability_desc": "Rage — gains +1 ATK every time it takes damage.", "desc": "Pain makes it stronger."},
	{"id": "demon_075", "name": "Pyromancer", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "rare", "ability": "spell_aoe", "ability_desc": "Whenever you play a spell, deal 1 damage to all enemy demons.", "desc": "Every word of power scorches the enemy."},
	{"id": "demon_076", "name": "Magma Titan", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 5, "hp": 4, "rarity": "rare", "ability": "battlecry_aoe_rear_2", "ability_desc": "Battlecry: Deal 2 damage to all enemy rear row demons.", "desc": "Reaches over the front line."},
	{"id": "demon_077", "name": "Hellfire Imp", "type": "demon", "subtype": "regalia", "cost": 0, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Free chaos."},
	{"id": "demon_078", "name": "Cinder Scholar", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "battlecry_face_per_spell_gy", "ability_desc": "Battlecry: Deal 1 damage to the enemy for each spell in your graveyard.", "desc": "The more you cast, the more it burns."},
	{"id": "demon_079", "name": "Phoenix", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "deathrattle_return_hand", "ability_desc": "Deathrattle: Return this to your hand when destroyed.", "desc": "Rises from its own ashes."},
	{"id": "demon_080", "name": "Lava Drake", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 3, "hp": 4, "rarity": "common", "ability": "lifesteal", "ability_desc": "Lifesteal.", "desc": "Drains life with burning claws."},
	{"id": "demon_081", "name": "Fire Elemental", "type": "demon", "subtype": "obscura", "cost": 4, "mana_value": 1, "atk": 4, "hp": 5, "rarity": "mythic", "ability": "battlecry_aoe_2", "ability_desc": "Battlecry: Deal 2 damage to all enemy demons.", "desc": "A living inferno."},
	{"id": "demon_082", "name": "Molten Giant", "type": "demon", "subtype": "regalia", "cost": 5, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "rare", "ability": "battlecry_aoe_1", "ability_desc": "Battlecry: Deal 1 damage to all enemy demons.", "desc": "The ground cracks beneath its steps."},
	{"id": "demon_083", "name": "Tidal Terror", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "mythic", "ability": "battlecry_aoe_per_spell", "ability_desc": "Battlecry: Deal 1 damage to each enemy demon for each spell in your graveyard.", "desc": "The tide rises with every spell cast."},
	{"id": "demon_084", "name": "Frost Mage", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 1, "hp": 3, "rarity": "uncommon", "ability": "battlecry_freeze_target", "ability_desc": "Battlecry: Exhaust (freeze) one enemy demon for a turn.", "desc": "A touch and the enemy slows."},
	{"id": "demon_085", "name": "Ice Barrier", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 0, "hp": 6, "rarity": "rare", "ability": "divine_shield taunt", "ability_desc": "Divine Shield — absorbs the first hit. Taunt.", "desc": "An impenetrable wall of frost."},
	{"id": "demon_086", "name": "Sea Serpent", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "common", "ability": "unblockable", "ability_desc": "Unblockable.", "desc": "Slithers through every defence."},
	{"id": "demon_087", "name": "Arcane Leech", "type": "demon", "subtype": "neutra", "cost": 2, "mana_value": 1, "atk": 1, "hp": 4, "rarity": "common", "ability": "lifesteal", "ability_desc": "Lifesteal.", "desc": "Drains the arcane from the living."},
	{"id": "demon_088", "name": "Glacial Colossus", "type": "demon", "subtype": "terresta", "cost": 7, "mana_value": 1, "atk": 6, "hp": 8, "rarity": "mythic", "ability": "battlecry_freeze_all", "ability_desc": "Battlecry: Exhaust all enemy demons.", "desc": "Winter itself steps onto the battlefield."},
	{"id": "demon_089", "name": "River Sprite", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 0, "hp": 2, "rarity": "uncommon", "ability": "mana_per_turn", "ability_desc": "At the start of your turn, gain 1 mana.", "desc": "The current never stops."},
	{"id": "demon_090", "name": "Storm Surge", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "uncommon", "ability": "rage", "ability_desc": "Rage — gains +1 ATK every time it takes damage.", "desc": "The storm intensifies."},
	{"id": "demon_091", "name": "Kraken Spawn", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 0, "hp": 4, "rarity": "common", "ability": "taunt", "ability_desc": "Taunt.", "desc": "A wall of writhing tentacles."},
	{"id": "demon_092", "name": "Deep Lurker", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 5, "rarity": "rare", "ability": "unblockable_lifesteal", "ability_desc": "Unblockable. Lifesteal.", "desc": "Surfaces only to feed."},
	{"id": "demon_093", "name": "Mana Dryad", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "uncommon", "ability": "mana_per_turn", "ability_desc": "At the start of your turn, gain 1 mana.", "desc": "Channels the land's energy every turn."},
	{"id": "demon_094", "name": "Elder Treant", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "uncommon", "ability": "mana_per_turn", "ability_desc": "At the start of your turn, gain 1 mana.", "desc": "Ancient and unyielding."},
	{"id": "demon_095", "name": "Stampeding Bull", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 5, "hp": 3, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Nothing stops it."},
	{"id": "demon_096", "name": "Giant Spider", "type": "demon", "subtype": "obscura", "cost": 3, "mana_value": 1, "atk": 2, "hp": 4, "rarity": "uncommon", "ability": "taunt_poisonous", "ability_desc": "Taunt. Poisonous.", "desc": "Every attacker regrets the choice."},
	{"id": "demon_097", "name": "Sabertooth", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 4, "hp": 2, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "Kills before the enemy reacts."},
	{"id": "demon_098", "name": "Pack Alpha", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "rare", "ability": "battlecry_buff_beast", "ability_desc": "Battlecry: Give all other friendly Terresta demons +1 ATK.", "desc": "Where it howls, the pack surges."},
	{"id": "demon_099", "name": "Thunderous Rex", "type": "demon", "subtype": "terresta", "cost": 6, "mana_value": 1, "atk": 7, "hp": 7, "rarity": "mythic", "ability": "haste_taunt", "ability_desc": "Haste. Taunt.", "desc": "It charges, and it must be faced."},
	{"id": "demon_100", "name": "Elder Dragon", "type": "demon", "subtype": "terresta", "cost": 5, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "mythic", "ability": "battlecry_aoe_2", "ability_desc": "Battlecry: Deal 2 damage to all enemy demons.", "desc": "The oldest hunter."},
	{"id": "demon_101", "name": "Dire Wolf", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "rage", "ability_desc": "Rage — gains +1 ATK every time it takes damage.", "desc": "Pain makes it more dangerous."},
	{"id": "demon_102", "name": "Ancient Tortoise", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 1, "hp": 8, "rarity": "rare", "ability": "taunt", "ability_desc": "Taunt.", "desc": "Unmovable."},
	{"id": "demon_103", "name": "Primal Dragon", "type": "demon", "subtype": "terresta", "cost": 5, "mana_value": 1, "atk": 5, "hp": 6, "rarity": "uncommon", "ability": "battlecry_buff_all_atk", "ability_desc": "Battlecry: All your other demons gain +1 ATK.", "desc": "Its roar inspires even the damned."},
	{"id": "demon_104", "name": "Forest Colossus", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 5, "rarity": "rare", "ability": "taunt_lifesteal", "ability_desc": "Taunt. Lifesteal.", "desc": "The forest sustains it through every wound."},
	{"id": "demon_105", "name": "Nest Warden", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 2, "hp": 3, "rarity": "uncommon", "ability": "deathrattle_summon_2_imps", "ability_desc": "Deathrattle: Summon two 1/1 Imps when destroyed.", "desc": "Its young scatter when it falls."},
	{"id": "spell_019", "name": "Dark Ritual", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "gain_mana", "value": 3, "ability_desc": "Gain 3 mana this turn."},
	{"id": "spell_020", "name": "Blood Price", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "uncommon", "effect": "hp_to_mana", "value": 4, "ability_desc": "Lose 4 HP. Gain 4 mana."},
	{"id": "spell_021", "name": "Ancient Rites", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "gain_mana", "value": 4, "ability_desc": "Gain 4 mana this turn."},
	{"id": "spell_022", "name": "Mana Convergence", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "gain_mana", "value": 6, "ability_desc": "Gain 6 mana this turn."},
	{"id": "spell_023", "name": "Soul Barter", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "uncommon", "effect": "mana_per_demon", "value": 1, "ability_desc": "Gain 1 mana per demon you control."},
	{"id": "spell_024", "name": "Rite of Power", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "mana_per_graveyard", "value": 5, "ability_desc": "Gain 1 mana per card in your graveyard (max 5)."},
	{"id": "spell_025", "name": "Essence Surge", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "deal_and_gain_mana", "value": 2, "ability_desc": "Deal 2 to the enemy. Gain 2 mana."},
	{"id": "spell_026", "name": "Lightning Bolt", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "deal_face", "value": 3, "ability_desc": "Deal 3 damage directly to the enemy."},
	{"id": "spell_027", "name": "Shock", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "deal_face", "value": 2, "ability_desc": "Deal 2 damage to the enemy."},
	{"id": "spell_028", "name": "Lava Burst", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "uncommon", "effect": "deal_face", "value": 5, "ability_desc": "Deal 5 damage to the enemy."},
	{"id": "spell_029", "name": "Volcanic Blast", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "deal_face", "value": 7, "ability_desc": "Deal 7 damage to the enemy."},
	{"id": "spell_030", "name": "Pyroclasm", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "uncommon", "effect": "aoe_all_2", "value": 2, "ability_desc": "Deal 2 damage to ALL demons on both sides."},
	{"id": "spell_031", "name": "Searing Touch", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "deal_face_if_low", "value": 5, "ability_desc": "Deal 5 to the enemy if they have 5 or less HP."},
	{"id": "spell_032", "name": "Fire Storm", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "aoe_enemy_and_face", "value": 3, "ability_desc": "Deal 3 to all enemy demons and to the enemy."},
	{"id": "spell_033", "name": "Chaos Bolt", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "chaos_damage", "value": 8, "ability_desc": "Deal a random 1–8 damage to the enemy."},
	{"id": "spell_034", "name": "Death Toll", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "rare", "effect": "face_per_graveyard", "value": 1, "ability_desc": "Deal 1 damage to the enemy for each card in your graveyard."},
	{"id": "spell_035", "name": "Twin Bolt", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "uncommon", "effect": "deal_face", "value": 4, "ability_desc": "Deal 4 damage to the enemy."},
	{"id": "spell_036", "name": "Ember Rain", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "aoe_demon_dmg", "value": 1, "ability_desc": "Deal 1 damage to all enemy demons."},
	{"id": "spell_037", "name": "Frost Nova", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "uncommon", "effect": "freeze_all_enemy", "value": 0, "ability_desc": "Exhaust all enemy demons for one turn."},
	{"id": "spell_038", "name": "Mind Control", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "legendary", "effect": "steal_demon", "value": 0, "ability_desc": "Take control of the weakest enemy demon."},
	{"id": "spell_039", "name": "Disruption", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "return_demon", "value": 0, "ability_desc": "Return the strongest enemy demon to their hand."},
	{"id": "spell_040", "name": "Drain Life", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "deal_face_drain", "value": 3, "ability_desc": "Deal 3 to the enemy. Gain 3 HP."},
	{"id": "spell_041", "name": "Wrath", "type": "spell", "cost": 4, "mana_value": 1, "rarity": "mythic", "effect": "destroy_all_both", "value": 0, "ability_desc": "Destroy ALL demons on both sides."},
	{"id": "spell_042", "name": "Silence", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "silence_demon", "value": 0, "ability_desc": "Remove the ability from the strongest enemy demon."},
	{"id": "spell_043", "name": "Dark Transformation", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "transform_1_1", "value": 0, "ability_desc": "Transform the weakest enemy demon into a 1/1 with no ability."},
	{"id": "spell_044", "name": "Frost Bolt", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "freeze_one_demon", "value": 0, "ability_desc": "Exhaust one enemy demon for a turn."},
	{"id": "spell_045", "name": "Execute", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "destroy_damaged", "value": 0, "ability_desc": "Destroy an enemy demon that has taken damage this turn."},
	{"id": "spell_046", "name": "Terror", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "destroy_low_atk", "value": 2, "ability_desc": "Destroy an enemy demon with 2 or less ATK."},
	{"id": "spell_047", "name": "Blood Draw", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "uncommon", "effect": "hp_for_draw", "value": 2, "ability_desc": "Lose 2 HP. Draw 2 cards."},
	{"id": "spell_048", "name": "Cantrip", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "common", "effect": "draw", "value": 1, "ability_desc": "Draw 1 card."},
	{"id": "spell_049", "name": "Arcane Study", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "uncommon", "effect": "draw", "value": 3, "ability_desc": "Draw 3 cards."},
	{"id": "spell_050", "name": "Rally", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "buff_all_stats", "value": 1, "ability_desc": "Give all your demons +1/+1."},
	{"id": "spell_051", "name": "Battle Frenzy", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "uncommon", "effect": "buff_atk_all_turn", "value": 2, "ability_desc": "Give all your demons +2 ATK until end of turn."},
	{"id": "spell_052", "name": "Divine Favor", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "buff_hp_all", "value": 1, "ability_desc": "Give all your demons +1 HP."},
	{"id": "spell_053", "name": "Spectral Shield", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "give_divine_shield", "value": 0, "ability_desc": "Give a friendly demon Divine Shield."},
	{"id": "spell_054", "name": "Battle Hardened", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "buff_target_stats", "value": 3, "ability_desc": "Give a friendly demon +3/+3."},
	{"id": "spell_055", "name": "Reanimate", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "reanimate_top", "value": 0, "ability_desc": "Summon the highest-cost demon from your graveyard."},
	{"id": "spell_056", "name": "Cursed Ground", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "debuff_atk_all", "value": 2, "ability_desc": "All enemy demons lose 2 ATK."},
	{"id": "spell_057", "name": "Arcane Mastery", "type": "spell", "cost": 0, "mana_value": 1, "rarity": "legendary", "effect": "double_next_spell", "value": 0, "ability_desc": "Your next spell this turn is cast twice."},
	{"id": "spell_058", "name": "Soul Link", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "rare", "effect": "deal_face_drain", "value": 2, "ability_desc": "Deal 2 to the enemy. Gain 2 HP."},
	{"id": "demon_106", "name": "Lava Imp", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Born screaming from a volcanic vent."},
	{"id": "demon_107", "name": "Cinder Hound", "type": "demon", "subtype": "obscura", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "haste_poisonous", "ability_desc": "Haste. Poisonous — kills any demon it damages.", "desc": "Ash in its lungs. Fire in its bite."},
	{"id": "demon_108", "name": "Magma Golem", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 2, "hp": 6, "rarity": "uncommon", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "Hardened lava given purpose."},
	{"id": "demon_109", "name": "Inferno Drake", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 5, "hp": 2, "rarity": "rare", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Dives and burns before you can blink."},
	{"id": "demon_110", "name": "Ember Phoenix", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 4, "rarity": "rare", "ability": "deathrattle_summon_ash_wraith", "ability_desc": "Deathrattle: Summon a 2/2 Ash Wraith when destroyed.", "desc": "Death is not the end. It never was on this island."},
	{"id": "demon_111", "name": "Volcano Lord", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 5, "hp": 5, "rarity": "mythic", "ability": "battlecry_damage_player_2", "ability_desc": "Battlecry: Deal 2 damage to the enemy.", "desc": "\"The mountain speaks. You will not like what it says.\" — Magma King"},
	{"id": "demon_112", "name": "Frost Rat", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 2, "rarity": "common", "ability": "poisonous", "ability_desc": "Poisonous — kills any demon it damages.", "desc": "Its bite freezes the blood solid."},
	{"id": "demon_113", "name": "Blizzard Imp", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Moves through snow like it is not there."},
	{"id": "demon_114", "name": "Glacier Drake", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 2, "hp": 5, "rarity": "uncommon", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "An ancient predator. Older than the ice itself."},
	{"id": "demon_115", "name": "Frost Wraith", "type": "demon", "subtype": "terresta", "cost": 3, "mana_value": 1, "atk": 3, "hp": 3, "rarity": "uncommon", "ability": "unblockable", "ability_desc": "Unblockable — can always attack the enemy directly.", "desc": "Cold beyond cold. A draft that kills."},
	{"id": "demon_116", "name": "Permafrost Titan", "type": "demon", "subtype": "terresta", "cost": 4, "mana_value": 1, "atk": 4, "hp": 7, "rarity": "rare", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "The north does not move. The north waits."},
	{"id": "demon_117", "name": "Glacial Sovereign", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 6, "hp": 4, "rarity": "mythic", "ability": "battlecry_aoe_1", "ability_desc": "Battlecry: Deal 1 damage to all enemy demons.", "desc": "\"The Final Council met here. In the cold. Before everything ended.\" — Fragment VII, Frost Inscription"},
	{"id": "spell_059", "name": "Magma Burst", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "damage", "value": 5, "ability_desc": "Deal 5 damage. The volcano does not miss."},
	{"id": "spell_060", "name": "Blizzard", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "aoe_enemy", "value": 3, "ability_desc": "Deal 3 damage to all enemy demons. Even the undead feel cold."},
	{"id": "spell_061", "name": "Lava Shield", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "buff_hp", "value": 4, "ability_desc": "Give a friendly demon +4 HP. Hardened from within."},
	{"id": "spell_062", "name": "Toxic Cloud", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "uncommon", "effect": "poison_all_enemy", "value": 3, "ability_desc": "Poison all enemy demons for 3 turns (1 dmg/turn)."},
	{"id": "spell_063", "name": "Venom Strike", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "common", "effect": "poison_one_enemy", "value": 4, "ability_desc": "Poison one enemy demon for 4 turns (1 dmg/turn)."},
	{"id": "spell_064", "name": "Cure", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "cure_all_friendly", "value": 0, "ability_desc": "Remove all poison from your demons."},
	{"id": "spell_065", "name": "Plague Surge", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "poison_face", "value": 2, "ability_desc": "Deal 2 damage now, then 2 more each turn for 2 turns."},
	{"id": "demon_118", "name": "Spark Imp", "type": "demon", "subtype": "regalia", "cost": 1, "mana_value": 1, "atk": 2, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Born in a lightning strike. Gone in the next."},
	{"id": "demon_119", "name": "Storm Hound", "type": "demon", "subtype": "regalia", "cost": 2, "mana_value": 1, "atk": 3, "hp": 2, "rarity": "common", "ability": "haste_poisonous", "ability_desc": "Haste. Poisonous — kills any demon it damages.", "desc": "The thunder carries it. The lightning is its bite."},
	{"id": "demon_120", "name": "Tempest Knight", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 2, "hp": 6, "rarity": "uncommon", "ability": "taunt", "ability_desc": "Taunt — enemies must attack this first.", "desc": "Stands in the eye of the storm. Unmoved."},
	{"id": "demon_121", "name": "Thunder Drake", "type": "demon", "subtype": "regalia", "cost": 3, "mana_value": 1, "atk": 5, "hp": 2, "rarity": "rare", "ability": "haste", "ability_desc": "Haste — can attack immediately.", "desc": "Strikes from the clouds before you can react."},
	{"id": "demon_122", "name": "Stormcaller", "type": "demon", "subtype": "regalia", "cost": 4, "mana_value": 1, "atk": 3, "hp": 5, "rarity": "rare", "ability": "battlecry_aoe_2", "ability_desc": "Battlecry: Deal 2 damage to all enemy demons.", "desc": "\"The storm does not choose its victims. It teaches them.\" — Stormcaller IX"},
	{"id": "demon_123", "name": "Thunder Sovereign", "type": "demon", "subtype": "regalia", "cost": 5, "mana_value": 1, "atk": 6, "hp": 6, "rarity": "mythic", "ability": "battlecry_damage_player_2", "ability_desc": "Battlecry: Deal 2 damage to the enemy.", "desc": "\"He who commands the storm commands all. And I command the storm.\" — Thunder Sovereign"},
	{"id": "spell_066", "name": "Lightning Bolt", "type": "spell", "cost": 2, "mana_value": 1, "rarity": "rare", "effect": "damage", "value": 6, "ability_desc": "Deal 6 damage. The sky does not warn you."},
	{"id": "spell_067", "name": "Chain Lightning", "type": "spell", "cost": 3, "mana_value": 1, "rarity": "rare", "effect": "aoe_enemy", "value": 2, "ability_desc": "Deal 2 damage to all enemy demons. The chain never ends."},
	{"id": "spell_068", "name": "Thunder Ward", "type": "spell", "cost": 1, "mana_value": 1, "rarity": "uncommon", "effect": "buff_hp", "value": 3, "ability_desc": "Give a friendly demon +3 HP. Hardened by lightning strikes."},
	# TOKENS (zelda battle)
	{"id": "token_zombie", "name": "Zombie", "type": "demon", "subtype": "obscura", "cost": 0, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "", "ability_desc": "", "desc": "A shuffling undead."},
	{"id": "token_ash_wraith", "name": "Ash Wraith", "type": "demon", "subtype": "regalia", "cost": 0, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "", "ability_desc": "", "desc": "Born from the phoenix's last breath."},
	{"id": "token_imp", "name": "Imp", "type": "demon", "subtype": "obscura", "cost": 0, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "haste", "ability_desc": "Haste.", "desc": "A tiny demon."},
	# Zelda legacy skeletons (IDs moved; bloodungeon 046+ are expansion cards)
	{"id": "demon_124", "name": "Skeleton", "type": "demon", "subtype": "terresta", "cost": 1, "mana_value": 1, "atk": 1, "hp": 1, "rarity": "common", "ability": "skeleton_horde", "ability_desc": "Skeleton Horde — no copy limit in your deck.", "desc": "A rookie in the infernal army."},
	{"id": "demon_125", "name": "Skeleton Soldier", "type": "demon", "subtype": "terresta", "cost": 2, "mana_value": 1, "atk": 2, "hp": 2, "rarity": "common", "ability": "skeleton_horde", "ability_desc": "Skeleton Horde — no copy limit in your deck.", "desc": "Frontline of the infernal army."}, ]
