extends Attack

@onready var anim: AnimationPlayer = $AnimationPlayer

const SOUNDS = [
	preload("res://data/sfx/LA_Sword_Slash1.wav"),
	preload("res://data/sfx/LA_Sword_Slash2.wav"),
	preload("res://data/sfx/LA_Sword_Slash3.wav"),
	preload("res://data/sfx/LA_Sword_Slash4.wav"),
]
const FRONT_REACH: float = 24.0
const FRONT_SLACK: float = 12.0

var target_cell_position : Vector2:
	get:
		var user_cell: Vector2 = user.position.snapped(Vector2(8, 8))
		
		match user.sprite_direction:
			"Left":
				return user_cell + Vector2(-24, 0)
			"Right":
				return user_cell + Vector2(16, 0)
			"Up":
				return user_cell + Vector2(-8, -16)
			"Down":
				return user_cell + Vector2(0, 16)
		
		return user_cell


var _hit_actor_ids: Dictionary = {}
var _slashed_cells: Dictionary = {}


func activate(u: Actor) -> void:
	user = u
	actor_type = user.actor_type
	if user.has_method("get_sword_damage"):
		damage = user.get_sword_damage()
	else:
		damage = 0.5
	user.current_state = user.state_swing
	user.connect("on_hit", queue_free)
	user.ray.add_exception(self)
	position = user.position
	
	anim.play(str("Swing", user.sprite_direction))
	Sound.play(SOUNDS[randi() % SOUNDS.size()])
	call_deferred("_check_actor_hits")
	call_deferred("_check_front_hits")
	call_deferred("_check_map_slash")


func _physics_process(_delta: float) -> void:
	_check_actor_hits()
	_check_front_hits()
	_check_map_slash()


func _check_actor_hits() -> void:
	for body: Node2D in get_overlapping_bodies():
		if body is Actor:
			_try_hit_actor(body as Actor)


func _check_front_hits() -> void:
	if user == null:
		return
	for node: Node in get_tree().get_nodes_in_group("actor"):
		if node is Actor:
			_try_hit_front(node as Actor)


func _try_hit_front(a: Actor) -> void:
	if a == user or a.actor_type == actor_type or a.in_battle:
		return
	var delta: Vector2 = a.position - user.position
	match user.sprite_direction:
		"Left":
			if delta.x > 0.0 or delta.x < -FRONT_REACH or absf(delta.y) > FRONT_SLACK:
				return
		"Right":
			if delta.x < 0.0 or delta.x > FRONT_REACH or absf(delta.y) > FRONT_SLACK:
				return
		"Up":
			if delta.y > 0.0 or delta.y < -FRONT_REACH or absf(delta.x) > FRONT_SLACK:
				return
		"Down":
			if delta.y < 0.0 or delta.y > FRONT_REACH or absf(delta.x) > FRONT_SLACK:
				return
	_try_hit_actor(a)


func _try_hit_actor(a: Actor) -> void:
	if a.actor_type == actor_type or a.in_battle:
		return
	var actor_id: int = a.get_instance_id()
	if _hit_actor_ids.has(actor_id):
		return
	_hit_actor_ids[actor_id] = true
	a._on_attacked(self)


func _check_map_slash() -> void:
	if user == null:
		return
	var parent_node: Node = user.get_parent()
	if not (parent_node is Map):
		return
	var map: Map = parent_node as Map
	var cell: Vector2i = map.local_to_map(target_cell_position)
	if _slashed_cells.has(cell):
		return
	_slashed_cells[cell] = true
	map.slash(cell)


func _on_swing_finished() -> void:
	if user != null and user.has_method("_on_sword_swing_finished"):
		user._on_sword_swing_finished()
	else:
		user.current_state = user.state_default
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Map:
		var map: Map = body as Map
		var cell: Vector2i = map.local_to_map(target_cell_position)
		map.slash(cell)
	elif body is Actor:
		_try_hit_actor(body as Actor)
