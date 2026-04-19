## Centralised NPC dialogue database.
##
## ═══════════════════════════════════════════════════════════════
## HOW TO WRITE DIALOGUE
## ═══════════════════════════════════════════════════════════════
##
## Each key in DB matches the `dialogue_id` export on an NPC node.
##
## ── TYPE 1: Simple (all lines in one talk, loops on retalk) ──
##
##   "my_npc": {
##       "name": "Old Man",           # shown as "Old Man:" in dialogue box
##       "lines": [
##           "Hello there!",
##           "Nice weather today.",
##           "Come back anytime.",
##       ],
##   }
##
##   All three lines play in a single interaction (press Z to advance).
##   Every retalk repeats from the first line.
##
## ── TYPE 2: Progressive (different content each retalk) ──
##
##   "shopkeeper": {
##       "name": "Shopkeeper",
##       "sequences": [
##           {
##               "lines": ["Welcome! First time here?", "I sell the finest cards."],
##           },
##           {
##               "lines": ["Back already? Good taste.", "New stock just arrived."],
##           },
##           {
##               "lines": ["Always a pleasure."],    # last sequence loops forever
##           },
##       ],
##   }
##
##   First talk → sequence 0. Second talk → sequence 1. Last sequence repeats.
##
## ── CHOICES: player-answer options (shown after last line) ──
##
##   {
##       "lines": ["What do you want?"],
##       "choices": [
##           {"text": "Tell me about cards.",  "event": "lore_hint"},
##           {"text": "Nothing, goodbye.",     "event": ""},
##       ],
##   }
##
##   Choices appear as a numbered list. The selected choice fires its "event".
##
## ── EVENTS: trigger game logic when dialogue ends ──
##
##   {
##       "lines": ["The chest is yours!"],
##       "event": "give_chest_reward",
##   }
##
##   When the sequence closes (or a choice is picked), Global emits:
##       Global.dialogue_event("give_chest_reward", "npc_id")
##   Connect anywhere:
##       Global.dialogue_event.connect(func(ev: String, id: String) -> void: ...)
##
## ═══════════════════════════════════════════════════════════════
class_name NPCDialogues
extends RefCounted


const DB: Dictionary = {
	"default": {
		"name": "???",
		"lines": ["..."],
	},

	"guide": {
		"name": "Old Guide",
		"sequences": [
			{
				"lines": [
					"Welcome, traveler.",
					"This land is ruled by card duels.",
					"Find enemies, fight them, collect cards.",
				],
			},
			{
				"lines": [
					"Build a deck from your collection.",
					"A good deck has threats, pitchers, and removal.",
				],
			},
			{
				"lines": [
					"Rest at bonfires to save your progress.",
					"Safe travels.",
				],
			},
			{
				"lines": ["Come back if you need advice."],
			},
		],
	},

	"fire_guide": {
		"name": "Flame Keeper",
		"lines": [
			"You can always rest here.",
			"Come by the unswept fire.",
		],
	},

	"bonzo_spawn": {
		"name": "Bonzo",
		"sequences": [
			{
				"lines": [
					"Was evoked from the graveyard?",
					"...",
					"Ah hello there!",
					"Inside this cave there is a shiny little thing.",
					"I think you need it.",
					"Me? No thanks, I'm afraid.",
				],
				"choices": [
					{"text": "I'll go find it.",     "event": "bonzo_spawn_accepted"},
					{"text": "Maybe another time.",  "event": ""},
				],
			},
			{
				"lines": ["Still haven't found it? It's just inside."],
			},
		],
	},

	"merchant_hint": {
		"name": "Tipsy Girl",
		"lines": [
			"I heard a merchant set up shop nearby.",
			"You can buy single cards from merchants.",
			"But packs are a much better deal.",
			"Foil cards are worth a fortune when sold!",
		],
	},

	"lore_1": {
		"name": "Elder",
		"lines": [
			"Long ago, this land was ruled by card masters.",
			"They would duel to settle every dispute.",
			"The Demon cards were the most feared of all.",
			"Some say the Osiris pieces still wander the wilds...",
		],
	},

	"old_dude": {
		"name": "Old Dude",
		"sequences": [
			{
				"lines": [
					"These old bones have seen many duels.",
					"Never underestimate a cheap pitcher card.",
					"Pitch early, pitch often.",
				],
			},
			{
				"lines": ["You look like you know how to pitch. Good."],
			},
		],
	},

	"bonzo": {
		"name": "Bonzo",
		"lines": [
			"Bonzo's the name, dueling's the game.",
			"I once beat a Chimera with a single Arcane Tome.",
			"True story.",
		],
	},

	"macho": {
		"name": "Macho",
		"sequences": [
			{
				"lines": ["You look strong. Strong enough to duel?"],
				"choices": [
					{"text": "I'm ready!",        "event": "macho_challenge"},
					{"text": "Not yet.",           "event": ""},
				],
			},
			{
				"lines": ["Come back when you've built a real deck."],
			},
		],
	},

	"bellezza": {
		"name": "Bellezza",
		"lines": [
			"Foil cards shimmer like stars.",
			"I collect only the finest.",
			"Sell me your spares and I'll pay double.",
		],
	},

	"girly": {
		"name": "Girly",
		"lines": [
			"Did you know Seraph has Divine Shield?",
			"I keep one in every deck.",
		],
	},

	"coolio": {
		"name": "Coolio",
		"lines": [
			"Stay cool. Play Aerial demons.",
			"Nothing says cool like flying past the front row.",
		],
	},

	"poke_bro": {
		"name": "Poke Bro",
		"lines": [
			"I've catalogued every creature in the land.",
			"Still haven't seen a Wormoyf in the wild.",
			"Rare beast, that one.",
		],
	},

	"potato_man": {
		"name": "Potato Man",
		"lines": [
			"Spuds.",
			"...that's all I've got.",
		],
	},

	"nude_guy": {
		"name": "???",
		"lines": [
			"Freedom!",
			"I lost my clothes in a card duel.",
			"Worth it.",
		],
	},

	"onigiri_doctor": {
		"name": "Dr. Onigiri",
		"lines": [
			"I prescribe a balanced deck.",
			"Two pitchers, three removal spells, fifteen threats.",
			"Classic recipe.",
		],
	},

	"super_bald": {
		"name": "Super Bald",
		"lines": [
			"Hair? Never needed it.",
			"What I DO need is more Legendary cards.",
		],
	},

	"ultra_bonzo": {
		"name": "Ultra Bonzo",
		"lines": [
			"ULTRA BONZO SMASH!",
			"...I mean, hello.",
			"Please trade cards with me.",
		],
	},

	"woman": {
		"name": "Woman",
		"lines": [
			"The card binder fills slowly, but surely.",
			"Keep opening packs. One day you'll complete the set.",
		],
	},
}


## Returns the sequence dict for `dialogue_id` at the given progress index.
static func get_sequence(dialogue_id: String, seq_idx: int) -> Dictionary:
	var entry: Dictionary = DB.get(dialogue_id, DB.get("default", {}))
	if entry.has("sequences"):
		var seqs: Array = entry.get("sequences", [])
		if seqs.is_empty():
			return {"lines": ["..."]}
		return seqs[mini(seq_idx, seqs.size() - 1)]
	return {"lines": entry.get("lines", ["..."])}


## Returns the next sequence index after completing `seq_idx`.
static func advance_sequence(dialogue_id: String, seq_idx: int) -> int:
	var entry: Dictionary = DB.get(dialogue_id, DB.get("default", {}))
	if not entry.has("sequences"):
		return 0  # simple lines always restart
	var seqs: Array = entry.get("sequences", [])
	if seq_idx >= seqs.size() - 1:
		return seq_idx  # already on last — stay there
	return seq_idx + 1


## Returns the display name for an NPC entry.
static func get_speaker_name(dialogue_id: String) -> String:
	var entry: Dictionary = DB.get(dialogue_id, DB.get("default", {}))
	return entry.get("name", "???")
