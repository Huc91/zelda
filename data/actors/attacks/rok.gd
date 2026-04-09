extends Attack

@export var speed: float = 120.0
## Self-destruct after this many pixels — keeps rok within the room it was fired from.
@export var max_distance: float = 128.0

var velocity := Vector2.ZERO
var _travelled: float = 0.0

func activate(u: Actor) -> void:
	user = u
	actor_type = user.actor_type
	position = user.position
	velocity = user.move_direction * speed

func _physics_process(delta: float) -> void:
	var step: Vector2 = velocity * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()
