class_name Coin extends Node2D

const COIN_TEX: Texture2D = preload("res://GUI_plugin/items/rpgItems.png")
const FRAME_SIZE: int = 16

## Money value this coin is worth. Visual tier: >=50=gold, >=10=silver, else copper.
var value: int = 1

var _area: Area2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_area = Area2D.new()
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 5.0
	cs.shape = shape
	_area.add_child(cs)
	_area.set_collision_layer_value(1, false)
	_area.set_collision_mask_value(1, false)
	_area.set_collision_mask_value(2, true)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Actor and (body as Actor).actor_type == 1:
		Global.add_money(value)
		_spawn_label()
		queue_free()


func _spawn_label() -> void:
	var lbl: Label = Label.new()
	lbl.text = "+%d" % value
	lbl.add_theme_color_override("font_color", _coin_color())
	lbl.add_theme_font_size_override("font_size", 8)
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector2(-8.0, -14.0)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -14.0), 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)


func _coin_color() -> Color:
	if value >= 50:
		return Color(1.0, 0.85, 0.1)
	elif value >= 10:
		return Color(0.85, 0.85, 0.9)
	return Color(0.78, 0.42, 0.12)


func _draw() -> void:
	var src_col: int
	if value >= 50:
		src_col = 1   # col 2 → index 1 (gold)
	elif value >= 10:
		src_col = 2   # col 3 → index 2 (silver)
	else:
		src_col = 3   # col 4 → index 3 (copper)
	var src: Rect2 = Rect2(src_col * FRAME_SIZE, 5 * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
	var dst: Rect2 = Rect2(-FRAME_SIZE / 2, -FRAME_SIZE / 2, FRAME_SIZE, FRAME_SIZE)
	draw_texture_rect_region(COIN_TEX, dst, src)
