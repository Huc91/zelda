extends Control
## BUILD DECK — left: zoom + deck list; right: collection grid (20/page). Pixel coords; Nudge Orb.

signal closed

const PAGE_SIZE: int = 20
const GRID_COLS: int = 5
const GRID_ROWS: int = 4
const LEFT_W: int = 176
## Tight list rows; compact +/- under full-size zoom.
const ROW_H: int = 14
const DECK_LIST_Y0: int = 268
const DECK_LIST_H: int = 250
const LIST_BTN_W: int = 14
const LIST_BTN_H: int = 12
const LIST_BTN_GAP: int = 3
const LIST_BTN_RIGHT_PAD: int = 4
## Full zoom (original layout).
const ZOOM_X: float = 8.0
const ZOOM_Y: float = 32.0
const ZOOM_W: float = 165.0
const ZOOM_H: float = 230.0
## Footer row (aligned with SAVE/CANCEL); H=576 → 14px margin below buttons.
const FOOT_Y: int = 532
const FOOT_BTN_H: int = 30

var _deck_index: int = 0
var _edit_ids: Array = []
var _snap_ids: Array = []
var _snap_name: String = ""
var _page: int = 0
var _all_ids: Array[String] = []

var _font: Font
var _name_edit: LineEdit

var _hover_zoom_id: String = ""
var _hover_slot: int = -1
var _deck_scroll: int = 0

# Hit rects (filled in _draw for _gui_input)
var _rects_collection: Array[Rect2] = []
var _rect_prev: Rect2 = Rect2()
var _rect_next: Rect2 = Rect2()
var _rect_cancel: Rect2 = Rect2()
var _rect_save: Rect2 = Rect2()
var _rect_deck_list_area: Rect2 = Rect2()

var _save_err_msg: String = ""
var _save_err_t: float = 0.0


func _process(delta: float) -> void:
	if _save_err_t <= 0.0:
		return
	_save_err_t -= delta
	if _save_err_t <= 0.0:
		_save_err_msg = ""
		set_process(false)
		queue_redraw()


func _show_save_error(msg: String) -> void:
	_save_err_msg = msg
	_save_err_t = 4.0
	set_process(true)
	queue_redraw()
	push_warning("Deck save: %s" % msg)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	custom_minimum_size = Vector2(CardBattleConstants.W, CardBattleConstants.H)
	_apply_full_viewport_rect()
	_ensure_font()

	_name_edit = LineEdit.new()
	_name_edit.position = Vector2i(8, 2)
	_name_edit.size = Vector2i(112, 15)
	_name_edit.max_length = 12
	_name_edit.placeholder_text = "Deck name"
	_name_edit.focus_mode = Control.FOCUS_ALL
	_name_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_edit.process_mode = Node.PROCESS_MODE_ALWAYS
	_name_edit.add_theme_font_size_override("font_size", 8)
	_name_edit.add_theme_constant_override("caret_width", 1)
	_name_edit.add_theme_constant_override("minimum_character_width", 0)
	add_child(_name_edit)
	if _font != null:
		_name_edit.add_theme_font_override("font", _font)


func _ensure_font() -> void:
	if _font != null:
		return
	var src: Resource = load(CardBattleConstants.FONT_PATH_PRIMARY)
	if src is FontFile:
		var ff: FontFile = (src as FontFile).duplicate(true) as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font = ff
		(_font as Font).clear_cache()
	else:
		_font = ThemeDB.fallback_font


func _apply_full_viewport_rect() -> void:
	# CanvasLayer children can stay 0×0 until layout; without size, no draw / no input.
	var vp := get_viewport()
	if vp == null:
		return
	var r := vp.get_visible_rect()
	position = r.position
	size = r.size


func open(deck_idx: int) -> void:
	_deck_index = deck_idx
	_all_ids = CardDB.all_collectible_ids()
	var d: Dictionary = Global.player_decks[deck_idx]
	_edit_ids = _as_string_array(d.get("card_ids", []))
	_snap_ids = _edit_ids.duplicate()
	_snap_name = str(d.get("name", "Deck"))
	_name_edit.text = _snap_name
	_page = 0
	_deck_scroll = 0
	_hover_zoom_id = ""
	_hover_slot = -1
	_save_err_msg = ""
	_save_err_t = 0.0
	set_process(false)
	_apply_full_viewport_rect()
	visible = true
	queue_redraw()
	_name_edit.visible = true
	call_deferred("_apply_full_viewport_rect")
	call_deferred("queue_redraw")


func _as_string_array(v: Variant) -> Array:
	var a: Array = v as Array if typeof(v) == TYPE_ARRAY else []
	var out: Array = []
	for x in a:
		if typeof(x) == TYPE_STRING:
			out.append(x)
	return out


func close_cancel() -> void:
	_edit_ids = _snap_ids.duplicate()
	_name_edit.text = _snap_name
	visible = false
	_name_edit.visible = false
	emit_signal("closed")


func close_save() -> void:
	if _edit_ids.size() != CardDB.DECK_SIZE_MAX:
		_show_save_error("Deck must have exactly %d cards (you have %d)." % [CardDB.DECK_SIZE_MAX, _edit_ids.size()])
		return
	if not CardDB.deck_ids_legal(_edit_ids):
		_show_save_error("Invalid deck: max %d copies per card (or bad card id)." % CardDB.DECK_COPY_MAX)
		return
	Global.apply_deck_edit(_deck_index, _name_edit.text, _edit_ids)
	visible = false
	_name_edit.visible = false
	emit_signal("closed")


func _count_id(card_id: String) -> int:
	var n: int = 0
	for x in _edit_ids:
		if str(x) == card_id:
			n += 1
	return n


func _owned(card_id: String) -> int:
	return int(Global.card_collection.get(card_id, 0)) + int(Global.foil_collection.get(card_id, 0))


func _can_add(card_id: String) -> bool:
	if _edit_ids.size() >= CardDB.DECK_SIZE_MAX:
		return false
	var in_d: int = _count_id(card_id)
	if in_d >= CardDB.DECK_COPY_MAX:
		return false
	if in_d >= _owned(card_id):
		return false
	return true


func _try_add(card_id: String) -> bool:
	if not _can_add(card_id):
		return false
	_edit_ids.append(card_id)
	return true


func _remove_one(card_id: String) -> void:
	var i: int = _edit_ids.find(card_id)
	if i >= 0:
		_edit_ids.remove_at(i)


func _deck_rows() -> Array[Dictionary]:
	var counts: Dictionary = {}
	for id in _edit_ids:
		var s: String = str(id)
		counts[s] = counts.get(s, 0) + 1
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b) -> bool:
		var na: String = str(CardDB.get_card(str(a)).get("name", a))
		var nb: String = str(CardDB.get_card(str(b)).get("name", b))
		return na < nb
	)
	var rows: Array[Dictionary] = []
	for k in keys:
		rows.append({"id": str(k), "count": int(counts[k])})
	return rows


func _tx(x: float) -> int:
	return int(floor(x))


func _fs(sz: int) -> int:
	return maxi(sz, CardBattleConstants.FONT_MIN)


func _fnt() -> Font:
	return _font


func _mix_white(c: Color, t: float) -> Color:
	var u: float = 1.0 - t
	return Color(c.r * t + u, c.g * t + u, c.b * t + u)


func _mini_shows_effect_label(card: Dictionary) -> bool:
	if card.get("type", "demon") == "demon":
		if str(card.get("ability", "")).strip_edges() != "":
			return true
		return str(card.get("ability_desc", "")).strip_edges() != ""
	return str(card.get("effect", "")).strip_edges() != "" \
		or str(card.get("ability_desc", "")).strip_edges() != ""


func _str(text: String, x: float, y: float, sz: int, color: Color) -> void:
	var fs: int = _fs(sz)
	draw_string(_fnt(), Vector2(_tx(x), _tx(y + float(fs))), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _str_r(text: String, rx: float, y: float, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(_tx(rx - tw), _tx(y + float(fs))), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _str_c(text: String, cx: float, cy: float, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(_tx(cx - tw * 0.5), _tx(cy + float(fs) * 0.5)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _str_r_atk_hp(atk_v: int, hp_v: int, max_hp: int, rx: float, y: float, sz: int) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var part_a: String = str(atk_v) + "/"
	var part_b: String = str(hp_v)
	var w1: float = f.get_string_size(part_a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2: float = f.get_string_size(part_b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0: float = rx - (w1 + w2)
	var baseline: float = y + float(fs)
	draw_string(f, Vector2(_tx(x0), _tx(baseline)), part_a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CardBattleConstants.C_TEXT)
	draw_string(f, Vector2(_tx(x0 + w1), _tx(baseline)), part_b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CardBattleConstants.C_HP_RED if hp_v < max_hp else CardBattleConstants.C_TEXT)


func _draw_cost_badge_rect(r: Rect2, cost: int) -> void:
	draw_rect(r, CardBattleConstants.C_COST_BADGE)
	draw_rect(r, CardBattleConstants.C_BLACK, false, 1.0)
	var fs: int = clampi(mini(int(r.size.x), int(r.size.y)) - 4, CardBattleConstants.FONT_MIN, 12)
	var s: String = str(cost)
	var f: Font = _fnt()
	var tw: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline: float = r.position.y + r.size.y - 3.0
	draw_string(f, Vector2(r.position.x + (r.size.x - tw) * 0.5, baseline), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CardBattleConstants.C_TEXT_LT)


func _draw_hand_card(r: Rect2, card: Dictionary, selected: bool, grayed: bool) -> void:
	var is_dem: bool = card.get("type", "demon") == "demon"
	draw_rect(r, CardBattleConstants.C_DEMON_BG if is_dem else CardBattleConstants.C_SPELL_BG)
	var border_col: Color = Color(0.0, 0.4, 1.0) if selected else CardBattleConstants.C_MINI_BORDER
	draw_rect(r, border_col, false, 2.0)
	if grayed:
		draw_rect(r, CardBattleConstants.C_GRAYED_CARD_OVERLAY)

	var nm: String = card.get("name", "")
	if nm.length() > 8:
		nm = nm.left(8) + "..."
	_str(nm, r.position.x + 5.0, r.position.y + 2.0, 8, CardBattleConstants.C_TEXT)

	var art_bg: Color = CardBattleConstants.C_DEMON_BG if is_dem else CardBattleConstants.C_SPELL_BG
	var art := Rect2(r.position.x + 8.0, r.position.y + CardBattleConstants.MINI_ART_TOP, CardBattleConstants.MINI_ART_SIZE, CardBattleConstants.MINI_ART_SIZE)
	draw_rect(art, Color(art_bg.r * 0.84, art_bg.g * 0.84, art_bg.b * 0.84))
	draw_rect(art, _mix_white(CardBattleConstants.C_MINI_BORDER, 0.35), false, 1.0)
	var _art_tex_mini: Texture2D = CardArt.card_art_1x(str(card.get("id", "")), false)
	if _art_tex_mini != null:
		draw_texture_rect(_art_tex_mini, art, false)

	if _mini_shows_effect_label(card) and _art_tex_mini == null:
		var art_bot: float = r.position.y + CardBattleConstants.MINI_ART_TOP + CardBattleConstants.MINI_ART_SIZE
		var fs_e: int = _fs(8)
		_str("Effect", r.position.x + 5.0, art_bot - 2.0 - float(fs_e), 8, CardBattleConstants.C_TEXT)

	if is_dem:
		var max_hp: int = card.get("hp", 1)
		_str_r_atk_hp(card.get("atk", 0), card.get("hp", 1), max_hp,
			r.position.x + r.size.x - 3.0, r.position.y + r.size.y - 12.0, 10)
	else:
		_str_c("SPELL", r.get_center().x, r.position.y + r.size.y - 14.0, 8, Color(0.24, 0.40, 0.08))

	_draw_cost_badge_rect(Rect2(r.position.x, r.position.y + float(CardBattleConstants.HAND_CH - CardBattleConstants.HAND_COST_H),
		float(CardBattleConstants.HAND_COST_W), float(CardBattleConstants.HAND_COST_H)), card.get("cost", 0))


func _list_row_btn_y(row_y: float) -> float:
	return row_y + (float(ROW_H) - float(LIST_BTN_H)) * 0.5


func _list_plus_minus_rects(row_y: float) -> Array[Rect2]:
	var by: float = _list_row_btn_y(row_y)
	var mx: float = float(LEFT_W - LIST_BTN_RIGHT_PAD - LIST_BTN_W)
	var px: float = mx - float(LIST_BTN_GAP) - float(LIST_BTN_W)
	return [
		Rect2(px, by, float(LIST_BTN_W), float(LIST_BTN_H)),
		Rect2(mx, by, float(LIST_BTN_W), float(LIST_BTN_H)),
	]


func _draw_zoom(card: Dictionary) -> void:
	var cr := Rect2(ZOOM_X, ZOOM_Y, ZOOM_W, ZOOM_H)
	CardZoomDraw.draw(self, _fnt(), cr, card, {})


func _page_count() -> int:
	return maxi(1, int(ceil(float(_all_ids.size()) / float(PAGE_SIZE))))


func _collection_grid_origin() -> Vector2:
	return Vector2(float(LEFT_W + 8), 28.0)


func _cell_stride_y() -> float:
	return float(CardBattleConstants.HAND_CH) + 14.0 + 6.0


func _draw() -> void:
	_rects_collection.clear()
	draw_rect(Rect2(0, 0, float(CardBattleConstants.W), float(CardBattleConstants.H)), CardBattleConstants.C_BG)
	draw_rect(Rect2(0, 0, float(LEFT_W), float(CardBattleConstants.H)), CardBattleConstants.C_LEFT_BG)

	var deck_sz: int = _edit_ids.size()
	_str_r("%d/20" % deck_sz, 168.0, 6.0, 9, CardBattleConstants.C_HP_RED)

	var start: int = _page * PAGE_SIZE

	_str("BUILD DECK — Your collection", float(LEFT_W + 8), 8.0, 9, CardBattleConstants.C_TEXT)

	var ox: float = _collection_grid_origin().x
	var oy: float = _collection_grid_origin().y
	var stride_y: float = _cell_stride_y()

	for slot in PAGE_SIZE:
		var idx: int = start + slot
		var col: int = slot % GRID_COLS
		var row: int = slot / GRID_COLS
		var cx: float = ox + float(col) * (float(CardBattleConstants.HAND_CW) + 6.0)
		var cy: float = oy + float(row) * stride_y
		var cr := Rect2(cx, cy, float(CardBattleConstants.HAND_CW), float(CardBattleConstants.HAND_CH))
		_rects_collection.append(cr)
		if idx >= _all_ids.size():
			draw_rect(cr, Color(0.75, 0.75, 0.75))
			draw_rect(cr, CardBattleConstants.C_MINI_BORDER, false, 1.0)
			continue
		var cid: String = _all_ids[idx]
		var card: Dictionary = CardDB.get_card(cid)
		var sel: bool = (_hover_slot == slot)
		var gray: bool = not _can_add(cid)
		_draw_hand_card(cr, card, sel, gray)
		var own: int = _owned(cid)
		var in_d: int = _count_id(cid)
		_str("x%d" % own, cx, cy + float(CardBattleConstants.HAND_CH) + 2.0, 8, CardBattleConstants.C_TEXT)
		_str("deck: %d" % in_d, cx + 36.0, cy + float(CardBattleConstants.HAND_CH) + 2.0, 8, CardBattleConstants.C_MUTED)

	if _hover_zoom_id != "":
		var zc: Dictionary = CardDB.get_card(_hover_zoom_id)
		if not zc.is_empty():
			_draw_zoom(zc)
	else:
		var ez := Rect2(ZOOM_X, ZOOM_Y, ZOOM_W, ZOOM_H)
		draw_rect(ez, Color(0.82, 0.82, 0.82))
		draw_rect(ez, CardBattleConstants.C_MINI_BORDER, false, 1.0)
		_str_c("Hover a card", ez.get_center().x, ez.get_center().y, 8, CardBattleConstants.C_MUTED)

	_str("Deck name", 8.0, 20.0, 7, CardBattleConstants.C_MUTED)

	var rows: Array[Dictionary] = _deck_rows()
	var max_scroll: int = maxi(0, rows.size() * ROW_H - DECK_LIST_H)
	_deck_scroll = clampi(_deck_scroll, 0, max_scroll)

	var y0: float = float(DECK_LIST_Y0)
	_rect_deck_list_area = Rect2(4.0, y0, float(LEFT_W - 8), float(DECK_LIST_H))
	for ri in rows.size():
		var row: Dictionary = rows[ri]
		var rid: String = str(row["id"])
		var cnt: int = int(row["count"])
		var y: float = y0 - float(_deck_scroll) + float(ri * ROW_H)
		if y + float(ROW_H) < y0:
			continue
		if y > y0 + float(DECK_LIST_H):
			break
		var cname: String = str(CardDB.get_card(rid).get("name", rid))
		if cname.length() > 16:
			cname = cname.left(16) + "…"
		var ty: float = y + 3.0
		_str("%d/%d" % [cnt, CardDB.DECK_COPY_MAX], 4.0, ty, 8, CardBattleConstants.C_TEXT)
		_str(cname, 40.0, ty, 8, CardBattleConstants.C_TEXT)
		var pm: Array[Rect2] = _list_plus_minus_rects(y)
		var plus_rect: Rect2 = pm[0]
		var minus_rect: Rect2 = pm[1]
		var can_p: bool = _can_add(rid)
		var can_m: bool = cnt > 0
		draw_rect(plus_rect, Color(0.55, 0.55, 0.55) if not can_p else Color(0.35, 0.45, 0.85))
		draw_rect(minus_rect, Color(0.55, 0.55, 0.55) if not can_m else Color(0.85, 0.45, 0.25))
		_str_c("+", plus_rect.get_center().x, plus_rect.get_center().y - 3.0, 9, Color.WHITE if can_p else Color(0.7, 0.7, 0.7))
		_str_c("−", minus_rect.get_center().x, minus_rect.get_center().y - 3.0, 9, Color.WHITE if can_m else Color(0.7, 0.7, 0.7))

	var col_name: String = str(Global.player_decks[_deck_index].get("color", "black"))
	_str("Deckbox: %s" % col_name.capitalize(), 8.0, 522.0, 7, CardBattleConstants.C_MUTED)

	var fy: float = float(FOOT_Y)
	var fh: float = float(FOOT_BTN_H)
	_rect_cancel = Rect2(8.0, fy, 90.0, fh)
	_rect_save = Rect2(102.0, fy, 90.0, fh)
	draw_rect(_rect_cancel, Color(0.20, 0.20, 0.20))
	draw_rect(_rect_cancel, Color(0.95, 0.95, 0.95), false, 2.0)
	draw_rect(_rect_save, Color(0.22, 0.44, 0.88))
	draw_rect(_rect_save, Color(0.65, 0.78, 1.0), false, 2.0)
	_str_in_rect_center("CANCEL", _rect_cancel, 10, Color.WHITE)
	_str_in_rect_center("SAVE", _rect_save, 10, Color.WHITE)

	var pc: int = _page_count()
	var rm: float = 8.0
	var nav_w: float = 92.0
	var nav_left_x: float = _rect_save.position.x + _rect_save.size.x + rm
	_rect_prev = Rect2(nav_left_x, fy, nav_w, fh)
	_rect_next = Rect2(float(CardBattleConstants.W) - rm - nav_w, fy, nav_w, fh)
	_str_c("page %d / %d" % [_page + 1, pc],
		(float(LEFT_W) + float(CardBattleConstants.W)) * 0.5, fy + fh * 0.5 - 2.0, 8, CardBattleConstants.C_TEXT)
	draw_rect(_rect_prev, Color(0.45, 0.45, 0.45) if _page <= 0 else Color(0.35, 0.35, 0.5))
	draw_rect(_rect_next, Color(0.45, 0.45, 0.45) if _page >= pc - 1 else Color(0.35, 0.35, 0.5))
	draw_rect(_rect_prev, Color(0.88, 0.88, 0.92), false, 2.0)
	draw_rect(_rect_next, Color(0.88, 0.88, 0.92), false, 2.0)
	_str_in_rect_center("< Prev", _rect_prev, 8, Color.WHITE)
	_str_in_rect_center("Next >", _rect_next, 8, Color.WHITE)

	if not _save_err_msg.is_empty():
		_str(_save_err_msg, 8.0, fy - 14.0, 7, Color(1.0, 0.35, 0.35))


func _str_in_rect_center(text: String, r: Rect2, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx: float = r.position.x + (r.size.x - tw) * 0.5
	var baseline: float = r.position.y + r.size.y * 0.5 + float(fs) * 0.35
	draw_string(f, Vector2(_tx(cx), _tx(baseline)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position
		_update_hover(p)
		queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		_handle_click(pos)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		if _rect_deck_list_area.has_point(event.position):
			_deck_scroll = maxi(0, _deck_scroll - ROW_H * 3)
			queue_redraw()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if _rect_deck_list_area.has_point(event.position):
			var rows: Array[Dictionary] = _deck_rows()
			var max_scroll: int = maxi(0, rows.size() * ROW_H - DECK_LIST_H)
			_deck_scroll = mini(max_scroll, _deck_scroll + ROW_H * 3)
			queue_redraw()
		accept_event()


func _update_hover(p: Vector2) -> void:
	_hover_slot = -1
	_hover_zoom_id = ""
	var start: int = _page * PAGE_SIZE
	for i in _rects_collection.size():
		var r: Rect2 = _rects_collection[i]
		if r.has_point(p):
			_hover_slot = i
			var idx: int = start + i
			if idx < _all_ids.size():
				_hover_zoom_id = _all_ids[idx]
			break
	if _hover_zoom_id != "":
		return
	var rows: Array[Dictionary] = _deck_rows()
	var y0: float = float(DECK_LIST_Y0)
	for ri in rows.size():
		var rid: String = str(rows[ri]["id"])
		var y: float = y0 - float(_deck_scroll) + float(ri * ROW_H)
		if y + float(ROW_H) < y0:
			continue
		if y > y0 + float(DECK_LIST_H):
			break
		var row_rect := Rect2(4.0, y, float(LEFT_W - 8), float(ROW_H))
		if row_rect.has_point(p):
			_hover_zoom_id = rid
			break


func _handle_click(pos: Vector2) -> void:
	if _rect_cancel.has_point(pos):
		close_cancel()
		return
	if _rect_save.has_point(pos):
		close_save()
		return
	if _rect_prev.has_point(pos) and _page > 0:
		_page -= 1
		queue_redraw()
		return
	if _rect_next.has_point(pos) and _page < _page_count() - 1:
		_page += 1
		queue_redraw()
		return

	var start: int = _page * PAGE_SIZE
	for i in _rects_collection.size():
		var r: Rect2 = _rects_collection[i]
		if r.has_point(pos):
			var idx: int = start + i
			if idx < _all_ids.size():
				_try_add(_all_ids[idx])
				queue_redraw()
			return

	var rows2: Array[Dictionary] = _deck_rows()
	var y0b: float = float(DECK_LIST_Y0)
	for ri in rows2.size():
		var rid2: String = str(rows2[ri]["id"])
		var yb: float = y0b - float(_deck_scroll) + float(ri * ROW_H)
		if yb + float(ROW_H) < y0b:
			continue
		if yb > y0b + float(DECK_LIST_H):
			break
		var pm2: Array[Rect2] = _list_plus_minus_rects(yb)
		var plus_rect2: Rect2 = pm2[0]
		var minus_rect2: Rect2 = pm2[1]
		if plus_rect2.has_point(pos) and _can_add(rid2):
			_try_add(rid2)
			queue_redraw()
			return
		if minus_rect2.has_point(pos) and _count_id(rid2) > 0:
			_remove_one(rid2)
			queue_redraw()
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		queue_redraw()
