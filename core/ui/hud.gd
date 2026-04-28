extends Node2D

const HUD_TEXTURE: Texture2D = preload("res://core/ui/hud.png")
const ICONS_TEXTURE: Texture2D = preload("res://assets/ui parts/icons.png")
const _SoulItemScript = preload("res://core/soul_item.gd")
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

const C_RED: Color   = Color(0.8, 0.1, 0.1)
const C_BLUE: Color  = Color(0.1, 0.3, 0.8)
const C_GREEN: Color = Color(0.1, 0.7, 0.2)
const C_SLOT_BORDER: Color = Color(0.0, 0.0, 0.0)
const C_SLOT_BG: Color     = Color(0.10, 0.10, 0.10)

const SOUL_POSITIONS: Array = [Vector2(4, 2), Vector2(24, 2), Vector2(44, 2)]
const SOUL_SLOTS: Array     = ["red", "blue", "green"]
const SOUL_COLORS: Array    = [Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.8), Color(0.1, 0.7, 0.2)]

# face=red(0), tao=blue(1), circle=green(2) — cropped tight to actual icon pixels
const ICON_REGIONS: Array = [Rect2(2, 4, 20, 20), Rect2(33, 4, 20, 20), Rect2(66, 4, 20, 20)]

var _font: Font
var _slot_icons: Array[AtlasTexture] = []


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	for reg: Rect2 in ICON_REGIONS:
		var at: AtlasTexture = AtlasTexture.new()
		at.atlas = ICONS_TEXTURE
		at.region = reg
		_slot_icons.append(at)
	Global.money_changed.connect(func(_r: int) -> void: queue_redraw())
	Global.soul_changed.connect(func() -> void: queue_redraw())


func _draw() -> void:
	draw_texture(HUD_TEXTURE, Vector2.ZERO)

	for i: int in 3:
		var slot: String = SOUL_SLOTS[i] as String
		var pos: Vector2  = SOUL_POSITIONS[i] as Vector2
		var col: Color    = SOUL_COLORS[i] as Color
		var soul: SoulItem = Global.get_equipped_soul(slot)

		# Outer 1px black border (14×14)
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(14, 14)), C_SLOT_BORDER)
		# Dark interior background (12×12)
		draw_rect(Rect2(pos, Vector2(12, 12)), C_SLOT_BG)

		# Slot icon or soul sprite filling the full 12×12 interior
		var inner: Rect2 = Rect2(pos, Vector2(12, 12))
		if soul != null:
			var soul_icon: Variant = soul.get("icon")
			if soul_icon != null and soul_icon is Texture2D:
				draw_texture_rect(soul_icon as Texture2D, inner, false)
			elif i < _slot_icons.size():
				draw_texture_rect(_slot_icons[i], inner, false)
		elif i < _slot_icons.size():
			draw_texture_rect(_slot_icons[i], inner, false)

		# Colored 2px strip TOP — drawn over sprite so it is always visible
		draw_rect(Rect2(pos, Vector2(12, 2)), col)
		# Colored 2px strip BOTTOM — drawn over sprite so it is always visible
		draw_rect(Rect2(pos + Vector2(0, 10), Vector2(12, 2)), col)

	# Money counter
	if _font != null:
		draw_string(_font, Vector2(79, 7),  "¥",              HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0))
		draw_string(_font, Vector2(79, 16), "%d" % Global.money, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0))
