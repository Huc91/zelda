extends Actor

## Difficulty color tints
const DIFF_MODULATE: Dictionary = {
	"easy":   Color(0.9, 0.85, 0.7),
	"normal": Color(0.7, 0.6, 1.0),
	"hard":   Color(1.0, 0.35, 0.35),
}

@export var aggro_range: float = 80.0
@export var wander_time: float = 1.4

var move_direction: Vector2 = Vector2.DOWN
var _player: Actor = null

var _path: PackedVector2Array = PackedVector2Array()
var _path_idx: int = 0
var _path_timer: float = 0.0
const PATH_REFRESH: float = 0.35
const WAYPOINT_REACH: float = 6.0


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
	health = hearts


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
	if is_on_wall():
		move_direction = _get_random_direction()
		_change_state(state_wander)
		return

	velocity = move_direction * speed
	move_and_slide()
	_check_collisions()
	_update_sprite_direction(move_direction)
	_play_animation("Walk")

	var p: Actor = _get_player()
	if p != null and position.distance_to(p.position) <= aggro_range:
		_path = PackedVector2Array()
		_path_idx = 0
		_path_timer = 0.0
		_change_state(state_chase)
		return

	if elapsed_state_time > wander_time:
		_change_state(state_default)


func state_chase() -> void:
	var p: Actor = _get_player()
	if p == null:
		_change_state(state_default)
		return

	var dt: float = get_process_delta_time()
	_path_timer -= dt

	if _path_timer <= 0.0 or _path_idx >= _path.size():
		_path_timer = PATH_REFRESH
		var map: Map = _get_map()
		if map != null:
			_path = map.nav_find_path(position, p.position)
			_path_idx = 0
			if _path.size() > 0 and position.distance_to(_path[0]) < WAYPOINT_REACH:
				_path_idx = 1

	var dir: Vector2 = Vector2.ZERO
	if _path_idx < _path.size():
		var target: Vector2 = _path[_path_idx]
		dir = (target - position).normalized()
		if position.distance_to(target) < WAYPOINT_REACH:
			_path_idx += 1
	else:
		dir = (p.position - position).normalized()

	if dir != Vector2.ZERO:
		velocity = dir * speed
		move_and_slide()
		_check_collisions()
		_update_sprite_direction(dir)
		_play_animation("Walk")
		move_direction = dir

	if position.distance_to(p.position) > aggro_range * 1.6:
		_path = PackedVector2Array()
		_path_idx = 0
		_change_state(state_default)
