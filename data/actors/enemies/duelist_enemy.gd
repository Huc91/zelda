extends "res://data/actors/enemies/humanoid.gd"

@export var duelist_id: String = "duelist_1"
@export var display_name: String = "Duelist"


func _mercy_save_key() -> String:
	return duelist_id


func _ready() -> void:
	taunt_lines = PackedStringArray([
		"Now we fight.",
		"You picked the wrong duel.",
		"Let's settle this.",
	])
	super._ready()
	add_to_group("duelist_enemy")


func get_name_label() -> String:
	return display_name
