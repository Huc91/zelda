class_name SoulInventory extends CanvasLayer

const SoulItem = preload("res://core/soul_item.gd")
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

## Draw in the same 640×576 screen space as DialogueBox.
const W: int = 640
const H: int = 576

const BG_COL:  Color = Color(0.08, 0.06, 0.12)
const BORDER:  Color = Color(0.0,  0.0,  0.0)
const C_TEXT:  Color = Color(1.0,  1.0,  1.0)
const C_MUTED: Color = Color(0.55, 0.55, 0.55)
const C_SEL:   Color = Color(0.9,  0.85, 0.2)
const C_RED:   Color = Color(0.8,  0.1,  0.1)
const C_BLUE:  Color = Color(0.1,  0.3,  0.8)
const C_GREEN: Color = Color(0.1,  0.7,  0.2)
const C_EMPTY: Color = Color(0.25, 0.25, 0.25)

const SLOT_LABELS: Array = ["Red", "Blue", "Green"]
const SLOT_KEYS:   Array = ["red", "blue", "green"]
const SLOT_COLS:   Array = [Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.8), Color(0.1, 0.7, 0.2)]

## Slot card size in screen pixels
const SLOT_W:   int = 120
const SLOT_H:   int = 48
const SLOT_PAD: int = 16
const SLOT_Y:   int = 48

## Collection list
const LIST_Y0:    int = 140
const ENTRY_H:    int = 28
const VISIBLE_ROWS: int = 12

var _list: Array[String] = []
var _cursor: int = 0
var _font: Font

signal closed

class _View extends Control:
	var b: SoulInventory
	func _draw() -> void:
		b._on_draw()
	func _process(_dt: float) -> void:
		b._handle_input()

var _view: _View


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_font = load(FONT_PATH) as Font
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
	elif Input.is_action_just_pressed("pause"):
		closed.emit()


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
		"red":
			if Global.equipped_soul_red == soul_id:
				Global.unequip_soul("red")
		"blue":
			if Global.equipped_soul_blue == soul_id:
				Global.unequip_soul("blue")
		"green":
			if Global.equipped_soul_green == soul_id:
				Global.unequip_soul("green")
	_view.queue_redraw()


func _on_draw() -> void:
	# Full-screen background
	_view.draw_rect(Rect2(0, 0, W, H), BG_COL)

	if _font == null:
		return

	# Title
	_view.draw_string(_font, Vector2(32, 32), "SOUL INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, C_TEXT)

	# ── Equipped slots ──────────────────────────────────────────
	var total_slots_w: int = 3 * SLOT_W + 2 * SLOT_PAD
	var slots_x0: int = (W - total_slots_w) / 2

	for i: int in 3:
		var sx: int = slots_x0 + i * (SLOT_W + SLOT_PAD)
		var sy: int = SLOT_Y
		var slot_key: String = SLOT_KEYS[i] as String
		var col: Color = SLOT_COLS[i] as Color
		var equipped: SoulItem = Global.get_equipped_soul(slot_key)

		# Border + fill
		_view.draw_rect(Rect2(sx - 2, sy - 2, SLOT_W + 4, SLOT_H + 4), BORDER)
		_view.draw_rect(Rect2(sx, sy, SLOT_W, SLOT_H), col if equipped != null else C_EMPTY)

		# Slot label (e.g. "RED SLOT")
		var label: String = (SLOT_LABELS[i] as String).to_upper() + " SLOT"
		_view.draw_string(_font, Vector2(sx + 6, sy + 14), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_TEXT)

		# Soul name or "empty"
		if equipped != null:
			_view.draw_string(_font, Vector2(sx + 6, sy + 34), equipped.name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_TEXT)
		else:
			_view.draw_string(_font, Vector2(sx + 6, sy + 34), "— empty —",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MUTED)

	# Divider
	_view.draw_line(Vector2(32, LIST_Y0 - 10), Vector2(W - 32, LIST_Y0 - 10), BORDER, 2.0)

	# Column headers
	_view.draw_string(_font, Vector2(60, LIST_Y0), "SOUL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MUTED)
	_view.draw_string(_font, Vector2(280, LIST_Y0), "SLOT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MUTED)
	_view.draw_string(_font, Vector2(420, LIST_Y0), "STATUS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_MUTED)

	# ── Soul collection list ────────────────────────────────────
	var list_y: int = LIST_Y0 + 20

	if _list.is_empty():
		_view.draw_string(_font, Vector2(60, list_y + 12), "No souls collected yet.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_MUTED)
	else:
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

			# Selection bar
			if is_sel:
				_view.draw_rect(Rect2(36, ey - 4, W - 72, ENTRY_H - 2), Color(0.2, 0.18, 0.35))

			# Slot color dot
			var dot_col: Color = C_RED if soul.slot == "red" else (C_BLUE if soul.slot == "blue" else C_GREEN)
			_view.draw_rect(Rect2(46, ey + 4, 8, 8), dot_col)

			# Name
			_view.draw_string(_font, Vector2(60, ey + 14), soul.name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_SEL if is_sel else C_TEXT)

			# Slot
			_view.draw_string(_font, Vector2(280, ey + 14), soul.slot.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dot_col)

			# Equipped status
			var slot_key2: String = soul.slot
			var equipped_id: String = ""
			match slot_key2:
				"red":   equipped_id = Global.equipped_soul_red
				"blue":  equipped_id = Global.equipped_soul_blue
				"green": equipped_id = Global.equipped_soul_green
			var status: String = "EQUIPPED" if equipped_id == soul_id else "owned"
			var status_col: Color = C_GREEN if equipped_id == soul_id else C_MUTED
			_view.draw_string(_font, Vector2(420, ey + 14), status,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, status_col)

	# ── Hints ───────────────────────────────────────────────────
	_view.draw_line(Vector2(32, H - 40), Vector2(W - 32, H - 40), BORDER, 2.0)
	_view.draw_string(_font, Vector2(32, H - 18),
		"UP/DOWN: navigate    X: equip    Z: unequip    I: cards    Esc: close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_MUTED)
