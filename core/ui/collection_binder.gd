## Collection binder: shows all cards in the Base Set, ordered by card number.
## Empty slots visible. Foil slots shown to the right of each normal slot.
class_name CollectionBinder
extends CanvasLayer

# ── Layout ────────────────────────────────────────────────────────────
const W: int = 640
const H: int = 576
const CARD_W: int = 52
const CARD_H: int = 72
const CARD_GAP_X: int = 6
const CARD_GAP_Y: int = 8
const COLS: int = 8          ## normal + foil pairs per row = 4 pairs
const START_X: int = 12
const START_Y: int = 52
const HEADER_H: int = 44
const FOIL_GAP: int = 3      ## gap between normal and foil slot
const PAIR_GAP: int = 12     ## gap between pairs

const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

const RARITY_COL: Dictionary = {
	"common"   : Color("#7C7C7C"),
	"uncommon" : Color("#0257F7"),
	"rare"     : Color("#F7A202"),
	"mythic"   : Color("#6844FC"),
	"legendary": Color("#F83902"),
}

const C_BG: Color        = Color(0.88, 0.88, 0.90)
const C_EMPTY: Color     = Color(0.70, 0.70, 0.72)
const C_EMPTY_BOR: Color = Color(0.55, 0.55, 0.58)
const C_FOIL_BOR: Color  = Color(1.0, 0.85, 0.1)
const C_HDR: Color       = Color(0.18, 0.12, 0.30)
const C_TEXT: Color      = Color(0.08, 0.04, 0.02)

# ── State ─────────────────────────────────────────────────────────────
var _view: Control
var _font: Font
var _scroll_y: float = 0.0
var _max_scroll: float = 0.0
## Ordered list of collectible card dicts (excludes tokens).
var _cards: Array = []

## Pair layout: each pair is {normal_x, foil_x, y, card_dict}
var _pairs: Array = []


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


func _build_layout() -> void:
	CardDB._ensure_init()
	_cards = []
	for c in CardDB.ALL_CARDS:
		var id: String = str(c.get("id", ""))
		if id.is_empty() or id.begins_with("token_"):
			continue
		_cards.append(c)
	# Sort by id
	_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	# Build pairs layout: 4 normal+foil pairs per row
	_pairs = []
	var pairs_per_row: int = 4
	var pair_w: int = CARD_W * 2 + FOIL_GAP
	var row_w: int = pairs_per_row * pair_w + (pairs_per_row - 1) * PAIR_GAP
	var x0: int = (W - row_w) / 2

	for i in _cards.size():
		var col: int = i % pairs_per_row
		var row: int = i / pairs_per_row
		var px: int = x0 + col * (pair_w + PAIR_GAP)
		var py: int = START_Y + row * (CARD_H + CARD_GAP_Y)
		_pairs.append({
			"normal_x": px,
			"foil_x": px + CARD_W + FOIL_GAP,
			"y": py,
			"card": _cards[i],
		})

	var total_rows: int = (_cards.size() + pairs_per_row - 1) / pairs_per_row
	var content_h: float = START_Y + total_rows * (CARD_H + CARD_GAP_Y) + 20.0
	_max_scroll = maxf(0.0, content_h - H)


func _process(_dt: float) -> void:
	if not visible:
		return
	_view.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed:
			if ek.keycode == KEY_ESCAPE or ek.keycode == KEY_TAB:
				hide()
			elif ek.keycode == KEY_UP or ek.keycode == KEY_W:
				_scroll_y = maxf(0.0, _scroll_y - 30.0)
			elif ek.keycode == KEY_DOWN or ek.keycode == KEY_S:
				_scroll_y = minf(_max_scroll, _scroll_y + 30.0)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_y = maxf(0.0, _scroll_y - 24.0)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_y = minf(_max_scroll, _scroll_y + 24.0)


func _on_draw() -> void:
	# Background
	_view.draw_rect(Rect2(0, 0, W, H), C_BG)

	# Header
	_view.draw_rect(Rect2(0, 0, W, HEADER_H), C_HDR)
	_draw_str_c("BASE SET COLLECTION", W * 0.5, 6, 12, Color.WHITE)
	# Rupies display
	_draw_str("Rupies: %d" % Global.rupies, 12, 24, 9, Color(1.0, 0.9, 0.3))
	# Total owned
	var total_owned: int = 0
	for c in _cards:
		var id: String = str(c.get("id", ""))
		if Global.card_collection.get(id, 0) > 0 or Global.foil_collection.get(id, 0) > 0:
			total_owned += 1
	_draw_str_r("%d / %d" % [total_owned, _cards.size()], W - 12, 6, 9, Color(0.85, 0.85, 0.85))
	_draw_str_r("ESC to close", W - 12, 20, 8, Color(0.7, 0.7, 0.7))

	# Clip scroll region
	_view.draw_rect(Rect2(0, HEADER_H, W, H - HEADER_H), C_BG)

	# Cards
	for p in _pairs:
		var card: Dictionary = p["card"]
		var ny: float = float(p["y"]) - _scroll_y
		if ny + CARD_H < HEADER_H or ny > H:
			continue
		var id: String = str(card.get("id", ""))
		var owned_normal: int = Global.card_collection.get(id, 0)
		var owned_foil: int = Global.foil_collection.get(id, 0)
		_draw_card_slot(float(p["normal_x"]), ny, card, owned_normal, false)
		_draw_card_slot(float(p["foil_x"]), ny, card, owned_foil, true)

	# Scroll indicator
	if _max_scroll > 0.0:
		var track_h: float = H - HEADER_H - 4.0
		var thumb_h: float = maxf(20.0, track_h * (H / (_max_scroll + H)))
		var thumb_y: float = HEADER_H + 2.0 + (_scroll_y / _max_scroll) * (track_h - thumb_h)
		_view.draw_rect(Rect2(W - 5.0, HEADER_H + 2.0, 3.0, track_h), Color(0.7, 0.7, 0.7))
		_view.draw_rect(Rect2(W - 5.0, thumb_y, 3.0, thumb_h), Color(0.3, 0.3, 0.4))


func _draw_card_slot(x: float, y: float, card: Dictionary, owned: int, is_foil: bool) -> void:
	var r: Rect2 = Rect2(x, y, CARD_W, CARD_H)
	var rarity: String = card.get("rarity", "common")
	var border_c: Color = RARITY_COL.get(rarity, C_EMPTY_BOR)
	if is_foil:
		border_c = C_FOIL_BOR

	if owned <= 0:
		# Empty slot
		_view.draw_rect(r, C_EMPTY)
		_view.draw_rect(r, C_EMPTY_BOR, false, 1.0)
		# Small "?" or foil indicator
		if is_foil:
			_draw_str_c("✦", x + CARD_W * 0.5, y + CARD_H * 0.5 - 6.0, 10, Color(0.7, 0.7, 0.7))
		else:
			_draw_str_c("?", x + CARD_W * 0.5, y + CARD_H * 0.5 - 6.0, 10, Color(0.65, 0.65, 0.65))
		return

	# Owned card
	var is_dem: bool = card.get("type", "demon") == "demon"
	var bg_c: Color = Color(0.96, 0.89, 0.85) if is_dem else Color(0.63, 0.71, 0.40)
	if is_foil:
		bg_c = bg_c.lerp(Color(1.0, 0.92, 0.5), 0.3)
	_view.draw_rect(r, bg_c)
	_view.draw_rect(r, border_c, false, 1.0)

	# Art
	var id: String = str(card.get("id", ""))
	var art_tex: Texture2D = CardArt.card_art_1x(id, is_foil)
	var art_r: Rect2 = Rect2(x + 2.0, y + 12.0, CARD_W - 4.0, CARD_H - 28.0)
	if art_tex != null:
		_view.draw_texture_rect(art_tex, art_r, false)
	else:
		_view.draw_rect(art_r, Color(bg_c.r * 0.82, bg_c.g * 0.82, bg_c.b * 0.82))

	# Name
	var nm: String = card.get("name", "")
	if nm.length() > 7:
		nm = nm.left(7) + "."
	_draw_str(nm, x + 2.0, y + 1.0, 6, C_TEXT)

	# Rarity dot
	_view.draw_circle(Vector2(x + CARD_W - 4.0, y + 5.0), 2.0, border_c)

	# Count badge if >1
	if owned > 1:
		var badge_r: Rect2 = Rect2(x + CARD_W - 13.0, y + CARD_H - 11.0, 12.0, 10.0)
		_view.draw_rect(badge_r, Color(0.1, 0.1, 0.1, 0.75))
		_draw_str_c("x%d" % owned, x + CARD_W - 7.0, y + CARD_H - 11.0, 7, Color.WHITE)

	# ATK/HP for demons
	if is_dem:
		_draw_str("%d/%d" % [card.get("atk", 0), card.get("hp", 0)],
			x + 2.0, y + CARD_H - 11.0, 6, C_TEXT)

	# FOIL label
	if is_foil:
		_draw_str_c("FOIL", x + CARD_W * 0.5, y + CARD_H - 11.0, 6, C_FOIL_BOR)

	# Foil shimmer lines overlay
	if is_foil:
		for fi in 3:
			var fy: float = y + 12.0 + fi * 12.0
			_view.draw_rect(Rect2(x + 1.0, fy, CARD_W - 2.0, 3.0), Color(1.0, 0.9, 0.3, 0.12))


# ── Text helpers ──────────────────────────────────────────────────────

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
