## Dialogue box overlay. Shows one line of text with a press-to-continue prompt.
class_name DialogueBox
extends CanvasLayer

signal finished

const W: int = 640
const H: int = 576
const BOX_H: int = 80
const BOX_Y: int = H - BOX_H - 12
const BOX_X: int = 20
const BOX_W: int = W - 40
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"
const C_BG: Color     = Color(0.08, 0.05, 0.16, 0.94)
const C_BORDER: Color = Color(0.6, 0.5, 0.9)
const C_TEXT: Color   = Color.WHITE
const C_HINT: Color   = Color(0.7, 0.7, 0.7)
const CHAR_DELAY: float = 0.03   ## typewriter speed

var _text: String = ""
var _displayed: String = ""
var _char_timer: float = 0.0
var _done_typing: bool = false
var _view: Control
var _font: Font


func _ready() -> void:
	layer = 30
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


func show_line(text: String) -> void:
	_text = text
	_displayed = ""
	_done_typing = false
	_char_timer = 0.0


func _process(delta: float) -> void:
	if _done_typing:
		return
	_char_timer += delta
	while _char_timer >= CHAR_DELAY and _displayed.length() < _text.length():
		_char_timer -= CHAR_DELAY
		_displayed += _text[_displayed.length()]
	if _displayed.length() >= _text.length():
		_done_typing = true
	_view.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed:
			if ek.keycode in [KEY_SPACE, KEY_ENTER, KEY_Z, KEY_ESCAPE]:
				_advance()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()


func _advance() -> void:
	if not _done_typing:
		# Skip to full text
		_displayed = _text
		_done_typing = true
		_view.queue_redraw()
	else:
		# Close
		queue_free()
		finished.emit()


func _on_draw() -> void:
	# Semi-transparent dark overlay
	_view.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))

	# Dialogue box
	var box: Rect2 = Rect2(BOX_X, BOX_Y, BOX_W, BOX_H)
	_view.draw_rect(box, C_BG)
	_view.draw_rect(box, C_BORDER, false, 2.0)

	# Text (word-wrapped)
	if _font != null and not _displayed.is_empty():
		_view.draw_string(_font, Vector2(BOX_X + 12, BOX_Y + 16),
			_displayed, HORIZONTAL_ALIGNMENT_LEFT, BOX_W - 24, 10, C_TEXT)

	# "Press Z/SPACE to continue" hint
	if _done_typing:
		var hint: String = "Press Z to continue"
		var hint_w: float = 0.0
		if _font != null:
			hint_w = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_view.draw_string(_font, Vector2(BOX_X + BOX_W - hint_w - 8, BOX_Y + BOX_H - 12),
			hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_HINT)
