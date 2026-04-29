## Figma zoom card (165×230) — pixel-identical to `CardBattle._draw_zoomed_card`.
class_name CardZoomDraw
extends RefCounted

const ZOOM_W: float = 165.0
const ZOOM_H: float = 230.0


static func draw(ci: CanvasItem, font: Font, rect: Rect2, card: Dictionary, state: Dictionary = {}) -> void:
	if font == null:
		return
	var cr: Rect2 = rect
	var is_dem: bool = card.get("type", "demon") == "demon"
	ci.draw_rect(cr, CardBattleConstants.C_DEMON_BG if is_dem else CardBattleConstants.C_SPELL_BG)
	_border(ci, cr, CardBattleConstants.C_MINI_BORDER, 2)

	_str_wrap(ci, font, card.get("name", ""), cr.position.x + 6.0, cr.position.y + 6.0,
		cr.size.x - 30.0, 12, CardBattleConstants.C_TEXT)

	_draw_cost_badge_rect(ci, font, Rect2(cr.position.x + cr.size.x - 22.0, cr.position.y + 2.0, 20.0, 19.0),
		card.get("cost", 0))

	var art := Rect2(cr.position.x + 18.0, cr.position.y + 30.0, 128.0, 128.0)
	var ztex: Texture2D = CardArt.card_art_2x(str(card.get("id", "")), card.get("foil", false))
	if ztex != null:
		ci.draw_texture_rect(ztex, art, false)

	_draw_rarity_jewel(ci, cr, card)

	var ab_desc: String = str(card.get("ability_desc", card.get("desc", "")))
	if ab_desc != "":
		_str_wrap_ml(ci, font, ab_desc, cr.position.x + 6.0, cr.position.y + 162.0,
			cr.size.x - 12.0, 7, CardBattleConstants.C_TEXT)

	if is_dem:
		_str(ci, font, "DEMON - %s" % str(card.get("subtype", "neutra")).to_upper(),
			cr.position.x + 7.0, cr.position.y + 216.0, 7, CardBattleConstants.C_MUTED)
	else:
		_str_c(ci, font, "SPELL", cr.get_center().x, cr.position.y + 216.0, 7, Color(0.24, 0.40, 0.08))

	if is_dem:
		var max_hp: int = card.get("hp", 1)
		var cur_hp: int = state.get("hp", max_hp) if not state.is_empty() else max_hp
		var atk_v: int = state.get("atk", card.get("atk", 0)) if not state.is_empty() else card.get("atk", 0)
		var exzoom: bool = state.get("exhausted", false) if not state.is_empty() else false
		_str_r_atk_hp(ci, font, atk_v, cur_hp, max_hp, cr.position.x + cr.size.x - 6.0, cr.position.y + 203.0, 12, exzoom)


static func _border(ci: CanvasItem, r: Rect2, col: Color, w: int) -> void:
	var x: int = int(r.position.x); var y: int = int(r.position.y)
	var rw: int = int(r.size.x);    var rh: int = int(r.size.y)
	ci.draw_rect(Rect2(x,          y,          rw, w),          col)
	ci.draw_rect(Rect2(x,          y + rh - w, rw, w),          col)
	ci.draw_rect(Rect2(x,          y + w,      w,  rh - w * 2), col)
	ci.draw_rect(Rect2(x + rw - w, y + w,      w,  rh - w * 2), col)


static func _tx(x: float) -> int:
	return int(floor(x))


static func _fs(sz: int) -> int:
	return maxi(sz, CardBattleConstants.FONT_MIN)


static func _mix_white(c: Color, t: float) -> Color:
	var u: float = 1.0 - t
	return Color(c.r * t + u, c.g * t + u, c.b * t + u)


## Rarity jewel PNG — pixel position x:147, y:139 relative to card top-left.
static var _jewel_cache: Dictionary = {}

static func _jewel_tex(rarity: String) -> Texture2D:
	if _jewel_cache.has(rarity):
		return _jewel_cache[rarity]
	var path: String
	match rarity:
		"legendary": path = "res://assets/ui parts/jewel rarity-legendary.png"
		"epic", "mythic": path = "res://assets/ui parts/jewel rarity-epic.png"
		"rare": path = "res://assets/ui parts/jewel rarity rare.png"
		_: path = "res://assets/ui parts/jewel rarity-common.png"
	var tex: Texture2D = load(path) as Texture2D
	_jewel_cache[rarity] = tex
	return tex

static func _draw_rarity_jewel(ci: CanvasItem, cr: Rect2, card: Dictionary) -> void:
	var rarity: String = str(card.get("rarity", "common"))
	var tex: Texture2D = _jewel_tex(rarity)
	if tex == null:
		return
	ci.draw_texture(tex, Vector2(int(cr.position.x + 147.0), int(cr.position.y + 139.0)))


static func _draw_cost_badge_rect(ci: CanvasItem, font: Font, r: Rect2, cost: int) -> void:
	var x: int = int(floor(r.position.x))
	var y: int = int(floor(r.position.y))
	var w: int = maxi(1, int(floor(r.size.x)))
	var h: int = maxi(1, int(floor(r.size.y)))
	ci.draw_rect(r, CardBattleConstants.C_COST_BADGE)
	_border(ci, r, CardBattleConstants.C_BLACK, 1)
	var fs: int = clampi(mini(w, h) - 4, CardBattleConstants.FONT_MIN, 12)
	var s: String = str(cost)
	var tw: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline: float = float(y + h) - 3.0
	ci.draw_string(font, Vector2(float(x) + (float(w) - tw) * 0.5, baseline),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CardBattleConstants.C_TEXT_LT)


static func _str(ci: CanvasItem, font: Font, text: String, x: float, y: float, sz: int, color: Color) -> void:
	var fs: int = _fs(sz)
	ci.draw_string(font, Vector2(_tx(x), _tx(y + float(fs))), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


static func _str_c(ci: CanvasItem, font: Font, text: String, cx: float, cy: float, sz: int, color: Color) -> void:
	var fs: int = _fs(sz)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, Vector2(_tx(cx - tw * 0.5), _tx(cy + float(fs) * 0.5)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


static func _str_wrap(ci: CanvasItem, font: Font, text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var fs: int = _fs(sz)
	var l1: String = ""
	var l2: String = ""
	for word in text.split(" "):
		var test: String = (l1 + " " + word).strip_edges()
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			l1 = test
		else:
			l2 = (l2 + " " + word).strip_edges()
	ci.draw_string(font, Vector2(_tx(x), _tx(y + float(fs))), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	if l2 != "":
		var s: String = l2 if font.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w \
				else l2.left(l2.length() - 2) + ".."
		ci.draw_string(font, Vector2(_tx(x), _tx(y + float(fs) * 2.0 + 2.0)), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


static func _str_wrap_ml(ci: CanvasItem, font: Font, text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var fs: int = _fs(sz)
	var line: String = ""
	var cy: float = y + float(fs)
	for word in text.split(" "):
		var test: String = (line + " " + word).strip_edges()
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			line = test
		else:
			if line != "":
				ci.draw_string(font, Vector2(_tx(x), _tx(cy)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
				cy += float(fs) + 2.0
			line = word
	if line != "":
		ci.draw_string(font, Vector2(_tx(x), _tx(cy)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


static func _str_r_atk_hp(ci: CanvasItem, font: Font, atk_v: int, cur_hp: int, max_hp: int, rx: float, y: float, sz: int, exhausted: bool) -> void:
	var fs: int = _fs(sz)
	var part_a: String = str(atk_v) + "/"
	var part_b: String = str(cur_hp)
	var w1: float = font.get_string_size(part_a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2: float = font.get_string_size(part_b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0: float = rx - (w1 + w2)
	var baseline: float = y + float(fs)
	var atk_col: Color = CardBattleConstants.C_EXHAUST_TEXT if exhausted else CardBattleConstants.C_TEXT
	var hp_col: Color = CardBattleConstants.C_EXHAUST_TEXT if exhausted else (CardBattleConstants.C_HP_RED if cur_hp < max_hp else CardBattleConstants.C_TEXT)
	ci.draw_string(font, Vector2(_tx(x0), _tx(baseline)), part_a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, atk_col)
	ci.draw_string(font, Vector2(_tx(x0 + w1), _tx(baseline)), part_b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hp_col)
