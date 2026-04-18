## Small non-blocking info box. No screen overlay. No pause. No input required.
class_name InfoBox
extends CanvasLayer

const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"
const C_BG: Color     = Color(0.08, 0.05, 0.16, 1.0)
const C_BORDER: Color = Color(0.6, 0.5, 0.9, 1.0)
const C_TEXT: Color   = Color.WHITE

var _text: String = ""
var _flash_timer: float = 0.0
var _view: Control
var _font: Font


func _ready() -> void:
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH) as Font
	_ensure_view()


func _ensure_view() -> void:
	if _view != null:
		return
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.draw.connect(_on_draw)
	_view.hide()


func show_hint(text: String) -> void:
	_ensure_view()
	_text = text
	_flash_timer = 0.0
	_view.show()
	_view.queue_redraw()


func show_flash(text: String, duration: float = 2.0) -> void:
	_ensure_view()
	_text = text
	_flash_timer = duration
	_view.show()
	_view.queue_redraw()


func dismiss() -> void:
	_text = ""
	_flash_timer = 0.0
	if _view != null:
		_view.hide()


## Only dismisses if not currently showing a flash — safe to call on body_exited.
func hide_hint() -> void:
	if _flash_timer <= 0.0:
		dismiss()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			dismiss()


func _on_draw() -> void:
	if _font == null or _text.is_empty():
		return
	var fs: int = 9
	var pad_x: float = 10.0
	var pad_y: float = 7.0
	var tw: float = _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bw: float = tw + pad_x * 2.0
	var bh: float = float(fs) + pad_y * 2.0
	var bx: float = (640.0 - bw) * 0.5
	var by: float = 576.0 - bh - 16.0
	var box: Rect2 = Rect2(bx, by, bw, bh)
	_view.draw_rect(box, C_BG)
	_view.draw_rect(box, C_BORDER, false, 1.0)
	_view.draw_string(_font, Vector2(bx + pad_x, by + pad_y + float(fs)),
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)
