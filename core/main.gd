extends Control

const STARTING_MAP: String = "res://data/maps/overworld.tscn"
const STARTING_ENTRANCE := Vector2i(116, 80)

@onready var screen = $Screen
@onready var player = preload("res://data/actors/player/player.tscn").instantiate()
@onready var ui = preload("res://core/ui/ui.tscn").instantiate()
var current_scene: GameScene

func _ready():
	initialize_scene(STARTING_MAP, STARTING_ENTRANCE)
	# UI must be a sibling of Screen, not a child of SubViewportContainer, or mouse hits the
	# embedded SubViewport first and Control buttons (e.g. deck DELETE) never receive clicks.
	add_child(ui)
	ui.initialize(player)
	Global.card_battle_requested.connect(_on_card_battle_requested)


func initialize_scene(map, entrance):
	get_tree().paused = false
	current_scene = GameScene.new(map, entrance, player)
	current_scene.map_changed.connect(initialize_scene)
	screen.add_child(current_scene)
	await ScreenFX.fade_white_out()


func _on_card_battle_requested(p_first: bool, enemy: Node) -> void:
	Global.in_battle = true
	# Disconnect to prevent re-entry while battle is active
	Global.card_battle_requested.disconnect(_on_card_battle_requested)
	# Freeze all actors
	for actor in get_tree().get_nodes_in_group("actor"):
		actor.set_physics_process(false)
	await ScreenFX.fade_white_in()
	var battle := CardBattle.new()
	add_child(battle)
	battle.setup(p_first, enemy)
	battle.battle_ended.connect(_on_battle_ended.bind(battle, enemy))
	await ScreenFX.fade_white_out()


func _on_battle_ended(player_won: bool, battle: Node, enemy: Node) -> void:
	Global.in_battle = false
	await ScreenFX.fade_white_in()
	battle.queue_free()
	if player_won and is_instance_valid(enemy):
		enemy.queue_free()
	# Unfreeze all living actors and reset battle flag
	for actor in get_tree().get_nodes_in_group("actor"):
		if is_instance_valid(actor) and actor is Actor:
			actor.set_physics_process(true)
			actor.in_battle = false
	await ScreenFX.fade_white_out()
	Global.card_battle_requested.connect(_on_card_battle_requested)
