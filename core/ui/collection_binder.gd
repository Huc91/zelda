## Collection binder: 3×3 grid of **battle zoom** cards (165×230, `CardZoomDraw`), scrolls vertically.
## Ownership line below each card (normal / foil counts).
class_name CollectionBinder
extends CanvasLayer

# ── Layout ────────────────────────────────────────────────────────────
const W: int = 640
const H: int = 576
const CARD_W: int = int(CardZoomDraw.ZOOM_W)
const CARD_H: int = int(CardZoomDraw.ZOOM_H)
const GRID_COLS: int = 3
const GAP_X: int = 10
const GAP_Y: int = 10
const OWN_LINE_H: int = 14
const START_Y: int = 52
const HEADER_H: int = 44

const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

const C_BG: Color        = Color(0.88, 0.88, 0.90)
const C_EMPTY: Color     = Color(0.70, 0.70, 0.72)
const C_EMPTY_BOR: Color = Color(0.55, 0.55, 0.58)
const C_HDR: Color       = Color(0.18, 0.12, 0.30)
const C_TEXT: Color      = Color(0.08, 0.04, 0.02)

# ── State ─────────────────────────────────────────────────────────────
var _view: Control
var _font: Font
var _scroll_y: float = 0.0
var _max_scroll: float = 0.0
var _cards: Array = []
var _grid_x0: float = 0.0


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as Font
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.focus_mode = Control.FOCUS_CLICK
	add_child(_view)
	_view.draw.connect(_on_draw)
	_view.gui_input.connect(_on_input)
	hide()


func open_binder() -> void:
	_build_layout()
	_scroll_y = 0.0
	show()
	_view.grab_focus()
	_view.queue_redraw()


func _cell_stride_y() -> float:
	return float(CARD_H + OWN_LINE_H + GAP_Y)


func _build_layout() -> void:
	CardDB._ensure_init()
	_cards = []
	for c in CardDB.ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if id.is_empty() or id.begins_with("token_"):
			continue
		_cards.append(c)
	_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	var row_w: float = float(GRID_COLS * CARD_W + maxi(0, GRID_COLS - 1) * GAP_X)
	_grid_x0 = (float(W) - row_w) * 0.5

	var total_rows: int = (_cards.size() + GRID_COLS - 1) / GRID_COLS
	var content_h: float = float(START_Y) + float(total_rows) * _cell_stride_y() + 20.0
	_max_scroll = maxf(0.0, content_h - float(H))


func _process(_dt: float) -> void:
	if not visible:
		return
	_view.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed:
			if ek.keycode == KEY_ESCAPE or ek.keycode == KEY_TAB:
				hide()
				get_viewport().set_input_as_handled()
			elif ek.keycode == KEY_UP or ek.keycode == KEY_W:
				_scroll_y = maxf(0.0, _scroll_y - 40.0)
				get_viewport().set_input_as_handled()
			elif ek.keycode == KEY_DOWN or ek.keycode == KEY_S:
				_scroll_y = minf(_max_scroll, _scroll_y + 40.0)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_y = maxf(0.0, _scroll_y - 32.0)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_y = minf(_max_scroll, _scroll_y + 32.0)
				get_viewport().set_input_as_handled()


func _on_input(event: InputEvent) -> void:
	pass


func _on_draw() -> void:
	_view.draw_rect(Rect2(0, 0, W, H), C_BG)

	for i in _cards.size():
		var col: int = i % GRID_COLS
		var row: int = i / GRID_COLS
		var cx: float = _grid_x0 + float(col * (CARD_W + GAP_X))
		var cy: float = float(START_Y) + float(row) * _cell_stride_y() - _scroll_y
		var cell_bottom: float = cy + float(CARD_H) + float(OWN_LINE_H) + 2.0
		if cell_bottom < float(HEADER_H) or cy > float(H):
			continue

		var card: Dictionary = _cards[i]
		var id: String = str(card.get("id", ""))
		var owned_normal: int = Global.card_collection.get(id, 0)
		var owned_foil: int = Global.foil_collection.get(id, 0)
		var cr := Rect2(cx, cy, float(CARD_W), float(CARD_H))
		_draw_cell(cr, card, owned_normal, owned_foil)

	# Header drawn after cards so it always covers any card overflow
	_view.draw_rect(Rect2(0, 0, W, HEADER_H), C_HDR)
	_draw_str_c("BASE SET COLLECTION", W * 0.5, 6, 12, Color.WHITE)
	_draw_str("Money: %d" % Global.money, 12, 24, 9, Color(1.0, 0.9, 0.3))

	var total_owned: int = 0
	for c in _cards:
		var id: String = str(c.get("id", ""))
		if Global.card_collection.get(id, 0) > 0 or Global.foil_collection.get(id, 0) > 0:
			total_owned += 1
	_draw_str_r("%d / %d" % [total_owned, _cards.size()], W - 12, 6, 9, Color(0.85, 0.85, 0.85))
	_draw_str_r("ESC to close", W - 12, 20, 8, Color(0.7, 0.7, 0.7))

	if _max_scroll > 0.0:
		var track_h: float = float(H - HEADER_H - 4)
		var thumb_h: float = maxf(20.0, track_h * (float(H) / (_max_scroll + float(H))))
		var thumb_y: float = float(HEADER_H) + 2.0 + (_scroll_y / _max_scroll) * (track_h - thumb_h)
		_view.draw_rect(Rect2(W - 5.0, float(HEADER_H) + 2.0, 3.0, track_h), Color(0.7, 0.7, 0.7))
		_view.draw_rect(Rect2(W - 5.0, thumb_y, 3.0, thumb_h), Color(0.3, 0.3, 0.4))


func _draw_cell(r: Rect2, card: Dictionary, owned_normal: int, owned_foil: int) -> void:
	if owned_normal <= 0 and owned_foil <= 0:
		_view.draw_rect(r, C_EMPTY)
		_view.draw_rect(r, C_EMPTY_BOR, false, 1.0)
		_draw_str_c("?", r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5 - 6.0, 10, Color(0.65, 0.65, 0.65))
		return

	var use_foil: bool = owned_foil > 0
	var draw_card: Dictionary = card.duplicate()
	draw_card["foil"] = use_foil
	CardZoomDraw.draw(_view, _font, r, draw_card, {})

	var count_str: String = ""
	if owned_normal > 0:
		count_str = "×%d" % owned_normal
	if owned_foil > 0:
		count_str += ("  " if count_str != "" else "") + "✦×%d" % owned_foil
	if count_str != "":
		var ly: float = r.position.y + r.size.y + 2.0
		_draw_str_c(count_str, r.get_center().x, ly, 7, C_TEXT)


func _draw_str(text: String, x: float, y: float, size: int, col: Color) -> void:
	if _font == null:
		return
	_view.draw_string(_font, Vector2(x, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_str_c(text: String, cx: float, y: float, size: int, col: Color) -> void:
	if _font == null:
		return
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_view.draw_string(_font, Vector2(cx - tw * 0.5, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_str_r(text: String, rx: float, y: float, size: int, col: Color) -> void:
	if _font == null:
		return
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_view.draw_string(_font, Vector2(rx - tw, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
