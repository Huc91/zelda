class_name CardPickup extends Node2D

const CARD_TEX: Texture2D = preload("res://data/actors/card_pickup.png")
const FLASH_DURATION: float = 3.0

## Specific card to give when collected. Empty = random collectible card.
@export var card_id: String = ""
## True for pickups placed in the map editor — persists collected state across saves.
@export var is_placed: bool = true

var _area: Area2D
var _info_box: InfoBox
var _collected: bool = false


func _ready() -> void:
	if is_placed and Global.is_pickup_collected(Global.current_map_path, position):
		queue_free()
		return
	var sp: Sprite2D = Sprite2D.new()
	sp.texture = CARD_TEX
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	_info_box = InfoBox.new()
	call_deferred("_add_info_box")
	_area = Area2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 6.0
	cs.shape = shape
	_area.add_child(cs)
	_area.set_collision_layer_value(1, false)
	_area.set_collision_mask_value(1, false)
	_area.set_collision_mask_value(2, true)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


func _add_info_box() -> void:
	if is_instance_valid(_info_box) and not _info_box.is_inside_tree():
		get_tree().root.add_child(_info_box)


func _exit_tree() -> void:
	if not is_instance_valid(_info_box):
		return
	if _collected:
		# InfoBox is showing the flash — let its timer clean it up
		get_tree().create_timer(FLASH_DURATION + 0.2, true).timeout.connect(
			func() -> void:
				if is_instance_valid(_info_box):
					_info_box.queue_free()
		)
	else:
		_info_box.queue_free()


func _on_body_entered(body: Node) -> void:
	if not (body is Actor and (body as Actor).actor_type == 1):
		return
	var collected_id: String = card_id
	if collected_id.is_empty():
		var ids: Array[String] = CardDB.all_collectible_ids()
		if ids.is_empty():
			queue_free()
			return
		collected_id = ids[randi() % ids.size()]
	Global.collect_card(collected_id, false)
	if is_placed:
		Global.record_pickup(Global.current_map_path, position)
		Global.save_game()
	var card: Dictionary = CardDB.get_card(collected_id)
	var card_name: String = card.get("name", "Card")
	_collected = true
	if is_instance_valid(_info_box):
		_info_box.show_flash('You found a "%s" card!' % card_name, FLASH_DURATION)
	queue_free()


