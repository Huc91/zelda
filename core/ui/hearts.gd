extends Node2D

const HEART_TEXTURE: Texture2D = preload("res://core/ui/hearts.png")
const HEART_SIZE: Vector2 = Vector2(8, 8)
const ROW_COUNT: int = 7


func _ready() -> void:
	Global.hp_changed.connect(func(_hp: int, _max: int) -> void: queue_redraw())
	Global.lives_changed.connect(func(_v: int) -> void: queue_redraw())
	queue_redraw()


func _draw() -> void:
	var max_hp: int = Global.get_effective_max_hp()
	var current_hp: int = Global.player_hp
	var max_hearts: int = ceili(float(max_hp) / 4.0)

	for heart_idx: int in max_hearts:
		var offset_x: int = (heart_idx % ROW_COUNT) * int(HEART_SIZE.x)
		@warning_ignore("integer_division")
		var offset_y: int = (heart_idx / ROW_COUNT) * int(HEART_SIZE.y)

		var hp_for_heart: int = current_hp - heart_idx * 4
		var src_x: int
		if hp_for_heart >= 4:
			src_x = 32
		elif hp_for_heart == 3:
			src_x = 24
		elif hp_for_heart == 2:
			src_x = 16
		elif hp_for_heart == 1:
			src_x = 8
		else:
			src_x = 0

		draw_texture_rect_region(
			HEART_TEXTURE,
			Rect2(Vector2(offset_x, offset_y), HEART_SIZE),
			Rect2(src_x, 0, 8, 8)
		)
