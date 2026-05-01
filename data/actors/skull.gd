## Generic skull remains node; absorb with hold-interact (world soul system).
extends Node2D

const TEX_SKULL: String = "res://data/actors/skull.png"

var _map_path: String = ""
var _cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group("world_soul")
	add_to_group("skull_remains")
	var spr: Sprite2D = $Sprite2D as Sprite2D
	if spr != null and ResourceLoader.exists(TEX_SKULL):
		spr.texture = load(TEX_SKULL) as Texture2D


func setup(p_map_path: String, world_pos: Vector2, map: Map) -> void:
	_map_path = p_map_path
	global_position = world_pos
	_cell = map.local_to_map(world_pos)


func matches_absorb_cell(map_path: String, cell: Vector2i) -> bool:
	return map_path == _map_path and cell == _cell


func absorb_world_soul() -> Dictionary:
	var p: Node = get_parent()
	if p != null and p.has_method("on_world_soul_absorb"):
		var result: Variant = p.call("on_world_soul_absorb", self)
		if typeof(result) == TYPE_DICTIONARY:
			return result as Dictionary
	return {"message": "Nothing to absorb here.", "consume": false}


func notify_absorbed() -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("on_world_soul_absorbed"):
		p.call("on_world_soul_absorbed", self)
	if is_inside_tree():
		queue_free()
