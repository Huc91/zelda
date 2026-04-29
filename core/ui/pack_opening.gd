## Pokemon Pocket–style pack opening overlay.
## Triggered by UI. Emits `finished` when player collects the cards.
class_name PackOpening
extends CanvasLayer
const PixelFont = preload("res://core/ui/pixel_font.gd")

signal finished

# ── Layout (640 × 576) ──────────────────────────────────────────────
const W: int = 640
const H: int = 576
## Same as battle zoom (CardZoomDraw): 165×230
const CARD_W: int = int(CardZoomDraw.ZOOM_W)
const CARD_H: int = int(CardZoomDraw.ZOOM_H)
const CARD_GAP: int = 10
const CARDS_TOTAL: int = 5
const PACK_ART: Texture2D = preload("res://Group 80.png")

# Two rows: 3 + 2 battle zoom cards; fit in 576px height
const _ROW1_Y: int = 48
const _ROW2_Y: int = _ROW1_Y + CARD_H + 12


static func _row_origin_x(count: int) -> float:
	var total: float = float(count * CARD_W + maxi(0, count - 1) * CARD_GAP)
	return (float(W) - total) * 0.5


static func _card_rect(i: int) -> Rect2:
	if i < 3:
		var x0: float = _row_origin_x(3)
		return Rect2(x0 + float(i * (CARD_W + CARD_GAP)), float(_ROW1_Y), float(CARD_W), float(CARD_H))
	var x0b: float = _row_origin_x(2)
	var j: int = i - 3
	return Rect2(x0b + float(j * (CARD_W + CARD_GAP)), float(_ROW2_Y), float(CARD_W), float(CARD_H))

# ── Colours ──────────────────────────────────────────────────────────
const C_BG: Color        = Color(0.06, 0.04, 0.12)
const C_CARD_BACK: Color = Color(0.15, 0.10, 0.30)
const C_BACK_BORDER: Color = Color(0.5, 0.3, 0.9)
const C_FOIL_SHIMMER: Color = Color(0.9, 0.8, 0.2)
const C_LEGENDARY_GLO: Color = Color(1.0, 0.35, 0.0)
const C_MYTHIC_GLO: Color = Color(0.45, 0.22, 1.0)
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

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
var _card_alpha: Array = [1.0, 1.0, 1.0, 1.0, 1.0]
var _card_face_visible: Array = [false, false, false, false, false]
var _particle_lists: Array = [[], [], [], [], []]   ## per-card particles
var _pack_y_off: float = 0.0

var _view: Control
var _font: Font
var _hint_text: String = "CLICK TO OPEN"
var _hint_alpha: float = 1.0
var _legendary_flash: float = 0.0
var _foil_time: float = 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = PixelFont.nudge_orb()
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.focus_mode = Control.FOCUS_CLICK
	add_child(_view)
	_view.draw.connect(_on_draw)
	_view.gui_input.connect(_on_input)
	hide()


## Call this to start a pack opening. Requires one owned Base Set pack.
func open_pack() -> void:
	if not Global.consume_base_set_pack():
		return
	_pack_cards = CardDB.roll_pack()
	_revealed_count = 0
	_animating = false
	_pack_scale = 0.5
	_pack_alpha = 0.0
	_pack_y_off = 0.0
	_hint_text = "CLICK TO OPEN"
	_hint_alpha = 1.0
	for i in CARDS_TOTAL:
		_card_alpha[i] = 1.0
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


func _process(dt: float) -> void:
	if _state == _State.IDLE:
		return
	_tick_particles()
	if _legendary_flash > 0.0:
		_legendary_flash = maxf(0.0, _legendary_flash - dt * 2.0)
	_foil_time += dt
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
	var rr: Rect2 = _card_rect(card_idx)
	var cx: float = rr.position.x + rr.size.x * 0.5
	var cy: float = rr.position.y + rr.size.y * 0.5
	var count: int
	if is_legendary:
		count = 120
	elif is_mythic:
		count = 80
	elif is_foil:
		count = 40
	else:
		count = 20
	for _i in count:
		var angle: float = randf() * TAU
		var speed: float = randf_range(0.5, 3.5) if (is_legendary or is_mythic) else randf_range(0.5, 2.5)
		var col: Color
		if is_legendary:
			var r: float = randf()
			if r < 0.6:
				col = Color(1.0, randf_range(0.1, 0.5), 0.0)
			elif r < 0.85:
				col = Color(1.0, randf_range(0.5, 0.9), 0.0)
			else:
				col = Color(1.0, 1.0, randf_range(0.0, 0.3))
		elif is_mythic:
			col = Color(randf_range(0.5, 1.0), randf_range(0.2, 0.4), 1.0)
		elif is_foil:
			col = Color(randf_range(0.7, 1.0), randf_range(0.7, 1.0), randf_range(0.3, 1.0))
		else:
			col = Color.WHITE
		var life: float = randf_range(0.8, 2.0) if is_legendary else randf_range(0.5, 1.2)
		_particle_lists[card_idx].append({
			"x": cx + randf_range(-rr.size.x * 0.4, rr.size.x * 0.4),
			"y": cy + randf_range(-rr.size.y * 0.4, rr.size.y * 0.4),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - 2.0 if is_legendary else sin(angle) * speed - 1.5,
			"life": life,
			"size": randf_range(2.0, 6.0) if is_legendary else randf_range(1.5, 4.0),
			"col": col,
		})


func _on_input(event: InputEvent) -> void:
	if _animating:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
	elif event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed and (ek.keycode == KEY_SPACE or ek.keycode == KEY_ENTER or ek.keycode == KEY_Z):
			_handle_click(null)


func _handle_click(click_pos: Variant) -> void:
	match _state:
		_State.PACK_SHOW:
			_do_open_animation()
		_State.REVEAL:
			var target: int = -1
			if click_pos == null:
				target = _next_unrevealed()
			else:
				var hit: int = -1
				for i in CARDS_TOTAL:
					if _card_rect(i).has_point(click_pos):
						hit = i; break
				if hit >= 0:
					if not _card_face_visible[hit]:
						target = hit
					# already revealed — do nothing
				else:
					target = _next_unrevealed()
			if target >= 0:
				_reveal_card(target)
		_State.DONE:
			_collect_all()


func _next_unrevealed() -> int:
	for i in CARDS_TOTAL:
		if not _card_face_visible[i]:
			return i
	return -1


func _do_open_animation() -> void:
	_animating = true
	_hint_text = ""
	Sound.play(preload("res://data/sfx/Sword_Slash.wav"))
	var tw: Tween = create_tween()
	# Shake
	tw.tween_method(_shake_pack, 0.0, 1.0, 0.3)
	# Fly up and fade out
	tw.tween_property(self, "_pack_y_off", -300.0, 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_pack_alpha", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		_state = _State.REVEAL
		_hint_text = "CLICK TO REVEAL"
		_animating = false
	)


func _shake_pack(t: float) -> void:
	_pack_shake_x = sin(t * 40.0) * 8.0 * (1.0 - t)
	_view.queue_redraw()


func _reveal_card(idx: int) -> void:
	if _card_face_visible[idx]: return
	_animating = true
	_hint_text = ""
	_card_face_visible[idx] = true
	_card_alpha[idx] = 0.0
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void: _card_alpha[idx] = v, 0.0, 1.0, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var card: Dictionary = _pack_cards[idx]
		var is_foil: bool = card.get("foil", false)
		var rarity: String = card.get("rarity", "common")
		var is_leg: bool = rarity == "legendary"
		var is_myth: bool = rarity == "mythic"
		var is_epic: bool = rarity == "epic"
		if is_foil or is_leg or is_myth or is_epic:
			_spawn_particles(idx, is_foil, is_leg, is_myth)
		if is_leg or is_foil:
			Sound.play(preload("res://data/sfx/to use/1up.wav"))
		elif is_epic or is_myth:
			Sound.play(preload("res://data/sfx/to use/gem.wav"))
		if is_leg:
			_legendary_flash = 1.0
		_revealed_count += 1
		if _revealed_count >= CARDS_TOTAL:
			_hint_text = "CLICK TO COLLECT"
			_state = _State.DONE
		else:
			_hint_text = "CLICK TO REVEAL"
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

	# Legendary flash overlay
	if _legendary_flash > 0.0:
		var fa: float = _legendary_flash * 0.55
		_view.draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.4, 0.0, fa))

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
		var r: Rect2 = _card_rect(i)

		if not _card_face_visible[i]:
			_draw_card_back(r)
		else:
			CardZoomDraw.draw(_view, _font, r, _pack_cards[i], {})
			if _card_alpha[i] < 1.0:
				_view.draw_rect(r, Color(C_BG.r, C_BG.g, C_BG.b, 1.0 - _card_alpha[i]))
			# Foil shimmer: rainbow sweep overlay
			if _pack_cards[i].get("foil", false):
				_draw_foil_shimmer(r)

		# Particles
		for p in _particle_lists[i]:
			var pc: Color = p["col"]
			pc.a = clampf(p["life"], 0.0, 1.0)
			_view.draw_circle(Vector2(p["x"], p["y"]), p["size"], pc)


func _draw_foil_shimmer(r: Rect2) -> void:
	# Animated diagonal rainbow sweep
	var t: float = _foil_time * 1.2
	var sweep: float = fmod(t, 2.0) / 2.0  # 0..1 cycling
	# Draw 3 thin diagonal color bands sweeping across the card
	for band in 3:
		var off: float = sweep + float(band) * 0.33
		off = fmod(off, 1.0)
		var hue: float = fmod(t * 0.3 + float(band) * 0.33, 1.0)
		var band_col: Color = Color.from_hsv(hue, 0.7, 1.0, 0.18)
		# Clip to card bounds by drawing a thin parallelogram approximated as a rect strip
		var bx: float = r.position.x + off * (r.size.x + r.size.y) - r.size.y * 0.5
		var stripe_w: float = r.size.x * 0.18
		var strip_r := Rect2(bx, r.position.y, stripe_w, r.size.y)
		# Intersect with card rect
		var clipped := r.intersection(strip_r)
		if not clipped.has_area():
			continue
		_view.draw_rect(clipped, band_col)
	# Sparkle dots
	var sparkle_seed: int = int(_foil_time * 8.0)
	for s in 6:
		var sx: float = r.position.x + float((sparkle_seed * 37 + s * 113) % int(r.size.x))
		var sy: float = r.position.y + float((sparkle_seed * 73 + s * 59) % int(r.size.y))
		var salpha: float = absf(sin(_foil_time * 3.0 + float(s)))
		var shue: float = fmod(_foil_time * 0.5 + float(s) * 0.16, 1.0)
		_view.draw_circle(Vector2(sx, sy), 2.0, Color.from_hsv(shue, 0.5, 1.0, salpha * 0.8))


func _draw_card_back(r: Rect2) -> void:
	_view.draw_rect(r, C_CARD_BACK)
	_view.draw_rect(r, C_BACK_BORDER, false, 2.0)
	# Simple pattern: small inner rectangle
	var inner: Rect2 = r.grow(-6.0)
	_view.draw_rect(inner, Color(0.25, 0.15, 0.45), false, 1.0)
	_draw_str_c("?", r.get_center().x, r.get_center().y - 6.0, 14, Color(0.6, 0.4, 0.9))


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
