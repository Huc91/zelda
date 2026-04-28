extends Actor

const SoulItem = preload("res://core/soul_item.gd")
const SOUL_HOLD_TIME: float = 2.0

var input_direction: Vector2:
	get: return Input.get_vector("left", "right", "up", "down")

var last_safe_position: Vector2
var drown_instantiated := false
var has_entered: bool = false
const ENTRY_DISTANCE: int = 64

var _soul_hold_timer: float = 0.0
var _soul_hold_active: bool = false
var _soul_hold_cell: Vector2i = Vector2i.ZERO

@onready var _soul_particles: CPUParticles2D = $SoulParticles
@onready var _soul_particles_center: CPUParticles2D = $SoulParticlesCenter


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not has_entered:
		has_entered = position.distance_squared_to(last_safe_position) > ENTRY_DISTANCE


func state_default() -> void:
	velocity = input_direction * speed
	move_and_slide()
	_update_sprite_direction(input_direction)
	_check_collisions()

	# Handle animations
	if velocity:
		if is_on_wall() and ((test_move(transform, Vector2.DOWN) and sprite_direction == "Down")
				or (test_move(transform, Vector2.UP) and sprite_direction == "Up")
				or (test_move(transform, Vector2.RIGHT) and sprite_direction == "Right")
				or (test_move(transform, Vector2.LEFT) and sprite_direction == "Left")):
			_play_animation("Push")
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
	if in_battle: return
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

	if soul_data.is_empty():
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
	_absorb_soul(soul_data, map.scene_file_path, cell)


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
