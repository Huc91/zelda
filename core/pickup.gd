class_name Pickup extends StaticBody2D

const SoulItem = preload("res://core/soul_item.gd")

## Soul ID given when player walks over this pickup.
var soul_id: String = "sword"

func _ready() -> void:
	if Global.is_pickup_collected(Global.current_map_path, position):
		queue_free()
		return
	var soul: SoulItem = Global.SOULS.get(soul_id, null) as SoulItem
	if soul == null:
		queue_free()
		return
	if soul.icon != null:
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = soul.icon
		add_child(sp)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = RectangleShape2D.new()
	(col.shape as RectangleShape2D).size = Vector2(8, 8)
	col.rotation_degrees = 45
	add_child(col)
	set_collision_layer_value(1, 0)
	set_collision_layer_value(2, 1)
