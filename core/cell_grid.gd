@tool
class_name CellGrid extends Node2D

const CELL_SIZE := Vector2(256, 176)
const GRID_RANGE := 20
const LINE_COLOR := Color(1, 0.4, 0.1, 0.5)
const TEXT_COLOR := Color(1, 0.4, 0.1, 0.8)
const FONT_SIZE := 10

func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var font := ThemeDB.fallback_font

	for gx in range(-GRID_RANGE, GRID_RANGE + 1):
		var x := gx * CELL_SIZE.x
		draw_line(Vector2(x, -GRID_RANGE * CELL_SIZE.y), Vector2(x, GRID_RANGE * CELL_SIZE.y), LINE_COLOR, 1.0)

	for gy in range(-GRID_RANGE, GRID_RANGE + 1):
		var y := gy * CELL_SIZE.y
		draw_line(Vector2(-GRID_RANGE * CELL_SIZE.x, y), Vector2(GRID_RANGE * CELL_SIZE.x, y), LINE_COLOR, 1.0)

	for gx in range(-GRID_RANGE, GRID_RANGE):
		for gy in range(-GRID_RANGE, GRID_RANGE):
			var label_pos := Vector2(gx * CELL_SIZE.x + 4, gy * CELL_SIZE.y + FONT_SIZE + 2)
			draw_string(font, label_pos, "%d,%d" % [gx, gy], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
