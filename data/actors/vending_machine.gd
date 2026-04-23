class_name VendingMachine
extends Area2D

const INTERACT_ACTION: String = "interact"
const PACK_COST: int = 10
const POCORI_COST: int = 5
const HEART_HP: int = 4

var _player_nearby: bool = false
var _ui_open: bool = false
var _cooldown_frames: int = 0
var _info_box: InfoBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_info_box = InfoBox.new()
	call_deferred("_add_info_box")


func _add_info_box() -> void:
	if is_instance_valid(_info_box) and not _info_box.is_inside_tree():
		get_tree().root.add_child(_info_box)


func _exit_tree() -> void:
	if is_instance_valid(_info_box):
		_info_box.queue_free()


func _process(_delta: float) -> void:
	if get_tree().paused:
		if is_instance_valid(_info_box):
			_info_box.hide_hint()
		return
	if _cooldown_frames > 0:
		_cooldown_frames -= 1
		return
	if not _player_nearby or _ui_open:
		return
	if is_instance_valid(_info_box):
		_info_box.show_hint("Press Z to buy")
	if Input.is_action_just_pressed(INTERACT_ACTION):
		_open_menu()


func _open_menu() -> void:
	_ui_open = true
	get_tree().paused = true
	_info_box.hide_hint()
	var dialog_box: DialogueBox = DialogueBox.new()
	dialog_box.finished.connect(_on_dialogue_done)
	get_tree().root.add_child(dialog_box)
	dialog_box.show_sequence({
		"lines": ["What do you want?"],
		"choices": [
			{"text": "Base Set Pack - 10 Y", "event": "buy_pack"},
			{"text": "Pocori Sweat - 5 Y", "event": "buy_pocori"},
			{"text": "Nothing", "event": ""},
		],
	}, "Vending")


func _on_dialogue_done(event_name: String) -> void:
	_ui_open = false
	_cooldown_frames = 6
	get_tree().paused = false
	match event_name:
		"buy_pack":
			_try_buy_pack()
		"buy_pocori":
			_try_buy_pocori()
	if _player_nearby and is_instance_valid(_info_box):
		_info_box.show_hint("Press Z to buy")


func _try_buy_pack() -> void:
	if not Global.spend_money(PACK_COST):
		_info_box.show_flash("Not enough money.", 1.8)
		return
	Global.add_base_set_pack(1)
	_info_box.show_flash("Bought 1 Base Set Pack.", 1.8)


func _try_buy_pocori() -> void:
	if not Global.spend_money(POCORI_COST):
		_info_box.show_flash("Not enough money.", 1.8)
		return
	Global.add_hp(HEART_HP)
	_info_box.show_flash("Pocori used. +1 heart.", 1.8)


func _on_body_entered(body: Node) -> void:
	if body is Actor and (body as Actor).actor_type == 1:
		_player_nearby = true
		if is_instance_valid(_info_box) and not get_tree().paused:
			_info_box.show_hint("Press Z to buy")


func _on_body_exited(_body: Node) -> void:
	_player_nearby = false
	if is_instance_valid(_info_box):
		_info_box.hide_hint()
