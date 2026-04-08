## NPC base class. Add to any scene on the map.
##
## ADDING DIALOGUES — simple way:
##   Export `dialogue_id` in the editor (e.g. "old_man").
##   Add your dialogue lines to the DIALOGUES dictionary below.
##   The NPC automatically cycles through the lines when the player talks.
##
## Example dialogue definition:
##   "old_man": [
##       "It's dangerous to go alone!",
##       "Take this sword with you.",
##   ],
class_name NPC
extends StaticBody2D

## Key into DIALOGUES. Set in the editor per-NPC instance.
@export var dialogue_id: String = "default"
## Which line to show next (auto-cycles).
var _dialogue_index: int = 0
var _ui_open: bool = false
const INTERACT_RADIUS: float = 24.0

# ── Dialogue database ─────────────────────────────────────────────────
## Add new NPCs here. Each entry is an Array of Strings (lines in order).
const DIALOGUES: Dictionary = {
	"default": [
		"...",
	],
	"guide": [
		"Welcome, young traveller!",
		"Defeat enemies to earn Rupies.",
		"Open your inventory (TAB) to manage your card decks.",
		"Open packs to collect new cards for your binder.",
		"The stronger the enemy, the better the reward.",
		"Good luck out there!",
	],
	"merchant_hint": [
		"I heard a merchant set up shop nearby.",
		"You can buy single cards from merchants,",
		"but packs are a much better deal.",
		"Foil cards are worth a fortune when sold!",
	],
	"lore_1": [
		"Long ago, this land was ruled by card masters.",
		"They would duel to settle every dispute.",
		"The Demon cards were the most feared of all.",
		"Some say the Osiris pieces still wander the wilds...",
	],
}

# ── Appearance ────────────────────────────────────────────────────────
@export var npc_color: Color = Color(0.4, 0.6, 0.9)

var _sprite: Sprite2D
var _dialog_box: DialogueBox


func _ready() -> void:
	add_to_group("npc")
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	_build_visuals()


func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	var img: Image = Image.create(12, 20, false, Image.FORMAT_RGBA8)
	img.fill(npc_color)
	_sprite.texture = ImageTexture.create_from_image(img)
	add_child(_sprite)

	# Exclamation mark above head to signal interactable
	var lbl: Label = Label.new()
	lbl.position = Vector2(-4, -28)
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 10)
	add_child(lbl)


func _physics_process(_delta: float) -> void:
	if Global.in_battle or _ui_open:
		return
	var player: Node = _find_player()
	if player == null:
		return
	if player.position.distance_to(position) < INTERACT_RADIUS:
		if Input.is_action_just_pressed("a") or Input.is_action_just_pressed("b"):
			_talk()


func _find_player() -> Node:
	for a in get_tree().get_nodes_in_group("actor"):
		if a.has_method("_pickup"):
			return a
	return null


func _talk() -> void:
	_ui_open = true
	get_tree().paused = true
	var lines: Array = DIALOGUES.get(dialogue_id, DIALOGUES["default"])
	var line: String = lines[_dialogue_index % lines.size()]
	_dialogue_index = (_dialogue_index + 1) % lines.size()
	_dialog_box = DialogueBox.new()
	_dialog_box.show_line(line)
	_dialog_box.finished.connect(_on_dialogue_done)
	get_tree().root.add_child(_dialog_box)


func _on_dialogue_done() -> void:
	_ui_open = false
	get_tree().paused = false
