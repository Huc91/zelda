## NPC base class. Add to any scene on the map.
##
## DIALOGUE FILE: data/actors/npc/dialogues.gd (NPCDialogues class).
## Set `dialogue_id` in the editor. If the NPC has a quest flag, a "!" balloon appears
## above their head and vanishes permanently after first conversation.
class_name NPC
extends StaticBody2D

## Key into NPCDialogues.DB. Set in the editor per-NPC instance.
@export var dialogue_id: String = "default"
## Sprite name from data/actors/npc/sprites/ (without .png). Leave empty for generated sprite.
@export var sprite_name: String = ""
## Color used when generating a procedural sprite (ignored if sprite_name is set).
@export var npc_color: Color = Color(0.4, 0.6, 0.9)
## Show "!" flag above head; flag disappears permanently after first conversation.
@export var has_flag: bool = false
## 0 = first frame (left), 1 = second, … along `sprites/<sprite_name>.png` (16×16 cells in a row).
@export_range(0, 15) var sprite_frame: int = 0

var _ui_open: bool = false
var _cooldown_frames: int = 0
var _flag_dismissed: bool = false

const INTERACT_RADIUS: float = 16.0

var _sprite: Sprite2D
var _flag_label: Label


func _ready() -> void:
	add_to_group("npc")
	set_collision_layer_value(1, true)
	set_collision_layer_value(2, false)
	_build_visuals()
	if has_flag:
		_flag_dismissed = Global.npc_flags_dismissed.get(dialogue_id, false)
		_flag_label.visible = not _flag_dismissed


func _build_visuals() -> void:
	var ph: Node = get_node_or_null("PlaceholderSprite")
	if ph != null:
		ph.queue_free()
	_sprite = Sprite2D.new()
	if sprite_name != "":
		var tex: Texture2D = load("res://data/actors/npc/sprites/" + sprite_name + ".png") as Texture2D
		if tex != null:
			_sprite.texture = tex
			_sprite.region_enabled = true
			_apply_sprite_frame()
			add_child(_sprite)
		else:
			return
	else:
		return

	_flag_label = Label.new()
	_flag_label.position = Vector2(-4, -36)
	_flag_label.text = "!"
	_flag_label.add_theme_font_size_override("font_size", 12)
	_flag_label.visible = false
	add_child(_flag_label)


func _apply_sprite_frame() -> void:
	_set_sprite_region_column(sprite_frame)


func _set_sprite_region_column(col: int) -> void:
	if _sprite == null or not _sprite.region_enabled:
		return
	_sprite.region_rect = Rect2(16 * col, 0, 16, 16)


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
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("b"):
			_talk()


func _find_player() -> Node:
	for a in get_tree().get_nodes_in_group("actor"):
		if a.has_method("_pickup"):
			return a
	return null


func _calc_player_dir(player: Node) -> int:
	var dx: float = position.x - player.position.x
	var dy: float = position.y - player.position.y
	if dx > 0 and dx < 16 and dy > -8 and dy < 8:
		return 2
	elif dx < 0 and dx > -16 and dy > -8 and dy < 8:
		return 0
	elif dy > 0 and dx > -8 and dx < 8:
		return 1
	return 0


func _talk() -> void:
	var player: Node = _find_player()
	if player == null:
		return
	_ui_open = true
	get_tree().paused = true

	if has_flag and not _flag_dismissed:
		_flag_dismissed = true
		_flag_label.visible = false
		Global.npc_flags_dismissed[dialogue_id] = true

	_set_sprite_region_column(_calc_player_dir(player))

	var seq_idx: int = Global.npc_progress.get(dialogue_id, 0)
	var sequence: Dictionary = NPCDialogues.get_sequence(dialogue_id, seq_idx)
	var speaker: String = NPCDialogues.get_speaker_name(dialogue_id)

	var dialog_box: DialogueBox = DialogueBox.new()
	dialog_box.finished.connect(_on_dialogue_done)
	get_tree().root.add_child(dialog_box)
	dialog_box.show_sequence(sequence, speaker)


func _on_dialogue_done(event: String) -> void:
	_ui_open = false
	_cooldown_frames = 6
	get_tree().paused = false
	_apply_sprite_frame()

	var seq_idx: int = Global.npc_progress.get(dialogue_id, 0)
	Global.npc_progress[dialogue_id] = NPCDialogues.advance_sequence(dialogue_id, seq_idx)

	if event != "":
		Global.dialogue_event.emit(event, dialogue_id)
