extends TileMapLayer

func _ready() -> void:
	for cell in get_used_cells():
		var data = get_cell_tile_data(cell)
		var scene_path = data.get_custom_data("spawn")
		if scene_path:
			var loaded = load(scene_path)
			var instance: Node
			if loaded is PackedScene:
				instance = loaded.instantiate()
			else:
				instance = loaded.new()
			add_sibling.call_deferred(instance)
			instance.position = map_to_local(cell)
	queue_free()
