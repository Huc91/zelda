extends Control

## Full-screen deck list (mock layout). Integer layout; theme uses Nudge Orb.

const BG_COLOR := Color(0.86, 0.86, 0.86)

const DECKBOX := {
	"black": preload("res://core/ui/deckbox_black.png"),
	"green": preload("res://core/ui/deckbox_green.png"),
	"orange": preload("res://core/ui/deckbox_orange.png"),
	"blue": preload("res://core/ui/deckbox_blue.png"),
}

signal deckbuilding_requested(deck_index: int)
signal open_pack_requested
signal binder_requested

var _subtitle: Label
var _slots_row: HBoxContainer
var _new_deck_btn: Button
var _money_lbl: Label
var _open_pack_btn: Button


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.position = Vector2i(16, 10)
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.08, 0.04, 0.02))
	add_child(title)

	_subtitle = Label.new()
	_subtitle.position = Vector2i(16, 72)
	_subtitle.add_theme_font_size_override("font_size", 9)
	_subtitle.add_theme_color_override("font_color", Color(0.25, 0.20, 0.15))
	add_child(_subtitle)

	# Money label — row 1, right of title
	_money_lbl = Label.new()
	_money_lbl.position = Vector2i(160, 10)
	_money_lbl.add_theme_font_size_override("font_size", 10)
	_money_lbl.add_theme_color_override("font_color", Color(0.70, 0.50, 0.05))
	add_child(_money_lbl)
	_refresh_money()
	Global.money_changed.connect(func(_r: int) -> void: _refresh_money())

	# Action row — full width, space-between: OPEN PACK | COLLECTION | NEW DECK
	var action_row := HBoxContainer.new()
	action_row.set_anchor(SIDE_LEFT, 0)
	action_row.set_anchor(SIDE_RIGHT, 1)
	action_row.offset_left = 8
	action_row.offset_right = -8
	action_row.offset_top = 44
	action_row.offset_bottom = 68
	add_child(action_row)

	_open_pack_btn = Button.new()
	_open_pack_btn.text = "OPEN PACK (%d)" % Global.PACK_COST
	_open_pack_btn.custom_minimum_size = Vector2i(160, 24)
	_open_pack_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_open_pack_btn, Color(0.65, 0.30, 0.10))
	_open_pack_btn.pressed.connect(func() -> void:
		Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
		emit_signal("open_pack_requested")
	)
	action_row.add_child(_open_pack_btn)

	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(spacer_l)

	var binder_btn := Button.new()
	binder_btn.text = "COLLECTION"
	binder_btn.custom_minimum_size = Vector2i(130, 24)
	binder_btn.focus_mode = Control.FOCUS_NONE
	_style_button(binder_btn, Color(0.10, 0.35, 0.50))
	binder_btn.pressed.connect(func() -> void:
		Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
		emit_signal("binder_requested")
	)
	action_row.add_child(binder_btn)

	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(spacer_r)

	_new_deck_btn = Button.new()
	_new_deck_btn.text = "NEW DECK"
	_new_deck_btn.custom_minimum_size = Vector2i(128, 24)
	_new_deck_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_new_deck_btn, Color(0.45, 0.25, 0.75))
	_new_deck_btn.pressed.connect(_on_new_deck_pressed)
	action_row.add_child(_new_deck_btn)

	_slots_row = HBoxContainer.new()
	_slots_row.position = Vector2i(24, 88)
	_slots_row.add_theme_constant_override("separation", 8)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_slots_row)


func _refresh_money() -> void:
	if _money_lbl != null:
		_money_lbl.text = "Money: %d" % Global.money
	if _open_pack_btn != null:
		_open_pack_btn.disabled = Global.money < Global.PACK_COST


func refresh_decks() -> void:
	for c in _slots_row.get_children():
		c.queue_free()
	var n: int = Global.player_decks.size()
	_subtitle.text = "Your Decks %d/%d" % [n, Global.MAX_DECKS]
	_new_deck_btn.disabled = n >= Global.MAX_DECKS
	_refresh_money()
	for i in n:
		_slots_row.add_child(_make_slot(i, Global.player_decks[i]))


func _make_slot(index: int, deck: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(112, 260)
	col.add_theme_constant_override("separation", 6)

	var tex_key: String = str(deck.get("color", "black"))
	if not DECKBOX.has(tex_key):
		tex_key = "black"
	var icon := TextureButton.new()
	icon.texture_normal = DECKBOX[tex_key]
	icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(96, 120)
	icon.ignore_texture_size = true
	icon.focus_mode = Control.FOCUS_NONE
	if index == Global.battle_deck_index:
		icon.modulate = Color(1.15, 1.15, 1.0)
	icon.pressed.connect(_on_deck_icon_pressed.bind(index))
	col.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = str(deck.get("name", "Deck"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Fixed height (~2 lines); no Label.max_lines in older Godot — clip extra text.
	name_lbl.custom_minimum_size = Vector2(112, 34)
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)

	var use_btn := Button.new()
	var is_battle: bool = index == Global.battle_deck_index
	use_btn.text = "BATTLE DECK" if is_battle else "USE FOR BATTLE"
	use_btn.custom_minimum_size = Vector2(100, 24)
	use_btn.focus_mode = Control.FOCUS_NONE
	use_btn.disabled = is_battle
	_style_button(use_btn, Color(0.10, 0.40, 0.15))
	use_btn.pressed.connect(_on_deck_icon_pressed.bind(index))
	col.add_child(use_btn)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.custom_minimum_size = Vector2(100, 24)
	del_btn.focus_mode = Control.FOCUS_NONE
	del_btn.disabled = Global.player_decks.size() <= 1
	_style_button(del_btn, Color(0.08, 0.08, 0.08))
	del_btn.pressed.connect(_on_delete_pressed.bind(index))
	col.add_child(del_btn)

	var edit_btn := Button.new()
	edit_btn.text = "EDIT"
	edit_btn.custom_minimum_size = Vector2(100, 24)
	edit_btn.focus_mode = Control.FOCUS_NONE
	_style_button(edit_btn, Color(0.2, 0.2, 0.35))
	edit_btn.pressed.connect(_on_edit_pressed.bind(index))
	col.add_child(edit_btn)

	return col


func _style_button(btn: Button, bg: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_color_override("font_color", Color.WHITE)


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
	# Rebuild next frame so we never free this button (or its slot) during the pressed callback.
	call_deferred("refresh_decks")


func _on_new_deck_pressed() -> void:
	if not Global.try_add_new_deck():
		return
	Sound.play(preload("res://data/sfx/to use/JDSherbert - Pixel UI SFX Pack - Select 2 (Sine).wav"))
	refresh_decks()
	var new_idx: int = Global.player_decks.size() - 1
	emit_signal("deckbuilding_requested", new_idx)
