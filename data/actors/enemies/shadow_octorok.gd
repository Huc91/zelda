extends "res://data/actors/enemies/octorok.gd"

var _shadow_uid: String = ""
var shadow_display_name: String = "Shadow"


func _ready() -> void:
	super._ready()
	add_to_group("shadow_enemy")
	sprite.modulate = Color(0.15, 0.15, 0.2)
	aggro_range *= 1.35
	wait1_time *= 0.65
	wait2_time *= 0.65


func setup_overworld_shadow(deck_ids: Array[String], p_display_name: String, uid: String) -> void:
	_shadow_uid = uid
	shadow_display_name = p_display_name
	battle_deck = CardDB.enemy_deck_from_card_ids(deck_ids)


func get_name_label() -> String:
	return shadow_display_name


func on_card_battle_won() -> void:
	Global.remove_overworld_shadow_uid(_shadow_uid)
	queue_free()
