class_name UI extends CanvasLayer

var target
@onready var hud = $HUD
@onready var hearts = $HUD/Hearts
@onready var inventory = $Inventory
@onready var deck_inventory = $DeckInventory

var _deck_editor: Control
var _deck_editor_layer: CanvasLayer
var _pack_opening: PackOpening
var _binder: CollectionBinder


func _ready() -> void:
	# Deferred delivery: runs after EDIT/NEW finishes input, safe while paused.
	if not deck_inventory.deckbuilding_requested.is_connected(_on_deckbuilding_requested):
		deck_inventory.deckbuilding_requested.connect(_on_deckbuilding_requested, CONNECT_DEFERRED)
	if not deck_inventory.open_pack_requested.is_connected(_on_open_pack_requested):
		deck_inventory.open_pack_requested.connect(_on_open_pack_requested, CONNECT_DEFERRED)
	if not deck_inventory.binder_requested.is_connected(_on_binder_requested):
		deck_inventory.binder_requested.connect(_on_binder_requested, CONNECT_DEFERRED)
	_ensure_pack_opening()
	_ensure_binder()


func initialize(_target : Actor):
	target = _target
	_inventory_changed(target.items)
	inventory.inventory_changed.connect(_inventory_changed)
	target.item_received.connect(_inventory_changed)


## Called from DeckInventory (EDIT / NEW DECK). Prefer this over relying on signal delivery alone.
func open_deck_editor(deck_index: int) -> void:
	if deck_index < 0 or deck_index >= Global.player_decks.size():
		push_error("open_deck_editor: invalid deck_index %s (decks: %s)" % [deck_index, Global.player_decks.size()])
		return
	_ensure_deck_editor()
	if _deck_editor == null:
		push_error("open_deck_editor: deck editor failed to build")
		return
	deck_inventory.hide()
	_deck_editor_layer.show()
	_deck_editor.show()
	_deck_editor.open(deck_index)


func _process(_delta):
	if ScreenFX.playing:
		return
	if _deck_editor_layer != null and _deck_editor_layer.visible and _deck_editor != null:
		if Input.is_action_just_pressed("pause"):
			_deck_editor.close_cancel()
		return
	if Input.is_action_just_pressed("inventory"):
		if Global.in_battle:
			return
		if deck_inventory.visible:
			_close_deck_inventory()
		else:
			_open_deck_inventory()
		return
	if Input.is_action_just_pressed("pause"):
		# ESC closes the deck inventory if open; CardBattle handles it internally.
		if Global.in_battle:
			return
		if deck_inventory.visible:
			_close_deck_inventory()


func _ensure_deck_editor() -> void:
	if _deck_editor != null:
		return
	var main := get_parent()
	if main == null:
		push_error("UI: expected parent Main for deck editor layer")
		return
	_deck_editor_layer = CanvasLayer.new()
	_deck_editor_layer.layer = 8
	_deck_editor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(_deck_editor_layer)
	_deck_editor = preload("res://core/ui/deck_editor.tscn").instantiate() as Control
	_deck_editor_layer.add_child(_deck_editor)
	_deck_editor.closed.connect(_on_deck_editor_closed)
	_deck_editor_layer.hide()


func _on_deckbuilding_requested(deck_index: int) -> void:
	# CONNECT_DEFERRED on the signal already defers this call.
	open_deck_editor(deck_index)


func _on_deck_editor_closed() -> void:
	if _deck_editor_layer != null:
		_deck_editor_layer.hide()
	deck_inventory.refresh_decks()
	deck_inventory.show()


func _ensure_pack_opening() -> void:
	if _pack_opening != null:
		return
	_pack_opening = PackOpening.new()
	get_parent().add_child(_pack_opening)
	_pack_opening.finished.connect(_on_pack_opening_finished)


func _ensure_binder() -> void:
	if _binder != null:
		return
	_binder = CollectionBinder.new()
	get_parent().add_child(_binder)


func _on_open_pack_requested() -> void:
	_ensure_pack_opening()
	if Global.money < Global.PACK_COST:
		return  # not enough money — deck_inventory should disable the button
	deck_inventory.hide()
	_pack_opening.open_pack()


func _on_binder_requested() -> void:
	_ensure_binder()
	deck_inventory.hide()
	_binder.open_binder()


func _on_pack_opening_finished() -> void:
	deck_inventory.refresh_decks()
	deck_inventory.show()


func _inventory_changed(new_items):
	inventory.items = new_items # redundant
	target.items = new_items
	hud.items = new_items
	hud.queue_redraw()


func _open_deck_inventory() -> void:
	get_tree().paused = true
	Sound.play(preload("res://data/sfx/LA_PauseMenu_Open.wav"))
	await ScreenFX.fade_white_in()
	deck_inventory.refresh_decks()
	deck_inventory.show()
	ScreenFX.fade_white_out()


func _close_deck_inventory() -> void:
	Sound.play(preload("res://data/sfx/LA_PauseMenu_Close.wav"))
	await ScreenFX.fade_white_in()
	deck_inventory.hide()
	await ScreenFX.fade_white_out()
	get_tree().paused = false


func _open_inventory():
	get_tree().paused = true
	Sound.play(preload("res://data/sfx/LA_PauseMenu_Open.wav"))
	await ScreenFX.fade_white_in()
	inventory.show()
	ScreenFX.fade_white_out()


func _close_inventory():
	Sound.play(preload("res://data/sfx/LA_PauseMenu_Close.wav"))
	await ScreenFX.fade_white_in()
	inventory.hide()
	await ScreenFX.fade_white_out()
	get_tree().paused = false
