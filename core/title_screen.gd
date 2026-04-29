class_name TitleScreen extends Control
const PixelFont = preload("res://core/ui/pixel_font.gd")

enum Choice { CONTINUE, NEW_GAME, DEV_MODE }

signal chosen(choice: Choice)

const _LOGO: Texture2D = preload("res://assets/logo.png")
var _font: Font

const _W: int = 640
const _H: int = 576
const _FONT_SIZE: int = 12
const _SELECTED_COLOR: Color = Color(1.0, 0.85, 0.1)
const _NORMAL_COLOR: Color = Color(0.85, 0.85, 0.85)
const _DIM_COLOR: Color = Color(0.4, 0.4, 0.4)

var _items: Array[Dictionary] = []  # { label, choice, enabled }
var _cursor: int = 0
var _ready_input: bool = false
var _ctrl: Control


func _ready() -> void:
	_font = PixelFont.nudge_orb()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_items()

	_ctrl = Control.new()
	_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctrl.draw.connect(_draw_screen)
	add_child(_ctrl)

	await get_tree().create_timer(0.3).timeout
	_ready_input = true


func _build_items() -> void:
	_items.clear()
	if Global.has_normal_save():
		_items.append({ "label": "CONTINUE", "choice": Choice.CONTINUE, "enabled": true })
	_items.append({ "label": "NEW GAME", "choice": Choice.NEW_GAME, "enabled": true })
	_items.append({ "label": "DEV MODE", "choice": Choice.DEV_MODE, "enabled": true })
	# Start cursor on first enabled item
	_cursor = 0


func _draw_screen() -> void:
	# Background
	_ctrl.draw_rect(Rect2(0, 0, _W, _H), Color(0.04, 0.02, 0.06))

	# Logo — centered, upper half
	var logo_w: float = _LOGO.get_width()
	var logo_h: float = _LOGO.get_height()
	var scale: float = minf(340.0 / logo_w, 220.0 / logo_h)
	var draw_w: float = logo_w * scale
	var draw_h: float = logo_h * scale
	var logo_x: float = (_W - draw_w) * 0.5
	var logo_y: float = 60.0
	_ctrl.draw_texture_rect(_LOGO, Rect2(logo_x, logo_y, draw_w, draw_h), false)

	# Menu items
	var item_h: int = 22
	var total_h: int = _items.size() * item_h
	var start_y: float = logo_y + draw_h + 36.0
	for i: int in _items.size():
		var item: Dictionary = _items[i]
		var label: String = item["label"] as String
		var enabled: bool = item["enabled"] as bool
		var color: Color
		if not enabled:
			color = _DIM_COLOR
		elif i == _cursor:
			color = _SELECTED_COLOR
		else:
			color = _NORMAL_COLOR
		var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
		var tx: float = (_W - tw) * 0.5
		var ty: float = start_y + i * item_h
		# Cursor arrow
		if i == _cursor and enabled:
			_ctrl.draw_string(_font, Vector2(tx - 16.0, ty), ">",
					HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, _SELECTED_COLOR)
		_ctrl.draw_string(_font, Vector2(tx, ty), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, color)


func _input(event: InputEvent) -> void:
	if not _ready_input:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key: InputEventKey = event as InputEventKey
		if key.physical_keycode == KEY_UP or key.physical_keycode == KEY_W:
			_move_cursor(-1)
		elif key.physical_keycode == KEY_DOWN or key.physical_keycode == KEY_S:
			_move_cursor(1)
		elif key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_Z \
				or key.physical_keycode == KEY_X or key.physical_keycode == KEY_SPACE:
			_confirm()


func _move_cursor(dir: int) -> void:
	var count: int = _items.size()
	var attempts: int = 0
	while attempts < count:
		_cursor = (_cursor + dir + count) % count
		if _items[_cursor]["enabled"]:
			break
		attempts += 1
	_ctrl.queue_redraw()


func _confirm() -> void:
	var item: Dictionary = _items[_cursor]
	if not item["enabled"]:
		return
	_ready_input = false
	chosen.emit(item["choice"] as Choice)
