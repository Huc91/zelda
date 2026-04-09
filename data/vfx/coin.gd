class_name Coin extends Node2D

## Money value this coin is worth. Visual tier: >=50=gold, >=10=silver, else copper.
var value: int = 1

var _area: Area2D


func _ready() -> void:
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
	var col: Color = _coin_color()
	draw_circle(Vector2.ZERO, 4.0, col)
	draw_arc(Vector2.ZERO, 4.0, 0.0, TAU, 12, col.darkened(0.3), 1.0)
	draw_circle(Vector2(-1.0, -1.0), 1.2, Color(1.0, 1.0, 1.0, 0.5))
