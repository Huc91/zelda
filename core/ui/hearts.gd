extends Node2D

const HEART_TEXTURE = preload("res://core/ui/hearts.png")
const HEART_SIZE: Vector2 = Vector2(8, 8)
const ROW_COUNT: int = 7


func _ready() -> void:
	Global.lives_changed.connect(func(_v: int) -> void: queue_redraw())


func _draw() -> void:
	var max_hearts: int = Global.MAX_LIVES
	var current: int = Global.lives
	for heart: int in max_hearts:
		var offset_x: int = (heart % ROW_COUNT) * int(HEART_SIZE.x)
		@warning_ignore("integer_division")
		var offset_y: int = (heart / ROW_COUNT) * int(HEART_SIZE.y)
		var src_rect: Rect2
		if heart < current:
			src_rect = Rect2(32, 0, 8, 8)
		else:
			src_rect = Rect2(0, 0, 8, 8)
		draw_texture_rect_region(HEART_TEXTURE, Rect2(Vector2(offset_x, offset_y), HEART_SIZE), src_rect)
