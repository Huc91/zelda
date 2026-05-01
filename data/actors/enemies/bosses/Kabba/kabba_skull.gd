## Remains after killing Kabba post-duel; absorb with hold-interact on this tile (same as tile souls).
extends Node2D

const TEX_SKULL: String = "res://data/actors/skull.png"

var _map_path: String = ""
var _cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group("world_soul")
	var spr: Sprite2D = $Sprite2D as Sprite2D
	if spr != null and ResourceLoader.exists(TEX_SKULL):
		spr.texture = load(TEX_SKULL) as Texture2D


func setup(p_map_path: String, world_pos: Vector2, map: Map) -> void:
	_map_path = p_map_path
	global_position = world_pos
	_cell = map.local_to_map(world_pos)


func matches_absorb_cell(map_path: String, cell: Vector2i) -> bool:
	return map_path == _map_path and cell == _cell


func notify_absorbed() -> void:
	Global.kabba_state = Global.KABBA_SKULL_DONE
	var p: Node = get_parent()
	if p != null:
		p.queue_free()
	else:
		queue_free()
