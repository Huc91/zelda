class_name PixelFont
extends RefCounted

const NUDGE_ORB_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

static var _cache: Dictionary = {}


static func _load_pixel_font(path: String) -> Font:
	if _cache.has(path):
		return _cache[path] as Font
	var src: Resource = load(path)
	if src is FontFile:
		var ff: FontFile = (src as FontFile).duplicate(true) as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		(ff as Font).clear_cache()
		_cache[path] = ff
		return ff
	var fallback: Font = ThemeDB.fallback_font
	_cache[path] = fallback
	return fallback


static func nudge_orb() -> Font:
	return _load_pixel_font(NUDGE_ORB_PATH)
