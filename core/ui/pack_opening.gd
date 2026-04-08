## Pokemon Pocket–style pack opening overlay.
## Triggered by UI. Emits `finished` when player collects the cards.
class_name PackOpening
extends CanvasLayer

signal finished

# ── Layout (640 × 576) ──────────────────────────────────────────────
const W: int = 640
const H: int = 576
const CARD_W: int = 79
const CARD_H: int = 110
const CARD_GAP: int = 10
const CARDS_TOTAL: int = 5
const PACK_ART: Texture2D = preload("res://Group 80.png")

# Positions for 5 revealed cards, centered horizontally
const _ROW_Y: int = 210
static func _card_x(i: int) -> int:
	var total: int = CARDS_TOTAL * CARD_W + (CARDS_TOTAL - 1) * CARD_GAP
	return (W - total) / 2 + i * (CARD_W + CARD_GAP)

# ── Colours ──────────────────────────────────────────────────────────
const C_BG: Color        = Color(0.06, 0.04, 0.12, 0.97)
const C_CARD_BACK: Color = Color(0.15, 0.10, 0.30)
const C_BACK_BORDER: Color = Color(0.5, 0.3, 0.9)
const C_FOIL_SHIMMER: Color = Color(0.9, 0.8, 0.2)
const C_LEGENDARY_GLO: Color = Color(1.0, 0.35, 0.0)
const C_MYTHIC_GLO: Color = Color(0.45, 0.22, 1.0)
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

# ── Rarity colours (matches CardBattleConstants) ─────────────────────
const RARITY_COL: Dictionary = {
	"common"   : Color("#7C7C7C"),
	"uncommon" : Color("#0257F7"),
	"rare"     : Color("#0257F7"),
	"mythic"   : Color("#6844FC"),
	"legendary": Color("#F83902"),
}

# ── State ────────────────────────────────────────────────────────────
enum _State { IDLE, PACK_SHOW, OPENING, REVEAL, DONE }
var _state: _State = _State.IDLE
var _pack_cards: Array = []
var _revealed_count: int = 0
var _animating: bool = false

# Visual state
var _pack_scale: float = 1.0
var _pack_alpha: float = 1.0
var _pack_shake_x: float = 0.0
var _card_scale_x: Array = [1.0, 1.0, 1.0, 1.0, 1.0]
var _card_face_visible: Array = [false, false, false, false, false]
var _particle_lists: Array = [[], [], [], [], []]   ## per-card particles
var _pack_y_off: float = 0.0

var _view: Control
var _font: Font
var _hint_text: String = "TAP TO OPEN"
var _hint_alpha: float = 1.0


func _ready() -> void:
	layer = 20
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


## Call this to start a pack opening. Deducts cost from rupies.
func open_pack() -> void:
	if not Global.spend_rupies(Global.PACK_COST):
		return
	_pack_cards = CardDB.roll_pack()
	_revealed_count = 0
	_animating = false
	_pack_scale = 0.5
	_pack_alpha = 0.0
	_pack_y_off = 0.0
	_hint_text = "TAP TO OPEN"
	_hint_alpha = 1.0
	for i in CARDS_TOTAL:
		_card_scale_x[i] = 1.0
		_card_face_visible[i] = false
		_particle_lists[i] = []
	_state = _State.PACK_SHOW
	show()
	_view.grab_focus()
	_view.queue_redraw()
	# Animate pack appearing
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "_pack_scale", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "_pack_alpha", 1.0, 0.25)


func _process(_dt: float) -> void:
	if _state == _State.IDLE:
		return
	_tick_particles()
	_view.queue_redraw()


func _tick_particles() -> void:
	for i in CARDS_TOTAL:
		var live: Array = []
		for p in _particle_lists[i]:
			p["life"] -= 0.016
			p["x"] += p["vx"]
			p["y"] += p["vy"]
			p["vy"] += 0.04
			if p["life"] > 0.0:
				live.append(p)
		_particle_lists[i] = live


func _spawn_particles(card_idx: int, is_foil: bool, is_legendary: bool, is_mythic: bool) -> void:
	var cx: float = float(_card_x(card_idx)) + CARD_W * 0.5
	var cy: float = float(_ROW_Y) + CARD_H * 0.5
	var count: int = 40 if (is_legendary or is_mythic) else 20
	for _i in count:
		var angle: float = randf() * TAU
		var speed: float = randf_range(0.5, 2.5)
		var col: Color
		if is_legendary:
			col = Color(1.0, randf_range(0.2, 0.6), 0.0)
		elif is_mythic:
			col = Color(randf_range(0.5, 1.0), randf_range(0.2, 0.4), 1.0)
		elif is_foil:
			col = Color(randf_range(0.7, 1.0), randf_range(0.7, 1.0), randf_range(0.3, 1.0))
		else:
			col = Color.WHITE
		_particle_lists[card_idx].append({
			"x": cx + randf_range(-10.0, 10.0),
			"y": cy + randf_range(-10.0, 10.0),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - 1.5,
			"life": randf_range(0.5, 1.2),
			"size": randf_range(1.5, 4.0),
			"col": col,
		})


func _on_input(event: InputEvent) -> void:
	if _animating:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_tap()
	elif event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed and (ek.keycode == KEY_SPACE or ek.keycode == KEY_ENTER or ek.keycode == KEY_Z):
			_handle_tap()


func _handle_tap() -> void:
	match _state:
		_State.PACK_SHOW:
			_do_open_animation()
		_State.REVEAL:
			if _revealed_count < CARDS_TOTAL:
				_reveal_next_card()
			else:
				_state = _State.DONE
				_hint_text = "COLLECT"
		_State.DONE:
			_collect_all()


func _do_open_animation() -> void:
	_animating = true
	_hint_text = ""
	var tw: Tween = create_tween()
	# Shake
	tw.tween_method(_shake_pack, 0.0, 1.0, 0.3)
	# Fly up and fade out
	tw.tween_property(self, "_pack_y_off", -300.0, 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_pack_alpha", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		_state = _State.REVEAL
		_hint_text = "TAP TO REVEAL"
		_animating = false
	)


func _shake_pack(t: float) -> void:
	_pack_shake_x = sin(t * 40.0) * 8.0 * (1.0 - t)
	_view.queue_redraw()


func _reveal_next_card() -> void:
	var idx: int = _revealed_count
	_animating = true
	_hint_text = ""
	# Flip: scale X to 0, flip to face, scale X back to 1
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void: _card_scale_x[idx] = v, 1.0, 0.0, 0.12)
	tw.tween_callback(func() -> void: _card_face_visible[idx] = true)
	tw.tween_method(func(v: float) -> void: _card_scale_x[idx] = v, 0.0, 1.0, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var card: Dictionary = _pack_cards[idx]
		var is_foil: bool = card.get("foil", false)
		var rarity: String = card.get("rarity", "common")
		var is_leg: bool = rarity == "legendary"
		var is_myth: bool = rarity == "mythic"
		if is_foil or is_leg or is_myth:
			_spawn_particles(idx, is_foil, is_leg, is_myth)
		_revealed_count += 1
		if _revealed_count >= CARDS_TOTAL:
			_hint_text = "TAP TO COLLECT"
			_state = _State.DONE
		else:
			_hint_text = "TAP TO REVEAL"
		_animating = false
	)


func _collect_all() -> void:
	for card in _pack_cards:
		var id: String = str(card.get("id", ""))
		if id.is_empty():
			continue
		Global.collect_card(id, card.get("foil", false))
	_state = _State.IDLE
	hide()
	finished.emit()


# ── Drawing ──────────────────────────────────────────────────────────

func _on_draw() -> void:
	# Dark background
	_view.draw_rect(Rect2(0, 0, W, H), C_BG)

	if _state == _State.PACK_SHOW or _state == _State.OPENING or (_state == _State.REVEAL and _pack_alpha > 0.01):
		_draw_pack()

	if _state == _State.REVEAL or _state == _State.DONE:
		_draw_cards()

	_draw_hint()


func _draw_pack() -> void:
	var pack_w: float = float(PACK_ART.get_width()) * _pack_scale
	var pack_h: float = float(PACK_ART.get_height()) * _pack_scale
	var px: float = (W - pack_w) * 0.5 + _pack_shake_x
	var py: float = (H - pack_h) * 0.5 + _pack_y_off
	var mod: Color = Color(1.0, 1.0, 1.0, _pack_alpha)
	_view.draw_texture_rect(PACK_ART, Rect2(px, py, pack_w, pack_h), false, mod)


func _draw_cards() -> void:
	for i in CARDS_TOTAL:
		var cx: int = _card_x(i)
		var sx: float = _card_scale_x[i]
		var offset_x: float = CARD_W * (1.0 - sx) * 0.5
		var r: Rect2 = Rect2(cx + offset_x, _ROW_Y, CARD_W * sx, CARD_H)

		if not _card_face_visible[i]:
			_draw_card_back(r, sx)
		else:
			_draw_card_face(r, _pack_cards[i], sx)

		# Particles
		for p in _particle_lists[i]:
			var pc: Color = p["col"]
			pc.a = clampf(p["life"], 0.0, 1.0)
			_view.draw_circle(Vector2(p["x"], p["y"]), p["size"], pc)


func _draw_card_back(r: Rect2, _sx: float) -> void:
	_view.draw_rect(r, C_CARD_BACK)
	_view.draw_rect(r, C_BACK_BORDER, false, 2.0)
	# Simple pattern: small inner rectangle
	var inner: Rect2 = r.grow(-6.0)
	_view.draw_rect(inner, Color(0.25, 0.15, 0.45), false, 1.0)
	_draw_str_c("?", r.get_center().x, r.get_center().y - 6.0, 14, Color(0.6, 0.4, 0.9))


func _draw_card_face(r: Rect2, card: Dictionary, _sx: float) -> void:
	var is_dem: bool = card.get("type", "demon") == "demon"
	var rarity: String = card.get("rarity", "common")
	var is_foil: bool = card.get("foil", false)

	var bg_c: Color = Color(0.96, 0.89, 0.85) if is_dem else Color(0.63, 0.71, 0.40)
	if is_foil:
		# Slight golden tint for foil
		bg_c = bg_c.lerp(Color(1.0, 0.92, 0.5), 0.25)
	_view.draw_rect(r, bg_c)

	var border_c: Color = RARITY_COL.get(rarity, Color(0.49, 0.43, 0.0))
	if is_foil:
		border_c = Color(1.0, 0.85, 0.1)
	_view.draw_rect(r, border_c, false, 2.0)

	if is_foil:
		# Extra shimmer border (inner)
		var fi: Rect2 = r.grow(-3.0)
		_view.draw_rect(fi, Color(1.0, 0.95, 0.5, 0.6), false, 1.0)

	var nm: String = card.get("name", "")
	if nm.length() > 9:
		nm = nm.left(9) + "."
	_draw_str(nm, r.position.x + 4.0, r.position.y + 2.0, 8, Color(0.1, 0.05, 0.0))

	# Art area
	var art_r: Rect2 = Rect2(r.position.x + 6.0, r.position.y + 16.0, CARD_W - 12.0, 55.0)
	var art_bg: Color = Color(bg_c.r * 0.84, bg_c.g * 0.84, bg_c.b * 0.84)
	_view.draw_rect(art_r, art_bg)

	var card_id: String = str(card.get("id", ""))
	var art_tex: Texture2D = CardArt.card_art_2x(card_id, is_foil)
	if art_tex != null:
		_view.draw_texture_rect(art_tex, art_r, false)
	else:
		# No art: show type text
		var type_str: String = card.get("subtype", card.get("type", "")).to_upper()
		_draw_str_c(type_str, art_r.get_center().x, art_r.get_center().y - 5.0, 8, Color(0.3, 0.2, 0.1, 0.7))

	# Foil shimmer overlay (always shown on foil cards, on top of art)
	if is_foil:
		for row in 5:
			var sy: float = art_r.position.y + row * 11.0
			var fc: Color = Color(1.0, 0.9, 0.3, 0.12)
			_view.draw_rect(Rect2(art_r.position.x, sy, art_r.size.x, 5.0), fc)

	# Rarity dot
	_view.draw_circle(Vector2(r.position.x + CARD_W - 7.0, r.position.y + 8.0), 3.0, border_c)

	# Stats area
	var stats_y: float = r.position.y + 74.0
	if is_dem:
		var atk_str: String = str(card.get("atk", 0))
		var hp_str: String = str(card.get("hp", 0))
		_draw_str(atk_str, r.position.x + 4.0, stats_y, 8, Color(0.1, 0.05, 0.0))
		_draw_str_r(hp_str, r.position.x + CARD_W - 4.0, stats_y, 8, Color(0.7, 0.0, 0.0))
	else:
		_draw_str_c("SPELL", r.get_center().x, stats_y, 8, Color(0.24, 0.40, 0.08))

	# Ability
	var ab: String = card.get("ability_desc", "")
	if ab.length() > 0:
		var short: String = ab.left(24)
		if ab.length() > 24:
			short += "..."
		_draw_str_wrap(short, r.position.x + 3.0, r.position.y + 86.0, CARD_W - 6.0, 6, Color(0.1, 0.05, 0.0))

	# Cost badge
	var cost_r: Rect2 = Rect2(r.position.x, r.position.y + CARD_H - 19.0, 20.0, 19.0)
	_view.draw_rect(cost_r, Color(0.24, 0.12, 0.08))
	_draw_str_c(str(card.get("cost", 0)), cost_r.get_center().x, cost_r.position.y + 2.0, 10, Color.WHITE)

	# FOIL badge
	if is_foil:
		var fb: Rect2 = Rect2(r.position.x + CARD_W - 30.0, r.position.y + CARD_H - 14.0, 28.0, 12.0)
		_view.draw_rect(fb, Color(0.8, 0.65, 0.0))
		_draw_str_c("FOIL", fb.get_center().x, fb.position.y + 1.0, 7, Color(0.05, 0.02, 0.0))


func _draw_hint() -> void:
	if _hint_text.is_empty():
		return
	var tx: float = W * 0.5
	var ty: float = H - 28.0
	_draw_str_c(_hint_text, tx, ty, 10, Color(1.0, 1.0, 1.0, _hint_alpha))


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


func _draw_str_wrap(text: String, x: float, y: float, max_w: float, size: int, col: Color) -> void:
	if _font == null or text.is_empty():
		return
	# Simple word-wrap: split by space, add words until line overflows
	var words: Array = text.split(" ")
	var line: String = ""
	var ly: float = y
	for word in words:
		var test: String = line + ("" if line.is_empty() else " ") + word
		var tw: float = _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if tw > max_w and not line.is_empty():
			_draw_str(line, x, ly, size, col)
			ly += float(size) + 2.0
			line = word
		else:
			line = test
	if not line.is_empty():
		_draw_str(line, x, ly, size, col)
