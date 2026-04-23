## Dialogue box: shows a sequence (multi-line, optional choices, speaker name).
## Emits finished(event) when the player closes or selects a choice.
class_name DialogueBox
extends CanvasLayer

signal finished(event: String)

const W: int = 640
const H: int = 576
const BOX_H: int = 88
const BOX_Y: int = H - BOX_H - 12
const BOX_X: int = 20
const BOX_W: int = W - 40
const NAME_H: int = 18
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

const C_BG: Color        = Color(0.06, 0.04, 0.14, 1.0)
const C_NAME_BG: Color   = Color(0.18, 0.10, 0.32, 1.0)
const C_BORDER: Color    = Color(0.6, 0.5, 0.9, 1.0)
const C_TEXT: Color      = Color(1.0, 1.0, 1.0, 1.0)
const C_NAME: Color      = Color(0.85, 0.75, 1.0, 1.0)
const C_HINT: Color      = Color(0.6, 0.6, 0.6, 1.0)
const C_CHOICE_BG: Color = Color(0.14, 0.09, 0.26, 1.0)
const C_CHOICE_HOV: Color = Color(0.30, 0.18, 0.52, 1.0)
const C_CHOICE_TXT: Color = Color(0.95, 0.90, 1.0, 1.0)
const CHAR_DELAY: float = 0.03

enum _Phase { TYPING, READING, CHOICES }

var _lines: Array = []
var _choices: Array = []   ## Array of {text, event}
var _sequence_event: String = ""
var _speaker: String = ""

var _line_idx: int = 0
var _displayed: String = ""
var _char_timer: float = 0.0
var _phase: _Phase = _Phase.TYPING
var _hovered_choice: int = -1
var _selected_choice: int = -1

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


## Call this to start the dialogue. sequence = {lines, choices?, event?}, speaker = display name.
func show_sequence(sequence: Dictionary, speaker: String = "") -> void:
	_lines = sequence.get("lines", ["..."])
	_choices = sequence.get("choices", [])
	_sequence_event = sequence.get("event", "")
	_speaker = speaker
	_line_idx = 0
	_start_line()


func _start_line() -> void:
	_displayed = ""
	_char_timer = 0.0
	_phase = _Phase.TYPING
	_view.queue_redraw()


func _process(delta: float) -> void:
	if _phase != _Phase.TYPING:
		return
	_char_timer += delta
	var current: String = _lines[_line_idx] if _line_idx < _lines.size() else ""
	while _char_timer >= CHAR_DELAY and _displayed.length() < current.length():
		_char_timer -= CHAR_DELAY
		_displayed += current[_displayed.length()]
	if _displayed.length() >= current.length():
		_phase = _Phase.READING
	_view.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if not ek.pressed:
			return
		if _phase == _Phase.CHOICES:
			if ek.keycode == KEY_UP and not _choices.is_empty():
				_selected_choice = maxi(0, _selected_choice - 1)
				_hovered_choice = _selected_choice
				_view.queue_redraw()
			elif ek.keycode == KEY_DOWN and not _choices.is_empty():
				_selected_choice = mini(_choices.size() - 1, _selected_choice + 1)
				_hovered_choice = _selected_choice
				_view.queue_redraw()
			elif ek.keycode in [KEY_Z, KEY_SPACE, KEY_ENTER]:
				if _selected_choice >= 0:
					_pick_choice(_selected_choice)
			elif ek.keycode == KEY_1 and _choices.size() >= 1:
				_pick_choice(0)
			elif ek.keycode == KEY_2 and _choices.size() >= 2:
				_pick_choice(1)
			elif ek.keycode == KEY_3 and _choices.size() >= 3:
				_pick_choice(2)
		else:
			if ek.keycode in [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
				_advance()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _phase == _Phase.CHOICES:
				var idx: int = _choice_at(mb.position)
				if idx >= 0:
					_pick_choice(idx)
			else:
				_advance()
	elif event is InputEventMouseMotion:
		if _phase == _Phase.CHOICES:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			var prev: int = _hovered_choice
			_hovered_choice = _choice_at(mm.position)
			if _hovered_choice >= 0:
				_selected_choice = _hovered_choice
			if _hovered_choice != prev:
				_view.queue_redraw()


func _advance() -> void:
	if _phase == _Phase.TYPING:
		# Skip typewriter
		_displayed = _lines[_line_idx] if _line_idx < _lines.size() else ""
		_phase = _Phase.READING
		_view.queue_redraw()
		return
	# READING: go to next line or choices/close
	_line_idx += 1
	if _line_idx < _lines.size():
		_start_line()
		return
	# All lines done
	if not _choices.is_empty():
		_phase = _Phase.CHOICES
		_hovered_choice = 0
		_selected_choice = 0
		_view.queue_redraw()
	else:
		_close(_sequence_event)


func _pick_choice(idx: int) -> void:
	if idx < 0 or idx >= _choices.size():
		return
	var ev: String = str(_choices[idx].get("event", ""))
	_close(ev if ev != "" else _sequence_event)


func _close(event: String) -> void:
	queue_free()
	finished.emit(event)


# ── Drawing ──────────────────────────────────────────────────────

func _choice_rect(idx: int) -> Rect2:
	const CHOICE_H: int = 14
	const CHOICE_GAP: int = 2
	const CHOICE_TOP: int = 34
	const CHOICE_INSET_X: int = 8
	var cy: int = BOX_Y + CHOICE_TOP + idx * (CHOICE_H + CHOICE_GAP)
	return Rect2(BOX_X + CHOICE_INSET_X, cy, BOX_W - CHOICE_INSET_X * 2, CHOICE_H)


func _choice_at(pos: Vector2) -> int:
	for i in _choices.size():
		if _choice_rect(i).has_point(pos):
			return i
	return -1


func _on_draw() -> void:
	if _font == null:
		return

	# Speaker name tab
	if _speaker != "":
		var name_rect: Rect2 = Rect2(float(BOX_X), float(BOX_Y) - float(NAME_H) - 2.0,
			_font.get_string_size(_speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 16.0,
			float(NAME_H))
		_view.draw_rect(name_rect, C_NAME_BG)
		_view.draw_rect(name_rect, C_BORDER, false, 1.0)
		_view.draw_string(_font, Vector2(name_rect.position.x + 8.0, name_rect.position.y + 12.0),
			_speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_NAME)

	# Main dialogue box
	var box: Rect2 = Rect2(float(BOX_X), float(BOX_Y), float(BOX_W), float(BOX_H))
	_view.draw_rect(box, C_BG)
	_view.draw_rect(box, C_BORDER, false, 2.0)

	# Text
	if not _displayed.is_empty():
		_view.draw_string(_font, Vector2(float(BOX_X) + 12.0, float(BOX_Y) + 18.0),
			_displayed, HORIZONTAL_ALIGNMENT_LEFT, BOX_W - 24, 10, C_TEXT)

	# Choices rendered inside the main dialogue box (classic RPG layout)
	if _phase == _Phase.CHOICES:
		for i in _choices.size():
			var r: Rect2 = _choice_rect(i)
			var is_focused: bool = i == _selected_choice or i == _hovered_choice
			var bg: Color = C_CHOICE_HOV if is_focused else C_CHOICE_BG
			_view.draw_rect(r, bg)
			_view.draw_rect(r, C_BORDER, false, 1.0)
			var label: String = "%d. %s" % [i + 1, _choices[i].get("text", "")]
			_view.draw_string(_font, Vector2(r.position.x + 6.0, r.position.y + 11.0),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_CHOICE_TXT)

	# Line counter if multiple lines
	if _lines.size() > 1:
		var counter: String = "%d/%d" % [_line_idx + 1, _lines.size()]
		var cw: float = _font.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		_view.draw_string(_font, Vector2(float(BOX_X + BOX_W) - cw - 8.0, float(BOX_Y) + 10.0),
			counter, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_HINT)

	# Hint
	if _phase == _Phase.READING:
		var hint: String = "Z / SPACE" if _choices.is_empty() or _line_idx < _lines.size() - 1 else "Z to choose"
		var hw: float = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		_view.draw_string(_font, Vector2(float(BOX_X + BOX_W) - hw - 8.0,
			float(BOX_Y + BOX_H) - 8.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_HINT)
