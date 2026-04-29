extends Node2D
const PixelFont = preload("res://core/ui/pixel_font.gd")

const HUD_TEXTURE: Texture2D = preload("res://core/ui/hud.png")
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

const SOUL_SLOTS: Array = ["red", "blue", "green"]
# 16×16 icons centered on the 12×12 slot placeholders baked into hud.png
const SOUL_ICON_POSITIONS: Array = [Vector2(0, 0), Vector2(15, 0), Vector2(30, 0)]

var _font: Font


func _ready() -> void:
	_font = PixelFont.nudge_orb()
	Global.money_changed.connect(func(_r: int) -> void: queue_redraw())
	Global.soul_changed.connect(func() -> void: queue_redraw())


func _draw() -> void:
	draw_texture(HUD_TEXTURE, Vector2.ZERO)

	for i: int in 3:
		var soul: SoulItem = Global.get_equipped_soul(SOUL_SLOTS[i] as String)
		if soul != null and soul.hud_icon != null:
			draw_texture(soul.hud_icon, SOUL_ICON_POSITIONS[i] as Vector2)

	if _font != null:
		draw_string(_font, Vector2(79, 7),  "¥",                 HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0))
		draw_string(_font, Vector2(79, 16), "%d" % Global.money, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0))
