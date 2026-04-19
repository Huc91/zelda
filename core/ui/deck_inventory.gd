extends Control

const FONT: FontFile = preload("res://assets/fonts/Nudge Orb.ttf")

const DECKBOX: Dictionary = {
	"black":  preload("res://core/ui/deckbox_black.png"),
	"green":  preload("res://core/ui/deckbox_green.png"),
	"orange": preload("res://core/ui/deckbox_orange.png"),
	"blue":   preload("res://core/ui/deckbox_blue.png"),
}

signal deckbuilding_requested(deck_index: int)
signal open_pack_requested
signal binder_requested
signal soul_system_requested

# ── Card definitions ─────────────────────────────────────────────
const CARDS: Array = [
	{
		"label": "PACKS",
		"desc":  "Open a new\ncard pack",
		"color": Color(0.80, 0.45, 0.05),
		"icon":  "orange",
	},
	{
		"label": "COLLECTION",
		"desc":  "Browse all\nyour cards",
		"color": Color(0.12, 0.32, 0.68),
		"icon":  "blue",
	},
	{
		"label": "DECKBUILDER",
		"desc":  "Build and\nmanage decks",
		"color": Color(0.32, 0.10, 0.62),
		"icon":  "black",
	},
	{
		"label": "SOUL SYSTEM",
		"desc":  "Equip and\nmanage souls",
		"color": Color(0.08, 0.50, 0.25),
		"icon":  "green",
	},
]

const CARD_W:   int = 128
const CARD_H:   int = 200
const CARD_GAP: int = 20
const CARD_Y:   int = 160

var _hub: Control
var _deck_list: Control
var _slots_row: HBoxContainer
var _new_deck_btn: Button
var _money_lbl_dl: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_bg()
	_build_hub()
	_build_deck_list()
	_show_hub()


func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.08, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "INVENTORY"
	title.position = Vector2i(0, 24)
	title.size = Vector2i(640, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	add_child(title)

	var hint := Label.new()
	hint.text = "ESC — back to game"
	hint.position = Vector2i(0, 544)
	hint.size = Vector2i(640, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(hint)


func _build_hub() -> void:
	_hub = Control.new()
	_hub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hub)

	var total_w: int = 4 * CARD_W + 3 * CARD_GAP
	var start_x: int = (640 - total_w) / 2

	for i: int in CARDS.size():
		var card_def: Dictionary = CARDS[i] as Dictionary
		var cx: int = start_x + i * (CARD_W + CARD_GAP)
		_hub.add_child(_make_card(card_def, cx, CARD_Y, i))


func _make_card(def: Dictionary, cx: int, cy: int, idx: int) -> Control:
	var col: Color = def["color"] as Color

	var btn := Button.new()
	btn.position = Vector2i(cx, cy)
	btn.custom_minimum_size = Vector2i(CARD_W, CARD_H)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Normal
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = col
	sb_n.set_corner_radius_all(6)
	sb_n.border_width_left   = 2
	sb_n.border_width_right  = 2
	sb_n.border_width_top    = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = col.lightened(0.15)
	btn.add_theme_stylebox_override("normal", sb_n)

	# Hover
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = col.lightened(0.18)
	sb_h.border_color = Color(1, 1, 1)
	btn.add_theme_stylebox_override("hover", sb_h)

	# Pressed
	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = col.darkened(0.18)
	btn.add_theme_stylebox_override("pressed", sb_p)

	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_font_override("font", FONT)

	btn.pressed.connect(_on_card_pressed.bind(idx))

	# Deckbox icon
	var icon_key: String = def["icon"] as String
	var tex_rect := TextureRect.new()
	tex_rect.texture = DECKBOX[icon_key] as Texture2D
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.position = Vector2i(16, 28)
	tex_rect.size = Vector2i(CARD_W - 32, 96)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tex_rect)

	# Card label
	var lbl := Label.new()
	lbl.text = def["label"] as String
	lbl.position = Vector2i(0, 132)
	lbl.size = Vector2i(CARD_W, 28)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	# Description
	var desc := Label.new()
	desc.text = def["desc"] as String
	desc.position = Vector2i(8, 162)
	desc.size = Vector2i(CARD_W - 16, 34)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_override("font", FONT)
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 1).darkened(0.1))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(desc)

	return btn


func _on_card_pressed(idx: int) -> void:
	Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
	match idx:
		0: emit_signal("open_pack_requested")
		1: emit_signal("binder_requested")
		2: _show_deck_list()
		3: emit_signal("soul_system_requested")


# ── Deck List sub-screen ─────────────────────────────────────────

func _build_deck_list() -> void:
	_deck_list = Control.new()
	_deck_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deck_list)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.position = Vector2i(16, 64)
	back_btn.custom_minimum_size = Vector2i(100, 28)
	back_btn.focus_mode = Control.FOCUS_NONE
	_style_flat(back_btn, Color(0.25, 0.20, 0.35))
	back_btn.pressed.connect(_show_hub)
	_deck_list.add_child(back_btn)

	# "Your Decks" title
	var sub_title := Label.new()
	sub_title.text = "DECKBUILDER"
	sub_title.position = Vector2i(0, 68)
	sub_title.size = Vector2i(640, 28)
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_title.add_theme_font_override("font", FONT)
	sub_title.add_theme_font_size_override("font_size", 16)
	sub_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_deck_list.add_child(sub_title)

	# Money label
	_money_lbl_dl = Label.new()
	_money_lbl_dl.position = Vector2i(0, 100)
	_money_lbl_dl.size = Vector2i(640, 20)
	_money_lbl_dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_lbl_dl.add_theme_font_override("font", FONT)
	_money_lbl_dl.add_theme_font_size_override("font_size", 11)
	_money_lbl_dl.add_theme_color_override("font_color", Color(0.80, 0.65, 0.10))
	_deck_list.add_child(_money_lbl_dl)
	Global.money_changed.connect(func(_r: int) -> void: _refresh_money())

	# Deck slots row
	_slots_row = HBoxContainer.new()
	_slots_row.position = Vector2i(0, 130)
	_slots_row.size = Vector2i(640, 300)
	_slots_row.add_theme_constant_override("separation", 16)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_deck_list.add_child(_slots_row)

	# New deck button
	_new_deck_btn = Button.new()
	_new_deck_btn.text = "+ NEW DECK"
	_new_deck_btn.position = Vector2i(240, 450)
	_new_deck_btn.custom_minimum_size = Vector2i(160, 30)
	_new_deck_btn.focus_mode = Control.FOCUS_NONE
	_style_flat(_new_deck_btn, Color(0.32, 0.10, 0.62))
	_new_deck_btn.pressed.connect(_on_new_deck_pressed)
	_deck_list.add_child(_new_deck_btn)


func _show_hub() -> void:
	_hub.visible = true
	_deck_list.visible = false


func _show_deck_list() -> void:
	_hub.visible = false
	_deck_list.visible = true
	refresh_decks()


func _refresh_money() -> void:
	if _money_lbl_dl != null:
		_money_lbl_dl.text = "Money: %d" % Global.money


func refresh_decks() -> void:
	for c: Node in _slots_row.get_children():
		c.queue_free()
	_new_deck_btn.disabled = Global.player_decks.size() >= Global.MAX_DECKS
	_refresh_money()
	for i: int in Global.player_decks.size():
		_slots_row.add_child(_make_deck_slot(i, Global.player_decks[i]))


func _make_deck_slot(index: int, deck: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(120, 280)
	col.add_theme_constant_override("separation", 6)

	var tex_key: String = str(deck.get("color", "black"))
	if not DECKBOX.has(tex_key):
		tex_key = "black"
	var icon := TextureButton.new()
	icon.texture_normal = DECKBOX[tex_key] as Texture2D
	icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(96, 130)
	icon.ignore_texture_size = true
	icon.focus_mode = Control.FOCUS_NONE
	if index == Global.battle_deck_index:
		icon.modulate = Color(1.15, 1.15, 1.0)
	icon.pressed.connect(_on_deck_icon_pressed.bind(index))
	col.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(deck.get("name", "Deck"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(120, 36)
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)

	var use_btn := Button.new()
	var is_battle: bool = index == Global.battle_deck_index
	use_btn.text = "✓ BATTLE" if is_battle else "USE"
	use_btn.custom_minimum_size = Vector2(100, 26)
	use_btn.focus_mode = Control.FOCUS_NONE
	use_btn.disabled = is_battle
	_style_flat(use_btn, Color(0.08, 0.42, 0.15))
	use_btn.pressed.connect(_on_deck_icon_pressed.bind(index))
	col.add_child(use_btn)

	var edit_btn := Button.new()
	edit_btn.text = "EDIT"
	edit_btn.custom_minimum_size = Vector2(100, 26)
	edit_btn.focus_mode = Control.FOCUS_NONE
	_style_flat(edit_btn, Color(0.20, 0.20, 0.38))
	edit_btn.pressed.connect(_on_edit_pressed.bind(index))
	col.add_child(edit_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.custom_minimum_size = Vector2(100, 26)
	del_btn.focus_mode = Control.FOCUS_NONE
	del_btn.disabled = Global.player_decks.size() <= 1
	_style_flat(del_btn, Color(0.40, 0.08, 0.08))
	del_btn.pressed.connect(_on_delete_pressed.bind(index))
	col.add_child(del_btn)

	return col


func _style_flat(btn: Button, bg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", sb_p)
	var sb_d := sb.duplicate() as StyleBoxFlat
	sb_d.bg_color = bg.darkened(0.30)
	btn.add_theme_stylebox_override("disabled", sb_d)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 11)


func _on_deck_icon_pressed(index: int) -> void:
	Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
	Global.set_battle_deck_index(index)
	call_deferred("refresh_decks")


func _on_edit_pressed(index: int) -> void:
	Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
	emit_signal("deckbuilding_requested", index)


func _on_delete_pressed(index: int) -> void:
	if index < 0 or index >= Global.player_decks.size():
		return
	Global.player_decks.remove_at(index)
	Global.notify_deck_removed_at(index)
	Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
	call_deferred("refresh_decks")


func _on_new_deck_pressed() -> void:
	if not Global.try_add_new_deck():
		return
	Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
	var new_idx: int = Global.player_decks.size() - 1
	refresh_decks()
	emit_signal("deckbuilding_requested", new_idx)
