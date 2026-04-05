extends Node

var Item = {
	Sword = preload("res://data/items/sword.tres")
}

signal card_battle_requested(player_first: bool, enemy: Node)

func request_card_battle(player_first: bool, enemy: Node) -> void:
	card_battle_requested.emit(player_first, enemy)
