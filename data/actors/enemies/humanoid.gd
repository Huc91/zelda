extends Actor

## Difficulty color tints
const DIFF_MODULATE: Dictionary = {
	"easy":   Color(0.9, 0.85, 0.7),
	"normal": Color(0.7, 0.6, 1.0),
	"hard":   Color(1.0, 0.35, 0.35),
}

const SWORD_SCENE: PackedScene = preload("res://data/actors/attacks/sword.tscn")
const ATTACK_RANGE: float = 36.0
const ATTACK_COOLDOWN: float = 0.9

@export var aggro_range: float = 80.0
@export var wander_time: float = 1.4

var move_direction: Vector2 = Vector2.DOWN
var _player: Actor = null
## Per-scene damage applies to sword swings only; body contact uses 0 (see _ready).
var _sword_damage: float = 0.5

var _path: PackedVector2Array = PackedVector2Array()
var _path_idx: int = 0
var _path_timer: float = 0.0
var _attack_cooldown: float = 0.0
const PATH_REFRESH: float = 0.35
const WAYPOINT_REACH: float = 6.0
const SPEED_MULT: float = 0.8
const ATTACK_ALIGN_SLACK: float = 10.0
const AXIS_LOCK_BIAS: float = 0.1
const PLAYER_SPACE_RADIUS: float = 14.0


func _ready() -> void:
	super._ready()
	sprite.modulate = DIFF_MODULATE.get(difficulty, DIFF_MODULATE["easy"])
	match difficulty:
		"normal":
			hearts = 1.0
			speed = 58.0
		"hard":
			hearts = 2.0
			speed = 72.0
	speed *= SPEED_MULT
	health = hearts
	_sword_damage = damage
	damage = 0.0


func _on_attacked(_source: Node) -> void:
	if in_battle: return
	in_battle = true
	Global.request_card_battle(true, self)


func _get_player() -> Actor:
	if _player != null and is_instance_valid(_player):
		return _player
	for node: Node in get_tree().get_nodes_in_group("actor"):
		if node is Actor and node.actor_type == 1:
			_player = node as Actor
			return _player
	return null


func _get_map() -> Map:
	var p: Node = get_parent()
	if p is Map:
		return p as Map
	return null


func get_sword_damage() -> float:
	return _sword_damage


func _play_humanoid_walk(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_update_sprite_direction(dir)
	_play_animation("Walk")
	sprite.flip_h = sprite_direction == "Right"


func _refresh_path(target_pos: Vector2) -> void:
	_path_timer = PATH_REFRESH
	var map: Map = _get_map()
	if map == null:
		_path = PackedVector2Array()
		_path_idx = 0
		return
	_path = map.nav_find_path(position, target_pos)
	_path_idx = 0


func _get_chase_direction(target_pos: Vector2) -> Vector2:
	while _path_idx < _path.size() and position.distance_to(_path[_path_idx]) < WAYPOINT_REACH:
		_path_idx += 1
	if _path_idx < _path.size():
		return (_path[_path_idx] - position).normalized()
	return (target_pos - position).normalized()


func _axis_locked_direction(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var abs_x: float = absf(dir.x)
	var abs_y: float = absf(dir.y)
	if abs_x > abs_y + AXIS_LOCK_BIAS:
		return Vector2.RIGHT if dir.x > 0.0 else Vector2.LEFT
	if abs_y > abs_x + AXIS_LOCK_BIAS:
		return Vector2.DOWN if dir.y > 0.0 else Vector2.UP
	if move_direction.x != 0.0:
		return Vector2.RIGHT if dir.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if dir.y >= 0.0 else Vector2.UP


func _can_attack_player(to_p: Vector2) -> bool:
	var abs_x: float = absf(to_p.x)
	var abs_y: float = absf(to_p.y)
	if abs_x >= abs_y:
		return abs_x <= ATTACK_RANGE and abs_y <= ATTACK_ALIGN_SLACK
	return abs_y <= ATTACK_RANGE and abs_x <= ATTACK_ALIGN_SLACK


func _can_enter_player_space(dir: Vector2, player: Actor, dt: float) -> bool:
	if dir == Vector2.ZERO:
		return false
	var next_pos: Vector2 = position + dir * speed * dt
	return next_pos.distance_to(player.position) < PLAYER_SPACE_RADIUS


func _secondary_chase_direction(to_p: Vector2, primary_dir: Vector2) -> Vector2:
	if primary_dir.x != 0.0:
		if absf(to_p.y) <= 0.001:
			return Vector2.ZERO
		return Vector2.DOWN if to_p.y > 0.0 else Vector2.UP
	if primary_dir.y != 0.0:
		if absf(to_p.x) <= 0.001:
			return Vector2.ZERO
		return Vector2.RIGHT if to_p.x > 0.0 else Vector2.LEFT
	return Vector2.ZERO


func _on_sword_swing_finished() -> void:
	_attack_cooldown = ATTACK_COOLDOWN
	_change_state(state_chase)


# ── States ────────────────────────────────────────────────────

func state_default() -> void:
	var p: Actor = _get_player()
	if p != null and position.distance_to(p.position) <= aggro_range:
		_path = PackedVector2Array()
		_path_idx = 0
		_path_timer = 0.0
		_change_state(state_chase)
		return
	move_direction = _get_random_direction()
	_change_state(state_wander)


func state_wander() -> void:
	if Global.in_battle:
		return
	if is_on_wall():
		move_direction = _get_random_direction()

	velocity = move_direction * speed
	move_and_slide()
	_check_collisions()
	_play_humanoid_walk(move_direction)

	var p: Actor = _get_player()
	if p != null and position.distance_to(p.position) <= aggro_range:
		_path = PackedVector2Array()
		_path_idx = 0
		_path_timer = 0.0
		_change_state(state_chase)
		return

	if elapsed_state_time > wander_time:
		_change_state(state_default)


func state_swing() -> void:
	if Global.in_battle:
		return
	# Hold last walk frame; sword.tscn provides the blade motion.
	velocity = Vector2.ZERO
	sprite.stop()
	sprite.flip_h = sprite_direction == "Right"


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
		velocity = dir * speed
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
