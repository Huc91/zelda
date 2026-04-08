extends Control

const STARTING_MAP: String = "res://data/maps/overworld.tscn"
const STARTING_ENTRANCE := Vector2i(116, 80)

@onready var screen = $Screen
## Lazy so headless smoke (no overworld) does not spawn physics bodies for a discarded player instance.
var player: Actor
## Lazy so headless smoke does not build HUD / deck UI.
var ui: UI
var current_scene: GameScene


func _ensure_player() -> Actor:
	if player == null:
		player = preload("res://data/actors/player/player.tscn").instantiate() as Actor
	return player


func _ensure_ui() -> UI:
	if ui == null:
		ui = preload("res://core/ui/ui.tscn").instantiate() as UI
	return ui

func _headless_battle_smoke_requested() -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a == "headless-battle-smoke" or a == "--headless-battle-smoke":
			return true
	return false


func _ready():
	if _headless_battle_smoke_requested():
		call_deferred("_run_headless_battle_smoke")
		return
	_ensure_player()
	initialize_scene(STARTING_MAP, STARTING_ENTRANCE)
	# UI must be a sibling of Screen, not a child of SubViewportContainer, or mouse hits the
	# embedded SubViewport first and Control buttons (e.g. deck DELETE) never receive clicks.
	add_child(_ensure_ui())
	_ensure_ui().initialize(_ensure_player())
	Global.card_battle_requested.connect(_on_card_battle_requested)


func _run_headless_battle_smoke() -> void:
	## CI / automation: full project autoloads (e.g. Global) — `godot --path . --headless -- --headless-battle-smoke`
	Global.in_battle = true
	var battle := CardBattle.new()
	add_child(battle)
	battle.setup(true, null)
	await get_tree().create_timer(2.5, true).timeout
	var b: Node = battle
	b.queue_free()
	await b.tree_exited
	Global.in_battle = false
	print("headless_battle_smoke: ok")
	get_tree().quit(0)


func initialize_scene(map, entrance):
	get_tree().paused = false
	current_scene = GameScene.new(map, entrance, _ensure_player())
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
