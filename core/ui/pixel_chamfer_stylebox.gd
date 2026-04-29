extends StyleBox
## Flat style with cut corners (pixel chamfer), not smooth rounded radius.

@export var bg_color: Color = Color(0.2, 0.2, 0.25)
@export var border_color: Color = Color(0.85, 0.85, 0.9)
@export var border_width: int = 2
@export var chamfer_pixels: int = 2


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	_draw_chamfer_rid(to_canvas_item, rect, bg_color, border_color, border_width, chamfer_pixels)


static func _clamp_chamfer(c: int, w: int, h: int) -> int:
	if w <= 0 or h <= 0:
		return 0
	var half: int = mini(w, h) >> 1
	var lim: int = maxi(half - 1, 0)
	return clampi(c, 0, lim)


static func octagon_points_px(x: int, y: int, w: int, h: int, c: int) -> PackedVector2Array:
	var cc: int = _clamp_chamfer(c, w, h)
	if cc <= 0:
		return PackedVector2Array([
			Vector2(x, y), Vector2(x, y + h), Vector2(x + w, y + h), Vector2(x + w, y)
		])
	var pts := PackedVector2Array([
		Vector2(x + cc, y),
		Vector2(x + w - cc, y),
		Vector2(x + w, y + cc),
		Vector2(x + w, y + h - cc),
		Vector2(x + w - cc, y + h),
		Vector2(x + cc, y + h),
		Vector2(x, y + h - cc),
		Vector2(x, y + cc),
	])
	pts.reverse()
	return pts


static func _draw_chamfer_rid(to_canvas_item: RID, rect: Rect2, bg: Color, border: Color, bw: int, chamfer: int) -> void:
	var x: int = int(floor(rect.position.x))
	var y: int = int(floor(rect.position.y))
	var w: int = int(floor(rect.size.x))
	var h: int = int(floor(rect.size.y))
	if w <= 0 or h <= 0:
		return
	var c: int = _clamp_chamfer(chamfer, w, h)
	var outer: PackedVector2Array = octagon_points_px(x, y, w, h, c)
	if bw <= 0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, outer, PackedColorArray([bg]))
		return
	RenderingServer.canvas_item_add_polygon(to_canvas_item, outer, PackedColorArray([border]))
	var ix: int = x + bw
	var iy: int = y + bw
	var iw: int = w - 2 * bw
	var ih: int = h - 2 * bw
	if iw <= 0 or ih <= 0:
		return
	var ic: int = _clamp_chamfer(chamfer - bw, iw, ih)
	var inner: PackedVector2Array = octagon_points_px(ix, iy, iw, ih, ic)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, inner, PackedColorArray([bg]))


## For Control._draw(): filled chamfered rect with uniform border inset.
static func draw_chamfer_control(ci: CanvasItem, rect: Rect2, bg: Color, border: Color, bw: int, chamfer: int) -> void:
	var x: int = int(floor(rect.position.x))
	var y: int = int(floor(rect.position.y))
	var w: int = int(floor(rect.size.x))
	var h: int = int(floor(rect.size.y))
	if w <= 0 or h <= 0:
		return
	var c: int = _clamp_chamfer(chamfer, w, h)
	var outer: PackedVector2Array = octagon_points_px(x, y, w, h, c)
	if bw <= 0:
		ci.draw_colored_polygon(outer, bg)
		return
	ci.draw_colored_polygon(outer, border)
	var ix: int = x + bw
	var iy: int = y + bw
	var iw: int = w - 2 * bw
	var ih: int = h - 2 * bw
	if iw <= 0 or ih <= 0:
		return
	var ic: int = _clamp_chamfer(chamfer - bw, iw, ih)
	var inner: PackedVector2Array = octagon_points_px(ix, iy, iw, ih, ic)
	ci.draw_colored_polygon(inner, bg)
