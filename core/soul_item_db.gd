class_name SoulItemDB extends RefCounted

static var _map: Dictionary = {}
static var _ready_flag: bool = false


static func _ensure_init() -> void:
	if _ready_flag:
		return
	_ready_flag = true
	_register_all()


static func get_item(id: String) -> Dictionary:
	_ensure_init()
	return _map.get(id, {}).duplicate(true)


static func all_ids() -> Array[String]:
	_ensure_init()
	var result: Array[String] = []
	for k: Variant in _map.keys():
		result.append(str(k))
	return result


static func _reg(id: String, data: Dictionary) -> void:
	data["id"] = id
	_map[id] = data


static func _register_all() -> void:
	_reg("sword", {
		"name": "Duel Glove",
		"description": "A glove imbued with a duelist's spirit.",
		"slot": "red",
		"is_weapon": true,
		"weapon_scene": "res://data/actors/attacks/duel_glove.tscn",
		"icon": "res://data/items/duel-glove-item.png",
		"hud_icon": "res://core/ui/gloveicon.png",
		"luck_bonus": 0,
		"max_hp_bonus": 0,
		"heal_after_battle": 0,
		"initiative_bonus": 0,
		"sell_price": 5,
	})
	_reg("flower", {
		"name": "Flower Soul",
		"description": "+1 Luck.",
		"slot": "green",
		"is_weapon": false,
		"weapon_scene": "",
		"icon": "",
		"hud_icon": "res://core/ui/florewericon.png",
		"luck_bonus": 1,
		"max_hp_bonus": 0,
		"heal_after_battle": 0,
		"initiative_bonus": 0,
		"sell_price": 3,
	})
	_reg("stone", {
		"name": "Stone Soul",
		"description": "+1 max HP.",
		"slot": "blue",
		"is_weapon": false,
		"weapon_scene": "",
		"icon": "",
		"hud_icon": "res://core/ui/stoneicon.png",
		"luck_bonus": 0,
		"max_hp_bonus": 1,
		"heal_after_battle": 0,
		"initiative_bonus": 0,
		"sell_price": 5,
	})
	_reg("tree", {
		"name": "Tree Soul",
		"description": "+4 HP healed at end of battle.",
		"slot": "green",
		"is_weapon": false,
		"weapon_scene": "",
		"icon": "",
		"hud_icon": "res://core/ui/treeicon.png",
		"luck_bonus": 0,
		"max_hp_bonus": 0,
		"heal_after_battle": 4,
		"initiative_bonus": 0,
		"sell_price": 3,
	})
	_reg("bamboo", {
		"name": "Bamboo Soul",
		"description": "+1 initiative.",
		"slot": "blue",
		"is_weapon": false,
		"weapon_scene": "",
		"icon": "",
		"hud_icon": "res://core/ui/bambooicon.png",
		"luck_bonus": 0,
		"max_hp_bonus": 0,
		"heal_after_battle": 0,
		"initiative_bonus": 1,
		"sell_price": 3,
	})
	_reg("power_trunks", {
		"name": "Power Trunks",
		"description": "Move rocks and other pushable objects while equipped. Holds a special card (TBD).",
		"slot": "blue",
		"is_weapon": false,
		"weapon_scene": "",
		"icon": "",
		"hud_icon": "res://core/ui/trunkicon.png",
		"luck_bonus": 0,
		"max_hp_bonus": 0,
		"heal_after_battle": 0,
		"initiative_bonus": 0,
		"sell_price": 25,
	})
