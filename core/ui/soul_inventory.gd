class_name SoulInventory extends CanvasLayer

const SoulItem = preload("res://core/soul_item.gd")
const ICONS_TEXTURE: Texture2D = preload("res://assets/ui parts/icons.png")
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

const W: int = 640
const H: int = 576

# ── Palette ──────────────────────────────────────────────────────────────────
const C_BG:        Color = Color(0.07, 0.06, 0.13)
const C_BLACK:     Color = Color(0.0,  0.0,  0.0)
const C_TEXT:      Color = Color(1.0,  1.0,  1.0)
const C_MUTED:     Color = Color(0.50, 0.50, 0.55)
const C_SEL_ROW:   Color = Color(0.15, 0.13, 0.28)
const C_SEL_TEXT:  Color = Color(0.9,  0.85, 0.2)
const C_DIV:       Color = Color(0.18, 0.16, 0.30)
const C_RED:       Color = Color(0.85, 0.15, 0.15)
const C_BLUE:      Color = Color(0.15, 0.35, 0.90)
const C_GREEN:     Color = Color(0.10, 0.75, 0.25)
const C_GOLD:      Color = Color(0.9,  0.82, 0.3)

# ── Soul card palette ─────────────────────────────────────────────────────────
const SC_BG:       Color = Color(0.05, 0.10, 0.20)   # deep navy
const SC_BORDER_O: Color = Color(0.0,  0.0,  0.0)   # outer border
const SC_BORDER_I: Color = Color(0.28, 0.72, 1.0)   # inner azure frame
const SC_ART_LINE: Color = Color(0.22, 0.60, 0.90)  # art-area divider
const SC_FT_BG:    Color = Color(0.03, 0.07, 0.16)  # footer strip
const SC_TEXT:     Color = Color(1.0,  1.0,  1.0)
const SC_MUTED:    Color = Color(0.55, 0.75, 0.90)

# ── Layout: list on left, card on right ───────────────────────────────────────
const LIST_X0:  int = 24
const LIST_X1:  int = 420   # list column right edge
const CARD_X:   int = 435
const CARD_Y:   int = 68
const CARD_W:   int = 165
const CARD_H:   int = 230

const SLOT_LABELS: Array = ["Red", "Blue", "Green"]
const SLOT_KEYS:   Array = ["red", "blue", "green"]
const SLOT_COLS:   Array = [Color(0.85, 0.15, 0.15), Color(0.15, 0.35, 0.90), Color(0.10, 0.75, 0.25)]

const SLOT_W:   int = 120
const SLOT_H:   int = 44
const SLOT_PAD: int = 14
const SLOT_Y:   int = 44

const LIST_Y0:     int = 140
const ENTRY_H:     int = 26
const VISIBLE_ROWS: int = 14

var _list:        Array[String] = []
var _cursor:      int = 0
var _font:        Font
var _back_rect:   Rect2 = Rect2(16, 8, 84, 24)
var _slot_icons:  Array[AtlasTexture] = []

# face=red(0), tao=blue(1), circle=green(2)
const ICON_REGIONS: Array = [Rect2(0, 0, 30, 30), Rect2(31, 0, 30, 30), Rect2(62, 0, 30, 30)]

signal back_requested

class _View extends Control:
	var b: SoulInventory
	func _draw() -> void:        b._on_draw()
	func _process(_dt: float) -> void: b._handle_input()
	func _gui_input(ev: InputEvent) -> void: b._handle_gui_input(ev)

var _view: _View


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_font = load(FONT_PATH) as Font
	for reg: Rect2 in ICON_REGIONS:
		var at: AtlasTexture = AtlasTexture.new()
		at.atlas = ICONS_TEXTURE
		at.region = reg
		_slot_icons.append(at)
	_view = _View.new()
	_view.b = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.focus_mode = Control.FOCUS_CLICK
	add_child(_view)
	Global.soul_changed.connect(func() -> void: _rebuild_list(); _view.queue_redraw())
	_rebuild_list()


func _rebuild_list() -> void:
	_list.clear()
	for soul_id: String in Global.SOULS:
		if int(Global.soul_collection.get(soul_id, 0)) > 0:
			_list.append(soul_id)
	_cursor = clampi(_cursor, 0, maxi(0, _list.size() - 1))


func _handle_input() -> void:
	if not visible or ScreenFX.playing:
		return
	if Input.is_action_just_pressed("up"):
		_cursor = wrapi(_cursor - 1, 0, maxi(1, _list.size()))
		Sound.play(preload("res://data/sfx/LA_Menu_Cursor.wav"))
		_view.queue_redraw()
	elif Input.is_action_just_pressed("down"):
		_cursor = wrapi(_cursor + 1, 0, maxi(1, _list.size()))
		Sound.play(preload("res://data/sfx/LA_Menu_Cursor.wav"))
		_view.queue_redraw()
	elif Input.is_action_just_pressed("attack"):
		_try_equip()
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("b"):
		_try_unequip_selected_soul()


func _handle_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _back_rect.has_point(mb.position):
				request_back()
				_view.accept_event()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var hovered: int = _row_at(mm.position)
		if hovered >= 0 and hovered != _cursor:
			_cursor = hovered
			_view.queue_redraw()


# Returns which list row the mouse is over, or -1.
func _row_at(mouse: Vector2) -> int:
	if _list.is_empty():
		return -1
	if mouse.x < LIST_X0 or mouse.x > LIST_X1:
		return -1
	var scroll_start: int = maxi(0, _cursor - VISIBLE_ROWS + 1)
	for row: int in VISIBLE_ROWS:
		var idx: int = scroll_start + row
		if idx >= _list.size():
			break
		var ey: int = LIST_Y0 + 20 + row * ENTRY_H
		if mouse.y >= ey - 4 and mouse.y < ey - 4 + ENTRY_H:
			return idx
	return -1


func _try_equip() -> void:
	if _list.is_empty() or _cursor >= _list.size():
		return
	Global.equip_soul(_list[_cursor])
	Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
	_view.queue_redraw()


func _try_unequip_selected_soul() -> void:
	if _list.is_empty() or _cursor >= _list.size():
		return
	var soul_id: String = _list[_cursor]
	var soul: SoulItem = Global.SOULS.get(soul_id, null) as SoulItem
	if soul == null:
		return
	match soul.slot:
		"red":   if Global.equipped_soul_red   == soul_id: Global.unequip_soul("red")
		"blue":  if Global.equipped_soul_blue  == soul_id: Global.unequip_soul("blue")
		"green": if Global.equipped_soul_green == soul_id: Global.unequip_soul("green")
	_view.queue_redraw()


# ── Draw ─────────────────────────────────────────────────────────────────────

func _on_draw() -> void:
	_view.draw_rect(Rect2(0, 0, W, H), C_BG)
	if _font == null:
		return

	_draw_header()
	_draw_equipped_slots()
	_draw_divider(LIST_Y0 - 8)
	_draw_column_headers()
	_draw_list()
	_draw_soul_card_panel()
	_draw_hints()


func _draw_header() -> void:
	_view.draw_rect(_back_rect, Color(0.20, 0.16, 0.32))
	_view.draw_rect(_back_rect, C_TEXT, false, 1.0)
	_str(22, 23, "< BACK", 9, C_TEXT)

	var title: String = "SOUL SYSTEM"
	var tw: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_view.draw_string(_font, Vector2(int((float(LIST_X1) - tw) * 0.5 + LIST_X0), 36),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, C_TEXT)


func _draw_equipped_slots() -> void:
	var sx0: int = LIST_X0

	for i: int in 3:
		var sx: int = sx0 + i * (SLOT_W + SLOT_PAD)
		var sy: int = SLOT_Y
		var slot_key: String = SLOT_KEYS[i] as String
		var col: Color       = SLOT_COLS[i] as Color
		var equipped: SoulItem = Global.get_equipped_soul(slot_key)

		# Outer black border
		_view.draw_rect(Rect2(sx - 1, sy - 1, SLOT_W + 2, SLOT_H + 2), C_BLACK)
		# Slot background
		_view.draw_rect(Rect2(sx, sy, SLOT_W, SLOT_H), col.darkened(0.5) if equipped == null else col.darkened(0.2))

		# Icon sub-area: 38×38 on left, padded 3px from slot edge
		var icon_rect: Rect2 = Rect2(sx + 3, sy + 3, 38, 38)
		_view.draw_rect(icon_rect, Color(0.08, 0.08, 0.08))

		# Soul sprite or slot type icon
		if equipped != null:
			var soul_icon: Variant = equipped.get("icon")
			if soul_icon != null and soul_icon is Texture2D:
				_view.draw_texture_rect(soul_icon as Texture2D, icon_rect, false)
			elif i < _slot_icons.size():
				_view.draw_texture_rect(_slot_icons[i], icon_rect, false)
		elif i < _slot_icons.size():
			_view.draw_texture_rect(_slot_icons[i], icon_rect, false)

		# Colored 3px strip TOP — over sprite
		_view.draw_rect(Rect2(sx + 3, sy + 3, 38, 3), col)
		# Colored 3px strip BOTTOM — over sprite
		_view.draw_rect(Rect2(sx + 3, sy + 38, 38, 3), col)

		# Text block to the right of icon area
		var tx: int = sx + 47
		var label: String = (SLOT_LABELS[i] as String).to_upper() + " SLOT"
		_str(tx, sy + 16, label, 8, C_TEXT)
		if equipped != null:
			_str(tx, sy + 30, equipped.name, 9, C_TEXT)
		else:
			_str(tx, sy + 30, "— empty —", 9, C_MUTED)


func _draw_divider(y: int) -> void:
	_view.draw_line(Vector2(LIST_X0, y), Vector2(LIST_X1, y), C_DIV, 1.0)


func _draw_column_headers() -> void:
	_str(LIST_X0 + 18, LIST_Y0, "SOUL",   9, C_MUTED)
	_str(280,          LIST_Y0, "STATUS", 9, C_MUTED)
	_str(370,          LIST_Y0, "QTY",    9, C_MUTED)


func _draw_list() -> void:
	var list_y: int = LIST_Y0 + 18

	if _list.is_empty():
		_str(LIST_X0 + 18, list_y + 12, "No souls collected yet.", 11, C_MUTED)
		return

	var scroll_start: int = maxi(0, _cursor - VISIBLE_ROWS + 1)
	for row: int in VISIBLE_ROWS:
		var idx: int = scroll_start + row
		if idx >= _list.size():
			break
		var soul_id: String = _list[idx]
		var soul: SoulItem = Global.SOULS.get(soul_id, null) as SoulItem
		if soul == null:
			continue
		var ey: int = list_y + row * ENTRY_H
		var is_sel: bool = idx == _cursor

		if is_sel:
			_view.draw_rect(Rect2(LIST_X0 + 2, ey - 3, LIST_X1 - LIST_X0 - 4, ENTRY_H - 1), C_SEL_ROW)

		# Slot dot
		var dot_col: Color = _slot_col(soul.slot)
		_view.draw_rect(Rect2(LIST_X0 + 6, ey + 4, 8, 8), dot_col)

		# Name
		var name_col: Color = C_SEL_TEXT if is_sel else C_TEXT
		_str(LIST_X0 + 20, ey + 12, soul.name, 11, name_col)

		# Equipped status
		var equipped_id: String = _equipped_id_for(soul.slot)
		var status: String = "EQUIPPED" if equipped_id == soul_id else "owned"
		var status_col: Color = C_GREEN if equipped_id == soul_id else C_MUTED
		_str(280, ey + 12, status, 9, status_col)

		# Qty
		var qty: int = mini(int(Global.soul_collection.get(soul_id, 0)), 99)
		_str(370, ey + 12, "x%d" % qty, 10, C_GOLD if qty >= 99 else C_TEXT)


func _draw_soul_card_panel() -> void:
	# Vertical divider between list and card
	_view.draw_line(Vector2(CARD_X - 8, SLOT_Y), Vector2(CARD_X - 8, H - 30), C_DIV, 1.0)

	if _list.is_empty() or _cursor >= _list.size():
		var cx: int = CARD_X + CARD_W / 2
		var cy: int = CARD_Y + CARD_H / 2
		var tw: float = _font.get_string_size("select a soul", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		_view.draw_string(_font, Vector2(int(float(cx) - tw * 0.5), cy),
			"select a soul", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_MUTED)
		return

	var soul_id: String = _list[_cursor]
	var soul: SoulItem = Global.SOULS.get(soul_id, null) as SoulItem
	if soul == null:
		return

	var qty: int = mini(int(Global.soul_collection.get(soul_id, 0)), 99)
	_draw_soul_card(Rect2(CARD_X, CARD_Y, CARD_W, CARD_H), soul, soul_id, qty)


func _draw_soul_card(cr: Rect2, soul: SoulItem, soul_id: String, qty: int) -> void:
	var x: int = int(cr.position.x)
	var y: int = int(cr.position.y)
	var w: int = int(cr.size.x)
	var h: int = int(cr.size.y)

	var slot_col: Color = _slot_col(soul.slot)

	# ── Background ────────────────────────────────────────────────
	_view.draw_rect(cr, SC_BG)

	# ── Outer black border ─────────────────────────────────────────
	_view.draw_rect(cr, SC_BORDER_O, false, 2.0)

	# ── Inner azure frame (inset 3px) ──────────────────────────────
	var inner: Rect2 = cr.grow(-3.0)
	_view.draw_rect(inner, SC_BORDER_I, false, 1.0)

	# ── Name strip ────────────────────────────────────────────────
	var name_strip: Rect2 = Rect2(x + 4, y + 4, w - 8, 18)
	_view.draw_rect(name_strip, SC_BG)
	_view.draw_string(_font,
		Vector2(x + 7, y + 16),
		soul.name, HORIZONTAL_ALIGNMENT_LEFT, w - 30, 10, SC_TEXT)

	# ── Slot square (top-right): type icon with colored top/bottom strips ──────
	var sq_x: int = x + w - 18
	var sq_y: int = y + 5
	_view.draw_rect(Rect2(sq_x, sq_y, 12, 12), SC_BORDER_O)
	_view.draw_rect(Rect2(sq_x + 1, sq_y + 1, 10, 10), Color(0.08, 0.08, 0.08))
	var sq_idx: int = SLOT_KEYS.find(soul.slot)
	if sq_idx >= 0 and sq_idx < _slot_icons.size():
		_view.draw_texture_rect(_slot_icons[sq_idx], Rect2(sq_x + 1, sq_y + 1, 10, 10), false)
	_view.draw_rect(Rect2(sq_x + 1, sq_y + 1, 10, 2), slot_col)
	_view.draw_rect(Rect2(sq_x + 1, sq_y + 9, 10, 2), slot_col)

	# ── Art area ──────────────────────────────────────────────────
	var art_y: int = y + 24
	var art_h: int = 96
	var art_rect: Rect2 = Rect2(x + 4, art_y, w - 8, art_h)

	# Art BG: dark slot-tinted block
	_view.draw_rect(art_rect, slot_col.darkened(0.78))
	_view.draw_rect(art_rect, SC_ART_LINE, false, 1.0)

	if soul.icon != null:
		# Center the icon inside the art area
		var tex_size: Vector2 = soul.icon.get_size()
		var scale: float = minf(float(art_rect.size.x - 8) / tex_size.x,
								float(art_rect.size.y - 8) / tex_size.y)
		var draw_w: int = int(tex_size.x * scale)
		var draw_h: int = int(tex_size.y * scale)
		var draw_x: int = int(art_rect.position.x + (art_rect.size.x - float(draw_w)) * 0.5)
		var draw_y: int = int(art_rect.position.y + (art_rect.size.y - float(draw_h)) * 0.5)
		_view.draw_texture_rect(soul.icon, Rect2(draw_x, draw_y, draw_w, draw_h), false)
	else:
		# Placeholder: big initial letter centered on the art
		var initial: String = soul.name.left(1).to_upper()
		var fs: int = 40
		var iw: float = _font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_view.draw_string(_font,
			Vector2(int(art_rect.get_center().x - iw * 0.5),
					int(art_rect.get_center().y + float(fs) * 0.35)),
			initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			slot_col.lightened(0.5))

	# ── Divider below art ─────────────────────────────────────────
	var div_y: int = art_y + art_h + 3
	_view.draw_line(Vector2(x + 4, div_y), Vector2(x + w - 4, div_y), SC_BORDER_I, 1.0)

	# ── Slot label row ────────────────────────────────────────────
	var label_y: int = div_y + 10
	_view.draw_string(_font,
		Vector2(x + 6, label_y),
		"SOUL  —  " + soul.slot.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, slot_col.lightened(0.3))

	# ── Description / effect text ─────────────────────────────────
	var desc_y: float = float(label_y + 12)
	_str_wrap_ml(x + 6, desc_y, soul.description, w - 12, 8, SC_MUTED)

	# ── Footer strip ──────────────────────────────────────────────
	var footer_y: int = y + h - 18
	_view.draw_rect(Rect2(x + 4, footer_y, w - 8, 14), SC_FT_BG)
	_view.draw_line(Vector2(x + 4, footer_y), Vector2(x + w - 4, footer_y), SC_BORDER_I, 1.0)

	# Qty badge on footer right
	var qty_str: String = "x%d" % qty
	var qty_w: float = _font.get_string_size(qty_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_view.draw_string(_font,
		Vector2(int(float(x + w) - qty_w - 7.0), footer_y + 11),
		qty_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		C_GOLD if qty >= 99 else SC_MUTED)

	_view.draw_string(_font, Vector2(x + 7, footer_y + 11),
		"SOUL ITEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, SC_MUTED)


func _draw_hints() -> void:
	_view.draw_line(Vector2(LIST_X0, H - 30), Vector2(LIST_X1, H - 30), C_DIV, 1.0)
	_str(LIST_X0, H - 14, "UP/DOWN  X:equip  Z:unequip  ESC:back", 9, C_MUTED)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _slot_col(slot: String) -> Color:
	match slot:
		"red":   return C_RED
		"blue":  return C_BLUE
		"green": return C_GREEN
	return C_MUTED


func _equipped_id_for(slot: String) -> String:
	match slot:
		"red":   return Global.equipped_soul_red
		"blue":  return Global.equipped_soul_blue
		"green": return Global.equipped_soul_green
	return ""


func _str(x: int, y: int, text: String, fs: int, col: Color) -> void:
	_view.draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _str_wrap_ml(x: int, y: float, text: String, max_w: int, fs: int, col: Color) -> void:
	var line: String = ""
	var cy: float = y + float(fs)
	for word: String in text.split(" "):
		var test: String = (line + " " + word).strip_edges()
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= float(max_w):
			line = test
		else:
			if line != "":
				_view.draw_string(_font, Vector2(x, int(cy)), line,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
				cy += float(fs) + 2.0
			line = word
	if line != "":
		_view.draw_string(_font, Vector2(x, int(cy)), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func request_back() -> void:
	back_requested.emit()
