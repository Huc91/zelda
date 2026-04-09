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
var _cooldown_frames: int = 0
const INTERACT_RADIUS: float = 32.0

# ── Dialogue database ─────────────────────────────────────────────────
## Add new NPCs here. Each entry is an Array of Strings (lines in order).
const DIALOGUES: Dictionary = {
	"default": [
		"...",
	],
	"guide": [
		"Welcome, young traveller!",
		"Defeat enemies to earn money.",
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
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, false)
	_build_visuals()


func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = ImageTexture.create_from_image(_make_npc_image())
	add_child(_sprite)

	var lbl: Label = Label.new()
	lbl.position = Vector2(-4, -28)
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 10)
	add_child(lbl)


func _make_npc_image() -> Image:
	# 12×20 pixel-art human silhouette
	# Row layout (y): 0-3 head, 4 neck, 5-12 body/arms, 13-19 legs
	const W: int = 12
	const H: int = 20
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin: Color = npc_color.lightened(0.35)
	var body: Color = npc_color
	var dark: Color = npc_color.darkened(0.35)
	var outline: Color = Color(0.05, 0.02, 0.02, 1.0)

	# Head (4×4 centered at x:4-7)
	for y in range(0, 4):
		for x in range(4, 8):
			img.set_pixel(x, y, skin)
	# Head outline
	for x in range(4, 8):
		img.set_pixel(x, 0, outline)
		img.set_pixel(x, 3, outline)
	img.set_pixel(4, 1, outline); img.set_pixel(4, 2, outline)
	img.set_pixel(7, 1, outline); img.set_pixel(7, 2, outline)

	# Neck
	img.set_pixel(5, 4, skin); img.set_pixel(6, 4, skin)

	# Body (6 wide, y 5-11)
	for y in range(5, 12):
		for x in range(3, 9):
			img.set_pixel(x, y, body)
	# Body outline sides
	for y in range(5, 12):
		img.set_pixel(3, y, outline)
		img.set_pixel(8, y, outline)
	for x in range(3, 9):
		img.set_pixel(x, 5, outline)
		img.set_pixel(x, 11, outline)

	# Arms (y 5-10, x 1-2 left, x 9-10 right)
	for y in range(5, 11):
		img.set_pixel(1, y, dark); img.set_pixel(2, y, dark)
		img.set_pixel(9, y, dark); img.set_pixel(10, y, dark)

	# Legs (y 12-19, split at center)
	for y in range(12, 20):
		img.set_pixel(3, y, dark); img.set_pixel(4, y, dark)
		img.set_pixel(7, y, dark); img.set_pixel(8, y, dark)
	# Leg outlines
	for y in range(12, 20):
		img.set_pixel(3, y, outline if y == 12 or y == 19 else dark)
		img.set_pixel(2, y, outline)
		img.set_pixel(9, y, outline)

	return img


func _physics_process(_delta: float) -> void:
	if _cooldown_frames > 0:
		_cooldown_frames -= 1
		return
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
	_cooldown_frames = 6
	get_tree().paused = false
