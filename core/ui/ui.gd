class_name UI extends CanvasLayer

const DeckInventory = preload("res://core/ui/deck_inventory.gd")
const SoulInventory = preload("res://core/ui/soul_inventory.gd")
const DeckEditor = preload("res://core/ui/deck_editor.gd")

var target: Actor
@onready var hud: Node2D = $HUD
@onready var hearts: Node2D = $HUD/Hearts
@onready var deck_inventory: DeckInventory = $DeckInventory

var _soul_inventory: SoulInventory
var _deck_editor: DeckEditor
var _deck_editor_layer: CanvasLayer
var _pack_opening: PackOpening
var _binder: CollectionBinder
var _closing_all_menus: bool = false


func _ready() -> void:
	if not deck_inventory.deckbuilding_requested.is_connected(_on_deckbuilding_requested):
		deck_inventory.deckbuilding_requested.connect(_on_deckbuilding_requested, CONNECT_DEFERRED)
	if not deck_inventory.open_pack_requested.is_connected(_on_open_pack_requested):
		deck_inventory.open_pack_requested.connect(_on_open_pack_requested, CONNECT_DEFERRED)
	if not deck_inventory.binder_requested.is_connected(_on_binder_requested):
		deck_inventory.binder_requested.connect(_on_binder_requested, CONNECT_DEFERRED)
	if not deck_inventory.soul_system_requested.is_connected(_on_soul_system_requested):
		deck_inventory.soul_system_requested.connect(_on_soul_system_requested, CONNECT_DEFERRED)
	if not deck_inventory.close_requested.is_connected(_close_all_menus):
		deck_inventory.close_requested.connect(_close_all_menus, CONNECT_DEFERRED)
	_ensure_pack_opening()
	_ensure_binder()
	_ensure_soul_inventory()


func initialize(_target: Actor) -> void:
	target = _target


func _process(_delta: float) -> void:
	if ScreenFX.playing:
		return
	if _is_pack_opening_open():
		return
	if _is_any_inventory_menu_open():
		if Input.is_action_just_pressed("inventory"):
			_close_all_menus()
			return
		if Input.is_action_just_pressed("pause"):
			_handle_menu_back()
			return
		return
	# Game — open inventory on "I".
	if Input.is_action_just_pressed("inventory"):
		if not _can_open_inventory_from_game():
			return
		_open_deck_inventory()


# ── Deck Inventory ──────────────────────────────────────────────────

func _open_deck_inventory() -> void:
	if not _can_open_inventory_from_game():
		return
	get_tree().paused = true
	Sound.play(preload("res://data/sfx/Menu_In.wav"))
	await ScreenFX.fade_white_in()
	deck_inventory.reset_to_root()
	deck_inventory.refresh_decks()
	deck_inventory.show()
	ScreenFX.fade_white_out()


func _close_all_menus() -> void:
	if _closing_all_menus or not _is_any_inventory_menu_open():
		return
	_closing_all_menus = true
	Sound.play(preload("res://data/sfx/Menu_Out.wav"))
	await ScreenFX.fade_white_in()
	if _is_deck_editor_open():
		_deck_editor.close_cancel()
	if _binder != null:
		_binder.hide()
	if _soul_inventory != null:
		_soul_inventory.visible = false
	if _deck_editor_layer != null:
		_deck_editor_layer.hide()
	deck_inventory.reset_to_root()
	deck_inventory.hide()
	await ScreenFX.fade_white_out()
	get_tree().paused = false
	_closing_all_menus = false


# ── Soul Inventory ──────────────────────────────────────────────────

func _ensure_soul_inventory() -> void:
	if _soul_inventory != null:
		return
	_soul_inventory = SoulInventory.new()
	_soul_inventory.visible = false
	get_tree().root.add_child(_soul_inventory)
	_soul_inventory.back_requested.connect(_on_soul_inventory_back)


func _on_soul_system_requested() -> void:
	deck_inventory.hide()
	_soul_inventory.visible = true


func _on_soul_inventory_back() -> void:
	_soul_inventory.visible = false
	_return_to_inventory_root()


# ── Deck Editor ─────────────────────────────────────────────────────

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


func _ensure_deck_editor() -> void:
	if _deck_editor != null:
		return
	var main: Node = get_parent()
	if main == null:
		push_error("UI: expected parent Main for deck editor layer")
		return
	_deck_editor_layer = CanvasLayer.new()
	_deck_editor_layer.layer = 8
	_deck_editor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(_deck_editor_layer)
	_deck_editor = preload("res://core/ui/deck_editor.tscn").instantiate() as DeckEditor
	_deck_editor_layer.add_child(_deck_editor)
	_deck_editor.closed.connect(_on_deck_editor_closed)
	_deck_editor_layer.hide()


func _on_deckbuilding_requested(deck_index: int) -> void:
	open_deck_editor(deck_index)


func _on_deck_editor_closed() -> void:
	if _deck_editor_layer != null:
		_deck_editor_layer.hide()
	if _closing_all_menus:
		return
	deck_inventory.refresh_decks()
	deck_inventory.show()
	# Return to deck list sub-screen, not hub.
	deck_inventory._show_deck_list()


# ── Pack Opening / Binder ────────────────────────────────────────────

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
	_binder.closed.connect(_on_binder_closed)


func _on_open_pack_requested() -> void:
	_ensure_pack_opening()
	if Global.base_set_packs <= 0:
		return
	deck_inventory.hide()
	_pack_opening.open_pack()


func _on_binder_requested() -> void:
	_ensure_binder()
	deck_inventory.hide()
	_binder.open_binder()


func _on_binder_closed() -> void:
	if _closing_all_menus:
		return
	_return_to_inventory_root()


func _on_pack_opening_finished() -> void:
	_return_to_inventory_root()


func _is_deck_editor_open() -> bool:
	return _deck_editor_layer != null and _deck_editor_layer.visible and _deck_editor != null and _deck_editor.visible


func _is_pack_opening_open() -> bool:
	return _pack_opening != null and _pack_opening.visible


func _is_any_inventory_menu_open() -> bool:
	return deck_inventory.visible or (_soul_inventory != null and _soul_inventory.visible) \
		or (_binder != null and _binder.visible) or _is_deck_editor_open()


func _handle_menu_back() -> void:
	if _is_deck_editor_open():
		_deck_editor.close_cancel()
		return
	if _binder != null and _binder.visible:
		_binder.request_back()
		return
	if _soul_inventory != null and _soul_inventory.visible:
		_on_soul_inventory_back()
		return
	if deck_inventory.visible and deck_inventory.go_back():
		return
	_close_all_menus()


func _return_to_inventory_root() -> void:
	deck_inventory.refresh_decks()
	deck_inventory.reset_to_root()
	deck_inventory.show()


func _can_open_inventory_from_game() -> bool:
	if Global.in_battle:
		return false
	if get_tree().paused:
		return false
	return true
