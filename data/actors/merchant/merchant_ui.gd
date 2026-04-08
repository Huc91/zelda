## Merchant shop UI overlay.
class_name MerchantUI
extends CanvasLayer

signal closed

const W: int = 640
const H: int = 576
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"
const C_BG: Color       = Color(0.10, 0.07, 0.18, 0.96)
const C_HDR: Color      = Color(0.20, 0.12, 0.35)
const C_TEXT: Color     = Color.WHITE
const C_PRICE: Color    = Color(1.0, 0.9, 0.3)
const C_SELL: Color     = Color(0.4, 0.9, 0.4)
const C_DIM: Color      = Color(0.55, 0.55, 0.55)
const C_BTN: Color      = Color(0.35, 0.20, 0.55)
const C_BTN_SEL: Color  = Color(0.55, 0.35, 0.80)

## Stock entry: { "card_id": String, "price": int, "is_foil": bool }
var _stock: Array = []
## Sellable entries: { "card_id": String, "price": int, "is_foil": bool, "copies": int }
var _sellable: Array = []

var _view: Control
var _font: Font
var _tab: int = 0   ## 0 = buy, 1 = sell
var _sel: int = 0
var _merchant_type: String = "general"

## Scroll
var _scroll: int = 0
const ROWS_VISIBLE: int = 7
const ROW_H: int = 36
const LIST_Y: int = 90


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as Font
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.focus_mode = Control.FOCUS_CLICK
	add_child(_view)
	_view.draw.connect(_on_draw)
	_view.gui_input.connect(_on_input)
	_view.grab_focus()
	_view.queue_redraw()


func setup(merchant_type: String) -> void:
	_merchant_type = merchant_type
	_build_stock()
	_build_sellable()


func _build_stock() -> void:
	_stock = []
	CardDB._ensure_init()
	var all_ids: Array[String] = CardDB.all_collectible_ids()
	var pool: Array[String] = []

	match _merchant_type:
		"general":
			# Mix of commons/uncommons
			for id in all_ids:
				var r: String = str(CardDB.get_card(id).get("rarity", ""))
				if r in ["common", "uncommon"]:
					pool.append(id)
			pool.shuffle()
			pool = pool.slice(0, 8)
		"rare_hunter":
			# Rares + mythics
			for id in all_ids:
				var r: String = str(CardDB.get_card(id).get("rarity", ""))
				if r in ["rare", "mythic"]:
					pool.append(id)
			pool.shuffle()
			pool = pool.slice(0, 6)
		"spell_dealer":
			# Spells only
			for id in all_ids:
				if id.begins_with("spell_"):
					pool.append(id)
			pool.shuffle()
			pool = pool.slice(0, 8)

	for id in pool:
		var base_price: int = _single_price(CardDB.get_card(id))
		_stock.append({"card_id": id, "price": base_price, "is_foil": false})


func _build_sellable() -> void:
	_sellable = []
	for id in Global.card_collection.keys():
		var extra_normal: int = Global.sellable_copies(id, false)
		if extra_normal > 0:
			_sellable.append({
				"card_id": id,
				"price": Global.SELL_NORMAL,
				"is_foil": false,
				"copies": extra_normal,
			})
	for id in Global.foil_collection.keys():
		var extra_foil: int = Global.sellable_copies(id, true)
		if extra_foil > 0:
			_sellable.append({
				"card_id": id,
				"price": Global.SELL_FOIL,
				"is_foil": true,
				"copies": extra_foil,
			})


func _single_price(card: Dictionary) -> int:
	# Singles are expensive to incentivize pack opening
	var rarity: String = str(card.get("rarity", "common"))
	var base: int = Global.PACK_COST * Global.SINGLE_BUY_MULT / 5
	match rarity:
		"common":    return base
		"uncommon":  return base * 2
		"rare":      return base * 4
		"mythic":    return base * 8
		"legendary": return base * 20
	return base


func _current_list() -> Array:
	return _stock if _tab == 0 else _sellable


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed:
			match ek.keycode:
				KEY_ESCAPE, KEY_Q:
					_close()
				KEY_LEFT, KEY_A:
					_tab = 0
					_sel = 0
					_scroll = 0
					_view.queue_redraw()
				KEY_RIGHT, KEY_D:
					_tab = 1
					_sel = 0
					_scroll = 0
					_build_sellable()
					_view.queue_redraw()
				KEY_UP, KEY_W:
					_sel = maxi(0, _sel - 1)
					_clamp_scroll()
					_view.queue_redraw()
				KEY_DOWN, KEY_S:
					_sel = mini(_sel + 1, _current_list().size() - 1)
					_clamp_scroll()
					_view.queue_redraw()
				KEY_ENTER, KEY_SPACE, KEY_Z:
					_confirm()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_click(mb.position)


func _clamp_scroll() -> void:
	_scroll = clampi(_scroll, _sel - ROWS_VISIBLE + 1, _sel)
	_scroll = maxi(0, _scroll)


func _try_click(pos: Vector2) -> void:
	# Tab clicks
	if pos.y < 70 and pos.y > 52:
		if pos.x < W / 2:
			_tab = 0
		else:
			_tab = 1
		_sel = 0
		_scroll = 0
		if _tab == 1:
			_build_sellable()
		_view.queue_redraw()
		return
	# Row clicks
	var rel_y: float = pos.y - LIST_Y
	if rel_y >= 0:
		var clicked_row: int = int(rel_y / ROW_H) + _scroll
		var lst: Array = _current_list()
		if clicked_row < lst.size():
			if _sel == clicked_row:
				_confirm()
			else:
				_sel = clicked_row
			_view.queue_redraw()
	# Close button
	if pos.y > H - 36 and pos.x > W - 120:
		_close()


func _confirm() -> void:
	var lst: Array = _current_list()
	if _sel >= lst.size():
		return
	var entry: Dictionary = lst[_sel]

	if _tab == 0:
		# BUY
		var price: int = int(entry.get("price", 0))
		if not Global.spend_rupies(price):
			return
		var id: String = str(entry.get("card_id", ""))
		var foil: bool = bool(entry.get("is_foil", false))
		Global.collect_card(id, foil)
		Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
	else:
		# SELL
		var id: String = str(entry.get("card_id", ""))
		var foil: bool = bool(entry.get("is_foil", false))
		Global.sell_one_copy(id, foil)
		Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
		_build_sellable()
		_sel = mini(_sel, _sellable.size() - 1)
		if _sellable.is_empty():
			_sel = 0

	_view.queue_redraw()


func _close() -> void:
	queue_free()
	closed.emit()


func _on_draw() -> void:
	_view.draw_rect(Rect2(0, 0, W, H), C_BG)
	_view.draw_rect(Rect2(0, 0, W, 44), C_HDR)
	_draw_str_c("MERCHANT", W * 0.5, 4, 14, C_TEXT)
	_draw_str("Rupies: %d" % Global.rupies, 12, 22, 9, C_PRICE)

	# Tabs
	var buy_col: Color  = C_BTN_SEL if _tab == 0 else C_BTN
	var sell_col: Color = C_BTN_SEL if _tab == 1 else C_BTN
	_view.draw_rect(Rect2(0, 46, W / 2, 22), buy_col)
	_view.draw_rect(Rect2(W / 2, 46, W / 2, 22), sell_col)
	_draw_str_c("BUY", W * 0.25, 49, 10, C_TEXT)
	_draw_str_c("SELL (>2 copies)", W * 0.75, 49, 9, C_TEXT)

	# List
	var lst: Array = _current_list()
	if lst.is_empty():
		_draw_str_c("Nothing here.", W * 0.5, LIST_Y + 30, 10, C_DIM)
	else:
		for i in ROWS_VISIBLE:
			var idx: int = i + _scroll
			if idx >= lst.size():
				break
			var entry: Dictionary = lst[idx]
			var ry: float = LIST_Y + i * ROW_H
			var sel: bool = idx == _sel

			var row_bg: Color = C_BTN_SEL if sel else Color(0.15, 0.10, 0.25)
			_view.draw_rect(Rect2(12, ry, W - 24, ROW_H - 2), row_bg)

			var id: String = str(entry.get("card_id", ""))
			var card: Dictionary = CardDB.get_card(id)
			var nm: String = str(card.get("name", id))
			var foil: bool = bool(entry.get("is_foil", false))
			if foil:
				nm += " [FOIL]"

			var rarity: String = str(card.get("rarity", "common"))
			var col: Color = CardBattleConstants.RARITY_COL.get(rarity, C_TEXT)

			_draw_str(nm, 20, ry + 4, 10, col)

			var price_str: String
			if _tab == 0:
				price_str = "%d R" % int(entry.get("price", 0))
				_draw_str_r(price_str, W - 20, ry + 4, 10, C_PRICE)
			else:
				var copies: int = int(entry.get("copies", 0))
				price_str = "SELL %d R  (x%d)" % [int(entry.get("price", 0)), copies]
				_draw_str_r(price_str, W - 20, ry + 4, 10, C_SELL)

			# Art thumbnail
			var art: Texture2D = CardArt.card_art_1x(id, foil)
			if art != null:
				_view.draw_texture_rect(art, Rect2(W - 80, ry + 2, 28, 32), false)

	# Close button
	_view.draw_rect(Rect2(W - 110, H - 34, 100, 24), C_BTN)
	_draw_str_c("CLOSE (ESC)", W - 60, H - 34, 9, C_TEXT)

	# Scroll indicator
	if lst.size() > ROWS_VISIBLE:
		var track_h: float = ROWS_VISIBLE * ROW_H
		var thumb_h: float = track_h * ROWS_VISIBLE / lst.size()
		var thumb_y: float = LIST_Y + track_h * _scroll / lst.size()
		_view.draw_rect(Rect2(W - 8, LIST_Y, 4, track_h), Color(0.25, 0.25, 0.35))
		_view.draw_rect(Rect2(W - 8, thumb_y, 4, thumb_h), Color(0.6, 0.5, 0.9))


func _draw_str(text: String, x: float, y: float, size: int, col: Color) -> void:
	if _font == null: return
	_view.draw_string(_font, Vector2(x, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_str_c(text: String, cx: float, y: float, size: int, col: Color) -> void:
	if _font == null: return
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_view.draw_string(_font, Vector2(cx - tw * 0.5, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_str_r(text: String, rx: float, y: float, size: int, col: Color) -> void:
	if _font == null: return
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_view.draw_string(_font, Vector2(rx - tw, y + size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
