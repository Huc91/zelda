extends Actor

## Color-coded difficulty modulate (applied in _ready after sprite init).
const DIFF_MODULATE: Dictionary = {
	"easy":   Color(0.5, 1.0, 0.5),   ## green tint
	"normal": Color(0.5, 0.7, 1.0),   ## blue tint
	"hard":   Color(1.0, 0.4, 0.4),   ## red tint
}


func _ready() -> void:
	super._ready()
	# Apply difficulty color tint and scale HP/speed with difficulty
	var mod: Color = DIFF_MODULATE.get(difficulty, DIFF_MODULATE["easy"])
	sprite.modulate = mod
	match difficulty:
		"normal":
			hearts = 1.0
			speed = 55.0
		"hard":
			hearts = 2.0
			speed = 70.0
	health = hearts


func _on_attacked(_source: Node) -> void:
	if in_battle: return
	in_battle = true
	Global.request_card_battle(true, self)

const ROK_PROJECTILE = preload("res://data/actors/attacks/rok.tscn")

@export var move_time : float = 1.0
@export var wait1_time : float = 1.0
@export var wait2_time : float = 1.0

var move_direction = Vector2.DOWN


func state_default() -> void:
	move_direction = _get_random_direction()
	_change_state(state_move)


func state_move() -> void:
	if is_on_wall():
		move_direction = -move_direction
	
	velocity = move_direction * speed
	move_and_slide()
	
	_check_collisions()
	_update_sprite_direction(move_direction)
	_play_animation("Walk")
	sprite.flip_v = (sprite_direction == "Up")
	
	if elapsed_state_time > move_time:
		_change_state(state_wait1)


func state_wait1() -> void:
	sprite.stop()
	_check_collisions()
	if elapsed_state_time > wait1_time:
		_use_item(ROK_PROJECTILE)
		_change_state(state_wait2)


func state_wait2() -> void:
	_check_collisions()
	if elapsed_state_time > wait2_time:
		_change_state(state_default)
