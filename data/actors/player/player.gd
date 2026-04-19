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
				|| (test_move(transform, Vector2.UP) and sprite_direction == "Up")
				|| (test_move(transform, Vector2.RIGHT) and sprite_direction == "Right")
				|| (test_move(transform, Vector2.LEFT) and sprite_direction == "Left")):
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
	# Auto-equip if the soul's slot is still empty
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
	pass  # Soul state lives in Global; nothing to restore here.


func _get_facing_cell(map: Map) -> Vector2i:
	var face_offset: Vector2 = Vector2.ZERO
	match sprite_direction:
		"Left":  face_offset = Vector2(-8, 0)
		"Right": face_offset = Vector2(8, 0)
		"Up":    face_offset = Vector2(0, -8)
		"Down":  face_offset = Vector2(0, 8)
	return map.local_to_map(position + face_offset)


func _update_soul_catch(dt: float) -> void:
	var map: Map = _get_map()
	if map == null:
		return

	var holding: bool = Input.is_action_pressed("interact")

	if not holding:
		_soul_hold_timer = 0.0
		_soul_hold_active = false
		return

	var cell: Vector2i = _get_facing_cell(map)
	var soul_type: String = map.get_soulable_type(cell)

	# Only valid soulable tiles trigger the hold.
	if soul_type == "":
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
	if _soul_hold_timer < SOUL_HOLD_TIME:
		return

	# 2 seconds held — absorb.
	_soul_hold_active = true
	_absorb_soul(soul_type, map, cell)


func _absorb_soul(soul_type: String, map: Map, cell: Vector2i) -> void:
	if Global.caught_souls.get(soul_type, false):
		_show_soul_dialog("You already carry the " + soul_type.capitalize() + " Soul.")
		return
	Global.caught_souls[soul_type] = true
	Global.add_soul_to_collection(soul_type)
	var soul: SoulItem = Global.SOULS.get(soul_type, null) as SoulItem
	if soul != null:
		var slot_empty: bool = false
		match soul.slot:
			"red":   slot_empty = Global.equipped_soul_red == ""
			"blue":  slot_empty = Global.equipped_soul_blue == ""
			"green": slot_empty = Global.equipped_soul_green == ""
		if slot_empty:
			Global.equip_soul(soul_type)
	_show_soul_dialog(soul_type.capitalize() + " Soul absorbed!")


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
