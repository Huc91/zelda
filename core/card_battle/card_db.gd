class_name CardDB extends RefCounted

static var _map: Dictionary = {}
static var _ready_flag := false


static func get_card(id: String) -> Dictionary:
	_ensure_init()
	return _map.get(id, {}).duplicate(true)


static func starter_deck() -> Array:
	return _build(PLAYER_DECK)


static func enemy_deck() -> Array:
	return _build(ENEMY_DECK)


static func _build(ids: Array) -> Array:
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


# ── Player starter deck (30 cards) ──────────────────────────────
const PLAYER_DECK = [
	"demon_001", "demon_001",
	"demon_003", "demon_003",
	"demon_018", "demon_018",
	"demon_002", "demon_002",
	"demon_006",
	"demon_007",
	"demon_008", "demon_008",
	"demon_005", "demon_005",
	"demon_013",
	"demon_015",
	"demon_017",
	"demon_012",
	"demon_011", "demon_011",
	"spell_004", "spell_004",
	"spell_016", "spell_016",
	"spell_013", "spell_013",
	"spell_005",
	"spell_001",
	"spell_007",
	"spell_003",
]

# ── Enemy deck (30 cards, aggressive) ────────────────────────────
const ENEMY_DECK = [
	"demon_001", "demon_001",
	"demon_002", "demon_002", "demon_002",
	"demon_004", "demon_004",
	"demon_009", "demon_009",
	"demon_010",
	"demon_014", "demon_014",
	"demon_016", "demon_016",
	"demon_011", "demon_011",
	"demon_003", "demon_003",
	"demon_012",
	"demon_013",
	"spell_001", "spell_001",
	"spell_005", "spell_005",
	"spell_013", "spell_013",
	"spell_002", "spell_002",
	"spell_003",
	"spell_011",
]

# ── Card definitions ─────────────────────────────────────────────
const ALL_CARDS = [
	# DEMONS — cost, mana_value, atk, hp
	{"id":"demon_001","name":"Imp",         "type":"demon","subtype":"dark", "cost":1,"mana_value":1,"atk":1,"hp":1,"rarity":"common",  "ability":"haste",                    "ability_desc":"Haste: attacks immediately.",           "desc":"Darts in fast."},
	{"id":"demon_002","name":"Hellhound",   "type":"demon","subtype":"fire", "cost":2,"mana_value":1,"atk":3,"hp":2,"rarity":"common",  "ability":"haste",                    "ability_desc":"Haste: attacks immediately.",           "desc":"Bites hard and fast."},
	{"id":"demon_003","name":"Plague Rat",  "type":"demon","subtype":"beast","cost":1,"mana_value":1,"atk":1,"hp":1,"rarity":"common",  "ability":"poisonous",                "ability_desc":"Poisonous: kills any demon it damages.","desc":"One scratch."},
	{"id":"demon_004","name":"Shadow Hound","type":"demon","subtype":"dark", "cost":2,"mana_value":1,"atk":3,"hp":3,"rarity":"common",  "ability":"",                         "ability_desc":"",                                     "desc":"A reliable fighter."},
	{"id":"demon_005","name":"Bone Knight", "type":"demon","subtype":"dark", "cost":3,"mana_value":1,"atk":3,"hp":4,"rarity":"common",  "ability":"deathrattle_damage_2",     "ability_desc":"Deathrattle: deal 2 to enemy.",        "desc":"Even in death it strikes."},
	{"id":"demon_006","name":"Specter",     "type":"demon","subtype":"dark", "cost":2,"mana_value":1,"atk":2,"hp":2,"rarity":"uncommon","ability":"unblockable",              "ability_desc":"Unblockable: always attacks face.",    "desc":"Slips past any defence."},
	{"id":"demon_007","name":"Succubus",    "type":"demon","subtype":"dark", "cost":2,"mana_value":1,"atk":1,"hp":3,"rarity":"rare",    "ability":"battlecry_draw_2",         "ability_desc":"Battlecry: draw 2 cards.",             "desc":"Beautiful and deadly."},
	{"id":"demon_008","name":"Blood Bat",   "type":"demon","subtype":"dark", "cost":2,"mana_value":1,"atk":2,"hp":3,"rarity":"common",  "ability":"lifesteal",                "ability_desc":"Lifesteal: heals for damage dealt.",   "desc":"Feeds on life force."},
	{"id":"demon_009","name":"Golem",       "type":"demon","subtype":"beast","cost":4,"mana_value":1,"atk":2,"hp":5,"rarity":"uncommon","ability":"taunt",                    "ability_desc":"Taunt: must be attacked first.",       "desc":"Slow but hard to kill."},
	{"id":"demon_010","name":"Cerberus",    "type":"demon","subtype":"fire", "cost":4,"mana_value":1,"atk":4,"hp":2,"rarity":"rare",    "ability":"haste_poisonous",          "ability_desc":"Haste. Poisonous.",                    "desc":"Three heads."},
	{"id":"demon_011","name":"Wraith",      "type":"demon","subtype":"dark", "cost":3,"mana_value":1,"atk":1,"hp":5,"rarity":"uncommon","ability":"taunt",                    "ability_desc":"Taunt: must be attacked first.",       "desc":"Impossible to ignore."},
	{"id":"demon_012","name":"Minotaur",    "type":"demon","subtype":"beast","cost":4,"mana_value":1,"atk":3,"hp":6,"rarity":"uncommon","ability":"rage",                     "ability_desc":"Rage: +1 ATK when it takes damage.",  "desc":"The angrier it gets."},
	{"id":"demon_013","name":"Ember Drake", "type":"demon","subtype":"fire", "cost":3,"mana_value":1,"atk":3,"hp":3,"rarity":"uncommon","ability":"battlecry_aoe_1",          "ability_desc":"Battlecry: 1 dmg all enemy demons.",  "desc":"Clears the path."},
	{"id":"demon_014","name":"Sand Ghoul",  "type":"demon","subtype":"beast","cost":3,"mana_value":1,"atk":4,"hp":4,"rarity":"common",  "ability":"",                         "ability_desc":"",                                     "desc":"Big and dumb."},
	{"id":"demon_015","name":"Void Crawler","type":"demon","subtype":"dark", "cost":3,"mana_value":1,"atk":3,"hp":3,"rarity":"uncommon","ability":"unblockable",              "ability_desc":"Unblockable: always attacks face.",    "desc":"Slips between dimensions."},
	{"id":"demon_016","name":"Nightmare",   "type":"demon","subtype":"dark", "cost":4,"mana_value":1,"atk":5,"hp":4,"rarity":"rare",    "ability":"battlecry_damage_player_2","ability_desc":"Battlecry: deal 2 to enemy.",         "desc":"Its arrival causes pain."},
	{"id":"demon_017","name":"Iron Djinn",  "type":"demon","subtype":"dark", "cost":4,"mana_value":1,"atk":4,"hp":4,"rarity":"rare",    "ability":"battlecry_buff_all_atk",   "ability_desc":"Battlecry: +1 ATK to all your demons.", "desc":"Commands the lesser demons."},
	{"id":"demon_018","name":"Dusk Faerie", "type":"demon","subtype":"dark", "cost":1,"mana_value":1,"atk":1,"hp":3,"rarity":"uncommon","ability":"battlecry_draw_1",         "ability_desc":"Battlecry: draw 1 card.",              "desc":"Worth playing for the card."},
	{"id":"demon_019","name":"Pit Fiend",   "type":"demon","subtype":"fire", "cost":4,"mana_value":1,"atk":4,"hp":3,"rarity":"rare",    "ability":"haste_lifesteal",          "ability_desc":"Haste. Lifesteal.",                    "desc":"Strikes and devours life."},
	{"id":"demon_020","name":"Medusa",      "type":"demon","subtype":"beast","cost":4,"mana_value":1,"atk":4,"hp":5,"rarity":"rare",    "ability":"battlecry_destroy_strongest","ability_desc":"Battlecry: destroy highest-ATK enemy.","desc":"One look kills."},
	{"id":"demon_021","name":"Lich King",   "type":"demon","subtype":"dark", "cost":4,"mana_value":1,"atk":5,"hp":5,"rarity":"mythic",  "ability":"deathrattle_summon_zombie","ability_desc":"Deathrattle: summon a 2/2 Zombie.",    "desc":"Death is a setback."},
	{"id":"demon_022","name":"Beelzebub",   "type":"demon","subtype":"dark", "cost":4,"mana_value":1,"atk":3,"hp":5,"rarity":"mythic",  "ability":"battlecry_summon_imps",    "ability_desc":"Battlecry: summon 2 Imps (1/1 Haste).","desc":"Lord of Flies."},
	{"id":"demon_045","name":"Twin Fury",   "type":"demon","subtype":"dark", "cost":4,"mana_value":1,"atk":2,"hp":2,"rarity":"rare",    "ability":"double_attack",            "ability_desc":"Can attack twice per turn.",           "desc":"Strikes before you can breathe."},
	# TOKENS
	{"id":"token_zombie","name":"Zombie","type":"demon","subtype":"dark","cost":0,"mana_value":1,"atk":2,"hp":2,"rarity":"common","ability":"",    "ability_desc":"",          "desc":"A shuffling undead."},
	{"id":"token_imp",   "name":"Imp",   "type":"demon","subtype":"dark","cost":0,"mana_value":1,"atk":1,"hp":1,"rarity":"common","ability":"haste","ability_desc":"Haste.",  "desc":"A tiny demon."},
	# SPELLS
	{"id":"spell_001","name":"Fireball",        "type":"spell","cost":2,"mana_value":1,"rarity":"common",   "effect":"damage",        "value":3, "ability_desc":"Deal 3 dmg to enemy."},
	{"id":"spell_002","name":"Heal",            "type":"spell","cost":1,"mana_value":1,"rarity":"common",   "effect":"heal",          "value":2, "ability_desc":"Restore 2 HP."},
	{"id":"spell_003","name":"Soul Drain",      "type":"spell","cost":2,"mana_value":1,"rarity":"rare",     "effect":"destroy",       "value":1, "ability_desc":"Destroy the weakest enemy demon."},
	{"id":"spell_004","name":"Dark Pact",       "type":"spell","cost":1,"mana_value":1,"rarity":"uncommon", "effect":"draw",          "value":2, "ability_desc":"Draw 2 cards."},
	{"id":"spell_005","name":"Inferno",         "type":"spell","cost":2,"mana_value":1,"rarity":"rare",     "effect":"aoe_enemy",     "value":2, "ability_desc":"2 dmg to all enemy demons."},
	{"id":"spell_007","name":"Hex",             "type":"spell","cost":1,"mana_value":1,"rarity":"uncommon", "effect":"debuff_atk",    "value":2, "ability_desc":"-2 ATK to strongest enemy demon."},
	{"id":"spell_009","name":"Mana Surge",      "type":"spell","cost":0,"mana_value":1,"rarity":"uncommon", "effect":"mana_boost",    "value":2, "ability_desc":"Gain 2 mana this turn."},
	{"id":"spell_011","name":"Chain Lightning", "type":"spell","cost":1,"mana_value":1,"rarity":"uncommon", "effect":"aoe_enemy",     "value":1, "ability_desc":"1 dmg to all enemy demons."},
	{"id":"spell_012","name":"Soul Harvest",    "type":"spell","cost":1,"mana_value":1,"rarity":"uncommon", "effect":"life_per_demon","value":1, "ability_desc":"Gain 1 HP per friendly demon."},
	{"id":"spell_013","name":"Arcane Bolt",     "type":"spell","cost":1,"mana_value":1,"rarity":"common",   "effect":"damage",        "value":2, "ability_desc":"Deal 2 dmg to enemy."},
	{"id":"spell_014","name":"Blood Moon",      "type":"spell","cost":1,"mana_value":1,"rarity":"rare",     "effect":"buff_atk_all",  "value":1, "ability_desc":"All friendly demons +1 ATK."},
	{"id":"spell_016","name":"Summon Familiar", "type":"spell","cost":0,"mana_value":1,"rarity":"common",   "effect":"summon_imp",    "value":0, "ability_desc":"Summon a 1/1 Imp."},
]
