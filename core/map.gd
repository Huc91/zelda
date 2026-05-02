@icon("res://editor/svg/Map.svg")
@tool
class_name Map extends TileMap

var scene: GameScene

enum Layer {STATIC, DYNAMIC}
class UniqueTile:
	var source_id: int
	var atlas_coords: Vector2i
	var alternative_tile: int
	
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

## Navigation ##
################

var _nav_astar: AStarGrid2D = AStarGrid2D.new()
var _nav_region: Rect2i = Rect2i()
var _nav_ready: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		_bake_navigation.call_deferred()


func _bake_navigation() -> void:
	var used: Array[Vector2i] = get_used_cells(Layer.STATIC)
	if used.is_empty():
		return
	var min_x: int = used[0].x
	var min_y: int = used[0].y
	var max_x: int = used[0].x
	var max_y: int = used[0].y
	for c: Vector2i in used:
		if c.x < min_x: min_x = c.x
		if c.y < min_y: min_y = c.y
		if c.x > max_x: max_x = c.x
		if c.y > max_y: max_y = c.y
	_nav_region = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_nav_astar.region = _nav_region
	_nav_astar.cell_size = Vector2(tile_set.tile_size)
	_nav_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav_astar.update()
	var used_set: Dictionary = {}
	for c: Vector2i in used:
		used_set[c] = true
	for cy: int in range(_nav_region.position.y, _nav_region.end.y):
		for cx: int in range(_nav_region.position.x, _nav_region.end.x):
			var cell := Vector2i(cx, cy)
			if not used_set.has(cell):
				_nav_astar.set_point_solid(cell, true)
				continue
			var data: TileData = get_cell_tile_data(Layer.STATIC, cell)
			if data == null or data.get_collision_polygons_count(0) > 0:
				_nav_astar.set_point_solid(cell, true)
	_nav_ready = true


func _clamp_to_region(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, _nav_region.position.x, _nav_region.end.x - 1),
		clampi(cell.y, _nav_region.position.y, _nav_region.end.y - 1)
	)


func _nav_nearest_walkable(cell: Vector2i) -> Vector2i:
	for r: int in range(1, 8):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if not _nav_region.has_point(c):
					continue
				if not _nav_astar.is_point_solid(c):
					return c
	return cell


func nav_find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	if not _nav_ready:
		return PackedVector2Array()
	var from_cell: Vector2i = _clamp_to_region(local_to_map(from_world))
	var to_cell: Vector2i = _clamp_to_region(local_to_map(to_world))
	if _nav_astar.is_point_solid(from_cell):
		from_cell = _nav_nearest_walkable(from_cell)
	if _nav_astar.is_point_solid(to_cell):
		to_cell = _nav_nearest_walkable(to_cell)
	var cell_path: Array[Vector2i] = _nav_astar.get_id_path(from_cell, to_cell)
	var result: PackedVector2Array = PackedVector2Array()
	for c: Vector2i in cell_path:
		result.append(map_to_local(c))
	return result


func is_walkable_cell(cell: Vector2i) -> bool:
	var data: TileData = get_cell_tile_data(Layer.STATIC, cell)
	if data == null:
		return false
	return data.get_collision_polygons_count(0) == 0


## Gameplay ##
##############

func on_step(actor: Actor) -> String:
	var cell = local_to_map(actor.position)
	var data = get_cell_tile_data(Layer.STATIC, cell)
	if data == null:
		return ""

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
	# Luck affects all thresholds
	var luck_bonus: float = float(Global.get_total_luck()) / 42.0 * 0.05
	var roll: float = randf()
	# Money drop (base 3%, +luck bonus)
	if roll < 0.03 + luck_bonus:
		var amount: int = randi_range(Global.MONEY_GRASS_MIN, Global.MONEY_GRASS_MAX)
		if Global.roll_luck():
			amount += 10
		Global.add_money(amount)
		_spawn_drop_label(world_pos, "+%d" % amount, Color(1.0, 0.9, 0.2))
		return
	# Card drop (base 0.5%)
	if roll < 0.035 + luck_bonus * 0.3:
		var ids: Array[String] = []
		for cid: String in CardDB.all_collectible_ids():
			var c: Dictionary = CardDB.get_card(cid)
			if not c.get("no_pack", false):
				ids.append(cid)
		if not ids.is_empty():
			var dropped: String = ids[randi() % ids.size()]
			var pickup: CardPickup = CardPickup.new()
			pickup.card_id = dropped
			pickup.is_placed = false
			pickup.position = world_pos
			add_child(pickup)


## Returns {soul_item_id, absorb_chance} for the cell if is_soulable is set on either layer.
## Checks DYNAMIC layer first (flowers, grass), then STATIC (rocks, trees).
func get_soul_data(cell: Vector2i) -> Dictionary:
	if Global.has_absorbed_soul(scene_file_path, cell):
		return {}
	var dyn: TileData = get_cell_tile_data(Layer.DYNAMIC, cell)
	if dyn != null and dyn.get_custom_data("is_soulable"):
		var item_id: String = str(dyn.get_custom_data("soul_item_id"))
		var chance: float = _read_chance(dyn)
		return {"soul_item_id": item_id, "absorb_chance": chance}
	var st: TileData = get_cell_tile_data(Layer.STATIC, cell)
	if st != null and st.get_custom_data("is_soulable"):
		var item_id: String = str(st.get_custom_data("soul_item_id"))
		var chance: float = _read_chance(st)
		return {"soul_item_id": item_id, "absorb_chance": chance}
	return {}


func _read_chance(td: TileData) -> float:
	var layer_idx: int = tile_set.get_custom_data_layer_by_name("soul_absorb_chance")
	if layer_idx < 0:
		push_warning("Map: 'soul_absorb_chance' custom data layer missing from TileSet — defaulting to 1.0")
		return 1.0
	return float(td.get_custom_data_by_layer_id(layer_idx))


func _can_push_to(dest: Vector2i) -> bool:
	var st: TileData = get_cell_tile_data(Layer.STATIC, dest)
	if st == null or st.get_collision_polygons_count(0) > 0:
		return false
	if str(st.get_custom_data("on_step")) == "drown":
		return false
	if get_cell_source_id(Layer.DYNAMIC, dest) != -1:
		return false
	return true


const PUSH_TILE_DURATION: float = 0.24


func _push_tile_draw_pos(cell: Vector2i, td: TileData) -> Vector2:
	return map_to_local(cell) + Vector2(td.get_texture_origin())


func _make_push_tile_sprite(atlas_source: TileSetAtlasSource, atlas_coords: Vector2i, td: TileData) -> Sprite2D:
	if atlas_source.texture == null:
		return null
	var region: Rect2i = atlas_source.get_tile_texture_region(atlas_coords)
	if region.size.x <= 0 or region.size.y <= 0:
		return null
	var at := AtlasTexture.new()
	at.atlas = atlas_source.texture
	at.region = region
	at.filter_clip = true
	var spr := Sprite2D.new()
	spr.texture = at
	spr.centered = true
	spr.flip_h = td.flip_h
	spr.flip_v = td.flip_v
	spr.z_index = 1
	return spr


## Slides the pushable DYNAMIC tile at `from` one step in `dir`.
## Returns true if the push succeeded.
func push_tile_animated(from: Vector2i, dir: Vector2i) -> bool:
	var data: TileData = get_cell_tile_data(Layer.DYNAMIC, from)
	if data == null or not bool(data.get_custom_data("is_pushable")):
		return false
	var dest: Vector2i = from + dir
	if not _can_push_to(dest):
		return false
	var source_id: int = get_cell_source_id(Layer.DYNAMIC, from)
	var atlas_coords: Vector2i = get_cell_atlas_coords(Layer.DYNAMIC, from)
	var alternative: int = get_cell_alternative_tile(Layer.DYNAMIC, from)
	erase_cell(Layer.DYNAMIC, from)
	_spawn_push_dust(map_to_local(from))
	var source: TileSetSource = tile_set.get_source(source_id)
	if source is TileSetAtlasSource:
		var sprite: Sprite2D = _make_push_tile_sprite(source as TileSetAtlasSource, atlas_coords, data)
		if sprite != null:
			sprite.position = _push_tile_draw_pos(from, data)
			add_child(sprite)
			var tw: Tween = create_tween()
			tw.tween_property(
				sprite,
				"position",
				_push_tile_draw_pos(dest, data),
				PUSH_TILE_DURATION,
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				set_cell(Layer.DYNAMIC, dest, source_id, atlas_coords, alternative)
				sprite.queue_free()
				_spawn_push_dust(map_to_local(dest))
			)
			return true
	var tw_fallback: Tween = create_tween()
	tw_fallback.tween_interval(0.12)
	tw_fallback.tween_callback(func() -> void:
		set_cell(Layer.DYNAMIC, dest, source_id, atlas_coords, alternative)
		_spawn_push_dust(map_to_local(dest))
	)
	return true


func _spawn_push_dust(world_pos: Vector2) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 8
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector2(0, 50)
	p.color = Color(0.75, 0.6, 0.35, 1.0)
	p.position = world_pos
	add_child(p)
	p.emitting = true
	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(p.queue_free)


func show_label(world_pos: Vector2, text: String, col: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = world_pos - Vector2(16, 16)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 8)
	add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "position", world_pos - Vector2(16, 32), 0.8)
	tw.tween_callback(lbl.queue_free)


func _spawn_drop_label(world_pos: Vector2, text: String, col: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = world_pos - Vector2(16, 16)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 8)
	add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "position", world_pos - Vector2(16, 32), 0.8)
	tw.tween_callback(lbl.queue_free)
