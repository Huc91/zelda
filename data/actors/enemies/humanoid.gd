extends Actor

## Difficulty color tints
const DIFF_MODULATE: Dictionary = {
	"easy":   Color(0.9, 0.85, 0.7),
	"normal": Color(0.7, 0.6, 1.0),
	"hard":   Color(1.0, 0.35, 0.35),
}

## Range at which this enemy detects and chases the player (pixels)
@export var aggro_range: float = 80.0
## Wander duration before picking a new direction
@export var wander_time: float = 1.4

var move_direction: Vector2 = Vector2.DOWN
var _player: Actor = null


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
		if node is Actor and node.actor_type == 1:   # 1 == Player
			_player = node as Actor
			return _player
	return null


# ── States ────────────────────────────────────────────────────

func state_default() -> void:
	var p: Actor = _get_player()
	if p != null and position.distance_to(p.position) <= aggro_range:
		_change_state(state_chase)
		return
	move_direction = _get_random_direction()
	_change_state(state_wander)


func state_wander() -> void:
	if is_on_wall():
		# Reverse direction flips every frame → oscillation. Pick a fresh direction instead.
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
		_change_state(state_chase)
		return

	if elapsed_state_time > wander_time:
		_change_state(state_default)


func state_chase() -> void:
	var p: Actor = _get_player()
	if p == null:
		_change_state(state_default)
		return

	# Snap to 4 cardinal directions — classic Zelda-style pursuit
	var diff: Vector2 = p.position - position
	var dir: Vector2
	if absf(diff.x) > absf(diff.y):
		dir = Vector2(signf(diff.x), 0.0)
	else:
		dir = Vector2(0.0, signf(diff.y))

	move_direction = dir
	velocity = dir * speed
	move_and_slide()
	_check_collisions()
	_update_sprite_direction(dir)
	_play_animation("Walk")

	# Drop chase if player moved far away
	if position.distance_to(p.position) > aggro_range * 1.6:
		_change_state(state_default)
