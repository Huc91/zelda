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
var _rupies_lbl: Label
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
	title.position = Vector2i(16, 12)
	title.text = "Inventory"
	add_child(title)

	_subtitle = Label.new()
	_subtitle.position = Vector2i(16, 28)
	add_child(_subtitle)

	_new_deck_btn = Button.new()
	_new_deck_btn.text = "NEW DECK"
	_new_deck_btn.position = Vector2i(480, 8)
	_new_deck_btn.size = Vector2i(140, 22)
	_new_deck_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_new_deck_btn, Color(0.45, 0.25, 0.75))
	_new_deck_btn.pressed.connect(_on_new_deck_pressed)
	add_child(_new_deck_btn)

	_slots_row = HBoxContainer.new()
	_slots_row.position = Vector2i(24, 100)
	_slots_row.add_theme_constant_override("separation", 8)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_slots_row)

	# Rupies label
	_rupies_lbl = Label.new()
	_rupies_lbl.position = Vector2i(16, 52)
	add_child(_rupies_lbl)
	_refresh_rupies()
	Global.rupies_changed.connect(func(_r: int) -> void: _refresh_rupies())

	# OPEN PACK button
	_open_pack_btn = Button.new()
	_open_pack_btn.text = "OPEN PACK (%d R)" % Global.PACK_COST
	_open_pack_btn.position = Vector2i(200, 46)
	_open_pack_btn.size = Vector2i(180, 24)
	_open_pack_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_open_pack_btn, Color(0.65, 0.30, 0.10))
	_open_pack_btn.pressed.connect(func() -> void:
		Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
		emit_signal("open_pack_requested")
	)
	add_child(_open_pack_btn)

	# BINDER button
	var binder_btn := Button.new()
	binder_btn.text = "COLLECTION"
	binder_btn.position = Vector2i(392, 46)
	binder_btn.size = Vector2i(140, 24)
	binder_btn.focus_mode = Control.FOCUS_NONE
	_style_button(binder_btn, Color(0.10, 0.35, 0.50))
	binder_btn.pressed.connect(func() -> void:
		Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
		emit_signal("binder_requested")
	)
	add_child(binder_btn)


func _refresh_rupies() -> void:
	if _rupies_lbl != null:
		_rupies_lbl.text = "Rupies: %d" % Global.rupies
	if _open_pack_btn != null:
		_open_pack_btn.disabled = Global.rupies < Global.PACK_COST


func refresh_decks() -> void:
	for c in _slots_row.get_children():
		c.queue_free()
	var n: int = Global.player_decks.size()
	_subtitle.text = "Your Decks %d/%d" % [n, Global.MAX_DECKS]
	_new_deck_btn.disabled = n >= Global.MAX_DECKS
	_refresh_rupies()
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

	var use_lbl := Label.new()
	use_lbl.text = "Battle deck" if index == Global.battle_deck_index else ""
	use_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	use_lbl.add_theme_color_override("font_color", Color(0.1, 0.45, 0.15))
	use_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(use_lbl)

	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.custom_minimum_size = Vector2(100, 24)
	del_btn.focus_mode = Control.FOCUS_NONE
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
	Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
	Global.set_battle_deck_index(index)
	call_deferred("refresh_decks")


func _on_edit_pressed(index: int) -> void:
	Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
	emit_signal("deckbuilding_requested", index)


func _on_delete_pressed(index: int) -> void:
	if index < 0 or index >= Global.player_decks.size():
		return
	Global.player_decks.remove_at(index)
	Global.notify_deck_removed_at(index)
	Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
	# Rebuild next frame so we never free this button (or its slot) during the pressed callback.
	call_deferred("refresh_decks")


func _on_new_deck_pressed() -> void:
	if not Global.try_add_new_deck():
		return
	Sound.play(preload("res://data/sfx/LA_Menu_Select.wav"))
	refresh_decks()
	var new_idx: int = Global.player_decks.size() - 1
	emit_signal("deckbuilding_requested", new_idx)
