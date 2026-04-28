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
	call_deferred("_show_title_screen")


func _show_title_screen() -> void:
	var title: TitleScreen = TitleScreen.new()
	add_child(title)
	var choice: TitleScreen.Choice = await title.chosen
	title.queue_free()
	await title.tree_exited
	match choice:
		TitleScreen.Choice.CONTINUE:
			Global.load_game()
		TitleScreen.Choice.NEW_GAME:
			Global.reset_new_game()
		TitleScreen.Choice.DEV_MODE:
			Global.reset_new_game()
			Global.dev_mode = true
			Global._apply_dev_mode()
	_ensure_player()
	await ScreenFX.fade_white_in()
	initialize_scene(STARTING_MAP, STARTING_ENTRANCE)
	# UI must be a sibling of Screen, not a child of SubViewportContainer, or mouse hits the
	# embedded SubViewport first and Control buttons (e.g. deck DELETE) never receive clicks.
	add_child(_ensure_ui())
	_ensure_ui().initialize(_ensure_player())
	_ensure_player().restore_state_from_global()
	Global.card_battle_requested.connect(_on_card_battle_requested)
	Global.bonfire_rested.connect(_on_bonfire_rested)


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


var _guide_npc_spawned: bool = false
var _guide_npcs: Array[Node] = []

func initialize_scene(map: String, entrance: Vector2i) -> void:
	get_tree().paused = false
	Global.current_map_path = map
	var old_scene: GameScene = current_scene
	current_scene = GameScene.new(map, entrance, _ensure_player())
	current_scene.map_changed.connect(initialize_scene)
	screen.add_child(current_scene)
	await ScreenFX.fade_white_out()


## Returns true if the tile at `cell` exists and has no collision shapes (open ground).
func _tile_walkable(cell: Vector2i) -> bool:
	var data: TileData = current_scene.map.get_cell_tile_data(Map.Layer.STATIC, cell)
	if data == null:
		return false
	return data.get_collision_polygons_count(0) == 0


## Searches outward from `center` for a walkable tile not in `used`.
## Stays within the same camera room as `center`.
func _find_walkable(center: Vector2i, min_r: int, max_r: int, used: Array) -> Vector2i:
	var center_world: Vector2 = current_scene.map.map_to_local(center)
	var room_origin: Vector2 = Vector2(
		floor(center_world.x / GridCamera.CELL_SIZE.x) * GridCamera.CELL_SIZE.x,
		floor(center_world.y / GridCamera.CELL_SIZE.y) * GridCamera.CELL_SIZE.y
	)
	var room_end: Vector2 = room_origin + GridCamera.CELL_SIZE

	for r in range(min_r, max_r + 1):
		var ring: Array[Vector2i] = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := center + Vector2i(dx, dy)
				if c in used:
					continue
				var cw: Vector2 = current_scene.map.map_to_local(c)
				if cw.x < room_origin.x or cw.x >= room_end.x:
					continue
				if cw.y < room_origin.y or cw.y >= room_end.y:
					continue
				if _tile_walkable(c):
					ring.append(c)
		if not ring.is_empty():
			return ring[0]
	return center


func _on_bonfire_rested() -> void:
	# Enemies respawn naturally when the player leaves and re-enters the map,
	# since initialize_scene always creates fresh instances.
	Global.reset_tried_souls()


func _on_card_battle_requested(p_first: bool, enemy: Node) -> void:
	Global.in_battle = true
	Global.card_battle_requested.disconnect(_on_card_battle_requested)
	for actor in get_tree().get_nodes_in_group("actor"):
		actor.set_physics_process(false)
	for child in get_tree().root.get_children():
		if child is DialogueBox or child is MerchantUI:
			child.queue_free()
	await ScreenFX.fade_white_in()
	# Initiative screen
	var init_screen: InitiativeScreen = InitiativeScreen.new()
	add_child(init_screen)
	init_screen.setup(p_first, enemy)
	await ScreenFX.fade_white_out()
	var actual_first: bool = await init_screen.result_ready
	await ScreenFX.fade_white_in()
	init_screen.queue_free()
	var battle := CardBattle.new()
	add_child(battle)
	battle.setup(actual_first, enemy)
	battle.battle_ended.connect(_on_battle_ended.bind(battle, enemy))
	await ScreenFX.fade_white_out()


func _on_battle_ended(player_won: bool, battle: Node, enemy: Node) -> void:
	Global.in_battle = false
	await ScreenFX.fade_white_in()
	battle.queue_free()
	if player_won and is_instance_valid(enemy):
		_give_battle_reward(enemy)
		# Apply post-battle heals from soul items
		var heal: int = Global.get_heal_after_battle()
		if heal > 0:
			Global.add_hp(heal)
		enemy.queue_free()
		# Unfreeze all living actors and reset battle flag
		for actor in get_tree().get_nodes_in_group("actor"):
			if is_instance_valid(actor) and actor is Actor:
				actor.set_physics_process(true)
				actor.in_battle = false
		await ScreenFX.fade_white_out()
		Global.card_battle_requested.connect(_on_card_battle_requested)
	else:
		# Player lost
		var diff: String = "easy"
		if is_instance_valid(enemy) and "difficulty" in enemy:
			diff = str(enemy.difficulty)
		var lethal: bool = diff == "hard" or diff == "boss"
		if lethal:
			Global.set_hp(0)
			await ScreenFX.fade_white_out()
			_show_game_over()
		else:
			# Skirmish loss — survive at 1 HP
			Global.set_hp(1)
			if is_instance_valid(enemy) and enemy is Actor:
				(enemy as Actor).in_battle = false
			for actor in get_tree().get_nodes_in_group("actor"):
				if is_instance_valid(actor) and actor is Actor:
					actor.set_physics_process(true)
					(actor as Actor).in_battle = false
			_ensure_player().invulnerable_timer = 3.0
			await ScreenFX.fade_white_out()
			Global.card_battle_requested.connect(_on_card_battle_requested)


func _respawn_at_bonfire() -> void:
	var p: Actor = _ensure_player()
	p.sprite.show()
	if Global.last_bonfire_position != null:
		p.position = Global.last_bonfire_position as Vector2
		p.last_safe_position = p.position
	else:
		# No bonfire activated yet — fall back to starting entrance
		p.position = current_scene.map.map_to_local(STARTING_ENTRANCE)
		p.last_safe_position = p.position
	p.invulnerable_timer = 3.0
	await ScreenFX.fade_white_out()


func _show_game_over() -> void:
	var go: CanvasLayer = CanvasLayer.new()
	go.layer = 50
	go.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(go)
	var font: Font = load("res://assets/fonts/Nudge Orb.ttf") as Font
	var ctrl: Control = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.focus_mode = Control.FOCUS_CLICK
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	go.add_child(ctrl)
	var _ready_input: bool = false
	ctrl.draw.connect(func() -> void:
		ctrl.draw_rect(Rect2(0, 0, 640, 576), Color(0.0, 0.0, 0.0, 0.88))
		if font == null:
			return
		var title: String = "GAME OVER"
		var tw_: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		ctrl.draw_string(font, Vector2((640.0 - tw_) * 0.5, 262.0), title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.15, 0.05))
		if _ready_input:
			var hint: String = "PRESS ANY KEY TO RESTART"
			var hw: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			ctrl.draw_string(font, Vector2((640.0 - hw) * 0.5, 302.0), hint,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 1.0, 1.0, 0.85))
	)
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if not _ready_input:
			return
		var do_restart: bool = false
		if event is InputEventKey and (event as InputEventKey).pressed:
			do_restart = true
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			do_restart = true
		if do_restart:
			Global.in_battle = false
			get_tree().reload_current_scene()
	)
	ctrl.grab_focus()
	ctrl.queue_redraw()
	await get_tree().create_timer(1.2).timeout
	_ready_input = true
	ctrl.queue_redraw()


func _give_battle_reward(enemy: Node) -> void:
	var diff: String = "easy"
	if "difficulty" in enemy:
		diff = str(enemy.difficulty)
	var reward_table: Dictionary = Global.REWARD_BY_DIFF.get(diff, Global.REWARD_BY_DIFF["easy"])
	var amount: int = randi_range(int(reward_table["min"]), int(reward_table["max"]))
	if Global.roll_luck():
		amount += 10
	_spawn_coins(enemy.position, amount)
	# Card drop chance by difficulty
	var card_drop_chance: float = 0.02
	if diff == "normal":
		card_drop_chance = 0.05
	elif diff == "hard":
		card_drop_chance = 0.15
	elif diff == "boss":
		card_drop_chance = 0.50
	if randf() < card_drop_chance:
		var ids: Array[String] = CardDB.all_collectible_ids()
		if not ids.is_empty():
			var dropped_id: String = ids[randi() % ids.size()]
			_spawn_card_pickup(enemy.position, dropped_id)


func _spawn_card_pickup(world_pos: Vector2, dropped_id: String) -> void:
	if current_scene == null or current_scene.map == null:
		Global.collect_card(dropped_id, false)
		return
	var tile: Vector2i = _find_walkable(current_scene.map.local_to_map(world_pos), 0, 3, [])
	var pickup: CardPickup = CardPickup.new()
	pickup.card_id = dropped_id
	pickup.is_placed = false
	pickup.position = current_scene.map.map_to_local(tile)
	current_scene.map.add_child(pickup)


func _decompose_to_coins(amount: int) -> Array[int]:
	var coins: Array[int] = []
	var remaining: int = amount
	while remaining >= 50:
		coins.append(50)
		remaining -= 50
	while remaining >= 10:
		coins.append(10)
		remaining -= 10
	while remaining > 0:
		coins.append(1)
		remaining -= 1
	return coins


func _spawn_coins(world_pos: Vector2, amount: int) -> void:
	if current_scene == null or current_scene.map == null:
		Global.add_money(amount)
		return
	var coin_values: Array[int] = _decompose_to_coins(amount)
	var center_cell: Vector2i = current_scene.map.local_to_map(world_pos)
	var used: Array = []
	for i: int in coin_values.size():
		var tile: Vector2i
		if i == 0:
			tile = center_cell
			used.append(tile)
		else:
			tile = _find_walkable(center_cell, 1, 5, used)
			used.append(tile)
		var coin: Coin = Coin.new()
		coin.value = coin_values[i]
		coin.position = current_scene.map.map_to_local(tile)
		current_scene.map.add_child(coin)
