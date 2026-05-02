class_name GameScene extends SubViewport

var map: Map
var player: Actor
var camera: GridCamera
var entrance: Vector2i
var _map_path: String

signal map_changed(map, entrance)

func _init(map_path: String, p_entrance: Vector2i, p_player: Actor):
	_map_path = map_path
	map = load(map_path).instantiate()
	map.scene = self
	map.z_index -= 1
	camera = GridCamera.new()
	player = p_player
	entrance = p_entrance
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	camera.scroll_started.connect(_on_camera_scroll_started)
	camera.scroll_completed.connect(_on_camera_scroll_completed)


func _enter_tree():
	add_child(map)
	_remove_collected_pickups()
	add_child(camera)
	camera.target = player
	map.add_child(player)
	player.position = map.map_to_local(entrance)
	player.last_safe_position = player.position
	call_deferred("_spawn_overworld_shadow_entries")


func _spawn_overworld_shadow_entries() -> void:
	if _map_path != Global.OVERWORLD_MAP_PATH:
		return
	for ev: Variant in Global.overworld_shadows:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = ev as Dictionary
		if str(entry.get("map_path", "")) != _map_path:
			continue
		var cell: Vector2i = Global.pick_overworld_shadow_spawn_cell(map)
		var sh: Node = Global.instantiate_overworld_shadow_actor(entry)
		map.add_child(sh)
		if sh is CharacterBody2D:
			(sh as CharacterBody2D).position = map.map_to_local(cell)
		if sh is Actor:
			(sh as Actor).last_safe_position = (sh as Actor).position


func _remove_collected_pickups() -> void:
	for child in map.get_children():
		if child is Pickup and Global.is_pickup_collected(_map_path, child.position):
			child.queue_free()


func _find_exit(exit_name: String) -> Vector2i:
	for exit in map.exits.values():
		if exit.name == exit_name:
			return exit.cell
	return Vector2i.ZERO


func _on_camera_scroll_started() -> void:
	for actor in get_tree().get_nodes_in_group("actor"):
		actor.set_physics_process(false)
		actor.sprite.stop()


func _on_camera_scroll_completed() -> void:
	Global.apply_kabba_spare_despawn_if_pending(_map_path)
	for actor in get_tree().get_nodes_in_group("actor"):
		if camera.world_to_grid(actor.position) == camera.grid_position:
			actor.set_physics_process(true)


func change_map(next_map, next_entrance):
	player.has_entered = false
	get_tree().paused = true
	await ScreenFX.fade_white_in()
	map.remove_child(player)
	map_changed.emit(next_map, next_entrance)
	queue_free()
