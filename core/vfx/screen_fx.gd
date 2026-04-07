extends CanvasLayer

@onready var anim = $AnimationPlayer
@onready var _rect: ColorRect = $ColorRect

var playing:
	get:
		return anim.is_playing()


func _ready() -> void:
	# Layer 5 sits above UI (layer 0). A full-screen ColorRect with default mouse_filter STOP
	# steals every click even at alpha 0 — deck inventory EDIT/DELETE never receive input.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim.animation_finished.connect(_on_animation_finished)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"FadeWhiteOut" or anim_name == &"RESET":
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_white_in():
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	anim.play("FadeWhiteIn")
	await anim.animation_finished
	return true


func fade_white_out():
	anim.play("FadeWhiteOut")
	await anim.animation_finished
	return true
