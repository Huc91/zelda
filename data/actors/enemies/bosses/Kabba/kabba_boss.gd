## Kabba — first boss: idle sway (frame_r ↔ front_l), talk face (front), defeat art after win.
## Root is Marker2D so you can select the cross gizmo in the 2D editor and drag placement (tiles won’t steal clicks as easily).
extends Marker2D

const INTERACT_RADIUS: float = 22.0
const IDLE_FLIP_SEC: float = 1.0

const TEX_R: String = "res://data/actors/enemies/bosses/Kabba/frame_r.png"
const TEX_FRONT_L: String = "res://data/actors/enemies/bosses/Kabba/front_l.png"
const TEX_FRONT: String = "res://data/actors/enemies/bosses/Kabba/front.png"
const TEX_DEFEAT: String = "res://data/actors/enemies/bosses/Kabba/defeat.png"
const SKULL_SCENE: PackedScene = preload("res://data/actors/skull.tscn")
const SKULL_SPAWN_OFFSET: Vector2 = Vector2(0, -24)

@export var dialogue_id: String = "kabba"
@export var difficulty: String = "boss"

var _ui_open: bool = false
var _cooldown_frames: int = 0
var _defeated: bool = false
var _idle_t: float = 0.0
var _idle_use_r: bool = true
var _mercy_ui_active: bool = false

var _tex_r: Texture2D
var _tex_front_l: Texture2D
var _tex_front: Texture2D
var _tex_defeat: Texture2D

@onready var _phys: StaticBody2D = $Body
@onready var _body: Sprite2D = $Body/Sprite2D


func _ready() -> void:
	add_to_group("kabba_boss")
	_phys.set_collision_layer_value(1, true)
	_phys.set_collision_layer_value(2, false)
	_tex_r = load(TEX_R) as Texture2D
	_tex_front_l = load(TEX_FRONT_L) as Texture2D
	_tex_front = load(TEX_FRONT) as Texture2D
	_tex_defeat = load(TEX_DEFEAT) as Texture2D

	if Global.npc_progress.get(dialogue_id, 0) >= 1 and Global.kabba_state == Global.KABBA_NONE:
		Global.kabba_state = Global.KABBA_MERCY_PENDING

	match Global.kabba_state:
		Global.KABBA_SPARED_GONE, Global.KABBA_SKULL_DONE:
			queue_free()
			return
		Global.KABBA_KILLED_SKULL:
			_apply_kill_visual_state()
			return
		Global.KABBA_SPARED_WAITING_SCROLL, Global.KABBA_MERCY_PENDING:
			_defeated = true
			_body.texture = _tex_defeat
		_:
			if Global.npc_progress.get(dialogue_id, 0) >= 1:
				_defeated = true
				_body.texture = _tex_defeat
			else:
				_body.texture = _tex_r

	if Global.kabba_state == Global.KABBA_MERCY_PENDING and not Global.in_battle:
		call_deferred("_deferred_offer_mercy")


func _deferred_offer_mercy() -> void:
	offer_post_victory_mercy()


func _process(delta: float) -> void:
	if _defeated or _ui_open:
		return
	_idle_t += delta
	if _idle_t < IDLE_FLIP_SEC:
		return
	_idle_t = 0.0
	_idle_use_r = not _idle_use_r
	_body.texture = _tex_r if _idle_use_r else _tex_front_l


func get_battle_deck() -> Array:
	return CardDB.meta_deck("kabba_deck")


func get_battle_start_hp() -> int:
	return 30


func defer_battle_reward_until_mercy() -> bool:
	return true


func should_skip_battle_reward() -> bool:
	return Global.kabba_state == Global.KABBA_SPARED_WAITING_SCROLL \
		or Global.kabba_state == Global.KABBA_SPARED_GONE \
		or Global.kabba_state == Global.KABBA_KILLED_SKULL \
		or Global.kabba_state == Global.KABBA_SKULL_DONE


func on_card_battle_won() -> void:
	_defeated = true
	_body.texture = _tex_defeat
	Global.npc_progress[dialogue_id] = 1
	Global.kabba_encounter_map_path = Global.current_map_path
	Global.kabba_state = Global.KABBA_MERCY_PENDING


func offer_post_victory_mercy() -> void:
	if Global.kabba_state != Global.KABBA_MERCY_PENDING:
		return
	if _mercy_ui_active:
		return
	_mercy_ui_active = true
	_ui_open = true
	get_tree().paused = true
	var dlg: DialogueBox = DialogueBox.new()
	get_tree().root.add_child(dlg)
	dlg.show_sequence(NPCDialogues.get_kabba_post_victory_mercy(), NPCDialogues.get_speaker_name(dialogue_id))
	var ev: Variant = await dlg.finished
	var evs: String = str(ev)
	if evs == "kabba_spare":
		await _mercy_spare_followup()
	elif evs == "kabba_kill":
		await _mercy_kill_sequence()
	get_tree().paused = false
	_mercy_ui_active = false
	_ui_open = false
	_restore_body_after_ui()


func _mercy_spare_followup() -> void:
	var d2: DialogueBox = DialogueBox.new()
	get_tree().root.add_child(d2)
	d2.show_sequence({"lines": ["This is for you."]}, NPCDialogues.get_speaker_name(dialogue_id))
	await d2.finished
	Global.try_grant_kabba_power_trunks_reward(false)
	Global.kabba_spare_dialogue_step = 0
	Global.kabba_fenrir_dropped = false
	Global.kabba_state = Global.KABBA_SPARED_WAITING_SCROLL


func _mercy_kill_sequence() -> void:
	# Mercy dialog leaves the tree paused; tweens do not advance while paused, so await never finishes.
	get_tree().paused = false
	var tw: Tween = create_tween()
	tw.tween_property(_body, "modulate", Color.BLACK, 0.35)
	await tw.finished
	_body.hide()
	_phys.set_collision_layer_value(1, false)
	_drop_kabba_signature_card()
	_spawn_skull()
	Global.kabba_state = Global.KABBA_KILLED_SKULL


func _drop_kabba_signature_card() -> void:
	if Global.kabba_fenrir_dropped:
		return
	var map: Map = get_parent() as Map
	if map == null:
		Global.collect_card(Global.KABBA_PROMO_CARD_ID, false)
		Global.kabba_fenrir_dropped = true
		return
	var center_cell: Vector2i = map.local_to_map(global_position)
	var drop_cell: Vector2i = center_cell + Vector2i(-1, 0)
	var pickup: CardPickup = CardPickup.new()
	pickup.card_id = Global.KABBA_PROMO_CARD_ID
	pickup.is_placed = false
	pickup.position = map.map_to_local(drop_cell)
	map.add_child(pickup)
	Global.kabba_fenrir_dropped = true


func _spawn_skull() -> void:
	var map: Map = get_parent() as Map
	if map == null:
		return
	var sk: Node = SKULL_SCENE.instantiate()
	add_child(sk)
	var skull_world: Vector2 = global_position + SKULL_SPAWN_OFFSET
	(sk as Node2D).global_position = skull_world
	if sk.has_method("setup"):
		sk.call("setup", map.scene_file_path, skull_world, map)


func on_world_soul_absorb(_world_soul: Node) -> Dictionary:
	var granted: bool = Global.try_grant_kabba_power_trunks_reward(false)
	var soul: SoulItem = Global.SOULS.get(Global.POWER_TRUNKS_SOUL_ID, null) as SoulItem
	if granted and soul != null:
		var count: int = int(Global.soul_collection.get(Global.POWER_TRUNKS_SOUL_ID, 1))
		var suffix: String = " (x%d)" % count if count > 1 else ""
		return {"message": soul.name + " absorbed!" + suffix, "consume": true}
	return {"message": "Nothing left here.", "consume": false}


func on_world_soul_absorbed(_world_soul: Node) -> void:
	Global.kabba_state = Global.KABBA_SKULL_DONE
	queue_free()


func _apply_kill_visual_state() -> void:
	_defeated = true
	_body.modulate = Color.BLACK
	_body.hide()
	_phys.set_collision_layer_value(1, false)
	if get_node_or_null("Skull") == null:
		_spawn_skull()


func _physics_process(_delta: float) -> void:
	if Global.kabba_state == Global.KABBA_KILLED_SKULL or Global.kabba_state == Global.KABBA_SKULL_DONE:
		return
	if Global.kabba_state == Global.KABBA_SPARED_GONE:
		return
	if _cooldown_frames > 0:
		_cooldown_frames -= 1
		return
	if Global.in_battle or _ui_open or _mercy_ui_active:
		return
	var player: Node = _find_player()
	if player == null:
		return
	if player.global_position.distance_to(global_position) < INTERACT_RADIUS:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("b"):
			_talk()


func _find_player() -> Node:
	for a in get_tree().get_nodes_in_group("actor"):
		if a.has_method("_pickup"):
			return a
	return null


func _should_flip_to_player(player: Node) -> bool:
	var dx: float = global_position.x - player.global_position.x
	var dy: float = global_position.y - player.global_position.y
	return dx < 0 and dx > -20 and dy > -10 and dy < 10


func _talk() -> void:
	if Global.kabba_state == Global.KABBA_MERCY_PENDING:
		offer_post_victory_mercy()
		return
	if Global.kabba_state == Global.KABBA_SPARED_WAITING_SCROLL:
		_talk_spared_defeated()
		return
	if Global.kabba_state >= Global.KABBA_SPARED_GONE:
		return
	var player: Node = _find_player()
	if player == null:
		return
	_ui_open = true
	get_tree().paused = true
	_body.texture = _tex_front

	var seq_idx: int = Global.npc_progress.get(dialogue_id, 0)
	var sequence: Dictionary = NPCDialogues.get_sequence(dialogue_id, seq_idx)
	var speaker: String = NPCDialogues.get_speaker_name(dialogue_id)

	var dialog_box: DialogueBox = DialogueBox.new()
	dialog_box.finished.connect(_on_dialogue_done)
	get_tree().root.add_child(dialog_box)
	dialog_box.show_sequence(sequence, speaker)


func _talk_spared_defeated() -> void:
	var lines: Array[String] = [
		"...",
		"...",
		"Why did you not finished me?",
		"I would have killed you.",
		"Take this.",
	]
	var step: int = clampi(Global.kabba_spare_dialogue_step, 0, 5)
	var line: String = "..." if step >= 5 else lines[step]
	_ui_open = true
	get_tree().paused = true
	_body.texture = _tex_front
	var dialog_box: DialogueBox = DialogueBox.new()
	dialog_box.finished.connect(_on_spared_talk_done)
	get_tree().root.add_child(dialog_box)
	dialog_box.show_sequence({"lines": [line]}, NPCDialogues.get_speaker_name(dialogue_id))


func _on_spared_talk_done(_event: String) -> void:
	_ui_open = false
	_cooldown_frames = 6
	get_tree().paused = false
	if Global.kabba_state != Global.KABBA_SPARED_WAITING_SCROLL:
		_restore_body_after_ui()
		return
	var step: int = clampi(Global.kabba_spare_dialogue_step, 0, 5)
	if step == 4 and not Global.kabba_fenrir_dropped:
		_drop_kabba_signature_card()
	Global.kabba_spare_dialogue_step = mini(5, step + 1)
	_restore_body_after_ui()


func _on_dialogue_done(event: String) -> void:
	_ui_open = false
	_cooldown_frames = 6
	get_tree().paused = false
	_restore_body_after_ui()

	if event.begins_with("kabba_fight_"):
		_offer_closer_then_fight()
		return

	var seq_idx: int = Global.npc_progress.get(dialogue_id, 0)
	Global.npc_progress[dialogue_id] = NPCDialogues.advance_sequence(dialogue_id, seq_idx)
	if event != "":
		Global.dialogue_event.emit(event, dialogue_id)


func _offer_closer_then_fight() -> void:
	_ui_open = true
	get_tree().paused = true
	_body.texture = _tex_front
	var dlg: DialogueBox = DialogueBox.new()
	dlg.finished.connect(_on_closer_done)
	get_tree().root.add_child(dlg)
	var nm: String = NPCDialogues.get_speaker_name(dialogue_id)
	dlg.show_sequence({
		"lines": [
			"I will have that pizza",
			"while you become a shadow.",
		],
	}, nm)


func _on_closer_done(_event: String) -> void:
	_ui_open = false
	_cooldown_frames = 6
	get_tree().paused = false
	_restore_body_after_ui()
	Global.request_card_battle(false, self)


func _restore_body_after_ui() -> void:
	if not _body.visible:
		return
	if _defeated:
		_body.texture = _tex_defeat
		_body.modulate = Color.WHITE
		return
	_body.texture = _tex_r if _idle_use_r else _tex_front_l
	_body.modulate = Color.WHITE
