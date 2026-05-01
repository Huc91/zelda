## Collection binder: 3×3 grid of **battle zoom** cards (165×230, `CardZoomDraw`), scrolls vertically.
## Ownership line below each card (normal / foil counts).
class_name CollectionBinder
extends CanvasLayer
const PixelFont = preload("res://core/ui/pixel_font.gd")

signal closed

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

const C_BG: Color = Color(0.88, 0.88, 0.90)
const C_EMPTY: Color = Color(0.70, 0.70, 0.72)
const C_EMPTY_BOR: Color = Color(0.55, 0.55, 0.58)
const C_HDR: Color = Color(0.18, 0.12, 0.30)
const C_TEXT: Color = Color(0.08, 0.04, 0.02)

# ── State ─────────────────────────────────────────────────────────────
var _view: Control
var _font: Font
var _scroll_y: float = 0.0
var _max_scroll: float = 0.0
var _cards: Array = []
var _sections: Array[Dictionary] = []
var _section_idx: int = 0
var _grid_x0: float = 0.0
var _back_rect: Rect2 = Rect2(16, 8, 92, 28)
var _detail_card: Dictionary = {}


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = PixelFont.nudge_orb()
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.focus_mode = Control.FOCUS_NONE
	_view.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_view)
	_view.draw.connect(_on_draw)
	_view.gui_input.connect(_on_input)
	hide()


func open_binder() -> void:
	_build_sections()
	_build_layout()
	_scroll_y = 0.0
	show()
	_view.queue_redraw()


func _cell_stride_y() -> float:
	return float(CARD_H + OWN_LINE_H + GAP_Y)


func _build_layout() -> void:
	CardDB._ensure_init()
	_cards = []
	var section_key: String = _active_section_key()
	for c in CardDB.ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if id.is_empty() or id.begins_with("token_"):
			continue
		var card_set: String = str(c.get("set", "base"))
		if section_key == "promo":
			if card_set != "promo":
				continue
		else:
			if card_set == "promo":
				continue
			if c.get("no_pack", false):
				continue
		if section_key != "promo" and c.get("no_pack", false):
			continue
		_cards.append(c)
	_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if section_key == "promo":
			return int(a.get("set_number", 9999)) < int(b.get("set_number", 9999))
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	var row_w: float = float(GRID_COLS * CARD_W + maxi(0, GRID_COLS - 1) * GAP_X)
	_grid_x0 = (float(W) - row_w) * 0.5

	var total_rows: int = (_cards.size() + GRID_COLS - 1) / GRID_COLS
	var content_h: float = float(START_Y) + float(total_rows) * _cell_stride_y() + 20.0
	_max_scroll = maxf(0.0, content_h - float(H))


func _build_sections() -> void:
	_sections = [
		{"key": "base", "label": "BASE SET COLLECTION"},
	]
	for c in CardDB.ALL_CARDS:
		if str(c.get("set", "")) == "promo":
			_sections.append({"key": "promo", "label": "PROMO COLLECTION"})
			break
	_section_idx = clampi(_section_idx, 0, maxi(0, _sections.size() - 1))


func _active_section_key() -> String:
	if _sections.is_empty():
		return "base"
	return str(_sections[_section_idx].get("key", "base"))


func _active_section_label() -> String:
	if _sections.is_empty():
		return "BASE SET COLLECTION"
	return str(_sections[_section_idx].get("label", "BASE SET COLLECTION"))


func _change_section(step: int) -> void:
	if _sections.size() <= 1:
		return
	_section_idx = posmod(_section_idx + step, _sections.size())
	_detail_card = {}
	_scroll_y = 0.0
	_build_layout()


func _process(_dt: float) -> void:
	if not visible:
		return
	_view.queue_redraw()


func _scroll(amount: float) -> void:
	_scroll_y = clampf(_scroll_y + amount, 0.0, _max_scroll)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _detail_card.is_empty():
		var dismiss: bool = false
		if event is InputEventKey and (event as InputEventKey).pressed:
			dismiss = true
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			dismiss = true
		if dismiss:
			_detail_card = {}
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed:
			if ek.keycode == KEY_UP or ek.keycode == KEY_W:
				_scroll(-40.0)
				get_viewport().set_input_as_handled()
			elif ek.keycode == KEY_DOWN or ek.keycode == KEY_S:
				_scroll(40.0)
				get_viewport().set_input_as_handled()
			elif ek.keycode == KEY_LEFT or ek.keycode == KEY_A:
				_change_section(-1)
				get_viewport().set_input_as_handled()
			elif ek.keycode == KEY_RIGHT or ek.keycode == KEY_D:
				_change_section(1)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll(-32.0)
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(32.0)
				get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		# macOS trackpad two-finger scroll
		var pg: InputEventPanGesture = event as InputEventPanGesture
		_scroll(pg.delta.y * 12.0)
		get_viewport().set_input_as_handled()


func _on_input(event: InputEvent) -> void:
	# Belt-and-suspenders: also handle in gui_input for cases where
	# MOUSE_FILTER_STOP on _view captures the event before _input() sees it.
	if not visible:
		return
	if not _detail_card.is_empty():
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_detail_card = {}
			_view.accept_event()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _back_rect.has_point(mb.position):
				request_back()
				_view.accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				var hit: Dictionary = _card_at_point(mb.position)
				if not hit.is_empty():
					_detail_card = hit
					_view.accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll(-32.0)
				_view.accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll(32.0)
				_view.accept_event()
	elif event is InputEventPanGesture:
		var pg: InputEventPanGesture = event as InputEventPanGesture
		_scroll(pg.delta.y * 12.0)
		_view.accept_event()


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
	_draw_back_button()
	_draw_str_c(_active_section_label(), W * 0.5, 6, 12, Color.WHITE)

	var total_owned: int = 0
	for c in _cards:
		var id: String = str(c.get("id", ""))
		if Global.card_collection.get(id, 0) > 0 or Global.foil_collection.get(id, 0) > 0:
			total_owned += 1
	_draw_str_r("%d / %d" % [total_owned, _cards.size()], W - 12, 6, 9, Color(0.85, 0.85, 0.85))
	_draw_str_c("LEFT/RIGHT: set    UP/DOWN: scroll    ESC: back    I: close", W * 0.5, H - 20, 8, Color(0.7, 0.7, 0.7))

	if _max_scroll > 0.0:
		var track_h: float = float(H - HEADER_H - 4)
		var thumb_h: float = maxf(20.0, track_h * (float(H) / (_max_scroll + float(H))))
		var thumb_y: float = float(HEADER_H) + 2.0 + (_scroll_y / _max_scroll) * (track_h - thumb_h)
		_view.draw_rect(Rect2(W - 5.0, float(HEADER_H) + 2.0, 3.0, track_h), Color(0.7, 0.7, 0.7))
		_view.draw_rect(Rect2(W - 5.0, thumb_y, 3.0, thumb_h), Color(0.3, 0.3, 0.4))

	if not _detail_card.is_empty():
		_draw_detail_overlay()


func _draw_cell(r: Rect2, card: Dictionary, owned_normal: int, owned_foil: int) -> void:
	if owned_normal <= 0 and owned_foil <= 0:
		_view.draw_rect(r, C_EMPTY)
		_border(r, C_EMPTY_BOR, 1)
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


func _border(r: Rect2, col: Color, w: int) -> void:
	var x: int = int(r.position.x); var y: int = int(r.position.y)
	var rw: int = int(r.size.x);    var rh: int = int(r.size.y)
	_view.draw_rect(Rect2(x,          y,          rw, w),          col)
	_view.draw_rect(Rect2(x,          y + rh - w, rw, w),          col)
	_view.draw_rect(Rect2(x,          y + w,      w,  rh - w * 2), col)
	_view.draw_rect(Rect2(x + rw - w, y + w,      w,  rh - w * 2), col)


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


func request_back() -> void:
	hide()
	closed.emit()


func _draw_back_button() -> void:
	_view.draw_rect(_back_rect, Color(0.24, 0.20, 0.34))
	_border(_back_rect, Color.WHITE, 2)
	_draw_str("< BACK", _back_rect.position.x + 12.0, _back_rect.position.y + 7.0, 10, Color.WHITE)


func _card_at_point(pt: Vector2) -> Dictionary:
	if pt.y <= float(HEADER_H):
		return {}
	var ry: float = pt.y + _scroll_y - float(START_Y)
	if ry < 0.0:
		return {}
	var row: int = int(ry / _cell_stride_y())
	if fmod(ry, _cell_stride_y()) >= float(CARD_H):
		return {}
	var col_f: float = pt.x - _grid_x0
	if col_f < 0.0:
		return {}
	var col: int = int(col_f / float(CARD_W + GAP_X))
	if col >= GRID_COLS or fmod(col_f, float(CARD_W + GAP_X)) >= float(CARD_W):
		return {}
	var idx: int = row * GRID_COLS + col
	if idx >= _cards.size():
		return {}
	var card: Dictionary = _cards[idx]
	var id: String = str(card.get("id", ""))
	if Global.card_collection.get(id, 0) <= 0 and Global.foil_collection.get(id, 0) <= 0:
		return {}
	return card


func _draw_detail_overlay() -> void:
	var id: String = str(_detail_card.get("id", ""))
	_view.draw_rect(Rect2(0, 0, float(W), float(H)), Color(0.08, 0.05, 0.14))
	var cx: float = (float(W) - float(CARD_W)) * 0.5
	var cy: float = 24.0
	var cr := Rect2(cx, cy, float(CARD_W), float(CARD_H))
	var draw_card: Dictionary = _detail_card.duplicate()
	draw_card["foil"] = Global.foil_collection.get(id, 0) > 0
	CardZoomDraw.draw(_view, _font, cr, draw_card, {})
	var ny: float = cy + float(CARD_H) + 10.0
	_draw_str_c(str(_detail_card.get("name", "")), float(W) * 0.5, ny, 10, Color.WHITE)
	var card_set: String = str(_detail_card.get("set", "")).to_upper()
	if card_set != "":
		var set_no: int = int(_detail_card.get("set_number", 0))
		var set_label: String = "%s #%03d" % [card_set, set_no] if set_no > 0 else card_set
		_draw_str_c(set_label, float(W) * 0.5, ny + 12.0, 8, Color(0.88, 0.84, 0.70))
	var flavor: String = CardDB.get_flavor(id)
	if not flavor.is_empty():
		var lines: Array[String] = _wrap_text(flavor, 380.0, 8)
		var base_y: float = ny + (34.0 if card_set != "" else 22.0)
		for li: int in lines.size():
			_draw_str_c(lines[li], float(W) * 0.5, base_y + float(li) * 13.0, 8, Color(0.78, 0.74, 0.66))
	_draw_str_c("press any key to close", float(W) * 0.5, float(H) - 16.0, 7, Color(0.45, 0.45, 0.45))


func _wrap_text(text: String, max_w: float, size: int) -> Array[String]:
	var lines: Array[String] = []
	if _font == null:
		lines.append(text)
		return lines
	var words: PackedStringArray = text.split(" ")
	var current: String = ""
	for word: String in words:
		var candidate: String = word if current.is_empty() else current + " " + word
		if _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	return lines
