class_name CardBattle extends CanvasLayer

class _View extends Control:
	var b
	func _draw() -> void:                   b._on_draw()
	func _gui_input(e: InputEvent) -> void: b._on_input(e)
	func _process(dt: float) -> void:       b._tick(dt)


# ══════════════════════════════════════════════════════════════════
# LAYOUT  (640 × 576 viewport)
# ══════════════════════════════════════════════════════════════════
const W        := 640
const H        := 576
const LEFT_W   := 170
const RIGHT_W  := 70
const BOARD_X  := LEFT_W
const BOARD_W  := W - LEFT_W - RIGHT_W   # 400
const SIDE_X   := W - RIGHT_W            # 570

# Left panel zones
const EINFO_H  := 55
const LOG_Y    := EINFO_H
const LOG_H    := 90
const ZOOM_Y   := LOG_Y + LOG_H          # 145
const ZOOM_H   := 225
const PINFO_Y  := ZOOM_Y + ZOOM_H        # 370
const PINFO_H  := 60                     # room for life, mana, buttons
const HAND_Y   := PINFO_Y + PINFO_H      # 430
const HAND_H   := H - HAND_Y             # 146

# Board rows
const ROW_H       := 100
const EFFRONT_Y   := 0
const EFREAR_Y    := ROW_H + 5           # 105
const BOARD_DIV_Y := EFREAR_Y + ROW_H + 5  # 210
const PFFRONT_Y   := BOARD_DIV_Y + 5     # 215
const PFREAR_Y    := PFFRONT_Y + ROW_H + 5 # 320

# Card sizes
const MINI_W   := 88
const MINI_H   := 92
const MINI_GAP := 6
const HAND_CW  := 90
const HAND_CH  := 130
const MAX_ROW  := 3

# Right sidebar: 6 equal sections
const SIDE_SEC := int(H / 6.0)   # 96

const STARTING_HP   := 15
const STARTING_HAND := 5
const LOG_LINE_H    := 11
const LOG_VISIBLE   := 7
const TOAST_DUR     := 2.2


# ══════════════════════════════════════════════════════════════════
# COLOURS
# ══════════════════════════════════════════════════════════════════
const C_BG       := Color(0.82, 0.78, 0.72)
const C_LEFT_BG  := Color(0.80, 0.77, 0.73)
const C_EINFO_BG := Color(0.75, 0.71, 0.65)
const C_LOG_BG   := Color(0.75, 0.88, 0.80)
const C_ZOOM_BG  := Color(0.78, 0.75, 0.70)
const C_PINFO_BG := Color(0.75, 0.71, 0.65)
const C_HAND_BG  := Color(0.20, 0.16, 0.12)
const C_SIDE_BG  := Color(0.26, 0.18, 0.12)
const C_DIV      := Color(0.50, 0.42, 0.34)

const C_TEXT     := Color(0.05, 0.05, 0.05)
const C_TEXT_LT  := Color(0.94, 0.92, 0.86)
const C_MUTED    := Color(0.45, 0.42, 0.38)
const C_HP_RED   := Color(0.88, 0.14, 0.12)
const C_MANA_BLU := Color(0.18, 0.40, 0.90)
const C_SEL      := Color(0.12, 0.88, 0.22)
const C_TARGET   := Color(0.92, 0.18, 0.10)
const C_EXHAUST  := Color(0.0,  0.0,  0.0,  0.54)
const C_TOAST_BG := Color(0.04, 0.04, 0.10, 0.90)
const C_MODAL_BG := Color(0.08, 0.06, 0.14, 0.94)
const C_DEMON_BG := Color(0.957, 0.894, 0.851)
const C_SPELL_BG := Color(0.631, 0.706, 0.404)

const RARITY_COL := {
	"common"   : Color(0.60, 0.60, 0.60),
	"uncommon" : Color(0.88, 0.88, 0.88),
	"rare"     : Color(0.28, 0.52, 0.95),
	"mythic"   : Color(0.72, 0.28, 0.95),
	"legendary": Color(1.0,  0.58, 0.10),
}


# ══════════════════════════════════════════════════════════════════
# STATE — game
# ══════════════════════════════════════════════════════════════════
var enemy_actor:  Node
var player_first: bool

var player_hp := STARTING_HP
var enemy_hp  := STARTING_HP

var player_deck:  Array = []
var enemy_deck:   Array = []
var player_hand:  Array = []
var enemy_hand:   Array = []
var player_gy:    Array = []
var enemy_gy:     Array = []

var player_front: Array = []
var player_rear:  Array = []
var enemy_front:  Array = []
var enemy_rear:   Array = []

var player_arsenal: Dictionary = {}

var _pitched_this_turn: Array = []
var _moved_this_turn   := false
var _stashed_this_turn := false

var player_mana     := 0
var player_max_mana := 0
var player_turn_num := 0
var enemy_mana      := 0
var enemy_turn_num  := 0

var _ai_type       := "midrange"
var is_player_turn := false
var _animating     := false
var _ended         := false

enum Mode { IDLE, CHOOSE_ROW, ATTACKING, CHOOSE_MOVE }
var _mode          := Mode.IDLE
var _pending_card:  Dictionary = {}
var _pending_hand_idx := -1
var _sel_idx          := -1

var _battle_log: Array = []
var _floats:     Array = []
var _particles:  Array = []


# ══════════════════════════════════════════════════════════════════
# STATE — UI
# ══════════════════════════════════════════════════════════════════
var _mouse_pos:   Vector2 = Vector2.ZERO
var _hover_card:  Dictionary = {}
var _hover_state: Dictionary = {}

var _drag_active:   bool = false
var _drag_card:     Dictionary = {}
var _drag_hand_idx: int = -1
var _drag_pos:      Vector2 = Vector2.ZERO

var _toast_text:  String = ""
var _toast_timer: float  = 0.0

var _modal_open:  bool   = false
var _modal_cards: Array  = []
var _modal_title: String = ""

var _view: _View
signal battle_ended(player_won: bool)


# ══════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════
func setup(p_first: bool, p_enemy: Node) -> void:
	player_first = p_first
	enemy_actor  = p_enemy
	layer        = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view        = _View.new()
	_view.b      = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_view)
	_start_battle()


# ══════════════════════════════════════════════════════════════════
# BATTLE FLOW
# ══════════════════════════════════════════════════════════════════
func _start_battle() -> void:
	player_deck = CardDB.starter_deck()
	enemy_deck  = CardDB.enemy_deck()
	_ai_type    = _detect_ai_type()
	_draw_n(player_hand, player_deck, STARTING_HAND)
	_draw_n(enemy_hand,  enemy_deck,  STARTING_HAND)
	_log("Battle started!")
	_show_toast("Battle Start!")
	_view.queue_redraw()
	await get_tree().create_timer(0.8, true).timeout
	if player_first: _start_player_turn()
	else:            _start_enemy_turn()


func _draw_n(hand: Array, deck: Array, n: int) -> void:
	for _i in n:
		if deck.is_empty(): return
		hand.append(deck.pop_front())


func _draw_one(hand: Array, deck: Array) -> void:
	if not deck.is_empty(): hand.append(deck.pop_front())


func _log(s: String) -> void:
	_battle_log.append(s)
	_view.queue_redraw()


func _start_player_turn() -> void:
	is_player_turn   = true
	_animating       = false
	player_turn_num += 1
	player_max_mana  = mini(player_turn_num, 10)
	if not player_first and player_turn_num == 1: player_max_mana += 1
	player_mana        = player_max_mana
	_pitched_this_turn.clear()
	_moved_this_turn   = false
	_stashed_this_turn = false
	_mode              = Mode.IDLE
	_sel_idx           = -1
	_pending_card      = {}
	for d in player_front: d["exhausted"] = false; d["attacked"] = 0
	for d in player_rear:  d["exhausted"] = false; d["attacked"] = 0
	_log("--- Your turn %d  (%d mana) ---" % [player_turn_num, player_max_mana])
	_show_toast("Your Turn")
	_view.queue_redraw()


func _end_player_turn() -> void:
	if not is_player_turn or _animating or _ended: return
	is_player_turn = false
	_mode          = Mode.IDLE
	_sel_idx       = -1
	_pending_card  = {}
	_pitched_this_turn.shuffle()
	for c in _pitched_this_turn: player_deck.append(c)
	_pitched_this_turn.clear()
	for c in player_hand: player_gy.append(c)
	player_hand.clear()
	_draw_n(player_hand, player_deck, STARTING_HAND)
	_view.queue_redraw()
	await get_tree().create_timer(0.05, true).timeout
	_start_enemy_turn()


func _start_enemy_turn() -> void:
	_animating     = true
	is_player_turn = false
	enemy_turn_num += 1
	enemy_mana      = mini(enemy_turn_num, 10)
	if player_first and enemy_turn_num == 1: enemy_mana += 1
	for c in enemy_hand: enemy_gy.append(c)
	enemy_hand.clear()
	_draw_n(enemy_hand, enemy_deck, STARTING_HAND)
	for d in enemy_front: d["exhausted"] = false; d["attacked"] = 0
	for d in enemy_rear:  d["exhausted"] = false; d["attacked"] = 0
	_log("--- Enemy turn %d ---" % enemy_turn_num)
	_show_toast("Enemy Turn")
	_view.queue_redraw()
	await get_tree().create_timer(0.4, true).timeout
	if _ended: return
	await _ai_play_phase()
	if _ended: return
	await _ai_attack_phase()
	if _ended: return
	_animating = false
	if not _ended: _start_player_turn()


# ══════════════════════════════════════════════════════════════════
# CARD PLAY
# ══════════════════════════════════════════════════════════════════
func _summon(card: Dictionary, is_player: bool, to_front: bool) -> void:
	var ab: String    = card.get("ability", "")
	var force_front   := "taunt" in ab
	var pf := player_front if is_player else enemy_front
	var pr := player_rear  if is_player else enemy_rear
	var use_front := force_front or to_front
	var row := pf if use_front else pr
	if row.size() >= MAX_ROW:
		var other := pr if use_front else pf
		if other.size() < MAX_ROW: row = other
		else: return
	var d := _make_board_demon(card)
	row.append(d)
	_resolve_battlecry(d, is_player)


func _make_board_demon(card: Dictionary) -> Dictionary:
	var ab: String = card.get("ability", "")
	return {
		"data"         : card,
		"hp"           : card.get("hp",  1),
		"atk"          : card.get("atk", 0),
		"exhausted"    : not _kwrd(ab, "haste"),
		"attacked"     : 0,
		"divine_active": _kwrd(ab, "divine_shield"),
		"poisonous"    : _kwrd(ab, "poisonous"),
		"lifesteal"    : _kwrd(ab, "lifesteal"),
		"taunt"        : _kwrd(ab, "taunt"),
		"unblockable"  : _kwrd(ab, "unblockable"),
		"rage"         : _kwrd(ab, "rage"),
		"double_attack": _kwrd(ab, "double_attack"),
		"uid"          : randi(),
	}


func _resolve_battlecry(d: Dictionary, is_player: bool) -> void:
	var ab: String = d["data"].get("ability", "")
	var pf   := player_front if is_player else enemy_front
	var pr   := player_rear  if is_player else enemy_rear
	var of_  := enemy_front  if is_player else player_front
	var or_  := enemy_rear   if is_player else player_rear
	var own_hand := player_hand if is_player else enemy_hand
	var own_deck := player_deck if is_player else enemy_deck

	if   "battlecry_draw_1"            in ab: _draw_one(own_hand, own_deck)
	elif "battlecry_draw_2"            in ab: _draw_one(own_hand, own_deck); _draw_one(own_hand, own_deck)
	elif "battlecry_damage_player_2"   in ab:
		if is_player: _deal_damage_to_enemy(2)
		else:         _deal_damage_to_player(2)
	elif "battlecry_aoe_1"             in ab:
		for o in of_.duplicate(): _hit_demon(o, 1, false)
		for o in or_.duplicate(): _hit_demon(o, 1, false)
		_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
	elif "battlecry_aoe_2"             in ab:
		for o in of_.duplicate(): _hit_demon(o, 2, false)
		for o in or_.duplicate(): _hit_demon(o, 2, false)
		_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
	elif "battlecry_buff_all_atk"      in ab:
		for ally in pf: if ally != d: ally["atk"] += 1
		for ally in pr: ally["atk"] += 1
	elif "battlecry_destroy_strongest" in ab:
		var all_o := of_.duplicate(); all_o.append_array(or_)
		if not all_o.is_empty():
			var strongest: Dictionary = all_o[0]
			for o in all_o:
				if o["atk"] > strongest["atk"]: strongest = o
			strongest["hp"] = 0
			_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
	elif "battlecry_destroy_all"       in ab:
		for o in of_.duplicate(): o["hp"] = 0
		for o in or_.duplicate(): o["hp"] = 0
		_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
	elif "battlecry_heal_3"            in ab:
		if is_player: player_hp = mini(player_hp + 3, STARTING_HP)
		else:         enemy_hp  = mini(enemy_hp  + 3, STARTING_HP)
	elif "battlecry_summon_imps"       in ab:
		_summon(CardDB.get_card("token_imp"), is_player, true)
		_summon(CardDB.get_card("token_imp"), is_player, true)
	elif "battlecry_summon_imp"        in ab:
		_summon(CardDB.get_card("token_imp"), is_player, true)


func _resolve_spell(card: Dictionary, is_player: bool) -> void:
	var effect: String = card.get("effect", "")
	var val: int = card.get("value", 0)
	var of_  := enemy_front  if is_player else player_front
	var or_  := enemy_rear   if is_player else player_rear
	var pf   := player_front if is_player else enemy_front
	var pr   := player_rear  if is_player else enemy_rear
	var own_hand := player_hand if is_player else enemy_hand
	var own_deck := player_deck if is_player else enemy_deck

	match effect:
		"damage":
			if is_player: _deal_damage_to_enemy(val)
			else:         _deal_damage_to_player(val)
		"heal":
			if is_player: player_hp = mini(player_hp + val, STARTING_HP)
			else:         enemy_hp  = mini(enemy_hp  + val, STARTING_HP)
		"draw":
			for _i in val: _draw_one(own_hand, own_deck)
		"aoe_enemy", "aoe_demon_dmg":
			for dd in of_.duplicate(): _hit_demon(dd, val, false)
			for dd in or_.duplicate(): _hit_demon(dd, val, false)
			_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
		"mana_boost":
			if is_player: player_mana = mini(player_mana + val, 10)
		"summon_imp":
			_summon(CardDB.get_card("token_imp"), is_player, true)
		"buff_atk_all":
			for dd in pf: dd["atk"] += val
			for dd in pr: dd["atk"] += val
		"destroy":
			var ti := _find_weakest(of_)
			if ti >= 0: of_[ti]["hp"] = 0; _process_deaths(of_, not is_player, true)
			else:
				ti = _find_weakest(or_)
				if ti >= 0: or_[ti]["hp"] = 0; _process_deaths(or_, not is_player, false)
		"debuff_atk":
			var ti := _find_strongest(of_)
			if ti >= 0: of_[ti]["atk"] = maxi(0, of_[ti]["atk"] - val)
			else:
				ti = _find_strongest(or_)
				if ti >= 0: or_[ti]["atk"] = maxi(0, or_[ti]["atk"] - val)
		"life_per_demon":
			var gain := (pf.size() + pr.size()) * val
			if is_player: player_hp = mini(player_hp + gain, STARTING_HP)
			else:         enemy_hp  = mini(enemy_hp  + gain, STARTING_HP)


# ══════════════════════════════════════════════════════════════════
# COMBAT
# ══════════════════════════════════════════════════════════════════
func _do_combat(a_board: Array, a_idx: int, a_is_player: bool, a_is_front: bool,
		d_board: Array, d_idx: int, d_is_front: bool) -> void:
	if a_idx >= a_board.size() or d_idx >= d_board.size(): return
	var att: Dictionary = a_board[a_idx]
	var def_: Dictionary = d_board[d_idx]
	var att_atk: int = att["atk"]; var def_atk: int = def_["atk"]
	var att_poi: bool = att.get("poisonous", false)
	var def_poi: bool = def_.get("poisonous", false)
	_spawn_float(_board_world_pos(a_is_player, a_is_front, a_idx),        "-%d" % def_atk, C_HP_RED)
	_spawn_float(_board_world_pos(not a_is_player, d_is_front, d_idx),    "-%d" % att_atk, C_HP_RED)
	_hit_demon(def_, att_atk, att_poi)
	_hit_demon(att,  def_atk, def_poi)
	if att.get("lifesteal", false) and att_atk > 0:
		if a_is_player: player_hp = mini(player_hp + att_atk, STARTING_HP)
		else:           enemy_hp  = mini(enemy_hp  + att_atk, STARTING_HP)
	_process_deaths(a_board, a_is_player,     a_is_front)
	_process_deaths(d_board, not a_is_player, d_is_front)


func _hit_demon(d: Dictionary, dmg: int, source_poi: bool) -> void:
	if dmg <= 0: return
	if d.get("divine_active", false): d["divine_active"] = false; return
	if d.get("rage", false): d["atk"] += 1
	d["hp"] -= dmg
	if source_poi: d["hp"] = 0


func _process_deaths(board: Array, is_player: bool, is_front: bool) -> void:
	for i in range(board.size() - 1, -1, -1):
		if board[i]["hp"] <= 0:
			var dead: Dictionary = board[i]
			_spawn_death_fx(_board_world_pos(is_player, is_front, i))
			board.remove_at(i)
			_resolve_deathrattle(dead, is_player, is_front)
	_view.queue_redraw()


func _resolve_deathrattle(d: Dictionary, is_player: bool, is_front: bool) -> void:
	var ab: String = d["data"].get("ability", "")
	var gy := player_gy if is_player else enemy_gy
	gy.append(d["data"])
	if   "deathrattle_damage_2"     in ab:
		if is_player: _deal_damage_to_enemy(2)
		else:         _deal_damage_to_player(2)
	elif "deathrattle_summon_zombie" in ab:
		_summon(CardDB.get_card("token_zombie"), is_player, is_front)
	elif "deathrattle_return_hand"   in ab:
		var hand := player_hand if is_player else enemy_hand
		hand.append(d["data"])
	elif "deathrattle_buff_all"      in ab:
		var pf := player_front if is_player else enemy_front
		var pr := player_rear  if is_player else enemy_rear
		for ally in pf: ally["atk"] += 1; ally["hp"] += 1
		for ally in pr: ally["atk"] += 1; ally["hp"] += 1


func _deal_damage_to_player(n: int) -> void:
	player_hp -= n
	_spawn_float(Vector2(float(LEFT_W) * 0.5, float(PINFO_Y) + 10.0), "-%d" % n, C_HP_RED)
	_view.queue_redraw()


func _deal_damage_to_enemy(n: int) -> void:
	enemy_hp -= n
	_spawn_float(Vector2(float(LEFT_W) * 0.5, float(EINFO_H) * 0.5), "-%d" % n, C_HP_RED)
	_view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# GAME OVER
# ══════════════════════════════════════════════════════════════════
func _check_game_over() -> bool:
	if _ended: return true
	if enemy_hp <= 0:
		_ended = true; _log("YOU WIN!")
		_show_toast("YOU WIN!")
		_view.queue_redraw()
		await get_tree().create_timer(2.5, true).timeout
		battle_ended.emit(true); return true
	if player_hp <= 0:
		_ended = true; _log("YOU LOSE!")
		_show_toast("YOU LOSE...")
		_view.queue_redraw()
		await get_tree().create_timer(2.5, true).timeout
		battle_ended.emit(false); return true
	return false


# ══════════════════════════════════════════════════════════════════
# AI
# ══════════════════════════════════════════════════════════════════
func _detect_ai_type() -> String:
	var aggro := 0; var ctrl := 0
	for card in enemy_deck:
		var cost: int = card.get("cost", 0); var ab: String = card.get("ability", "")
		if cost <= 2: aggro += 1
		if cost >= 4: ctrl  += 1
		if "haste" in ab: aggro += 1
		if "battlecry_destroy" in ab or "battlecry_aoe" in ab: ctrl += 2
	if aggro > ctrl + 4: return "aggro"
	if ctrl  > aggro + 3: return "control"
	return "midrange"


func _ai_play_phase() -> void:
	var played := true
	while played and not _ended:
		played = false
		var best_i := -1; var best_score := -1
		for i in enemy_hand.size():
			var c: Dictionary = enemy_hand[i]
			if c.get("cost", 0) > enemy_mana: continue
			if c["type"] == "demon" and enemy_front.size() >= MAX_ROW and enemy_rear.size() >= MAX_ROW: continue
			var score := _ai_card_score(c)
			if score > best_score: best_score = score; best_i = i
		if best_i >= 0:
			var card: Dictionary = enemy_hand[best_i]
			enemy_mana -= card.get("cost", 0)
			enemy_hand.remove_at(best_i)
			if card["type"] == "demon":
				var ab: String = card.get("ability", "")
				var to_front := true
				if _ai_type == "control" and not ("taunt" in ab) and not ("haste" in ab):
					to_front = enemy_front.size() > 0
				_summon(card, false, to_front)
				_log("Enemy plays %s!" % card["name"])
			else:
				_resolve_spell(card, false); enemy_gy.append(card)
				_log("Enemy casts %s!" % card["name"])
			_view.queue_redraw()
			await get_tree().create_timer(0.45, true).timeout
			if _ended: return
			if await _check_game_over(): return
			played = true


func _ai_card_score(card: Dictionary) -> int:
	var cost: int = card.get("cost", 0); var ab: String = card.get("ability", "")
	var score := cost * 2
	match _ai_type:
		"aggro":
			if "haste" in ab: score += 5
			if card.get("atk", 0) >= 3: score += 2
		"control":
			if "battlecry_destroy" in ab or "battlecry_aoe" in ab: score += 6
			if "taunt" in ab: score += 3
		_: score += card.get("atk", 0) + card.get("hp", 0)
	return score


func _ai_attack_phase() -> void:
	if enemy_front.is_empty() and not enemy_rear.is_empty():
		var mover: Dictionary = enemy_rear.pop_front()
		mover["exhausted"] = false; enemy_front.append(mover)
		_log("Enemy advances %s!" % mover["data"]["name"])
		_view.queue_redraw()
		await get_tree().create_timer(0.3, true).timeout
		if _ended: return

	var attackers := enemy_front.duplicate()
	for attacker in attackers:
		if _ended: return
		if not enemy_front.has(attacker): continue
		if attacker["exhausted"]: continue
		var a_idx: int = enemy_front.find(attacker)
		if a_idx < 0: continue
		attacker["attacked"] += 1
		var max_atk: int = 2 if attacker.get("double_attack", false) else 1
		attacker["exhausted"] = attacker["attacked"] >= max_atk
		_ai_do_attack(a_idx)
		_view.queue_redraw()
		if await _check_game_over(): return
		await get_tree().create_timer(0.35, true).timeout
		if _ended: return
		if not attacker["exhausted"] and enemy_front.has(attacker):
			a_idx = enemy_front.find(attacker)
			if a_idx >= 0:
				attacker["attacked"] += 1; attacker["exhausted"] = true
				_ai_do_attack(a_idx); _view.queue_redraw()
				if await _check_game_over(): return
				await get_tree().create_timer(0.35, true).timeout
				if _ended: return


func _ai_do_attack(a_idx: int) -> void:
	if a_idx >= enemy_front.size(): return
	var att: Dictionary = enemy_front[a_idx]; var nm: String = att["data"]["name"]
	if att.get("unblockable", false):
		_deal_damage_to_player(att["atk"])
		if att.get("lifesteal", false): enemy_hp = mini(enemy_hp + att["atk"], STARTING_HP)
		_log("%s pierces face for %d!" % [nm, att["atk"]]); return
	var taunt_idx := _find_taunt(player_front)
	if taunt_idx >= 0:
		_log("%s → taunt %s!" % [nm, player_front[taunt_idx]["data"]["name"]])
		_do_combat(enemy_front, a_idx, false, true, player_front, taunt_idx, true); return
	if not player_front.is_empty():
		var t := _ai_pick_target(player_front)
		_log("%s → %s!" % [nm, player_front[t]["data"]["name"]])
		_do_combat(enemy_front, a_idx, false, true, player_front, t, true); return
	if _ai_type == "aggro" or player_rear.is_empty():
		_deal_damage_to_player(att["atk"])
		if att.get("lifesteal", false): enemy_hp = mini(enemy_hp + att["atk"], STARTING_HP)
		_log("%s attacks face for %d!" % [nm, att["atk"]])
	else:
		var t := _ai_pick_target(player_rear)
		_log("%s → rear %s!" % [nm, player_rear[t]["data"]["name"]])
		_do_combat(enemy_front, a_idx, false, true, player_rear, t, false)


func _ai_pick_target(board: Array) -> int:
	if board.is_empty(): return -1
	match _ai_type:
		"aggro":   return _find_weakest(board)
		"control": return _find_strongest(board)
		_:
			if not enemy_front.is_empty():
				var atk_pow: int = enemy_front[0]["atk"]
				for i in board.size():
					if board[i]["hp"] <= atk_pow: return i
			return _find_strongest(board)


# ══════════════════════════════════════════════════════════════════
# INPUT
# ══════════════════════════════════════════════════════════════════
func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
		_update_hover()
		if _drag_active: _drag_pos = event.position
		_view.queue_redraw()
		return

	if not (event is InputEventMouseButton): return
	var pos: Vector2 = (event as InputEventMouseButton).position

	if _modal_open:
		_modal_open = false; _view.queue_redraw(); _view.accept_event(); return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_right_click(pos); _view.accept_event(); return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _on_left_press(pos)
		else:
			if _drag_active: _on_drag_drop(pos)
			_drag_active = false; _drag_card = {}; _drag_hand_idx = -1
		_view.accept_event()


func _update_hover() -> void:
	_hover_card = {}; _hover_state = {}
	for i in player_hand.size():
		if _hand_rect(i).has_point(_mouse_pos):
			_hover_card = player_hand[i]; return
	for i in player_front.size():
		if _mini_rect(player_front, PFFRONT_Y, i).has_point(_mouse_pos):
			_hover_card = player_front[i]["data"]; _hover_state = player_front[i]; return
	for i in player_rear.size():
		if _mini_rect(player_rear, PFREAR_Y, i).has_point(_mouse_pos):
			_hover_card = player_rear[i]["data"]; _hover_state = player_rear[i]; return
	for i in enemy_front.size():
		if _mini_rect(enemy_front, EFFRONT_Y, i).has_point(_mouse_pos):
			_hover_card = enemy_front[i]["data"]; _hover_state = enemy_front[i]; return
	for i in enemy_rear.size():
		if _mini_rect(enemy_rear, EFREAR_Y, i).has_point(_mouse_pos):
			_hover_card = enemy_rear[i]["data"]; _hover_state = enemy_rear[i]; return
	if not player_arsenal.is_empty() and _player_arsenal_rect().has_point(_mouse_pos):
		_hover_card = player_arsenal


func _on_right_click(pos: Vector2) -> void:
	if not is_player_turn or _animating or _ended: return
	for i in player_hand.size():
		if _hand_rect(i).has_point(pos): _pitch_card(i); return


func _on_left_press(pos: Vector2) -> void:
	if _ended: return

	# Sidebar: grave / deck → modal
	if _side_grave_rect(true).has_point(pos):
		_open_modal(enemy_gy, "Enemy Graveyard"); return
	if _side_grave_rect(false).has_point(pos):
		_open_modal(player_gy, "Your Graveyard"); return
	if _side_deck_rect(true).has_point(pos):
		var s := enemy_deck.duplicate(); s.shuffle(); _open_modal(s, "Enemy Deck (random)"); return
	if _side_deck_rect(false).has_point(pos):
		var s := player_deck.duplicate(); s.shuffle(); _open_modal(s, "Your Deck (random)"); return

	if not is_player_turn or _animating: return

	# Buttons
	if _end_btn_rect().has_point(pos): _end_player_turn(); return
	if _move_btn_rect().has_point(pos) and not _moved_this_turn:
		_mode = Mode.CHOOSE_MOVE if _mode != Mode.CHOOSE_MOVE else Mode.IDLE
		_view.queue_redraw(); return

	# CHOOSE_ROW
	if _mode == Mode.CHOOSE_ROW:
		if _row_drop_rect(true).has_point(pos):  _place_pending(true);  return
		if _row_drop_rect(false).has_point(pos): _place_pending(false); return
		_mode = Mode.IDLE; _pending_card = {}; _view.queue_redraw(); return

	# CHOOSE_MOVE
	if _mode == Mode.CHOOSE_MOVE:
		for i in player_front.size():
			if _mini_rect(player_front, PFFRONT_Y, i).has_point(pos): _on_move_demon(i, true); return
		for i in player_rear.size():
			if _mini_rect(player_rear, PFREAR_Y, i).has_point(pos): _on_move_demon(i, false); return
		_mode = Mode.IDLE; _view.queue_redraw(); return

	# ATTACKING: resolve target
	if _mode == Mode.ATTACKING:
		if _enemy_face_rect().has_point(pos): _on_attack_face(); return
		for i in enemy_front.size():
			if _mini_rect(enemy_front, EFFRONT_Y, i).has_point(pos): _on_attack_demon(i, true); return
		for i in enemy_rear.size():
			if _mini_rect(enemy_rear, EFREAR_Y, i).has_point(pos): _on_attack_demon(i, false); return
		_mode = Mode.IDLE; _sel_idx = -1; _view.queue_redraw(); return

	# Hand → start drag
	for i in player_hand.size():
		if _hand_rect(i).has_point(pos):
			_drag_active = true; _drag_card = player_hand[i]
			_drag_hand_idx = i; _drag_pos = pos
			_view.queue_redraw(); return

	# Arsenal click → play
	if not player_arsenal.is_empty() and _player_arsenal_rect().has_point(pos):
		_on_arsenal_play(); return

	# Player front card → select attacker
	for i in player_front.size():
		if _mini_rect(player_front, PFFRONT_Y, i).has_point(pos):
			_on_player_front_click(i); return


func _on_drag_drop(pos: Vector2) -> void:
	if _drag_card.is_empty(): return
	var card     := _drag_card
	var hand_idx := _drag_hand_idx

	if not is_player_turn or _animating or _ended: _view.queue_redraw(); return

	# Drop on player info → pitch
	if _pinfo_rect().has_point(pos):
		if hand_idx >= 0 and hand_idx < player_hand.size(): _pitch_card(hand_idx)
		_view.queue_redraw(); return

	# Drop on arsenal
	if _player_arsenal_rect().has_point(pos):
		if hand_idx >= 0 and not _stashed_this_turn and player_arsenal.is_empty():
			_on_stash(hand_idx)
		_view.queue_redraw(); return

	# Cost check
	if card.get("cost", 0) > player_mana:
		_log("Not enough mana!"); _view.queue_redraw(); return

	# Drop on front row
	if _row_drop_rect(true).has_point(pos):
		if card["type"] == "demon":
			if hand_idx >= 0: player_hand.remove_at(hand_idx)
			player_mana -= card.get("cost", 0)
			_summon(card, true, true); player_gy.append(card)
			_log("Played %s to front!" % card["name"])
		else:
			if hand_idx >= 0: player_hand.remove_at(hand_idx)
			player_mana -= card.get("cost", 0)
			_resolve_spell(card, true); player_gy.append(card)
			_log("Cast %s!" % card["name"])
		_view.queue_redraw(); _check_game_over(); return

	# Drop on rear row
	if _row_drop_rect(false).has_point(pos):
		if card["type"] == "demon":
			var ab: String = card.get("ability", "")
			if "taunt" in ab: _log("Taunt must go to front!"); _view.queue_redraw(); return
			if hand_idx >= 0: player_hand.remove_at(hand_idx)
			player_mana -= card.get("cost", 0)
			_summon(card, true, false); player_gy.append(card)
			_log("Played %s to rear!" % card["name"])
		_view.queue_redraw(); _check_game_over(); return

	_view.queue_redraw()


func _pitch_card(i: int) -> void:
	if i >= player_hand.size(): return
	var card: Dictionary = player_hand[i]
	var mv: int = card.get("mana_value", 1)
	player_mana += mv
	_pitched_this_turn.append(card); player_hand.remove_at(i)
	_mode = Mode.IDLE; _sel_idx = -1
	_log("Pitched %s (+%d mana)" % [card["name"], mv]); _view.queue_redraw()


func _place_pending(to_front: bool) -> void:
	if _pending_card.is_empty(): _mode = Mode.IDLE; return
	var row := player_front if to_front else player_rear
	if row.size() >= MAX_ROW:
		_log("%s row is full!" % ("Front" if to_front else "Rear")); _view.queue_redraw(); return
	player_mana -= _pending_card.get("cost", 0)
	if _pending_hand_idx >= 0 and _pending_hand_idx < player_hand.size():
		player_hand.remove_at(_pending_hand_idx)
	_summon(_pending_card, true, to_front); player_gy.append(_pending_card)
	_log("Played %s (%s)" % [_pending_card["name"], "front" if to_front else "rear"])
	_pending_card = {}; _pending_hand_idx = -1; _mode = Mode.IDLE
	_view.queue_redraw(); _check_game_over()


func _on_player_front_click(i: int) -> void:
	if i >= player_front.size(): return
	var d: Dictionary = player_front[i]
	if _mode == Mode.ATTACKING and _sel_idx == i:
		_mode = Mode.IDLE; _sel_idx = -1; _view.queue_redraw(); return
	if d["exhausted"]: _log("%s is exhausted!" % d["data"]["name"]); _view.queue_redraw(); return
	_mode = Mode.ATTACKING; _sel_idx = i; _view.queue_redraw()


func _on_attack_face() -> void:
	if _mode != Mode.ATTACKING or _sel_idx >= player_front.size(): return
	var att: Dictionary = player_front[_sel_idx]
	if not att.get("unblockable", false):
		if not enemy_front.is_empty(): _log("Must attack enemy front!"); _view.queue_redraw(); return
		if _has_taunt(enemy_front):    _log("Attack the taunt!");       _view.queue_redraw(); return
	att["attacked"] += 1
	att["exhausted"] = att["attacked"] >= (2 if att.get("double_attack", false) else 1)
	_deal_damage_to_enemy(att["atk"])
	if att.get("lifesteal", false): player_hp = mini(player_hp + att["atk"], STARTING_HP)
	_log("%s attacks face for %d!" % [att["data"]["name"], att["atk"]])
	_mode = Mode.IDLE; _sel_idx = -1; _view.queue_redraw(); _check_game_over()


func _on_attack_demon(d_idx: int, d_is_front: bool) -> void:
	if _mode != Mode.ATTACKING or _sel_idx >= player_front.size(): return
	var att: Dictionary = player_front[_sel_idx]
	var d_board := enemy_front if d_is_front else enemy_rear
	if d_idx >= d_board.size(): return
	if not att.get("unblockable", false):
		if not d_is_front and not enemy_front.is_empty():
			_log("Must attack front first!"); _view.queue_redraw(); return
		if _has_taunt(enemy_front) and not d_board[d_idx].get("taunt", false):
			_log("Attack the taunt!"); _view.queue_redraw(); return
	att["attacked"] += 1
	att["exhausted"] = att["attacked"] >= (2 if att.get("double_attack", false) else 1)
	_log("%s → %s!" % [att["data"]["name"], d_board[d_idx]["data"]["name"]])
	_do_combat(player_front, _sel_idx, true, true, d_board, d_idx, d_is_front)
	_mode = Mode.IDLE; _sel_idx = -1; _view.queue_redraw(); _check_game_over()


func _on_arsenal_play() -> void:
	if player_arsenal.is_empty(): return
	var card := player_arsenal
	if card.get("cost", 0) > player_mana: _log("Not enough mana!"); _view.queue_redraw(); return
	player_arsenal = {}
	if card["type"] == "demon":
		var ab: String = card.get("ability", "")
		if "taunt" in ab:
			player_mana -= card.get("cost", 0); _summon(card, true, true); player_gy.append(card)
			_log("Arsenal: %s to front!" % card["name"]); _view.queue_redraw()
		else:
			_pending_card = card; _pending_hand_idx = -1; _mode = Mode.CHOOSE_ROW; _view.queue_redraw()
	else:
		player_mana -= card.get("cost", 0); _resolve_spell(card, true); player_gy.append(card)
		_log("Arsenal: %s!" % card["name"]); _view.queue_redraw(); _check_game_over()


func _on_stash(i: int) -> void:
	if i >= player_hand.size(): return
	player_arsenal = player_hand[i]; player_hand.remove_at(i)
	_stashed_this_turn = true; _mode = Mode.IDLE
	_log("Stashed %s in Arsenal" % player_arsenal["name"]); _view.queue_redraw()


func _on_move_demon(i: int, from_front: bool) -> void:
	if from_front:
		if i >= player_front.size(): return
		if player_rear.size() >= MAX_ROW: _log("Rear full!"); _mode = Mode.IDLE; _view.queue_redraw(); return
		var d: Dictionary = player_front[i]; player_front.remove_at(i); player_rear.append(d)
		_log("Moved %s to rear" % d["data"]["name"])
	else:
		if i >= player_rear.size(): return
		if player_front.size() >= MAX_ROW: _log("Front full!"); _mode = Mode.IDLE; _view.queue_redraw(); return
		var d: Dictionary = player_rear[i]; player_rear.remove_at(i); player_front.append(d)
		_log("Moved %s to front" % d["data"]["name"])
	_moved_this_turn = true; _mode = Mode.IDLE; _view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# TOAST & MODAL
# ══════════════════════════════════════════════════════════════════
func _show_toast(text: String) -> void:
	_toast_text = text; _toast_timer = TOAST_DUR

func _open_modal(cards: Array, title: String) -> void:
	_modal_open = true; _modal_cards = cards; _modal_title = title; _view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════
func _kwrd(ability: String, keyword: String) -> bool: return keyword in ability
func _has_taunt(board: Array) -> bool:
	for d in board:
		if d.get("taunt", false): return true
	return false
func _find_taunt(board: Array) -> int:
	for i in board.size():
		if board[i].get("taunt", false): return i
	return -1
func _find_weakest(board: Array) -> int:
	if board.is_empty(): return -1
	var idx := 0
	for i in board.size():
		if board[i]["hp"] < board[idx]["hp"]: idx = i
	return idx
func _find_strongest(board: Array) -> int:
	if board.is_empty(): return -1
	var idx := 0
	for i in board.size():
		if board[i]["atk"] > board[idx]["atk"]: idx = i
	return idx
func _get_row(is_player: bool, is_front: bool) -> Array:
	if is_player: return player_front if is_front else player_rear
	return enemy_front if is_front else enemy_rear
func _enemy_name() -> String:
	if enemy_actor and enemy_actor.has_method("get_name_label"):
		return enemy_actor.get_name_label()
	return "Matthew"


# ══════════════════════════════════════════════════════════════════
# RECT HELPERS
# ══════════════════════════════════════════════════════════════════
func _mini_rect(board: Array, board_y: int, i: int) -> Rect2:
	var count := board.size()
	var total := float(count * MINI_W + maxi(count - 1, 0) * MINI_GAP)
	var sx    := BOARD_X + (BOARD_W - total) / 2.0
	return Rect2(sx + i * (MINI_W + MINI_GAP), float(board_y) + 4.0, MINI_W, MINI_H)

func _hand_rect(i: int) -> Rect2:
	var count := player_hand.size()
	var avail := float(SIDE_X - 4)
	var w     := minf(HAND_CW, (avail - MINI_GAP * maxi(count - 1, 0)) / maxi(count, 1))
	var total := count * w + maxi(count - 1, 0) * MINI_GAP
	var sx    := maxf(2.0, (avail - total) / 2.0)
	return Rect2(sx + i * (w + MINI_GAP), float(HAND_Y) + 4.0, w, float(HAND_CH))

func _row_drop_rect(is_front: bool) -> Rect2:
	var y := float(PFFRONT_Y) if is_front else float(PFREAR_Y)
	return Rect2(float(BOARD_X), y, float(BOARD_W), float(ROW_H) + 8.0)

func _enemy_face_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(SIDE_X), float(EINFO_H))

func _pinfo_rect() -> Rect2:
	return Rect2(0.0, float(PINFO_Y), float(LEFT_W), float(PINFO_H))

func _end_btn_rect() -> Rect2:
	return Rect2(5.0, float(PINFO_Y) + 38.0, float(LEFT_W) - 10.0, 18.0)

func _move_btn_rect() -> Rect2:
	return Rect2(5.0, float(PINFO_Y) + 18.0, float(LEFT_W) - 10.0, 18.0)

func _side_grave_rect(is_enemy: bool) -> Rect2:
	var sec := 0 if is_enemy else 5
	return Rect2(float(SIDE_X), float(sec * SIDE_SEC), float(RIGHT_W), float(SIDE_SEC))

func _side_arsenal_rect(is_enemy: bool) -> Rect2:
	var sec := 1 if is_enemy else 4
	return Rect2(float(SIDE_X), float(sec * SIDE_SEC), float(RIGHT_W), float(SIDE_SEC))

func _side_deck_rect(is_enemy: bool) -> Rect2:
	var sec := 2 if is_enemy else 3
	return Rect2(float(SIDE_X), float(sec * SIDE_SEC), float(RIGHT_W), float(SIDE_SEC))

func _player_arsenal_rect() -> Rect2:
	return _side_arsenal_rect(false)

func _board_world_pos(is_player: bool, is_front: bool, idx: int) -> Vector2:
	var row    := _get_row(is_player, is_front)
	var board_y: int = (PFFRONT_Y if is_front else PFREAR_Y) if is_player else (EFFRONT_Y if is_front else EFREAR_Y)
	var count  := row.size()
	var total  := float(count * MINI_W + maxi(count - 1, 0) * MINI_GAP)
	var sx     := BOARD_X + (BOARD_W - total) / 2.0
	return Vector2(sx + idx * (MINI_W + MINI_GAP) + MINI_W * 0.5, float(board_y) + MINI_H * 0.5)


# ══════════════════════════════════════════════════════════════════
# VFX
# ══════════════════════════════════════════════════════════════════
func _spawn_float(pos: Vector2, text: String, color: Color) -> void:
	_floats.append({"pos": pos, "text": text, "color": color, "alpha": 1.0,
		"vel": Vector2(randf_range(-8.0, 8.0), -38.0)})

func _spawn_death_fx(pos: Vector2) -> void:
	for i in 8:
		var angle := i * TAU / 8.0
		_particles.append({"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(18.0, 46.0),
			"color": Color(randf_range(0.7, 1.0), randf_range(0.1, 0.5), 0.1), "alpha": 1.0})

func _tick(delta: float) -> void:
	var changed := false
	if _toast_timer > 0.0: _toast_timer -= delta; changed = true
	for i in range(_floats.size() - 1, -1, -1):
		var f: Dictionary = _floats[i]; f["pos"] += f["vel"] * delta; f["alpha"] -= delta * 1.3
		if f["alpha"] <= 0.0: _floats.remove_at(i)
		changed = true
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]; p["pos"] += p["vel"] * delta; p["alpha"] -= delta * 1.6
		if p["alpha"] <= 0.0: _particles.remove_at(i)
		changed = true
	if changed: _view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# DRAWING — root
# ══════════════════════════════════════════════════════════════════
func _on_draw() -> void:
	_view.draw_rect(Rect2(0, 0, W, H), C_BG)
	_view.draw_rect(Rect2(0, 0, LEFT_W, H), C_LEFT_BG)
	_view.draw_rect(Rect2(SIDE_X, 0, RIGHT_W, H), C_SIDE_BG)
	_view.draw_rect(Rect2(0, HAND_Y, SIDE_X, HAND_H), C_HAND_BG)

	_draw_left_panel()
	_draw_board()
	_draw_right_sidebar()
	_draw_hand()

	for f in _floats:
		_str_c(f["text"], f["pos"].x, f["pos"].y, 11, Color(f["color"].r, f["color"].g, f["color"].b, f["alpha"]))
	for p in _particles:
		_view.draw_circle(p["pos"], 2.5, Color(p["color"].r, p["color"].g, p["color"].b, p["alpha"]))

	if _drag_active and not _drag_card.is_empty():
		var r := Rect2(_drag_pos - Vector2(HAND_CW, HAND_CH) * 0.5, Vector2(HAND_CW, HAND_CH))
		_draw_hand_card(r, _drag_card, false, false)
		_view.draw_rect(r, Color(1.0, 1.0, 1.0, 0.20))

	if _mode == Mode.CHOOSE_ROW:
		_view.draw_rect(_row_drop_rect(true),  Color(0.2, 0.9, 0.2, 0.22))
		_view.draw_rect(_row_drop_rect(false), Color(0.2, 0.5, 1.0, 0.22))
		_str_c("FRONT", float(BOARD_X) + float(BOARD_W) * 0.5,
			float(PFFRONT_Y) + ROW_H * 0.5 - 4.0, 9, Color(0.2, 1.0, 0.2))
		_str_c("REAR",  float(BOARD_X) + float(BOARD_W) * 0.5,
			float(PFREAR_Y) + ROW_H * 0.5 - 4.0,  9, Color(0.4, 0.7, 1.0))

	if _toast_timer > 0.0: _draw_toast()
	if _modal_open:        _draw_modal()


# ══════════════════════════════════════════════════════════════════
# DRAWING — left panel
# ══════════════════════════════════════════════════════════════════
func _draw_left_panel() -> void:
	# Enemy info
	_view.draw_rect(Rect2(0, 0, LEFT_W, EINFO_H), C_EINFO_BG)
	_view.draw_rect(Rect2(0, 0, LEFT_W, EINFO_H), C_DIV, false, 1.0)
	_str("Enemy! %s" % _enemy_name(), 5.0, 2.0, 8, C_TEXT)
	_str("Life: %d" % enemy_hp,       5.0, 14.0, 9, C_HP_RED if enemy_hp <= 5 else C_TEXT)
	_str("Hand: %d" % enemy_hand.size(), 5.0, 26.0, 9, C_TEXT)
	var turn_col := C_SEL if is_player_turn else C_TARGET
	_view.draw_circle(Vector2(LEFT_W - 10.0, EINFO_H * 0.5), 7.0, turn_col)
	_view.draw_circle(Vector2(LEFT_W - 10.0, EINFO_H * 0.5), 7.0, C_DIV, false, 1.0)

	# Log
	_view.draw_rect(Rect2(0, LOG_Y, LEFT_W, LOG_H), C_LOG_BG)
	_view.draw_rect(Rect2(0, LOG_Y, LEFT_W, LOG_H), C_DIV, false, 1.0)
	_str("Log", 4.0, float(LOG_Y) + 1.0, 7, C_MUTED)
	var start := maxi(0, _battle_log.size() - LOG_VISIBLE)
	for i in mini(LOG_VISIBLE, _battle_log.size()):
		var idx   := start + i
		var alpha := maxf(0.45, 1.0 - float(_battle_log.size() - 1 - idx) * 0.14)
		_str("_" + _battle_log[idx], 3.0, float(LOG_Y) + 10.0 + i * LOG_LINE_H, 7,
			Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, alpha))

	# Zoomed card
	_view.draw_rect(Rect2(0, ZOOM_Y, LEFT_W, ZOOM_H), C_ZOOM_BG)
	_view.draw_rect(Rect2(0, ZOOM_Y, LEFT_W, ZOOM_H), C_DIV, false, 1.0)
	if not _hover_card.is_empty():
		_draw_zoomed_card(_hover_card, _hover_state)

	# Player info
	_view.draw_rect(Rect2(0, PINFO_Y, LEFT_W, PINFO_H), C_PINFO_BG)
	_view.draw_rect(Rect2(0, PINFO_Y, LEFT_W, PINFO_H), C_DIV, false, 1.0)
	_str("You", 5.0, float(PINFO_Y) + 1.0, 8, C_TEXT)
	_str("Life: %d" % player_hp, 5.0, float(PINFO_Y) + 12.0, 9,
		C_HP_RED if player_hp <= 5 else C_TEXT)
	for mi in player_max_mana:
		var cx := 5.0 + mi * 9.0; var cy := float(PINFO_Y) + 24.0
		_view.draw_circle(Vector2(cx, cy), 3.5,
			C_MANA_BLU if mi < player_mana else Color(0.20, 0.22, 0.35))
		_view.draw_circle(Vector2(cx, cy), 3.5, C_DIV, false, 0.5)

	# MOVE button
	var mb := _move_btn_rect()
	var ma := is_player_turn and not _moved_this_turn and not _animating
	_view.draw_rect(mb, Color(0.20, 0.20, 0.12) if ma else Color(0.16, 0.13, 0.10))
	_view.draw_rect(mb, C_DIV, false, 1.0)
	_str_c("MOVE", mb.get_center().x, mb.get_center().y - 4.0, 8,
		C_TEXT if ma else Color(C_TEXT, 0.35))

	# END TURN button
	var eb := _end_btn_rect()
	var ea := is_player_turn and not _animating and not _ended
	_view.draw_rect(eb, Color(0.55, 0.30, 0.12) if ea else Color(0.22, 0.16, 0.10))
	_view.draw_rect(eb, C_DIV, false, 1.0)
	_str_c("END TURN", eb.get_center().x, eb.get_center().y - 4.0, 9,
		C_TEXT_LT if ea else Color(C_TEXT_LT, 0.35))


# ══════════════════════════════════════════════════════════════════
# DRAWING — board
# ══════════════════════════════════════════════════════════════════
func _draw_board() -> void:
	_view.draw_line(Vector2(BOARD_X, BOARD_DIV_Y), Vector2(SIDE_X, BOARD_DIV_Y), C_DIV, 2.0)

	_str("ENEMY FRONT", float(BOARD_X) + 3.0, float(EFFRONT_Y) + 2.0, 7, C_MUTED)
	_str("ENEMY REAR",  float(BOARD_X) + 3.0, float(EFREAR_Y)  + 2.0, 7, C_MUTED)
	_str("FRONT",       float(BOARD_X) + 3.0, float(PFFRONT_Y) + 2.0, 7, C_MUTED)
	_str("REAR",        float(BOARD_X) + 3.0, float(PFREAR_Y)  + 2.0, 7, C_MUTED)

	if enemy_front.is_empty():
		_str_c("— empty —", float(BOARD_X) + float(BOARD_W) * 0.5,
			float(EFFRONT_Y) + ROW_H * 0.5 - 4.0, 7, Color(C_MUTED, 0.4))
	if enemy_rear.is_empty():
		_str_c("— empty —", float(BOARD_X) + float(BOARD_W) * 0.5,
			float(EFREAR_Y) + ROW_H * 0.5 - 4.0,  7, Color(C_MUTED, 0.35))
	if player_front.is_empty():
		_str_c("— empty —", float(BOARD_X) + float(BOARD_W) * 0.5,
			float(PFFRONT_Y) + ROW_H * 0.5 - 4.0, 7, Color(C_MUTED, 0.4))
	if player_rear.is_empty():
		_str_c("— empty —", float(BOARD_X) + float(BOARD_W) * 0.5,
			float(PFREAR_Y) + ROW_H * 0.5 - 4.0,  7, Color(C_MUTED, 0.35))

	for i in enemy_front.size():
		_draw_mini_card(_mini_rect(enemy_front, EFFRONT_Y, i), enemy_front[i],
			_mode == Mode.ATTACKING, false)
	for i in enemy_rear.size():
		var tgt := _mode == Mode.ATTACKING and enemy_front.is_empty()
		_draw_mini_card(_mini_rect(enemy_rear, EFREAR_Y, i), enemy_rear[i], tgt, false)
	for i in player_front.size():
		var sel := _mode == Mode.ATTACKING and _sel_idx == i
		_draw_mini_card(_mini_rect(player_front, PFFRONT_Y, i), player_front[i], false, sel)
	for i in player_rear.size():
		_draw_mini_card(_mini_rect(player_rear, PFREAR_Y, i), player_rear[i], false, false)

	# Attack arrow
	if _mode == Mode.ATTACKING and _sel_idx >= 0 and _sel_idx < player_front.size():
		var start := _board_world_pos(true, true, _sel_idx)
		_draw_arrow(start, _mouse_pos, C_SEL)
		if player_front[_sel_idx].get("unblockable", false) or enemy_front.is_empty():
			_view.draw_rect(_enemy_face_rect(), Color(1.0, 0.3, 0.1, 0.22))
			_str_c("DIRECT ATTACK", float(SIDE_X) * 0.5,
				float(EINFO_H) * 0.5 - 4.0, 8, C_TARGET)

	if _mode == Mode.CHOOSE_MOVE:
		_view.draw_rect(_row_drop_rect(true),  Color(0.2, 0.9, 0.2, 0.12))
		_view.draw_rect(_row_drop_rect(false), Color(0.4, 0.7, 1.0, 0.12))


# ══════════════════════════════════════════════════════════════════
# DRAWING — right sidebar
# ══════════════════════════════════════════════════════════════════
func _draw_right_sidebar() -> void:
	_draw_side_sec(0, "GRAVE",   enemy_gy.size(),    {})
	_draw_side_sec(1, "ARSENAL", -1,                 {})   # enemy arsenal (not tracked)
	_draw_side_sec(2, "DECK",    enemy_deck.size(),  {})
	_draw_side_sec(3, "DECK",    player_deck.size(), {})
	_draw_side_sec(4, "ARSENAL", -1,                 player_arsenal)
	_draw_side_sec(5, "GRAVE",   player_gy.size(),   {})


func _draw_side_sec(sec: int, label: String, count: int, card: Dictionary) -> void:
	var r := Rect2(float(SIDE_X), float(sec * SIDE_SEC), float(RIGHT_W), float(SIDE_SEC))
	_view.draw_rect(r, C_SIDE_BG)
	_view.draw_rect(r, C_DIV, false, 0.5)

	if count >= 0:
		_str_c(label, r.get_center().x, r.position.y + 4.0,  7, C_TEXT_LT)
		_str_c(str(count), r.get_center().x, r.position.y + 16.0, 13, C_TEXT_LT)
		_str_c("cards", r.get_center().x, r.position.y + 32.0, 6,  Color(C_TEXT_LT, 0.55))
	else:
		_str_c(label, r.get_center().x, r.position.y + 3.0, 6, Color(C_TEXT_LT, 0.65))
		if not card.is_empty():
			var cr := Rect2(r.position.x + 3.0, r.position.y + 13.0,
					r.size.x - 6.0, r.size.y - 16.0)
			_draw_side_card(cr, card)
		else:
			_str_c("empty", r.get_center().x, r.get_center().y, 6, Color(C_TEXT_LT, 0.30))


# ══════════════════════════════════════════════════════════════════
# DRAWING — hand
# ══════════════════════════════════════════════════════════════════
func _draw_hand() -> void:
	if player_hand.is_empty():
		_str_c("(empty hand)", float(SIDE_X) * 0.5, float(HAND_Y) + HAND_CH * 0.5, 8, C_MUTED)
		return
	for i in player_hand.size():
		if _drag_active and _drag_hand_idx == i: continue
		var r    := _hand_rect(i)
		var card: Dictionary = player_hand[i]
		var gray: bool = card.get("cost", 0) > player_mana
		_draw_hand_card(r, card, false, gray)


# ══════════════════════════════════════════════════════════════════
# DRAWING — card renders
# ══════════════════════════════════════════════════════════════════
func _draw_mini_card(r: Rect2, d: Dictionary, targetable: bool, selected: bool) -> void:
	var card: Dictionary = d["data"]
	var is_dem: bool = card.get("type", "demon") == "demon"
	_view.draw_rect(r, C_DEMON_BG if is_dem else C_SPELL_BG)

	var rc: Color = RARITY_COL.get(card.get("rarity", "common"), C_MUTED)
	var border := C_SEL if selected else (C_TARGET if targetable else rc)
	_view.draw_rect(r, border, false, 2.0)

	if d.get("taunt", false):
		_view.draw_rect(r, Color(1.0, 0.85, 0.1), false, 3.0)

	if d.get("exhausted", false):
		_view.draw_rect(r, C_EXHAUST)
		_str_c("ZZZ", r.get_center().x, r.get_center().y - 6.0, 10, Color(0.85, 0.85, 1.0, 0.75))

	var nm: String = card.get("name", "")
	if nm.length() > 8: nm = nm.left(8) + "..."
	_str(nm, r.position.x + 3.0, r.position.y + 2.0, 7, C_TEXT)

	if card.get("ability", "") != "" and not d.get("exhausted", false):
		_str_c("Effect", r.get_center().x, r.get_center().y - 6.0, 7, Color(0.28, 0.18, 0.60))

	if is_dem:
		var max_hp: int = card.get("hp", 1); var cur_hp: int = d.get("hp", max_hp)
		_str(  str(d.get("atk", card.get("atk", 0))),
			r.position.x + 3.0,            r.position.y + r.size.y - 12.0, 9, C_TEXT)
		_str_c("/", r.get_center().x,      r.position.y + r.size.y - 12.0, 9, C_MUTED)
		_str_r(str(cur_hp),
			r.position.x + r.size.x - 3.0, r.position.y + r.size.y - 12.0, 9,
			C_HP_RED if cur_hp < max_hp else C_TEXT)
	else:
		_str_c("SPELL", r.get_center().x, r.position.y + r.size.y - 14.0, 7, Color(0.24, 0.40, 0.08))

	# Cost badge bottom-left (spec)
	_draw_cost_badge(r.position + Vector2(2.0, r.size.y - 26.0), card.get("cost", 0))


func _draw_hand_card(r: Rect2, card: Dictionary, selected: bool, grayed: bool) -> void:
	var is_dem: bool = card.get("type", "demon") == "demon"
	_view.draw_rect(r, C_DEMON_BG if is_dem else C_SPELL_BG)
	var rc: Color = RARITY_COL.get(card.get("rarity", "common"), C_MUTED)
	_view.draw_rect(r, C_SEL if selected else rc, false, 2.0)
	if grayed: _view.draw_rect(r, Color(0.0, 0.0, 0.0, 0.38))

	_str_fit(card.get("name", ""), r.position.x + 3.0, r.position.y + 2.0,
		r.size.x - 16.0, 7, C_TEXT)
	# Cost badge top-right (spec: "angle on top right")
	_draw_cost_badge(Vector2(r.position.x + r.size.x - 15.0, r.position.y + 2.0),
		card.get("cost", 0))

	# Art placeholder
	var art := Rect2(r.position.x + 4.0, r.position.y + 18.0, r.size.x - 8.0, r.size.y - 46.0)
	var hc_art_bg := C_DEMON_BG if is_dem else C_SPELL_BG
	_view.draw_rect(art, Color(hc_art_bg.r * 0.84, hc_art_bg.g * 0.84, hc_art_bg.b * 0.84))
	_view.draw_rect(art, Color(rc.r, rc.g, rc.b, 0.35), false, 1.0)

	if is_dem:
		_str(  str(card.get("atk", 0)), r.position.x + 3.0,             r.position.y + r.size.y - 12.0, 9, C_TEXT)
		_str_c("/",                      r.get_center().x,               r.position.y + r.size.y - 12.0, 9, C_MUTED)
		_str_r(str(card.get("hp",  0)), r.position.x + r.size.x - 3.0, r.position.y + r.size.y - 12.0, 9, C_TEXT)
	else:
		_str_c("SPELL", r.get_center().x, r.position.y + r.size.y - 14.0, 7, Color(0.24, 0.40, 0.08))


func _draw_zoomed_card(card: Dictionary, state: Dictionary) -> void:
	var m  := 6.0
	var cr := Rect2(m, float(ZOOM_Y) + m, float(LEFT_W) - m * 2.0, float(ZOOM_H) - m * 2.0)
	var is_dem: bool = card.get("type", "demon") == "demon"
	_view.draw_rect(cr, C_DEMON_BG if is_dem else C_SPELL_BG)
	var rc: Color = RARITY_COL.get(card.get("rarity", "common"), C_MUTED)
	_view.draw_rect(cr, rc, false, 2.0)

	# Name + cost
	_str_fit(card.get("name", ""), cr.position.x + 4.0, cr.position.y + 2.0,
		cr.size.x - 18.0, 8, C_TEXT)
	_draw_cost_badge(Vector2(cr.position.x + cr.size.x - 15.0, cr.position.y + 2.0),
		card.get("cost", 0))

	# Rarity jewel
	_view.draw_circle(Vector2(cr.position.x + cr.size.x - 7.0, cr.position.y + 20.0), 4.0, rc)

	# Art area
	var art_h := 80.0
	var art   := Rect2(cr.position.x + 4.0, cr.position.y + 18.0, cr.size.x - 8.0, art_h)
	var art_bg := C_DEMON_BG if is_dem else C_SPELL_BG
	_view.draw_rect(art, Color(art_bg.r * 0.80, art_bg.g * 0.80, art_bg.b * 0.80))
	_view.draw_rect(art, Color(rc.r, rc.g, rc.b, 0.28), false, 1.0)

	# Type line
	var ty := cr.position.y + 18.0 + art_h + 4.0
	if is_dem:
		_str_c("DEMON - %s" % card.get("subtype", "dark").to_upper(), cr.get_center().x, ty, 7, C_MUTED)
	else:
		_str_c("SPELL", cr.get_center().x, ty, 7, Color(0.24, 0.40, 0.08))

	# Effect text (full, wrapped)
	var ab_desc: String = card.get("ability_desc", card.get("desc", ""))
	if ab_desc != "":
		_str_wrap_ml(ab_desc, cr.position.x + 4.0, ty + 12.0, cr.size.x - 8.0, 7, C_TEXT)

	# ATK / HP
	if is_dem:
		var max_hp: int = card.get("hp", 1)
		var cur_hp: int = state.get("hp", max_hp)
		var cur_atk     := str(state.get("atk", card.get("atk", 0)))
		_str(   cur_atk,        cr.position.x + 4.0,             cr.position.y + cr.size.y - 12.0, 10, C_TEXT)
		_str_c( "/",            cr.get_center().x,                cr.position.y + cr.size.y - 12.0, 10, C_MUTED)
		_str_r( str(cur_hp),    cr.position.x + cr.size.x - 4.0, cr.position.y + cr.size.y - 12.0, 10,
			C_HP_RED if cur_hp < max_hp else C_TEXT)


func _draw_side_card(r: Rect2, card: Dictionary) -> void:
	var is_dem: bool = card.get("type", "demon") == "demon"
	_view.draw_rect(r, C_DEMON_BG if is_dem else C_SPELL_BG)
	var rc: Color = RARITY_COL.get(card.get("rarity", "common"), C_MUTED)
	_view.draw_rect(r, rc, false, 1.5)
	var nm: String = card.get("name", "")
	if nm.length() > 7: nm = nm.left(7) + "..."
	_str(nm, r.position.x + 2.0, r.position.y + 2.0, 6, C_TEXT)
	if card.get("ability", "") != "":
		_str_c("Effect", r.get_center().x, r.get_center().y - 4.0, 6, Color(0.28, 0.18, 0.60))
	if is_dem:
		_str(  str(card.get("atk", 0)), r.position.x + 2.0,             r.position.y + r.size.y - 10.0, 8, C_TEXT)
		_str_c("/",                      r.get_center().x,               r.position.y + r.size.y - 10.0, 8, C_MUTED)
		_str_r(str(card.get("hp",  0)), r.position.x + r.size.x - 2.0, r.position.y + r.size.y - 10.0, 8, C_TEXT)
	else:
		_str_c("SPELL", r.get_center().x, r.position.y + r.size.y - 12.0, 6, Color(0.24, 0.40, 0.08))


func _draw_cost_badge(pos: Vector2, cost: int) -> void:
	var c := pos + Vector2(5, 5)
	_view.draw_circle(c, 6.0, Color(0.10, 0.20, 0.76))
	_view.draw_circle(c, 6.0, Color(0.30, 0.50, 1.0), false, 1.0)
	_str_c(str(cost), c.x, c.y - 3.0, 7, Color.WHITE)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	if (to - from).length() < 10.0: return
	var norm := (to - from).normalized()
	var perp := Vector2(-norm.y, norm.x)
	_view.draw_line(from, to, color, 2.0)
	_view.draw_line(to, to - norm * 10.0 + perp * 5.0, color, 2.0)
	_view.draw_line(to, to - norm * 10.0 - perp * 5.0, color, 2.0)


func _draw_toast() -> void:
	var alpha := clampf(_toast_timer / TOAST_DUR * 3.0, 0.0, 1.0)
	if alpha <= 0.0: return
	var tw := 200.0; var th := 30.0
	var tx := (W - tw) * 0.5; var ty := H * 0.5 - th * 0.5
	_view.draw_rect(Rect2(tx, ty, tw, th),
		Color(C_TOAST_BG.r, C_TOAST_BG.g, C_TOAST_BG.b, C_TOAST_BG.a * alpha))
	_view.draw_rect(Rect2(tx, ty, tw, th), Color(C_DIV.r, C_DIV.g, C_DIV.b, alpha), false, 1.5)
	_str_c(_toast_text, W * 0.5, ty + 7.0, 13, Color(1.0, 1.0, 1.0, alpha))


func _draw_modal() -> void:
	_view.draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0, 0.62))
	var mw := 490.0; var mh := 410.0
	var mx := (W - mw) * 0.5; var my := (H - mh) * 0.5
	_view.draw_rect(Rect2(mx, my, mw, mh), C_MODAL_BG)
	_view.draw_rect(Rect2(mx, my, mw, mh), C_DIV, false, 1.5)
	_str_c(_modal_title, W * 0.5, my + 5.0, 10, C_TEXT_LT)
	_view.draw_line(Vector2(mx + 4, my + 19), Vector2(mx + mw - 4, my + 19), C_DIV, 1.0)
	var cols := 4; var cw := 90.0; var ch := 120.0; var gap := 8.0
	var sx := mx + (mw - (cols * cw + (cols - 1) * gap)) * 0.5
	var sy := my + 26.0
	for i in _modal_cards.size():
		var row := int(float(i) / float(cols)); var col := i % cols
		var cr  := Rect2(sx + col * (cw + gap), sy + row * (ch + gap), cw, ch)
		if cr.position.y + ch > my + mh - 14.0: break
		_draw_hand_card(cr, _modal_cards[i], false, false)
	_str_c("Click anywhere to close", W * 0.5, my + mh - 10.0, 7, Color(C_TEXT_LT, 0.45))


# ══════════════════════════════════════════════════════════════════
# TEXT HELPERS
# ══════════════════════════════════════════════════════════════════
func _fnt() -> Font: return ThemeDB.fallback_font

func _str(text: String, x: float, y: float, sz: int = 9, color: Color = C_TEXT) -> void:
	_view.draw_string(_fnt(), Vector2(x, y + sz), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)

func _str_c(text: String, cx: float, cy: float, sz: int = 9, color: Color = C_TEXT) -> void:
	var tw := _fnt().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	_view.draw_string(_fnt(), Vector2(cx - tw * 0.5, cy + sz * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)

func _str_r(text: String, rx: float, y: float, sz: int = 9, color: Color = C_TEXT) -> void:
	var tw := _fnt().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	_view.draw_string(_fnt(), Vector2(rx - tw, y + sz), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)

func _str_fit(text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var f := _fnt(); var t := text
	while t.length() > 2 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		t = t.left(t.length() - 1)
	if t != text: t = t.left(t.length() - 1) + "."
	_view.draw_string(f, Vector2(x, y + sz), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)

func _str_wrap(text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var f := _fnt(); var l1 := ""; var l2 := ""
	for word in text.split(" "):
		var test := (l1 + " " + word).strip_edges()
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= max_w: l1 = test
		else: l2 = (l2 + " " + word).strip_edges()
	_view.draw_string(f, Vector2(x, y + sz), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)
	if l2 != "":
		var s := l2 if f.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= max_w \
				else l2.left(l2.length() - 2) + ".."
		_view.draw_string(f, Vector2(x, y + sz * 2 + 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)

func _str_wrap_ml(text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var f := _fnt(); var line := ""; var cy := y + sz
	for word in text.split(" "):
		var test := (line + " " + word).strip_edges()
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= max_w:
			line = test
		else:
			if line != "":
				_view.draw_string(f, Vector2(x, cy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)
				cy += sz + 2
			line = word
	if line != "":
		_view.draw_string(f, Vector2(x, cy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, color)
