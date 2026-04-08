## Merchant NPC: player interacts to buy singles or sell excess cards.
## Place on the map via SpawnLayer. Set `merchant_type` to control stock.
class_name Merchant
extends StaticBody2D

@export_enum("general", "rare_hunter", "spell_dealer") var merchant_type: String = "general"

const INTERACT_RADIUS: float = 24.0
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

var _player: Node = null
var _ui_open: bool = false
var _merchant_ui: MerchantUI = null
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("merchant")
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)
	_build_sprite()


func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	# Simple colored square as placeholder merchant art
	var img: Image = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	match merchant_type:
		"general":      img.fill(Color(0.6, 0.5, 0.2))
		"rare_hunter":  img.fill(Color(0.7, 0.2, 0.7))
		"spell_dealer": img.fill(Color(0.2, 0.4, 0.8))
	_sprite.texture = ImageTexture.create_from_image(img)
	add_child(_sprite)

	# Name label above
	var lbl: Label = Label.new()
	lbl.position = Vector2(-20, -28)
	lbl.text = _display_name()
	lbl.add_theme_font_size_override("font_size", 6)
	add_child(lbl)


func _display_name() -> String:
	match merchant_type:
		"general":      return "Merchant"
		"rare_hunter":  return "Rare Hunter"
		"spell_dealer": return "Spell Dealer"
	return "Merchant"


func _physics_process(_delta: float) -> void:
	if Global.in_battle or _ui_open:
		return
	_player = _find_player()
	if _player == null:
		return
	if _player.position.distance_to(position) < INTERACT_RADIUS:
		if Input.is_action_just_pressed("a") or Input.is_action_just_pressed("b"):
			_open_shop()


func _find_player() -> Node:
	var players: Array = get_tree().get_nodes_in_group("actor")
	for a in players:
		if a.has_method("_pickup"):
			return a
	return null


func _open_shop() -> void:
	_ui_open = true
	get_tree().paused = true
	_merchant_ui = MerchantUI.new()
	_merchant_ui.setup(merchant_type)
	_merchant_ui.closed.connect(_on_shop_closed)
	get_tree().root.add_child(_merchant_ui)


func _on_shop_closed() -> void:
	_ui_open = false
	get_tree().paused = false
