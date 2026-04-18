## Centralised NPC dialogue database.
##
## HOW TO ADD AN NPC:
##   1. Add a key to DB below. The key matches `dialogue_id` set on the NPC node.
##   2. "lines": Array of Strings — cycled through each time the player talks.
##   3. Optional "flag": true — makes the NPC show "!" until first conversation.
##
## Example with branching (future): add "choices" and "on_choice" keys.
class_name NPCDialogues
extends RefCounted

const DB: Dictionary = {
	"default": {
		"lines": ["..."],
	},

	"fire_guide": {
		"flag": true,
		"lines": [
			"You can always rest here",
			"Come by the unswept fire.",
		],
	},
	
	"bonzo_spawn": {
		"flag": false,
		"lines": [
			"Was evoked from the graveyard?",
			"...",
			"Ah hello there!",
			"Inside this cave there is a shiny little thing",
			"I think you need it.",
			"Me? no thanks, I'm afraid.",
			"Take this has a token of good luck.",
		],
	},

	"merchant_hint": {
		"lines": [
			"I heard a merchant set up shop nearby.",
			"You can buy single cards from merchants,",
			"but packs are a much better deal.",
			"Foil cards are worth a fortune when sold!",
		],
	},

	"lore_1": {
		"lines": [
			"Long ago, this land was ruled by card masters.",
			"They would duel to settle every dispute.",
			"The Demon cards were the most feared of all.",
			"Some say the Osiris pieces still wander the wilds...",
		],
	},

	"old_dude": {
		"lines": [
			"These old bones have seen many duels.",
			"Never underestimate a cheap pitcher card.",
			"Pitch early, pitch often.",
		],
	},

	"bonzo": {
		"lines": [
			"Bonzo's the name, dueling's the game.",
			"I once beat a Chimera with a single Arcane Tome.",
			"True story.",
		],
	},

	"macho": {
		"lines": [
			"You look strong. Strong enough to duel?",
			"Come back when you've built a real deck.",
		],
	},

	"bellezza": {
		"lines": [
			"Foil cards shimmer like stars.",
			"I collect only the finest.",
			"Sell me your spares and I'll pay double.",
		],
	},

	"girly": {
		"lines": [
			"Did you know Seraph has Divine Shield?",
			"I keep one in every deck.",
		],
	},

	"coolio": {
		"lines": [
			"Stay cool. Play Aerial demons.",
			"Nothing says cool like flying past the front row.",
		],
	},

	"poke_bro": {
		"lines": [
			"I've catalogued every creature in the land.",
			"Still haven't seen a Wormoyf in the wild.",
			"Rare beast, that one.",
		],
	},

	"potato_man": {
		"lines": [
			"Spuds.",
			"...that's all I've got.",
		],
	},

	"nude_guy": {
		"lines": [
			"Freedom!",
			"I lost my clothes in a card duel.",
			"Worth it.",
		],
	},

	"onigiri_doctor": {
		"lines": [
			"I prescribe a balanced deck.",
			"Two pitchers, three removal spells, fifteen threats.",
			"Classic recipe.",
		],
	},

	"super_bald": {
		"lines": [
			"Hair? Never needed it.",
			"What I DO need is more Legendary cards.",
		],
	},

	"ultra_bonzo": {
		"lines": [
			"ULTRA BONZO SMASH!",
			"...I mean, hello.",
			"Please trade cards with me.",
		],
	},

	"woman": {
		"lines": [
			"The card binder fills slowly, but surely.",
			"Keep opening packs. One day you'll complete the set.",
		],
	},
}
