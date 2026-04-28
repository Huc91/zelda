class_name SoulItem

var soul_id: String = ""
var name: String = ""
var slot: String = ""   # "red" / "blue" / "green"
var description: String = ""
var luck_bonus: int = 0
var max_hp_bonus: int = 0
var heal_after_battle: int = 0
var initiative_bonus: int = 0
var is_weapon: bool = false
var weapon_scene: PackedScene = null
var icon: Texture2D = null
var sell_price: int = 1
