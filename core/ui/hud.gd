extends Node2D

const HUD_TEXTURE = preload("res://core/ui/hud.png")
const ITEM_B_POSITION = Vector2(8,0)
const ITEM_A_POSITION = Vector2(48,0)
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

var items = {}
var _font: Font


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	Global.rupies_changed.connect(func(_r: int) -> void: queue_redraw())


func _draw() -> void:
	draw_texture(HUD_TEXTURE, Vector2.ZERO)

	if items.get("B"):
		draw_texture(items["B"].icon, ITEM_B_POSITION)
	if items.get("A"):
		draw_texture(items["A"].icon, ITEM_A_POSITION)

	# Rupies counter (top-right of HUD, small text)
	if _font != null:
		var rupie_text: String = "R:%d" % Global.rupies
		draw_string(_font, Vector2(100, 10), rupie_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.9, 0.2))
