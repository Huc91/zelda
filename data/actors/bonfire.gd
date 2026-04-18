class_name Bonfire extends Area2D

const INTERACT_ACTION: String = "b"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var lit: bool = false
var _player_nearby: bool = false
var _info_box: InfoBox


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	lit = Global.is_bonfire_lit(position, Global.current_map_path)
	_refresh_sprite()
	_info_box = InfoBox.new()
	call_deferred("_add_info_box")


func _add_info_box() -> void:
	if is_instance_valid(_info_box) and not _info_box.is_inside_tree():
		get_tree().root.add_child(_info_box)


func _exit_tree() -> void:
	if is_instance_valid(_info_box):
		_info_box.queue_free()


func _process(_delta: float) -> void:
	if not _player_nearby:
		return
	if Input.is_action_just_pressed(INTERACT_ACTION):
		if lit:
			_rest()
		else:
			_light()


func _light() -> void:
	lit = true
	_refresh_sprite()
	_do_rest()
	_info_box.show_flash("Bonfire lit! Game saved.", 2.5)


func _rest() -> void:
	_do_rest()
	_info_box.show_flash("Rested. Game saved.", 2.5)


func _do_rest() -> void:
	Global.activate_bonfire(position, Global.current_map_path)
	Global.restore_lives()
	Global.save_game()
	Global.bonfire_rested.emit()


func _refresh_sprite() -> void:
	if lit:
		sprite.play("Lit")
	else:
		sprite.play("Unlit")


func _on_body_entered(body: Node) -> void:
	if body is Actor and (body as Actor).actor_type == 1:
		_player_nearby = true
		if not _info_box.is_queued_for_deletion():
			var hint: String = "Press Z to rest" if lit else "Press Z to light bonfire"
			_info_box.show_hint(hint)


func _on_body_exited(_body: Node) -> void:
	_player_nearby = false
	if is_instance_valid(_info_box):
		_info_box.hide_hint()
