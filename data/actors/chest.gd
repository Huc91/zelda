class_name Chest extends StaticBody2D

const INTERACT_ACTION: String = "interact"

enum ContentType { PACK, CARD, MONEY, SOUL_CARD }

@export var content_type: ContentType = ContentType.PACK
@export var quantity: int = 1
## Card id (used when content_type is CARD) or soul id (when SOUL_CARD).
@export var item_id: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger: Area2D = $TriggerArea

var _opened: bool = false
var _player_nearby: bool = false
var _animating: bool = false
var _info_box: InfoBox


func _ready() -> void:
	trigger.body_entered.connect(_on_body_entered)
	trigger.body_exited.connect(_on_body_exited)
	sprite.animation_finished.connect(_on_animation_finished)
	_opened = Global.is_chest_opened(position, Global.current_map_path)
	_info_box = InfoBox.new()
	call_deferred("_add_info_box")
	if _opened:
		sprite.play("Open")
		sprite.stop()
		sprite.frame = 3


func _add_info_box() -> void:
	if is_instance_valid(_info_box) and not _info_box.is_inside_tree():
		get_tree().root.add_child(_info_box)


func _exit_tree() -> void:
	if is_instance_valid(_info_box):
		_info_box.queue_free()


func _process(_delta: float) -> void:
	if _opened or _animating or not _player_nearby:
		return
	if Input.is_action_just_pressed(INTERACT_ACTION):
		_open()


func _open() -> void:
	_animating = true
	_info_box.hide_hint()
	sprite.play("Open")


func _on_animation_finished() -> void:
	if sprite.animation != &"Open":
		return
	_animating = false
	_opened = true
	Global.open_chest(position, Global.current_map_path)
	Global.save_game()
	_give_reward()


func _give_reward() -> void:
	var label: String = ""
	match content_type:
		ContentType.PACK:
			Global.add_base_set_pack(quantity)
			label = "Found %d Base Set Pack%s!" % [quantity, "s" if quantity > 1 else ""]
		ContentType.CARD:
			if not item_id.is_empty():
				for _i in quantity:
					Global.collect_card(item_id, false)
				var card: Dictionary = CardDB.get_card(item_id)
				var name_str: String = card.get("name", item_id)
				label = "Found %s%s!" % [str(quantity) + "× " if quantity > 1 else "", name_str]
			else:
				label = "Found a card!"
		ContentType.MONEY:
			Global.add_money(quantity)
			label = "Found %d Y!" % quantity
		ContentType.SOUL_CARD:
			if not item_id.is_empty():
				Global.add_soul_to_collection(item_id)
				label = "Found Soul: %s!" % item_id.capitalize().replace("_", " ")
			else:
				label = "Found a soul item!"
	_info_box.show_flash(label, 3.0)


func _on_body_entered(body: Node) -> void:
	if _opened:
		return
	if body is Actor and (body as Actor).actor_type == 1:
		_player_nearby = true
		if is_instance_valid(_info_box):
			_info_box.show_hint("Press Z to open")


func _on_body_exited(_body: Node) -> void:
	_player_nearby = false
	if is_instance_valid(_info_box):
		_info_box.hide_hint()
