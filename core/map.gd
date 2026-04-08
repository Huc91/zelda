@icon("res://editor/svg/Map.svg")
@tool
class_name Map extends TileMap

var scene: GameScene

enum Layer {STATIC, DYNAMIC}
class UniqueTile:
	var source_id : int
	var atlas_coords : Vector2i
	var alternative_tile : int
	
	func _init(id, ac, at) -> void:
		source_id = id
		atlas_coords = ac
		alternative_tile = at

## Exits ##
###########

# Primarily managed by exit_editor.gd
@export var exits = {}

func reload_exits() -> void:
	var exit_cells = _get_exit_cells()
	for exit in exits.keys():
		if not exit in exit_cells:
			exits.erase(exit)
	
	for cell in exit_cells:
		if not cell in exits.keys():
			exits[cell] = new_exit_dict(cell)


func new_exit_dict(c) -> Dictionary:
	var exit_dict = {
		"cell": c,
		"name": "",
		"linked_map": "",
		"linked_exit": Vector2i(),
	}
	return exit_dict


func _get_exit_cells() -> Array:
	var exit_cells = []
	
	for tile in _get_exit_tiles():
		for cell in get_used_cells_by_id(Layer.STATIC, tile.source_id, tile.atlas_coords, tile.alternative_tile):
			exit_cells.append(cell)
	
	return exit_cells


func _get_exit_tiles() -> Array:
	var exit_tiles = []
	
	for source_id in tile_set.get_source_count():
		var source = tile_set.get_source(source_id)
		
		for tile_id in source.get_tiles_count():
			var atlas_coords = source.get_tile_id(tile_id)
			
			for alternative_tile in source.get_alternative_tiles_count(atlas_coords):
				var data = source.get_tile_data(atlas_coords, 0)
				
				if data and data.get_custom_data("is_exit"):
					exit_tiles.append(UniqueTile.new(source_id, atlas_coords, alternative_tile))
	
	return exit_tiles

## Gameplay ##
##############

func on_step(actor: Actor) -> String:
	var cell = local_to_map(actor.position)
	var data = get_cell_tile_data(Layer.STATIC, cell)
	
	if data.get_custom_data("is_exit") and actor == scene.player and actor.has_entered:
		scene.change_map(exits[cell].linked_map, exits[cell].linked_exit)
	if data.get_custom_data("on_step"):
		return data.get_custom_data("on_step")
	
	return ""


func slash(cell: Vector2i) -> void:
	var data = get_cell_tile_data(Layer.DYNAMIC, cell)

	if data and data.get_custom_data("is_cuttable"):
		var cut_fx = preload("res://core/vfx/grass_cut.tscn").instantiate()

		cut_fx.position = map_to_local(cell)
		add_child(cut_fx)
		erase_cell(Layer.DYNAMIC, cell)
		_try_grass_drop(map_to_local(cell))


func _try_grass_drop(world_pos: Vector2) -> void:
	var roll: float = randf()
	# 3% chance: rupie drop
	if roll < 0.03:
		var amount: int = randi_range(Global.RUPIES_GRASS_MIN, Global.RUPIES_GRASS_MAX)
		Global.add_rupies(amount)
		_spawn_drop_label(world_pos, "+%d R" % amount, Color(1.0, 0.9, 0.2))
		return
	# 0.5% chance: card drop
	if roll < 0.035:
		var ids: Array[String] = CardDB.all_collectible_ids()
		if not ids.is_empty():
			var dropped: String = ids[randi() % ids.size()]
			Global.collect_card(dropped, false)
			var card: Dictionary = CardDB.get_card(dropped)
			_spawn_drop_label(world_pos, card.get("name", "Card") + "!", Color(0.4, 0.8, 1.0))


func _spawn_drop_label(world_pos: Vector2, text: String, col: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = world_pos - Vector2(16, 16)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 8)
	add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "position", world_pos - Vector2(16, 32), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)
