extends Node2D

const HUD_TEXTURE: Texture2D = preload("res://core/ui/hud.png")
const _SoulItemScript = preload("res://core/soul_item.gd")
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

const C_RED: Color = Color(0.8, 0.1, 0.1)
const C_BLUE: Color = Color(0.1, 0.3, 0.8)
const C_GREEN: Color = Color(0.1, 0.7, 0.2)
const C_SLOT_EMPTY: Color = Color(0.25, 0.25, 0.25)
const C_SLOT_BORDER: Color = Color(0.0, 0.0, 0.0)

const SOUL_POSITIONS: Array = [Vector2(4, 2), Vector2(24, 2), Vector2(44, 2)]
const SOUL_SLOTS: Array = ["red", "blue", "green"]
const SOUL_COLORS: Array = [Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.8), Color(0.1, 0.7, 0.2)]

var _font: Font


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	Global.money_changed.connect(func(_r: int) -> void: queue_redraw())
	Global.soul_changed.connect(func() -> void: queue_redraw())


func _draw() -> void:
	draw_texture(HUD_TEXTURE, Vector2.ZERO)

	for i: int in 3:
		var slot: String = SOUL_SLOTS[i] as String
		var pos: Vector2 = SOUL_POSITIONS[i] as Vector2
		var slot_color: Color = SOUL_COLORS[i] as Color
		var soul: Object = Global.get_equipped_soul(slot)
		var equipped: bool = soul != null

		# 1px black border
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(14, 14)), C_SLOT_BORDER)
		# Colored fill
		draw_rect(Rect2(pos, Vector2(12, 12)), slot_color if equipped else C_SLOT_EMPTY)

		if equipped:
			var soul_icon: Variant = soul.get("icon")
			var soul_name: String = str(soul.get("name"))
			if soul_icon != null and soul_icon is Texture2D:
				draw_texture(soul_icon as Texture2D, pos)
			elif _font != null:
				var letter: String = soul_name.left(1).to_upper()
				draw_string(_font, pos + Vector2(3, 10), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))

	# Money counter
	if _font != null:
		draw_string(_font, Vector2(79, 7), "¥", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0))
		draw_string(_font, Vector2(79, 16), "%d" % Global.money, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0))
