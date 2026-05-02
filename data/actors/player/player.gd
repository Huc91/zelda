extends Actor

const SoulItem = preload("res://core/soul_item.gd")
const SOUL_HOLD_TIME: float = 2.0
const PUSH_COOLDOWN: float = 0.35
## Matches facing probe offset; 1px test_move misses collisions on some axes / FLOATING mode.
const PUSH_COLLISION_TEST_PX: float = 8.0

var input_direction: Vector2:
	get: return Input.get_vector("left", "right", "up", "down")

var drown_instantiated := false
var has_entered: bool = false
const ENTRY_DISTANCE: int = 64

var _soul_hold_timer: float = 0.0
var _soul_hold_active: bool = false
var _soul_hold_cell: Vector2i = Vector2i.ZERO
var _push_cooldown: float = 0.0

@onready var _soul_particles: CPUParticles2D = $SoulParticles
@onready var _soul_particles_center: CPUParticles2D = $SoulParticlesCenter


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not has_entered:
		has_entered = position.distance_squared_to(last_safe_position) > ENTRY_DISTANCE


func _is_blocked_into_axis(axis: Vector2) -> bool:
	if axis == Vector2.ZERO:
		return false
	for i: int in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col.get_normal().dot(axis) < -0.2:
			return true
	return false


func state_default() -> void:
	var block_axis: Vector2 = _dominant_cardinal_vector(input_direction)
	velocity = input_direction * speed
	move_and_slide()
	_update_sprite_direction(input_direction)
	_check_collisions()

	if _push_cooldown > 0.0:
		_push_cooldown -= get_physics_process_delta_time()

	# Blocked / Push: prefer slide normals from move_and_slide (symmetric for all facings).
	# Diamond collision (rotated rect) + FLOATING can make test_move(transform, …) flaky on some axes.
	if input_direction.length_squared() > 0.0:
		var blocked_in_facing: bool = _is_blocked_into_axis(block_axis)
		if not blocked_in_facing and block_axis != Vector2.ZERO:
			blocked_in_facing = test_move(global_transform, block_axis * PUSH_COLLISION_TEST_PX)
		if blocked_in_facing:
			_play_animation("Push")
			_try_push()
		else:
			_play_animation("Walk")
	else:
		_play_animation("Walk")
		sprite.stop()

	# Handle soul-based item usage (skip while battle UI is up).
	if not Global.in_battle:
		if Input.is_action_just_pressed("attack") and Global.equipped_soul_red != "":
			var soul: SoulItem = Global.get_equipped_soul("red")
			if soul != null and soul.is_weapon and soul.weapon_scene != null:
				_use_item(soul.weapon_scene)
		_update_soul_catch(get_process_delta_time())


func state_swing() -> void:
	_play_animation("Swing")


func state_drown() -> void:
	# State init
	if sprite.animation != "SwimDown":
		sprite.animation = "SwimDown"
		sprite.stop()
		Sound.play(DROWN_SFX)

	# Show drown effect. Instance frees itself
	if elapsed_state_time > 0.25:
		sprite.hide()
		_oneshot_vfx(DROWN_VFX)
		_change_state(state_respawning)


func state_respawning() -> void:
	if elapsed_state_time >= 1:
		_respawn()


func _on_attacked(source: Node) -> void:
	if in_battle:
		return
	# Dialogue, vending, merchant UI pause the tree; attacks must not start a battle anyway.
	if get_tree().paused:
		return
	in_battle = true
	var enemy: Node = source.user if "user" in source else source
	Global.request_card_battle(false, enemy)


func _custom_collision(other: Object) -> void:
	if other is Pickup:
		_pickup(other as Pickup)


func _pickup(other: Pickup) -> void:
	Global.record_pickup(Global.current_map_path, other.position)
	var soul_id: String = other.soul_id
	Global.add_soul_to_collection(soul_id)
	var si: SoulItem = Global.SOULS.get(soul_id, null) as SoulItem
	if si != null:
		var slot_empty: bool = false
		match si.slot:
			"red":   slot_empty = Global.equipped_soul_red == ""
			"blue":  slot_empty = Global.equipped_soul_blue == ""
			"green": slot_empty = Global.equipped_soul_green == ""
		if slot_empty:
			Global.equip_soul(soul_id)
	other.queue_free()


func restore_state_from_global() -> void:
	pass


func _try_push() -> void:
	if _push_cooldown > 0.0:
		return
	if Global.equipped_soul_blue != Global.POWER_TRUNKS_SOUL_ID:
		return
	var map: Map = _get_map()
	if map == null:
		return
	var face_cell: Vector2i = _get_facing_cell(map)
	var dir: Vector2i = Vector2i.ZERO
	match sprite_direction:
		"Left":  dir = Vector2i(-1, 0)
		"Right": dir = Vector2i(1, 0)
		"Up":    dir = Vector2i(0, -1)
		_:       dir = Vector2i(0, 1)
	if map.push_tile_animated(face_cell, dir):
		_push_cooldown = PUSH_COOLDOWN


func _get_facing_cell(map: Map) -> Vector2i:
	var face_offset: Vector2 = Vector2.ZERO
	match sprite_direction:
		"Left":  face_offset = Vector2(-8, 0)
		"Right": face_offset = Vector2(8, 0)
		"Up":    face_offset = Vector2(0, -8)
		"Down":  face_offset = Vector2(0, 8)
	return map.local_to_map(position + face_offset)


func _facing_world_pos(map: Map) -> Vector2:
	return map.map_to_local(_get_facing_cell(map))


func _update_soul_catch(dt: float) -> void:
	var map: Map = _get_map()
	if map == null:
		_stop_absorb_vfx()
		return

	var holding: bool = Input.is_action_pressed("interact")

	if not holding:
		_stop_absorb_vfx()
		_soul_hold_timer = 0.0
		_soul_hold_active = false
		return

	var cell: Vector2i = _get_facing_cell(map)
	var soul_data: Dictionary = map.get_soul_data(cell)
	var world_soul: Node = null
	if soul_data.is_empty():
		world_soul = _find_world_soul_at_cell(map, cell)
		if world_soul == null:
			_stop_absorb_vfx()
			_soul_hold_timer = 0.0
			_soul_hold_active = false
			return

	# New cell — reset timer.
	if cell != _soul_hold_cell:
		_soul_hold_cell = cell
		_soul_hold_timer = 0.0
		_soul_hold_active = false

	if _soul_hold_active:
		return

	_soul_hold_timer += dt
	var progress: float = clampf(_soul_hold_timer / SOUL_HOLD_TIME, 0.0, 1.0)
	_update_absorb_vfx(progress, map)

	if _soul_hold_timer < SOUL_HOLD_TIME:
		return

	# 2 seconds held — attempt absorption.
	_soul_hold_active = true
	_stop_absorb_vfx()
	if world_soul != null:
		_absorb_world_soul(world_soul, map, cell)
	else:
		_absorb_soul(soul_data, map.scene_file_path, cell)


func _find_world_soul_at_cell(p_map: Map, cell: Vector2i) -> Node:
	var p: String = p_map.scene_file_path
	for n: Node in get_tree().get_nodes_in_group("world_soul"):
		if n.has_method("matches_absorb_cell") and n.matches_absorb_cell(p, cell):
			return n
	return null


func _absorb_world_soul(world: Node, map: Map, cell: Vector2i) -> void:
	var map_path: String = map.scene_file_path
	if Global.has_absorbed_soul(map_path, cell):
		_show_soul_dialog("Nothing to absorb here.")
		return
	Global.record_soul_absorb(map_path, cell)
	var result: Dictionary = {}
	if world.has_method("absorb_world_soul"):
		var v: Variant = world.call("absorb_world_soul")
		if typeof(v) == TYPE_DICTIONARY:
			result = v as Dictionary
	var msg: String = str(result.get("message", "Nothing to absorb here."))
	if msg != "":
		_show_soul_dialog(msg)
	var consume: bool = bool(result.get("consume", true))
	if consume and world.has_method("notify_absorbed"):
		world.notify_absorbed()


func _absorb_soul(soul_data: Dictionary, map_path: String, cell: Vector2i) -> void:
	var reward_id: String = soul_data.get("soul_item_id", "")
	var absorb_chance: float = float(soul_data.get("absorb_chance", 1.0))

	if reward_id == "":
		_show_soul_dialog("Nothing to absorb here.")
		return

	# Lock this cell for the rest of the session — any attempt (success or fail) counts.
	Global.record_soul_absorb(map_path, cell)

	if randf() > absorb_chance:
		_show_soul_dialog("The soul slipped away...")
		return

	# Soul item from SoulItemDB takes priority; fall back to CardDB.
	var soul: SoulItem = Global.SOULS.get(reward_id, null) as SoulItem
	if soul != null:
		Global.add_soul_to_collection(reward_id)
		var slot_empty: bool = false
		match soul.slot:
			"red":   slot_empty = Global.equipped_soul_red == ""
			"blue":  slot_empty = Global.equipped_soul_blue == ""
			"green": slot_empty = Global.equipped_soul_green == ""
		if slot_empty:
			Global.equip_soul(reward_id)
		var count: int = int(Global.soul_collection.get(reward_id, 1))
		var suffix: String = " (x%d)" % count if count > 1 else ""
		_show_soul_dialog(soul.name + " absorbed!" + suffix)
	else:
		var card: Dictionary = CardDB.get_card(reward_id)
		if card.is_empty():
			_show_soul_dialog("Nothing to absorb here.")
			return
		Global.collect_card(reward_id, false)
		var card_name: String = str(card.get("name", reward_id))
		var count: int = int(Global.card_collection.get(reward_id, 1))
		var suffix: String = " (x%d)" % count if count > 1 else ""
		_show_soul_dialog(card_name + " absorbed!" + suffix)


func _update_absorb_vfx(progress: float, map: Map) -> void:
	_play_animation("Absorb")
	var tile_pos: Vector2 = _facing_world_pos(map)
	_soul_particles.global_position = tile_pos
	_soul_particles.emitting = true
	_soul_particles.amount = int(lerp(14.0, 32.0, progress))
	_soul_particles.speed_scale = lerp(0.8, 1.6, progress)
	_soul_particles.color = Color(
		lerp(0.2, 0.7, progress),
		lerp(0.85, 1.0, progress),
		1.0, 1.0)
	_soul_particles_center.global_position = tile_pos
	_soul_particles_center.emitting = true
	_soul_particles_center.amount = int(lerp(4.0, 12.0, progress))
	_soul_particles_center.color = Color(
		lerp(0.7, 1.0, progress),
		lerp(0.97, 1.0, progress),
		1.0, 1.0)


func _stop_absorb_vfx() -> void:
	_soul_particles.emitting = false
	_soul_particles_center.emitting = false


func _show_soul_dialog(msg: String) -> void:
	var box: DialogueBox = DialogueBox.new()
	box.finished.connect(func(_e: String) -> void: pass)
	get_tree().root.add_child(box)
	box.show_sequence({"lines": [msg]}, "Soul")


func _get_map() -> Map:
	var p: Node = get_parent()
	if p is Map:
		return p as Map
	return null


func _respawn() -> void:
	has_entered = false
	position = last_safe_position
	sprite.show()
	Sound.play(hit_sfx)
	_change_state(state_default)


func _on_scroll_completed() -> void:
	last_safe_position = position
