extends "res://data/actors/enemies/humanoid.gd"

var _shadow_uid: String = ""
var shadow_display_name: String = "Shadow"


func _ready() -> void:
	super._ready()
	add_to_group("shadow_enemy")
	sprite.modulate = Color(0.15, 0.15, 0.2)
	aggro_range *= 1.45
	speed *= 1.2


func setup_overworld_shadow(deck_ids: Array[String], p_display_name: String, uid: String) -> void:
	_shadow_uid = uid
	shadow_display_name = p_display_name
	battle_deck = CardDB.enemy_deck_from_card_ids(deck_ids)


func get_name_label() -> String:
	return shadow_display_name


func on_card_battle_won() -> void:
	Global.remove_overworld_shadow_uid(_shadow_uid)
	queue_free()


func state_chase() -> void:
	if Global.in_battle:
		return
	var p: Actor = _get_player()
	if p == null:
		_change_state(state_default)
		return

	var dt: float = get_process_delta_time()
	_attack_cooldown = maxf(0.0, _attack_cooldown - dt)

	var to_p: Vector2 = p.position - position
	var run_speed: float = speed
	if position.distance_to(p.position) < 72.0:
		run_speed *= 2.0

	if _attack_cooldown <= 0.0 and _can_attack_player(to_p):
		if to_p.length_squared() > 0.0001:
			move_direction = _axis_locked_direction(to_p.normalized())
			_play_humanoid_walk(move_direction)
		velocity = Vector2.ZERO
		var sw: Node = SWORD_SCENE.instantiate()
		get_parent().add_child(sw)
		(sw as Attack).activate(self)
		return

	_path_timer -= dt

	if _path_timer <= 0.0 or _path_idx >= _path.size():
		_refresh_path(p.position)

	var dir: Vector2 = _axis_locked_direction(_get_chase_direction(p.position))
	if _can_enter_player_space(dir, p, dt):
		var alt_dir: Vector2 = _secondary_chase_direction(to_p, dir)
		if alt_dir != Vector2.ZERO and not _can_enter_player_space(alt_dir, p, dt):
			dir = alt_dir
		else:
			dir = Vector2.ZERO

	if dir != Vector2.ZERO:
		velocity = dir * run_speed
		move_and_slide()
		_check_collisions()
		_play_humanoid_walk(dir)
		move_direction = dir
	else:
		velocity = Vector2.ZERO

	if position.distance_to(p.position) > aggro_range * 1.6:
		_path = PackedVector2Array()
		_path_idx = 0
		_change_state(state_default)
