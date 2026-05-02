extends Actor

## Difficulty color tints
const DIFF_MODULATE: Dictionary = {
	"easy":   Color(0.9, 0.85, 0.7),
	"normal": Color(0.7, 0.6, 1.0),
	"hard":   Color(1.0, 0.35, 0.35),
}

const SWORD_SCENE: PackedScene = preload("res://data/actors/attacks/sword.tscn")
const GLOVE_SCENE: PackedScene = preload("res://data/actors/attacks/duel_glove.tscn")
const ENEMY_GLOVE_TINT: Color = Color(1.0, 0.35, 0.35)
const SKULL_SCENE: PackedScene = preload("res://data/actors/skull.tscn")
const SKULL_SPAWN_OFFSET: Vector2 = Vector2(0, -24)
const ATTACK_RANGE: float = 36.0
const ATTACK_COOLDOWN: float = 0.9

@export var aggro_range: float = 80.0
@export var wander_time: float = 1.4
## Human soldiers: after winning the card battle, offer Spare / Kill (same persistence as duelists).
@export var offers_card_battle_mercy: bool = false
@export var mercy_display_name: String = "Soldier"
## Lines before card battle (mercy duelists / human soldiers with spare-kill flow).
@export var taunt_lines: PackedStringArray = PackedStringArray([
	"Now we fight.",
	"Cards. Now.",
	"You picked the wrong fight.",
])

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

var _mercy_spawn_position: Vector2 = Vector2.ZERO
var _mercy_ui_active: bool = false
var _mercy_chose_kill: bool = false


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
	if _mercy_save_key() != "":
		_mercy_spawn_position = position
		if not Global.bonfire_rested.is_connected(Callable(self, "_on_mercy_bonfire_rested")):
			Global.bonfire_rested.connect(_on_mercy_bonfire_rested)
		_apply_mercy_persistent_state()


## Override on duelist (fixed id). Shadows should keep default "".
func _mercy_save_key() -> String:
	if not offers_card_battle_mercy:
		return ""
	var m: Map = _get_map()
	var mp: String = m.scene_file_path if m != null else ""
	return "%s#%s" % [mp, str(name)]


## Kabba-style overworld: taunt, red duel glove (not sword), then card battle + spare/kill.
func _wants_duel_glove_overworld() -> bool:
	return _mercy_save_key() != ""


func get_name_label() -> String:
	if _mercy_save_key() != "":
		return mercy_display_name
	return str(name)


func _on_mercy_bonfire_rested() -> void:
	var k: String = _mercy_save_key()
	if k == "":
		return
	if Global.duelist_states.get(k, Global.DUELIST_ST_ALIVE) != Global.DUELIST_ST_SPARED_HIDDEN:
		return
	Global.duelist_states[k] = Global.DUELIST_ST_ALIVE
	_mercy_chose_kill = false
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	position = _mercy_spawn_position
	sprite.show()
	sprite.modulate = DIFF_MODULATE.get(difficulty, DIFF_MODULATE["easy"])


func _apply_mercy_persistent_state() -> void:
	var k: String = _mercy_save_key()
	var st: int = int(Global.duelist_states.get(k, Global.DUELIST_ST_ALIVE))
	match st:
		Global.DUELIST_ST_SKULL_DONE:
			queue_free()
			return
		Global.DUELIST_ST_KILLED_SKULL:
			sprite.modulate = Color.BLACK
			sprite.hide()
			set_collision_layer_value(1, false)
			set_collision_layer_value(2, false)
			process_mode = Node.PROCESS_MODE_DISABLED
			if get_node_or_null("Skull") == null:
				_mercy_spawn_skull_remains()
		Global.DUELIST_ST_MERCY_PENDING:
			if not Global.in_battle:
				call_deferred("offer_post_victory_mercy")
		Global.DUELIST_ST_SPARED_HIDDEN:
			visible = false
			set_collision_layer_value(1, false)
			set_collision_layer_value(2, false)
			process_mode = Node.PROCESS_MODE_DISABLED
		_:
			pass


func defer_battle_reward_until_mercy() -> bool:
	return _mercy_save_key() != ""


func should_skip_battle_reward() -> bool:
	var k: String = _mercy_save_key()
	if k == "":
		return false
	var st: int = int(Global.duelist_states.get(k, Global.DUELIST_ST_ALIVE))
	## Spare still counts as a won fight — grant loot. Only skip after skull was fully absorbed.
	return st == Global.DUELIST_ST_SKULL_DONE


func get_battle_gold_multiplier() -> float:
	if _mercy_save_key() == "":
		return 1.0
	return 1.2 if _mercy_chose_kill else 1.0


func on_card_battle_won() -> void:
	var k: String = _mercy_save_key()
	if k != "":
		Global.duelist_states[k] = Global.DUELIST_ST_MERCY_PENDING
	else:
		queue_free()


func offer_post_victory_mercy() -> void:
	var k: String = _mercy_save_key()
	if k == "":
		return
	if int(Global.duelist_states.get(k, Global.DUELIST_ST_ALIVE)) != Global.DUELIST_ST_MERCY_PENDING:
		return
	if _mercy_ui_active:
		return
	_mercy_ui_active = true
	get_tree().paused = true
	var dlg: DialogueBox = DialogueBox.new()
	get_tree().root.add_child(dlg)
	dlg.show_sequence(NPCDialogues.get_duelist_post_victory_mercy(), get_name_label())
	var ev: Variant = await dlg.finished
	var evs: String = str(ev)
	if evs == "duelist_spare":
		await _mercy_spare_sequence()
	elif evs == "duelist_kill":
		await _mercy_kill_sequence()
	get_tree().paused = false
	_mercy_ui_active = false


func _mercy_spare_sequence() -> void:
	var dlg2: DialogueBox = DialogueBox.new()
	get_tree().root.add_child(dlg2)
	dlg2.show_sequence({"lines": ["Next time, then.", "You were lucky."]}, get_name_label())
	await dlg2.finished
	var k: String = _mercy_save_key()
	if k != "":
		Global.duelist_states[k] = Global.DUELIST_ST_SPARED_HIDDEN
	await _mercy_walk_off_camera_then_hide()


func _mercy_kill_sequence() -> void:
	_mercy_chose_kill = true
	get_tree().paused = false
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color.BLACK, 0.35)
	await tw.finished
	sprite.hide()
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	_mercy_spawn_skull_remains()
	var k: String = _mercy_save_key()
	if k != "":
		Global.duelist_states[k] = Global.DUELIST_ST_KILLED_SKULL
	process_mode = Node.PROCESS_MODE_DISABLED
	Global.apply_post_kill_world_rules(self, true)


func _mercy_spawn_skull_remains() -> void:
	var map: Map = _get_map()
	if map == null:
		return
	var sk: Node = SKULL_SCENE.instantiate()
	add_child(sk)
	var skull_world: Vector2 = global_position + SKULL_SPAWN_OFFSET
	(sk as Node2D).global_position = skull_world
	if sk.has_method("setup"):
		sk.call("setup", map.scene_file_path, skull_world, map)


func _mercy_walk_off_camera_then_hide() -> void:
	get_tree().paused = false
	var map: Map = _get_map()
	var p: Actor = _get_player()
	if map == null or p == null:
		_mercy_apply_spare_hidden_transform()
		return
	var my_sec: Vector2i = Vector2i(
		int(floor(global_position.x / GridCamera.CELL_SIZE.x)),
		int(floor(global_position.y / GridCamera.CELL_SIZE.y))
	)
	var p_sec: Vector2i = Vector2i(
		int(floor(p.global_position.x / GridCamera.CELL_SIZE.x)),
		int(floor(p.global_position.y / GridCamera.CELL_SIZE.y))
	)
	var delta_sec: Vector2i = my_sec - p_sec
	if delta_sec == Vector2i.ZERO:
		delta_sec = Vector2i(1, 0)
	var signx: int = signi(delta_sec.x)
	var signy: int = signi(delta_sec.y)
	if signx == 0:
		signx = 1
	if signy == 0:
		signy = 1
	var away: Vector2i = my_sec + Vector2i(signx * 3, signy * 3)
	var tw: Vector2 = GridCamera.CELL_SIZE
	var target: Vector2 = Vector2(
		float(away.x) * tw.x + tw.x * 0.5,
		float(away.y) * tw.y + tw.y * 0.5
	)
	var twm: Tween = create_tween()
	twm.tween_property(self, "position", target, 1.8)
	await twm.finished
	_mercy_apply_spare_hidden_transform()


func _mercy_apply_spare_hidden_transform() -> void:
	visible = false
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	process_mode = Node.PROCESS_MODE_DISABLED


func on_world_soul_absorb(_world_soul: Node) -> Dictionary:
	var k: String = _mercy_save_key()
	if k == "":
		return {}
	var ids: Array[String] = []
	var built: Array = get_battle_deck()
	ids = Global.card_ids_from_built_deck(built)
	return Global.try_duelist_skull_absorb(ids, get_name_label())


func on_world_soul_absorbed(_world_soul: Node) -> void:
	var k: String = _mercy_save_key()
	if k == "":
		return
	Global.duelist_states[k] = Global.DUELIST_ST_SKULL_DONE
	queue_free()


func _on_attacked(_source: Node) -> void:
	if in_battle:
		return
	if _wants_duel_glove_overworld():
		_taunt_then_start_card_battle()
	else:
		in_battle = true
		Global.request_card_battle(true, self)


func _taunt_then_start_card_battle() -> void:
	get_tree().paused = true
	var dlg: DialogueBox = DialogueBox.new()
	get_tree().root.add_child(dlg)
	var lines: PackedStringArray = taunt_lines
	var line: String = "Now we fight."
	if lines.size() > 0:
		line = lines[randi() % lines.size()]
	dlg.show_sequence({"lines": [line]}, get_name_label())
	await dlg.finished
	get_tree().paused = false
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
		if _wants_duel_glove_overworld():
			var gl: Node = GLOVE_SCENE.instantiate()
			get_parent().add_child(gl)
			(gl as Attack).activate(self)
			var spr: Sprite2D = gl.get_node_or_null("Sprite2D") as Sprite2D
			if spr != null:
				spr.modulate = ENEMY_GLOVE_TINT
		else:
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
