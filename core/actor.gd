@icon("res://editor/svg/Actor.svg")
class_name Actor extends CharacterBody2D

static var SHADER = preload("res://data/vfx/actor.gdshader")
static var DEATH_FX = preload("res://data/vfx/enemy_death.tres")
static var DROWN_SFX = preload("res://data/sfx/LA_Link_Wade1.wav")
static var DROWN_VFX = preload("res://data/vfx/drown.tres")
static var KB_TIME = 0.2
static var KB_AMT = 100

@export_enum("Enemy", "Player") var actor_type
@export var speed := 70.0
@export var hearts := 1.0
@export var damage := 0.5
@export var hit_sfx = preload("res://data/sfx/LA_Enemy_Hit.wav")
## Difficulty determines money reward and battle deck used. Values: "easy" / "normal" / "hard" / "boss"
@export var difficulty: String = "easy"
@onready var health = hearts

var current_state = state_default
var last_state = state_default
var elapsed_state_time := 0.0
var sprite_direction := "Down"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
var ray: RayCast2D
var hitbox: Area2D

var in_battle := false
## Seconds of post-respawn invulnerability remaining. Enemies cannot trigger battle while > 0.
var invulnerable_timer: float = 0.0
## Respawn / scene placement (player); overworld shadows also get this set on spawn.
var last_safe_position: Vector2 = Vector2.ZERO
var battle_deck: Array = []
var _home_sector: Vector2 = Vector2.ZERO
var _home_sector_set: bool = false

signal on_hit

func _ready() -> void:
	add_to_group("actor")
	
	_init_shader()
	_init_raycast()
	_init_hitbox()
	
	ray.add_exception(hitbox)
	
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	if actor_type == 0:
		_home_sector = Vector2(
			floor(position.x / GridCamera.CELL_SIZE.x),
			floor(position.y / GridCamera.CELL_SIZE.y)
		)
		_home_sector_set = true


func _init_shader() -> void:
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = SHADER


func _init_raycast() -> void:
	ray = RayCast2D.new()
	ray.target_position = Vector2.ZERO
	ray.hit_from_inside = true
	ray.collide_with_areas = true
	ray.set_collision_mask_value(2, true) # collides with entities
	add_child(ray)

func _init_hitbox() -> void:
	# We want to make an area2D that is slightly larger than
	#  the actor's current shape.
	hitbox = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	var actor_size: Vector2 = collision.shape.size
	hitbox.add_child(collision_shape)
	collision_shape.shape = rectangle_shape
	rectangle_shape.size = actor_size + Vector2.ONE
	hitbox.set_collision_mask_value(2, true) # collides with entities
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
		# Blink ~8 times/sec while invulnerable; restore when done.
		sprite.visible = int(invulnerable_timer * 16.0) % 2 == 0
		if invulnerable_timer == 0.0:
			sprite.visible = true
	_state_process(delta)
	if actor_type == 0:
		_constrain_enemy_to_home_sector()


# -------------------
# State machine stuff

func _state_process(delta) -> void:
	current_state.call()
	last_state = current_state
	elapsed_state_time += delta


func _change_state(new_state) -> void:
	elapsed_state_time = 0
	current_state = new_state


func state_default() -> void:
	pass


func state_hurt() -> void:
	sprite.material.set_shader_parameter("is_hurt", true)
	move_and_slide()
	
	if elapsed_state_time > KB_TIME:
		if health <= 0:
			_die()
		else:
			sprite.material.set_shader_parameter("is_hurt", false)
			_change_state(state_default)


func state_drown() -> void:
	Sound.play(DROWN_SFX)
	_oneshot_vfx(DROWN_VFX)
	queue_free()

# -------------------


func _snap_position() -> void:
	position = position.snapped(Vector2.ONE)


## Single cardinal axis for movement/facing (length 1 on one axis, or ZERO).
## Near-diagonals use a tie-break so facing always updates (avoids stale Up/Right).
func _dominant_cardinal_vector(vector: Vector2) -> Vector2:
	if vector == Vector2.ZERO:
		return Vector2.ZERO
	var abs_x: float = absf(vector.x)
	var abs_y: float = absf(vector.y)
	const AXIS_SWITCH_BIAS: float = 0.12
	if abs_x > abs_y + AXIS_SWITCH_BIAS:
		return Vector2(signf(vector.x), 0.0)
	if abs_y > abs_x + AXIS_SWITCH_BIAS:
		return Vector2(0.0, signf(vector.y))
	if abs_x >= abs_y:
		return Vector2(signf(vector.x), 0.0)
	return Vector2(0.0, signf(vector.y))


# Sets sprite direction to last orthogonal direction.
func _update_sprite_direction(vector : Vector2) -> void:
	if vector == Vector2.ZERO:
		return
	var axis: Vector2 = _dominant_cardinal_vector(vector)
	if axis.x > 0.0:
		sprite_direction = "Right"
	elif axis.x < 0.0:
		sprite_direction = "Left"
	elif axis.y > 0.0:
		sprite_direction = "Down"
	elif axis.y < 0.0:
		sprite_direction = "Up"


# Plays an animation from a directioned set.
func _play_animation(animation : String) -> void:
	var direction = "Side" if sprite_direction in ["Left", "Right"] else sprite_direction
	sprite.play(animation + direction)
	sprite.flip_h = sprite_direction == "Left"


func _die() -> void:
	Sound.play(preload("res://data/sfx/LA_Enemy_Die.wav"))
	_oneshot_vfx(DEATH_FX)
	queue_free()


# Instances item and passes self as its user.
func _use_item(item) -> void:
	var instance = item.instantiate()
	get_parent().add_child(instance)
	instance.activate(self)


# Returns a random orthogonal direction.
func _get_random_direction() -> Vector2:
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	return directions[randi() % directions.size()]


func _check_collisions():
	var ray_offset = 2
	var ray_length = 12
	var collision_offset = 1
	# Update raycast direction when moving
	if velocity:
		var direction = velocity.normalized()
		ray.position = direction * -ray_offset
		ray.target_position = direction * ray_length
		
		if direction.x != 0 and collision.position.x != direction.x and not test_move(transform, Vector2(direction.x, 0)):
			collision.position.x = direction.x * collision_offset
		if direction.y != 0 and collision.position.y != direction.y and not test_move(transform, Vector2(0, direction.y)):
			collision.position.y = direction.y * collision_offset
	
	# Handle collisions
	if ray.is_colliding():
		var other = ray.get_collider()
		
		if other is Map:
			var on_step = other.on_step(self)
			if has_method(on_step):
				call(on_step)
		elif other is Attack:
			if other.actor_type != actor_type and other.damage > 0:
				_on_attacked(other)
		else:
			_custom_collision(other)

	for other in hitbox.get_overlapping_bodies():
		if other is Actor:
			var other_actor: Actor = other as Actor
			if other_actor.actor_type != actor_type and other_actor.damage > 0:
				if invulnerable_timer > 0.0 or other_actor.invulnerable_timer > 0.0:
					continue
				_on_attacked(other)


func _custom_collision(_other):
	pass


func _constrain_enemy_to_home_sector() -> void:
	if not _home_sector_set:
		return
	var sector_origin: Vector2 = Vector2(
		_home_sector.x * GridCamera.CELL_SIZE.x,
		_home_sector.y * GridCamera.CELL_SIZE.y
	)
	var min_x: float = sector_origin.x + 1.0
	var min_y: float = sector_origin.y + 1.0
	var max_x: float = sector_origin.x + GridCamera.CELL_SIZE.x - 1.0
	var max_y: float = sector_origin.y + GridCamera.CELL_SIZE.y - 1.0
	var clamped: Vector2 = position
	clamped.x = clampf(clamped.x, min_x, max_x)
	clamped.y = clampf(clamped.y, min_y, max_y)
	if clamped != position:
		position = clamped


# Override in subclasses to intercept hits (e.g. trigger card battle).
# Default: apply damage normally.
func _on_attacked(source: Node) -> void:
	_hit(source.damage, source.position)


func _oneshot_vfx(frames : SpriteFrames) -> void:
	var new_fx = AnimatedSprite2D.new()
	new_fx.animation_finished.connect(new_fx.queue_free)
	new_fx.position = position
	new_fx.sprite_frames = frames
	new_fx.play()
	get_parent().add_child(new_fx)


# Setup hit state and switch
func _hit(amount, pos) -> void:
	velocity = (position - pos).normalized() * KB_AMT
	health -= amount
	Sound.play(hit_sfx)
	emit_signal("on_hit", health)
	_change_state(state_hurt)


func drown() -> void:
	_change_state(state_drown)


func get_battle_deck() -> Array:
	if battle_deck.is_empty():
		battle_deck = CardDB.enemy_deck_for_difficulty(difficulty)
	return battle_deck.duplicate(true)
