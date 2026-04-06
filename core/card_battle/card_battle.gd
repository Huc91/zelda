class_name CardBattle extends CanvasLayer

class _View extends Control:
	var b
	func _draw() -> void:                   b._on_draw()
	func _gui_input(e: InputEvent) -> void: b._on_input(e)
	func _process(dt: float) -> void:       b._tick(dt)


# Pixel-perfect layout / palette: `CardBattleConstants` (card_battle_constants.gd).
# https://www.figma.com/design/iRJDqyetz1RTxvQOd1a7mU/test?node-id=1-3

# ══════════════════════════════════════════════════════════════════
# STATE — game
# ══════════════════════════════════════════════════════════════════
var enemy_actor:  Node
var player_first: bool

var player_hp := CardBattleConstants.STARTING_HP
var enemy_hp  := CardBattleConstants.STARTING_HP

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
var enemy_arsenal: Dictionary = {}

var _pitched_this_turn:       Array = []
var _enemy_pitched_this_turn: Array = []
var _moved_this_turn   := false
var _stashed_this_turn := false
var _enemy_stashed_this_turn := false

var player_mana     := 0
var player_turn_num := 0
var enemy_mana      := 0
var enemy_turn_num  := 0

var _ai_type       := "midrange"
var is_player_turn := false
var _animating     := false
var _ended         := false

enum Mode { IDLE, CHOOSE_ROW, ATTACKING, CHOOSE_ARSENAL }
var _mode          := Mode.IDLE
var _pending_card:  Dictionary = {}
var _pending_hand_idx := -1
var _sel_idx          := -1

var _battle_log:  Array = []
var _log_scroll:  int   = 0
var _floats:      Array = []
var _particles:   Array = []


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

## Context menu: `_ctx_idx` indexes `player_front` or `player_rear` depending on `_ctx_is_front`.
## Front minion: drag past threshold = attack aim (arrow). Rear: click toggles context only.
var _ctx_idx: int = -1
var _ctx_is_front: bool = true
var _atk_drag_idx: int = -1
var _atk_drag_start: Vector2 = Vector2.ZERO
var _rear_pick_idx: int = -1
var _rear_pick_start: Vector2 = Vector2.ZERO

var _toast_text:  String = ""
var _toast_timer: float  = 0.0
## True after End Turn opened the Arsenal choice — stashing should finish the turn without a second End press.
var _pending_finish_after_arsenal: bool = false

var _modal_open:  bool   = false
var _modal_cards: Array  = []
var _modal_title: String = ""

var _view: _View
var _battle_font: Font
var _ai_runner: CardBattleAIRunner
signal battle_ended(player_won: bool)


# ══════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════
func setup(p_first: bool, p_enemy: Node) -> void:
	player_first = p_first
	enemy_actor  = p_enemy
	layer        = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_battle_font()
	_view        = _View.new()
	_view.b      = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_view)
	_ai_runner = CardBattleAIRunner.new(self)
	_start_battle()


# ══════════════════════════════════════════════════════════════════
# BATTLE FLOW
# ══════════════════════════════════════════════════════════════════
func _start_battle() -> void:
	player_deck = CardDB.starter_deck()
	enemy_deck  = CardDB.enemy_deck()
	_ai_type    = _ai_runner.detect_ai_type_from_deck(enemy_deck)
	if not _draw_mandatory_refresh(player_hand, player_deck, CardBattleConstants.STARTING_HAND, true): return
	if not _draw_mandatory_refresh(enemy_hand, enemy_deck, CardBattleConstants.STARTING_HAND, false): return
	_log("Battle started!")
	_show_toast("Battle Start!")
	_view.queue_redraw()
	await get_tree().create_timer(0.8, true).timeout
	if _ended: return
	if player_first: _start_player_turn()
	else:            _start_enemy_turn()


## Mandatory draws (opening + end-of-turn refresh). Draw up to n; stop if deck runs dry (no cards forced from empty deck).
## Lose only when deck, hand, and board are all empty for that side.
func _draw_mandatory_refresh(hand: Array, deck: Array, n: int, is_player_deck: bool) -> bool:
	for _i in n:
		if deck.is_empty():
			break
		hand.append(deck.pop_front())
	_check_auto_lose_no_resources(is_player_deck)
	return not _ended


func _board_empty_for(is_player_side: bool) -> bool:
	if is_player_side:
		return player_front.is_empty() and player_rear.is_empty()
	return enemy_front.is_empty() and enemy_rear.is_empty()


func _check_auto_lose_no_resources(is_player_side: bool) -> void:
	if _ended: return
	var d: Array = player_deck if is_player_side else enemy_deck
	var h: Array = player_hand if is_player_side else enemy_hand
	if not d.is_empty():
		return
	if not h.is_empty():
		return
	if not _board_empty_for(is_player_side):
		return
	_schedule_empty_resources_loss(is_player_side)


func _schedule_empty_resources_loss(is_player_side: bool) -> void:
	if _ended: return
	_ended = true
	if is_player_side:
		_log("You're out of cards and minions — you lose.")
		_show_toast("Out of resources!")
	else:
		_log("The enemy is out of cards and minions — you win!")
		_show_toast("Enemy out!")
	_view.queue_redraw()
	var player_won: bool = not is_player_side
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func (): battle_ended.emit(player_won))


func _draw_n(hand: Array, deck: Array, n: int) -> void:
	for _i in n:
		if deck.is_empty(): return
		hand.append(deck.pop_front())


func _draw_one(hand: Array, deck: Array) -> void:
	if not deck.is_empty(): hand.append(deck.pop_front())
	if hand == player_hand: _check_osiris_combo_win()


func _log(s: String) -> void:
	_battle_log.append(s)
	var flat: Array[String] = _log_flat_lines()
	_log_scroll = maxi(0, flat.size() - CardBattleConstants.LOG_VISIBLE)
	_clamp_log_scroll()
	_view.queue_redraw()


func _start_player_turn() -> void:
	is_player_turn   = true
	_animating       = false
	player_turn_num += 1
	player_mana        = 0
	_pitched_this_turn.clear()
	_moved_this_turn   = false
	_stashed_this_turn = false
	_mode              = Mode.IDLE
	_sel_idx           = -1
	_ctx_idx           = -1
	_ctx_is_front      = true
	_atk_drag_idx      = -1
	_rear_pick_idx     = -1
	_pending_card      = {}
	_begin_turn_refresh_exhaustion_for_side(true)
	_apply_start_of_turn_board_effects(true)
	_log("--- Your turn %d — %d mana (pitch hand for more) ---" % [player_turn_num, player_mana])
	_show_toast("Your Turn")
	_view.queue_redraw()


## End Turn button: optional Arsenal stash first (see _handle_end_turn_click).
func _finish_end_player_turn() -> void:
	if not is_player_turn or _animating or _ended: return
	_apply_end_of_turn_board_effects(true)
	_thaw_frozen_minions_for_side(true)
	is_player_turn = false
	_mode          = Mode.IDLE
	_sel_idx       = -1
	_ctx_idx       = -1
	_ctx_is_front  = true
	_atk_drag_idx  = -1
	_rear_pick_idx = -1
	_pending_card  = {}
	_pitched_this_turn.shuffle()
	for c in _pitched_this_turn: player_deck.append(c)
	_pitched_this_turn.clear()
	for c in player_hand: player_gy.append(c)
	player_hand.clear()
	if not _draw_mandatory_refresh(player_hand, player_deck, CardBattleConstants.STARTING_HAND, true):
		return
	_check_osiris_combo_win()
	_view.queue_redraw()
	# Interstitial banner: fully clear before AI runs (fixes.md)
	_toast_text = "Enemy Turn"
	_toast_timer = CardBattleConstants.ENEMY_TURN_LEAD_SEC
	_view.queue_redraw()
	await get_tree().create_timer(CardBattleConstants.ENEMY_TURN_LEAD_SEC, true).timeout
	if _ended: return
	_toast_timer = 0.0
	_toast_text = ""
	_view.queue_redraw()
	_start_enemy_turn()


func _handle_end_turn_click() -> void:
	if not is_player_turn or _animating or _ended: return
	if _mode == Mode.ATTACKING or _mode == Mode.CHOOSE_ROW:
		_log("Finish that action first (attack / row).")
		return
	if _mode == Mode.CHOOSE_ARSENAL:
		_pending_finish_after_arsenal = false
		_mode = Mode.IDLE
		await _finish_end_player_turn()
		return
	if player_arsenal.is_empty() and not _stashed_this_turn and not player_hand.is_empty():
		_pending_finish_after_arsenal = true
		_mode = Mode.CHOOSE_ARSENAL
		_ctx_idx = -1
		_ctx_is_front = true
		_atk_drag_idx = -1
		_rear_pick_idx = -1
		_sel_idx = -1
		_show_toast("Arsenal: hand card or End to skip")
		_log("Arsenal — click a hand card to stash, or End Turn to skip.")
		_view.queue_redraw()
		return
	await _finish_end_player_turn()


func _start_enemy_turn() -> void:
	if _ended:
		_animating = false
		return
	_animating     = true
	is_player_turn = false
	enemy_turn_num += 1
	enemy_mana      = 0
	_enemy_stashed_this_turn = false
	for c in enemy_hand: enemy_gy.append(c)
	enemy_hand.clear()
	if not _draw_mandatory_refresh(enemy_hand, enemy_deck, CardBattleConstants.STARTING_HAND, false):
		_animating = false
		return
	_begin_turn_refresh_exhaustion_for_side(false)
	_apply_start_of_turn_board_effects(false)
	_log("--- Enemy turn %d ---" % enemy_turn_num)
	_view.queue_redraw()
	await _ai_runner.play_phase()
	if _ended: return
	await _ai_runner.attack_phase()
	if _ended: return
	_enemy_pitched_this_turn.shuffle()
	for c in _enemy_pitched_this_turn: enemy_deck.append(c)
	_enemy_pitched_this_turn.clear()
	_ai_runner.stash_arsenal_at_turn_end()
	_apply_end_of_turn_board_effects(false)
	_thaw_frozen_minions_for_side(false)
	_animating = false
	if not _ended: _start_player_turn()


# ══════════════════════════════════════════════════════════════════
# START OF TURN — field abilities (after mana reset & before pitch / AI)
# ══════════════════════════════════════════════════════════════════
func _apply_start_of_turn_board_effects(is_player: bool) -> void:
	var pf: Array = player_front if is_player else enemy_front
	var pr: Array = player_rear  if is_player else enemy_rear
	var gain: int = 0
	var parts: Array[String] = []
	for row in [pf, pr]:
		for d in row:
			if d.get("hp", 0) <= 0:
				continue
			var ab: String = str(d["data"].get("ability", ""))
			if _kwrd(ab, "mana_per_turn"):
				gain += 1
				parts.append(str(d["data"].get("name", "?")))
	if gain <= 0:
		return
	if is_player:
		player_mana = mini(player_mana + gain, 10)
	else:
		enemy_mana = mini(enemy_mana + gain, 10)
	var who: String = "You" if is_player else "Enemy"
	var name_list: String = ""
	for i in range(parts.size()):
		if i > 0:
			name_list += ", "
		name_list += parts[i]
	_log("%s: +%d mana (%s)." % [who, gain, name_list])


## End of turn — field abilities (e.g. Radiant Sentinel regen) while minions are still on board.
func _apply_end_of_turn_board_effects(is_player: bool) -> void:
	var pf: Array = player_front if is_player else enemy_front
	var pr: Array = player_rear  if is_player else enemy_rear
	for row in [pf, pr]:
		for d in row:
			if d.get("hp", 0) <= 0:
				continue
			var ab: String = str(d["data"].get("ability", ""))
			if not _kwrd(ab, "taunt_regen"):
				continue
			var mx: int = int(d["data"].get("hp", 1))
			if d["hp"] >= mx:
				continue
			d["hp"] = mini(d["hp"] + 1, mx)
			_log("%s restores 1 HP." % str(d["data"].get("name", "?")))


## Freeze — show exhausted (ZZZ) on the target until end of that minion owner's next turn (then thaw).
func _apply_freeze(d: Dictionary) -> void:
	d["frozen"] = true
	d["exhausted"] = true


func _begin_turn_refresh_exhaustion_for_side(is_player_side: bool) -> void:
	var pf: Array = player_front if is_player_side else enemy_front
	var pr: Array = player_rear  if is_player_side else enemy_rear
	for row in [pf, pr]:
		for d in row:
			d["attacked"] = 0
			if d.get("frozen", false):
				d["exhausted"] = true
			else:
				d["exhausted"] = false


func _thaw_frozen_minions_for_side(is_player_side: bool) -> void:
	var pf: Array = player_front if is_player_side else enemy_front
	var pr: Array = player_rear  if is_player_side else enemy_rear
	for row in [pf, pr]:
		for d in row:
			if d.get("frozen", false):
				d["frozen"] = false
				d["exhausted"] = false


# ══════════════════════════════════════════════════════════════════
# CARD PLAY
# ══════════════════════════════════════════════════════════════════
func _summon(card: Dictionary, is_player: bool, to_front: bool) -> void:
	if card.get("id", "") == "god_card":
		if is_player: _schedule_instant_win("◈ CARD KING ◈")
		else:         _schedule_instant_lose("The enemy plays ◈ THE FIRST ONE ◈")
		return
	var ab: String    = card.get("ability", "")
	var force_front   := "taunt" in ab
	var pf := player_front if is_player else enemy_front
	var pr := player_rear  if is_player else enemy_rear
	var use_front := force_front or to_front
	var row := pf if use_front else pr
	if row.size() >= CardBattleConstants.MAX_ROW:
		var other := pr if use_front else pf
		if other.size() < CardBattleConstants.MAX_ROW: row = other
		else: return
	var d := _make_board_demon(card)
	row.append(d)
	if "mimic_board_count" in ab:
		var tot: int = player_front.size() + player_rear.size() + enemy_front.size() + enemy_rear.size()
		d["atk"] = tot
		d["hp"] = tot
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
		"frozen"       : false,
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
		if is_player: player_hp = mini(player_hp + 3, CardBattleConstants.STARTING_HP)
		else:         enemy_hp  = mini(enemy_hp  + 3, CardBattleConstants.STARTING_HP)
	elif "battlecry_summon_imps"       in ab:
		_summon(CardDB.get_card("token_imp"), is_player, true)
		_summon(CardDB.get_card("token_imp"), is_player, true)
	elif "battlecry_summon_imp"        in ab:
		_summon(CardDB.get_card("token_imp"), is_player, true)
	elif "battlecry_freeze_all" in ab:
		for o in of_: _apply_freeze(o)
		for o in or_: _apply_freeze(o)
	elif "battlecry_freeze_target" in ab:
		var all_e: Array = []
		for o in of_: all_e.append(o)
		for o in or_: all_e.append(o)
		if not all_e.is_empty():
			var hi: Dictionary = all_e[0]
			for o in all_e:
				if o["atk"] > hi["atk"]:
					hi = o
			_apply_freeze(hi)
	_check_auto_lose_no_resources(is_player)


func _schedule_instant_win(msg: String) -> void:
	if _ended: return
	_ended = true
	_log(msg)
	_show_toast("YOU WIN!")
	_view.queue_redraw()
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func (): battle_ended.emit(true))


func _schedule_instant_lose(msg: String) -> void:
	if _ended: return
	_ended = true
	_log(msg)
	_show_toast("YOU LOSE...")
	_view.queue_redraw()
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func (): battle_ended.emit(false))


func _check_osiris_combo_win() -> void:
	if _ended: return
	const PIECES: Array[String] = ["demon_031", "demon_032", "demon_033", "demon_034", "demon_035"]
	var have: Dictionary = {}
	for c in player_hand:
		have[c.get("id", "")] = true
	for pid in PIECES:
		if not have.get(pid, false): return
	_schedule_instant_win("The Osiris fragments reunite in your hand. You win.")


func _refresh_demon_keywords(d: Dictionary) -> void:
	var ab: String = str(d["data"].get("ability", ""))
	d["poisonous"]     = _kwrd(ab, "poisonous")
	d["lifesteal"]     = _kwrd(ab, "lifesteal")
	d["taunt"]         = _kwrd(ab, "taunt")
	d["unblockable"]   = _kwrd(ab, "unblockable")
	d["rage"]          = _kwrd(ab, "rage")
	d["double_attack"] = _kwrd(ab, "double_attack")
	d["divine_active"] = _kwrd(ab, "divine_shield")


func _resolve_spell(card: Dictionary, is_player: bool) -> void:
	CardBattleSpellEffects.resolve(self, card, is_player)


# ══════════════════════════════════════════════════════════════════
# COMBAT
# ══════════════════════════════════════════════════════════════════
func _do_combat(a_board: Array, a_idx: int, a_is_player: bool, a_is_front: bool,
		d_board: Array, d_idx: int, d_is_front: bool) -> void:
	if a_idx >= a_board.size() or d_idx >= d_board.size(): return
	var att: Dictionary = a_board[a_idx]
	var def_: Dictionary = d_board[d_idx]
	var att_atk: int = att["atk"]
	var def_atk: int = def_["atk"]
	var att_poi: bool = att.get("poisonous", false)
	var def_poi: bool = def_.get("poisonous", false)
	# Type-advantage bonus
	var att_sub: String = att["data"].get("subtype", "")
	var def_sub: String = def_["data"].get("subtype", "")
	var type_bonus: int = _type_advantage(att_sub, def_sub)
	_spawn_float(CardBattleLayout.board_world_pos(_get_row(a_is_player, a_is_front), a_is_player, a_is_front, a_idx),      "-%d" % def_atk, CardBattleConstants.C_HP_RED)
	_spawn_float(CardBattleLayout.board_world_pos(_get_row(not a_is_player, d_is_front), not a_is_player, d_is_front, d_idx),  "-%d" % (att_atk + type_bonus), CardBattleConstants.C_HP_RED)
	_hit_demon(def_, att_atk + type_bonus, att_poi)
	_hit_demon(att,  def_atk, def_poi)
	if att.get("lifesteal", false) and att_atk > 0:
		if a_is_player: player_hp = mini(player_hp + att_atk, CardBattleConstants.STARTING_HP)
		else:           enemy_hp  = mini(enemy_hp  + att_atk, CardBattleConstants.STARTING_HP)
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
			_spawn_death_fx(CardBattleLayout.board_world_pos(_get_row(is_player, is_front), is_player, is_front, i))
			board.remove_at(i)
			_resolve_deathrattle(dead, is_player, is_front)
	_check_auto_lose_no_resources(is_player)
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
	elif "deathrattle_summon_ash_wraith" in ab:
		_summon(CardDB.get_card("token_ash_wraith"), is_player, is_front)
	elif "deathrattle_return_hand"   in ab:
		var hand := player_hand if is_player else enemy_hand
		hand.append(d["data"])
	elif "deathrattle_buff_all"      in ab:
		var pf := player_front if is_player else enemy_front
		var pr := player_rear  if is_player else enemy_rear
		for ally in pf: ally["atk"] += 1; ally["hp"] += 1
		for ally in pr: ally["atk"] += 1; ally["hp"] += 1
	elif "deathrattle_summon_2_imps" in ab:
		_summon(CardDB.get_card("token_imp"), is_player, is_front)
		_summon(CardDB.get_card("token_imp"), is_player, is_front)


func _deal_damage_to_player(n: int) -> void:
	player_hp -= n
	_spawn_float(Vector2(float(CardBattleConstants.LEFT_W) * 0.5, float(CardBattleConstants.PINFO_Y) + 10.0), "-%d" % n, CardBattleConstants.C_HP_RED)
	_view.queue_redraw()
	_check_game_over()


func _deal_damage_to_enemy(n: int) -> void:
	enemy_hp -= n
	_spawn_float(Vector2(float(CardBattleConstants.LEFT_W) * 0.5, float(CardBattleConstants.EINFO_H) * 0.5), "-%d" % n, CardBattleConstants.C_HP_RED)
	_view.queue_redraw()
	_check_game_over()


# ══════════════════════════════════════════════════════════════════
# GAME OVER
# ══════════════════════════════════════════════════════════════════
# • Enemy life <= 0 → you win. Your life <= 0 → you lose.
# • Else: you lose when deck, hand, and both board rows are empty (enemy symmetric).
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
# AI  (logic in `card_battle_ai_runner.gd`; thin facades for the runner)
# ══════════════════════════════════════════════════════════════════
func ai_is_battle_ended() -> bool:
	return _ended


func ai_queue_redraw() -> void:
	_view.queue_redraw()


func ai_check_game_over_co() -> bool:
	return await _check_game_over()


func ai_enemy_summon(card: Dictionary, to_front: bool) -> void:
	_summon(card, false, to_front)


func ai_enemy_resolve_spell(card: Dictionary) -> void:
	_resolve_spell(card, false)


func ai_enemy_pitch_idx(i: int) -> void:
	_enemy_pitch_card(i)


func ai_log_line(s: String) -> void:
	_log(s)


func ai_enemy_stashed_this_turn() -> bool:
	return _enemy_stashed_this_turn


func ai_set_enemy_stashed(v: bool) -> void:
	_enemy_stashed_this_turn = v


func ai_get_ai_type() -> String:
	return _ai_type


func ai_keyword(ability: String, keyword: String) -> bool:
	return _kwrd(ability, keyword)


func ai_deal_damage_to_player(n: int) -> void:
	_deal_damage_to_player(n)


func ai_find_taunt(board: Array) -> int:
	return _find_taunt(board)


func ai_do_combat(a_board: Array, a_idx: int, a_is_player: bool, a_is_front: bool,
		d_board: Array, d_idx: int, d_is_front: bool) -> void:
	_do_combat(a_board, a_idx, a_is_player, a_is_front, d_board, d_idx, d_is_front)


func ai_find_weakest(board: Array) -> int:
	return _find_weakest(board)


func ai_find_strongest(board: Array) -> int:
	return _find_strongest(board)


func _enemy_pitch_card(i: int) -> void:
	if i < 0 or i >= enemy_hand.size(): return
	var card: Dictionary = enemy_hand[i]
	var mv: int = card.get("mana_value", 1)
	enemy_mana += mv
	_enemy_pitched_this_turn.append(card)
	enemy_hand.remove_at(i)
	_log("Enemy pitches %s (+%d mana)" % [card["name"], mv])


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

	# Godot 4 sends wheel as InputEventMouseWheel (not MouseButton) — required for log scroll
	if str(event.get_class()) == "InputEventMouseWheel":
		if CardBattleLayout.log_rect().has_point(event.position):
			if event.delta.y > 0.0:
				_log_scroll = maxi(0, _log_scroll - 1)
			elif event.delta.y < 0.0:
				var fl: Array[String] = _log_flat_lines()
				_log_scroll = mini(_log_scroll + 1, maxi(0, fl.size() - CardBattleConstants.LOG_VISIBLE))
			_clamp_log_scroll()
			_view.queue_redraw()
			_view.accept_event()
		return

	if str(event.get_class()) == "InputEventPanGesture":
		if CardBattleLayout.log_rect().has_point(event.position):
			if event.delta.y < -0.35:
				_log_scroll = maxi(0, _log_scroll - 1)
			elif event.delta.y > 0.35:
				var fl2: Array[String] = _log_flat_lines()
				_log_scroll = mini(_log_scroll + 1, maxi(0, fl2.size() - CardBattleConstants.LOG_VISIBLE))
			_clamp_log_scroll()
			_view.queue_redraw()
			_view.accept_event()
		return

	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var pos: Vector2 = mb.position

	# Fallback: some platforms still emit wheel as MouseButton; do not gate on pressed
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		if CardBattleLayout.log_rect().has_point(pos):
			_log_scroll = maxi(0, _log_scroll - 1)
			_clamp_log_scroll()
			_view.queue_redraw()
			_view.accept_event()
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if CardBattleLayout.log_rect().has_point(pos):
			var fl3: Array[String] = _log_flat_lines()
			_log_scroll = mini(_log_scroll + 1, maxi(0, fl3.size() - CardBattleConstants.LOG_VISIBLE))
			_clamp_log_scroll()
			_view.queue_redraw()
			_view.accept_event()
		return

	# Modal: Figma — no dimmer; black panel is x≥176 only; close by clicking that panel (or CLOSE)
	if mb.pressed and _modal_open and pos.x >= float(CardBattleConstants.BOARD_X):
		_modal_open = false
		_ctx_idx = -1
		_ctx_is_front = true
		_atk_drag_idx = -1
		_rear_pick_idx = -1
		_view.queue_redraw()
		_view.accept_event()
		return

	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click(pos); _view.accept_event(); return

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_on_left_press(pos)
		else:
			if _drag_active:
				_on_drag_drop(pos)
			else:
				_on_left_release(pos)
			_drag_active = false
			_drag_card = {}
			_drag_hand_idx = -1
		_view.accept_event()


## Modal grid must match `_draw_modal`; used so zoom shows the hovered modal card, not board minions underneath.
func _modal_hover_index() -> int:
	if not _modal_open or _modal_cards.is_empty():
		return -1
	var sx: float = CardBattleConstants.MODAL_GRID_X0
	var sy0: float = CardBattleConstants.MODAL_GRID_Y0
	var mh: float = float(CardBattleConstants.H)
	for i in _modal_cards.size():
		var row: int = i / CardBattleConstants.MODAL_COLS
		var col: int = i % CardBattleConstants.MODAL_COLS
		var cy: float = sy0 + float(row) * CardBattleConstants.MODAL_ROW_H
		if cy + float(CardBattleConstants.HAND_CH) > mh:
			break
		var cr := Rect2(sx + float(col) * CardBattleConstants.MODAL_COL_W, cy, float(CardBattleConstants.HAND_CW), float(CardBattleConstants.HAND_CH))
		if cr.has_point(_mouse_pos):
			return i
	return -1


func _update_hover() -> void:
	_hover_card = {}; _hover_state = {}
	if _modal_open:
		if _mouse_pos.x >= float(CardBattleConstants.BOARD_X):
			var hi: int = _modal_hover_index()
			if hi >= 0:
				var mc: Variant = _modal_cards[hi]
				if mc is Dictionary:
					_hover_card = mc as Dictionary
					_hover_state = {}
		return
	for i in player_hand.size():
		if CardBattleLayout.hand_rect(i, player_hand.size()).has_point(_mouse_pos):
			_hover_card = player_hand[i]; return
	for i in player_front.size():
		if CardBattleLayout.mini_rect(player_front, CardBattleConstants.PFFRONT_Y, i).has_point(_mouse_pos):
			_hover_card = player_front[i]["data"]; _hover_state = player_front[i]; return
	for i in player_rear.size():
		if CardBattleLayout.mini_rect(player_rear, CardBattleConstants.PFREAR_Y, i).has_point(_mouse_pos):
			_hover_card = player_rear[i]["data"]; _hover_state = player_rear[i]; return
	for i in enemy_front.size():
		if CardBattleLayout.mini_rect(enemy_front, CardBattleConstants.EFFRONT_Y, i).has_point(_mouse_pos):
			_hover_card = enemy_front[i]["data"]; _hover_state = enemy_front[i]; return
	for i in enemy_rear.size():
		if CardBattleLayout.mini_rect(enemy_rear, CardBattleConstants.EFREAR_Y, i).has_point(_mouse_pos):
			_hover_card = enemy_rear[i]["data"]; _hover_state = enemy_rear[i]; return
	if not player_arsenal.is_empty() and CardBattleLayout.player_arsenal_rect().has_point(_mouse_pos):
		_hover_card = player_arsenal
	if not enemy_arsenal.is_empty() and CardBattleLayout.side_arsenal_rect(true).has_point(_mouse_pos):
		_hover_card = enemy_arsenal


func _on_right_click(pos: Vector2) -> void:
	if not is_player_turn or _animating or _ended: return
	for i in player_hand.size():
		if CardBattleLayout.hand_rect(i, player_hand.size()).has_point(pos): _pitch_card(i); return


func _on_left_press(pos: Vector2) -> void:
	if _ended: return
	# Modal open: left strip (x<176) stays interactive for hover/log; block board actions here
	if _modal_open and pos.x < float(CardBattleConstants.BOARD_X):
		return

	# Sidebar: grave / deck → modal
	if CardBattleLayout.side_grave_rect(true).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		_open_modal(enemy_gy, "Enemy Graveyard"); return
	if CardBattleLayout.side_grave_rect(false).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		_open_modal(player_gy, "Your Graveyard"); return
	if CardBattleLayout.side_deck_rect(true).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		var s := enemy_deck.duplicate(); s.shuffle(); _open_modal(s, "Enemy Deck (random)"); return
	if CardBattleLayout.side_deck_rect(false).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		var s := player_deck.duplicate(); s.shuffle(); _open_modal(s, "Your Deck (random)"); return

	if not is_player_turn or _animating: return

	# Buttons
	if CardBattleLayout.end_btn_rect().has_point(pos):
		_ctx_idx = -1
		_ctx_is_front = true
		_atk_drag_idx = -1
		_rear_pick_idx = -1
		_handle_end_turn_click()
		return

	# CHOOSE_ROW
	if _mode == Mode.CHOOSE_ROW:
		if CardBattleLayout.row_drop_rect(true).has_point(pos):  _place_pending(true);  return
		if CardBattleLayout.row_drop_rect(false).has_point(pos): _place_pending(false); return
		_mode = Mode.IDLE; _pending_card = {}; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		_view.queue_redraw(); return

	# Context menu: MOVE / EFF. (selected front or rear minion)
	if _ctx_idx >= 0:
		var ctx_row: Array = player_front if _ctx_is_front else player_rear
		var ctx_y: int = CardBattleConstants.PFFRONT_Y if _ctx_is_front else CardBattleConstants.PFREAR_Y
		if _ctx_idx >= ctx_row.size():
			_ctx_idx = -1
			_ctx_is_front = true
		else:
			var cr_ctx := CardBattleLayout.mini_rect(ctx_row, ctx_y, _ctx_idx)
			var d_ctx: Dictionary = ctx_row[_ctx_idx]
			var ab_ctx: String = d_ctx["data"].get("ability", "")
			var can_move_btn: bool = is_player_turn and not _moved_this_turn and not _animating
			var can_eff_btn: bool = is_player_turn and not _animating and not d_ctx.get("exhausted", false) \
				and _has_exhaust_activation(ab_ctx)
			if can_move_btn and CardBattleLayout.context_move_btn_rect(cr_ctx).has_point(pos):
				_on_move_demon(_ctx_idx, _ctx_is_front)
				_ctx_idx = -1
				_ctx_is_front = true
				return
			if can_eff_btn:
				var er_hit: Rect2 = CardBattleLayout.context_eff_btn_rect(cr_ctx) if can_move_btn else CardBattleLayout.context_move_btn_rect(cr_ctx)
				if er_hit.has_point(pos):
					_on_exhaust_effect(_ctx_idx, _ctx_is_front)
					_ctx_idx = -1
					_ctx_is_front = true
					return

	# Hand → start drag (clears attack prep / menu)
	for i in player_hand.size():
		if CardBattleLayout.hand_rect(i, player_hand.size()).has_point(pos):
			_ctx_idx = -1
			_ctx_is_front = true
			_atk_drag_idx = -1
			_rear_pick_idx = -1
			_mode = Mode.IDLE
			_sel_idx = -1
			_drag_active = true
			_drag_card = player_hand[i]
			_drag_hand_idx = i
			_drag_pos = pos
			_view.queue_redraw()
			return

	# Arsenal click → play
	if not player_arsenal.is_empty() and CardBattleLayout.player_arsenal_rect().has_point(pos):
		_ctx_idx = -1
		_ctx_is_front = true
		_atk_drag_idx = -1
		_rear_pick_idx = -1
		_on_arsenal_play()
		return

	# Player front minion: begin drag-vs-click (release chooses — see _on_left_release / _tick)
	for i in player_front.size():
		if CardBattleLayout.mini_rect(player_front, CardBattleConstants.PFFRONT_Y, i).has_point(pos):
			if _mode == Mode.ATTACKING and i != _sel_idx:
				return
			_rear_pick_idx = -1
			_atk_drag_idx = i
			_atk_drag_start = pos
			_view.queue_redraw()
			return

	# Player rear minion: click/release toggles context (MOVE/EFF.); no attack drag from rear
	for i in player_rear.size():
		if CardBattleLayout.mini_rect(player_rear, CardBattleConstants.PFREAR_Y, i).has_point(pos):
			_atk_drag_idx = -1
			_rear_pick_idx = i
			_rear_pick_start = pos
			_view.queue_redraw()
			return

	# Click elsewhere: dismiss context menu / cancel attack prep
	_ctx_idx = -1
	_ctx_is_front = true
	_atk_drag_idx = -1
	_rear_pick_idx = -1


func _on_drag_drop(pos: Vector2) -> void:
	if _drag_card.is_empty(): return
	var card     := _drag_card
	var hand_idx := _drag_hand_idx

	if not is_player_turn or _animating or _ended: _view.queue_redraw(); return

	# Drop on player info → pitch
	if CardBattleLayout.pinfo_rect().has_point(pos):
		if hand_idx >= 0 and hand_idx < player_hand.size(): _pitch_card(hand_idx)
		_view.queue_redraw(); return

	# Drop on arsenal
	if CardBattleLayout.player_arsenal_rect().has_point(pos):
		if hand_idx >= 0 and not _stashed_this_turn and player_arsenal.is_empty():
			await _on_stash(hand_idx)
		_view.queue_redraw(); return

	# Cost check
	if card.get("cost", 0) > player_mana:
		_log("Not enough mana!"); _view.queue_redraw(); return

	# Drop on front row
	if CardBattleLayout.row_drop_rect(true).has_point(pos):
		if _mode == Mode.CHOOSE_ARSENAL:
			_pending_finish_after_arsenal = false
			_mode = Mode.IDLE
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
	if CardBattleLayout.row_drop_rect(false).has_point(pos):
		if _mode == Mode.CHOOSE_ARSENAL:
			_pending_finish_after_arsenal = false
			_mode = Mode.IDLE
		if card["type"] == "demon":
			var ab: String = card.get("ability", "")
			if "taunt" in ab: _log("Taunt must go to front!"); _view.queue_redraw(); return
			if hand_idx >= 0: player_hand.remove_at(hand_idx)
			player_mana -= card.get("cost", 0)
			_summon(card, true, false); player_gy.append(card)
			_log("Played %s to rear!" % card["name"])
		_view.queue_redraw(); _check_game_over(); return

	# End-of-turn Arsenal: release on same hand card → stash it (tap-to-stash)
	if _mode == Mode.CHOOSE_ARSENAL and hand_idx >= 0 and hand_idx < player_hand.size() \
			and not _stashed_this_turn and player_arsenal.is_empty():
		if CardBattleLayout.hand_rect(hand_idx, player_hand.size()).has_point(pos):
			await _on_stash(hand_idx)
	_view.queue_redraw()


func _on_left_release(pos: Vector2) -> void:
	if _ended or not is_player_turn or _animating:
		_atk_drag_idx = -1
		_rear_pick_idx = -1
		return
	# DIRECT ATTACK with context menu (IDLE): commit face attack without entering drag-aim first.
	if CardBattleLayout.direct_attack_btn_rect().has_point(pos) \
			and _mode == Mode.IDLE and _ctx_idx >= 0 and _ctx_is_front \
			and _ctx_idx < player_front.size():
		var att_idle: Dictionary = player_front[_ctx_idx]
		if not att_idle.get("exhausted", false):
			_sel_idx = _ctx_idx
			_mode = Mode.ATTACKING
			if _direct_attack_face_legal():
				_on_attack_face()
			else:
				_mode = Mode.IDLE
				_sel_idx = -1
		_ctx_idx = -1
		_ctx_is_front = true
		_atk_drag_idx = -1
		_rear_pick_idx = -1
		_view.queue_redraw()
		return
	# Drop-to-attack: release completes targeting
	if _mode == Mode.ATTACKING and _sel_idx >= 0 and _sel_idx < player_front.size():
		_resolve_attack_at(pos)
		_ctx_idx = -1
		_ctx_is_front = true
		return
	# Rear minion: short click toggles context menu
	if _rear_pick_idx >= 0 and _rear_pick_idx < player_rear.size():
		var dist_r: float = pos.distance_to(_rear_pick_start)
		if dist_r <= CardBattleConstants.ATTACK_DRAG_THRESH:
			if _ctx_idx == _rear_pick_idx and not _ctx_is_front:
				_ctx_idx = -1
				_ctx_is_front = true
			else:
				_ctx_idx = _rear_pick_idx
				_ctx_is_front = false
		_rear_pick_idx = -1
		_view.queue_redraw()
		return
	# Front minion: short click toggles context; long drag handled in _tick → ATTACKING
	if _atk_drag_idx >= 0 and _atk_drag_idx < player_front.size():
		var dist: float = pos.distance_to(_atk_drag_start)
		if dist <= CardBattleConstants.ATTACK_DRAG_THRESH:
			if _ctx_idx == _atk_drag_idx and _ctx_is_front:
				_ctx_idx = -1
				_ctx_is_front = true
			else:
				_ctx_idx = _atk_drag_idx
				_ctx_is_front = true
		_atk_drag_idx = -1
		_view.queue_redraw()


func _resolve_attack_at(pos: Vector2) -> void:
	if _mode != Mode.ATTACKING or _sel_idx < 0 or _sel_idx >= player_front.size():
		return
	if CardBattleLayout.direct_attack_btn_rect().has_point(pos):
		if _direct_attack_face_legal():
			_on_attack_face()
		return
	if CardBattleLayout.enemy_face_rect().has_point(pos):
		_on_attack_face()
		return
	for i in enemy_front.size():
		if CardBattleLayout.mini_rect(enemy_front, CardBattleConstants.EFFRONT_Y, i).has_point(pos):
			_on_attack_demon(i, true)
			return
	for i in enemy_rear.size():
		if CardBattleLayout.mini_rect(enemy_rear, CardBattleConstants.EFREAR_Y, i).has_point(pos):
			_on_attack_demon(i, false)
			return
	_mode = Mode.IDLE
	_sel_idx = -1
	_ctx_idx = -1
	_ctx_is_front = true
	_view.queue_redraw()


func _pitch_card(i: int) -> void:
	if i >= player_hand.size(): return
	if _mode == Mode.CHOOSE_ARSENAL:
		_pending_finish_after_arsenal = false
	var card: Dictionary = player_hand[i]
	var mv: int = card.get("mana_value", 1)
	player_mana += mv
	_pitched_this_turn.append(card); player_hand.remove_at(i)
	_mode = Mode.IDLE
	_sel_idx = -1
	_ctx_idx = -1
	_ctx_is_front = true
	_rear_pick_idx = -1
	_log("Pitched %s (+%d mana)" % [card["name"], mv])
	_view.queue_redraw()
	_check_auto_lose_no_resources(true)


func _place_pending(to_front: bool) -> void:
	if _pending_card.is_empty(): _mode = Mode.IDLE; return
	var row := player_front if to_front else player_rear
	if row.size() >= CardBattleConstants.MAX_ROW:
		_log("%s row is full!" % ("Front" if to_front else "Rear")); _view.queue_redraw(); return
	player_mana -= _pending_card.get("cost", 0)
	if _pending_hand_idx >= 0 and _pending_hand_idx < player_hand.size():
		player_hand.remove_at(_pending_hand_idx)
	_summon(_pending_card, true, to_front); player_gy.append(_pending_card)
	_log("Played %s (%s)" % [_pending_card["name"], "front" if to_front else "rear"])
	_pending_card = {}; _pending_hand_idx = -1; _mode = Mode.IDLE
	_view.queue_redraw(); _check_game_over()


func _on_attack_face() -> void:
	if _mode != Mode.ATTACKING or _sel_idx >= player_front.size(): return
	var att: Dictionary = player_front[_sel_idx]
	if not att.get("unblockable", false):
		if not enemy_front.is_empty(): _log("Must attack enemy front!"); _view.queue_redraw(); return
		if _has_taunt(enemy_front):    _log("Attack the taunt!");       _view.queue_redraw(); return
	att["attacked"] += 1
	att["exhausted"] = att["attacked"] >= (2 if att.get("double_attack", false) else 1)
	_deal_damage_to_enemy(att["atk"])
	if att.get("lifesteal", false): player_hp = mini(player_hp + att["atk"], CardBattleConstants.STARTING_HP)
	_log("%s attacks face for %d!" % [att["data"]["name"], att["atk"]])
	_mode = Mode.IDLE
	_sel_idx = -1
	_ctx_idx = -1
	_ctx_is_front = true
	_view.queue_redraw()
	_check_game_over()


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
	_mode = Mode.IDLE
	_sel_idx = -1
	_ctx_idx = -1
	_ctx_is_front = true
	_view.queue_redraw()
	_check_game_over()


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
	if _pending_finish_after_arsenal:
		_pending_finish_after_arsenal = false
		await _finish_end_player_turn()


func _on_move_demon(i: int, from_front: bool) -> void:
	_sel_idx = -1
	_ctx_idx = -1
	_ctx_is_front = true
	if from_front:
		if i >= player_front.size(): return
		if player_rear.size() >= CardBattleConstants.MAX_ROW: _log("Rear full!"); _mode = Mode.IDLE; _view.queue_redraw(); return
		var d: Dictionary = player_front[i]; player_front.remove_at(i); player_rear.append(d)
		_log("Moved %s to rear" % d["data"]["name"])
	else:
		if i >= player_rear.size(): return
		if player_front.size() >= CardBattleConstants.MAX_ROW: _log("Front full!"); _mode = Mode.IDLE; _view.queue_redraw(); return
		var d: Dictionary = player_rear[i]; player_rear.remove_at(i); player_front.append(d)
		_log("Moved %s to front" % d["data"]["name"])
	_moved_this_turn = true; _mode = Mode.IDLE; _view.queue_redraw()


func _on_exhaust_effect(idx: int, from_front: bool) -> void:
	var row: Array = player_front if from_front else player_rear
	if idx < 0 or idx >= row.size(): return
	var d: Dictionary = row[idx]
	if d.get("exhausted", false): return
	var ab: String = d["data"].get("ability", "")
	if not _has_exhaust_activation(ab): return
	d["exhausted"] = true
	_log("%s exhausts — effect pending (exhaust_ abilities)" % d["data"]["name"])
	_mode = Mode.IDLE
	_sel_idx = -1
	_ctx_idx = -1
	_ctx_is_front = true
	_view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# TOAST & MODAL
# ══════════════════════════════════════════════════════════════════
func _show_toast(text: String) -> void:
	_toast_text = text
	_toast_timer = CardBattleConstants.TOAST_DUR

func _open_modal(cards: Array, title: String) -> void:
	_modal_open = true; _modal_cards = cards; _modal_title = title; _view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════
func _kwrd(ability: String, keyword: String) -> bool: return keyword in ability

func _has_exhaust_activation(ability: String) -> bool:
	return ability.contains("exhaust_")

func _type_advantage(att_sub: String, def_sub: String) -> int:
	return 1 if CardBattleConstants.TYPE_ADV.get(att_sub, "") == def_sub else 0
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
func _clamp_log_scroll() -> void:
	var flat: Array[String] = _log_flat_lines()
	var max_start: int = maxi(0, flat.size() - CardBattleConstants.LOG_VISIBLE)
	_log_scroll = clampi(_log_scroll, 0, max_start)


func _hard_break_string(s: String, max_w: float, fs: int, f: Font) -> Array[String]:
	var acc: Array[String] = []
	var chunk: String = ""
	for i in range(s.length()):
		var c: String = s[i]
		var test: String = chunk + c
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			chunk = test
		else:
			if not chunk.is_empty():
				acc.append(chunk)
			chunk = c
	if not chunk.is_empty():
		acc.append(chunk)
	return acc


func _wrap_log_lines(text: String, max_w: float, sz: int) -> Array[String]:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var out: Array[String] = []
	var line: String = ""
	for word in text.split(" "):
		if word.is_empty():
			continue
		var cand: String = line + (" " if not line.is_empty() else "") + word
		if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			line = cand
		else:
			if not line.is_empty():
				out.append(line)
			if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
				line = word
			else:
				out.append_array(_hard_break_string(word, max_w, fs, f))
				line = ""
	if not line.is_empty():
		out.append(line)
	return out


func _log_flat_lines() -> Array[String]:
	var acc: Array[String] = []
	for entry in _battle_log:
		for wl in _wrap_log_lines("_" + str(entry), CardBattleConstants.LOG_TEXT_MAX_W, 8):
			acc.append(wl)
	return acc


func _draw_log_line_at(text: String, y_arg: float, sz: int, color: Color) -> void:
	var fs: int = _fs(sz)
	var f: Font = _fnt()
	var baseline: float = y_arg + float(fs)
	_view.draw_string(f, Vector2(_tx(CardBattleConstants.LOG_BODY_X), _tx(baseline)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

## Opaque mix toward white (replaces translucent rarity tint on card art).
func _mix_white(c: Color, t: float) -> Color:
	var u: float = 1.0 - t
	return Color(c.r * t + u, c.g * t + u, c.b * t + u)


## Premultiplied RGB → opaque `Color` (fade VFX without alpha channel).
func _opaque_rgb_fade(c: Color, a: float) -> Color:
	return Color(c.r * a, c.g * a, c.b * a)


func _direct_attack_face_legal() -> bool:
	# Face is legal when no enemy blockers, or when the chosen attacker ignores them.
	# Show DIRECT ATTACK "on" whenever that is true — not only after entering ATTACKING mode.
	if enemy_front.is_empty():
		return true
	if _mode != Mode.ATTACKING or _sel_idx < 0 or _sel_idx >= player_front.size():
		return false
	return player_front[_sel_idx].get("unblockable", false)


## Aim arrow only while dragging (LMB + past threshold from attacker); click-to-target needs no arrow.
func _atk_show_attack_arrow() -> bool:
	if _mode != Mode.ATTACKING or _sel_idx < 0 or _sel_idx >= player_front.size():
		return false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	var start: Vector2 = CardBattleLayout.board_world_pos(_get_row(true, true), true, true, _sel_idx)
	return _mouse_pos.distance_to(start) > CardBattleConstants.ATTACK_DRAG_THRESH

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
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_text = ""
		changed = true
	for i in range(_floats.size() - 1, -1, -1):
		var f: Dictionary = _floats[i]; f["pos"] += f["vel"] * delta; f["alpha"] -= delta * 1.3
		if f["alpha"] <= 0.0: _floats.remove_at(i)
		changed = true
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]; p["pos"] += p["vel"] * delta; p["alpha"] -= delta * 1.6
		if p["alpha"] <= 0.0: _particles.remove_at(i)
		changed = true
	if changed: _view.queue_redraw()
	# Drag past threshold on a front minion → attack aim (arrow); exhausted minions skip
	if _atk_drag_idx >= 0 and not _drag_active and is_player_turn and not _animating and not _ended \
			and _mode != Mode.CHOOSE_ROW and _mode != Mode.CHOOSE_ARSENAL:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _mouse_pos.distance_to(_atk_drag_start) > CardBattleConstants.ATTACK_DRAG_THRESH:
				if _atk_drag_idx < player_front.size():
					var d_try: Dictionary = player_front[_atk_drag_idx]
					if not d_try.get("exhausted", false):
						_ctx_idx = -1
						_ctx_is_front = true
						_rear_pick_idx = -1
						_mode = Mode.ATTACKING
						_sel_idx = _atk_drag_idx
						_atk_drag_idx = -1
						_view.queue_redraw()
	if _atk_show_attack_arrow():
		_view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# DRAWING — root
# ══════════════════════════════════════════════════════════════════
func _on_draw() -> void:
	_view.draw_rect(Rect2(0, 0, CardBattleConstants.W, CardBattleConstants.H), CardBattleConstants.C_BG)
	_view.draw_rect(Rect2(0, 0, CardBattleConstants.LEFT_W, CardBattleConstants.HAND_Y), CardBattleConstants.C_LEFT_BG)
	_view.draw_rect(Rect2(CardBattleConstants.BOARD_X, 0, CardBattleConstants.BOARD_W, CardBattleConstants.HAND_Y), CardBattleConstants.C_BOARD_BG)
	_view.draw_rect(Rect2(CardBattleConstants.RAIL_LINE_X, 0, CardBattleConstants.RIGHT_W, CardBattleConstants.HAND_Y), CardBattleConstants.C_BG)
	_view.draw_rect(Rect2(0, CardBattleConstants.HAND_Y, CardBattleConstants.LEFT_W, CardBattleConstants.HAND_H), CardBattleConstants.C_LEFT_BG)
	_view.draw_rect(Rect2(CardBattleConstants.BOARD_X, CardBattleConstants.HAND_Y, CardBattleConstants.BOARD_W, CardBattleConstants.HAND_H), CardBattleConstants.C_BOARD_BG)
	_view.draw_rect(Rect2(CardBattleConstants.RAIL_LINE_X, CardBattleConstants.HAND_Y, CardBattleConstants.RIGHT_W, CardBattleConstants.HAND_H), CardBattleConstants.C_BG)

	_draw_left_panel()
	_draw_board()
	_draw_right_sidebar()
	_draw_hand()
	_draw_chrome()

	for f in _floats:
		_str_c(f["text"], f["pos"].x, f["pos"].y, 11,
			_opaque_rgb_fade(f["color"], f["alpha"]))
	for p in _particles:
		_view.draw_circle(p["pos"], 2.5, _opaque_rgb_fade(p["color"], p["alpha"]))

	if _drag_active and not _drag_card.is_empty():
		var r := Rect2(_drag_pos - Vector2(CardBattleConstants.HAND_CW, CardBattleConstants.HAND_CH) * 0.5, Vector2(CardBattleConstants.HAND_CW, CardBattleConstants.HAND_CH))
		_draw_hand_card(r, _drag_card, false, false)

	if _mode == Mode.CHOOSE_ROW:
		_view.draw_rect(CardBattleLayout.row_drop_rect(true), CardBattleConstants.C_ROW_DROP_FRONT)
		_view.draw_rect(CardBattleLayout.row_drop_rect(false), CardBattleConstants.C_ROW_DROP_REAR)
		_str_c("FRONT", float(CardBattleConstants.BOARD_X) + float(CardBattleConstants.BOARD_W) * 0.5,
			float(CardBattleConstants.PFFRONT_Y) + CardBattleConstants.ROW_H * 0.5 - 4.0, 9, Color(0.2, 1.0, 0.2))
		_str_c("REAR",  float(CardBattleConstants.BOARD_X) + float(CardBattleConstants.BOARD_W) * 0.5,
			float(CardBattleConstants.PFREAR_Y) + CardBattleConstants.ROW_H * 0.5 - 4.0,  9, Color(0.4, 0.7, 1.0))

	if _mode == Mode.CHOOSE_ARSENAL:
		var az: Rect2 = CardBattleLayout.player_arsenal_rect()
		_view.draw_rect(az, Color(0.25, 0.85, 0.35), false, 2.0)

	if _toast_timer > 0.0: _draw_toast()
	if _modal_open:        _draw_modal()


func _draw_chrome() -> void:
	# Figma 1:3 — verticals x=176 & rail x=CardBattleConstants.RAIL_LINE_X; horizontals y=167 & y=407; mid y=288 h=4
	_view.draw_rect(Rect2(176.0, 0.0, 2.0, float(CardBattleConstants.H)), CardBattleConstants.C_CHROME_V)
	_view.draw_rect(Rect2(float(CardBattleConstants.RAIL_LINE_X), 0.0, 2.0, float(CardBattleConstants.H)), CardBattleConstants.C_CHROME_V)
	var line_span: float = float(CardBattleConstants.RAIL_LINE_X) - 8.0
	_view.draw_rect(Rect2(4.0, float(CardBattleConstants.LINE_Y_LOG_ZOOM), line_span, 2.0), CardBattleConstants.C_LINE_H)
	_view.draw_rect(Rect2(4.0, float(CardBattleConstants.LINE_Y_PINFO_HAND), line_span, 2.0), CardBattleConstants.C_LINE_H)
	_view.draw_rect(Rect2(float(CardBattleConstants.BOARD_X), float(CardBattleConstants.BOARD_DIV_Y) - 2.0, float(CardBattleConstants.BOARD_W), 4.0), CardBattleConstants.C_LINE_H)


# ══════════════════════════════════════════════════════════════════
# DRAWING — left panel
# ══════════════════════════════════════════════════════════════════
func _draw_left_panel() -> void:
	# Enemy info — Figma 4:347 (10px / 14px / 14px); no stroke on identity strip
	_view.draw_rect(Rect2(0, 0, CardBattleConstants.LEFT_W, CardBattleConstants.EINFO_H), CardBattleConstants.C_EINFO_BG)
	_str("Enemy: %s" % _enemy_name(), CardBattleConstants.EINFO_TEXT_X, CardBattleConstants.EINFO_LINE_1_Y, 10, CardBattleConstants.C_TEXT)
	_str("Life: %d" % enemy_hp, CardBattleConstants.EINFO_TEXT_X, CardBattleConstants.EINFO_LINE_2_Y, 14,
		CardBattleConstants.C_HP_RED if enemy_hp <= CardBattleConstants.LOW_LIFE_THRESHOLD else CardBattleConstants.C_TEXT)
	_str("Hand: %d" % enemy_hand.size(), CardBattleConstants.EINFO_TEXT_X, CardBattleConstants.EINFO_LINE_3_Y, 14, CardBattleConstants.C_TEXT)

	# Log — Figma 4:352 mint panel + 2px #3c1e15 border
	_view.draw_rect(CardBattleLayout.log_rect(), CardBattleConstants.C_LOG_BG)
	_view.draw_rect(CardBattleLayout.log_rect(), CardBattleConstants.C_LOG_BORDER, false, 2.0)
	_str("Log", CardBattleConstants.LOG_TITLE_X, float(CardBattleConstants.LOG_Y) + CardBattleConstants.LOG_TITLE_Y, 10, CardBattleConstants.C_LOG_TITLE)
	_clamp_log_scroll()
	var flat: Array[String] = _log_flat_lines()
	var total_lines: int = flat.size()
	var max_scroll: int = maxi(0, total_lines - CardBattleConstants.LOG_VISIBLE)
	var start: int = clampi(_log_scroll, 0, max_scroll)
	var vis_count: int = mini(CardBattleConstants.LOG_VISIBLE, total_lines - start)
	for i in vis_count:
		var y_line: float = float(CardBattleConstants.LOG_Y) + CardBattleConstants.LOG_BODY_Y0 + float(i) * float(CardBattleConstants.LOG_LINE_H)
		_draw_log_line_at(flat[start + i], y_line, 8, CardBattleConstants.C_LOG_BODY)
	if total_lines > CardBattleConstants.LOG_VISIBLE:
		var track_h: float = float(CardBattleConstants.LOG_H) - 9.0
		var thumb_h: float = maxf(8.0, track_h * float(CardBattleConstants.LOG_VISIBLE) / float(total_lines))
		var denom: float = float(max_scroll) if max_scroll > 0 else 1.0
		var thumb_y: float = float(CardBattleConstants.LOG_Y) + 5.0 + (track_h - thumb_h) * float(start) / denom
		_view.draw_rect(Rect2(CardBattleConstants.LOG_SCROLL_X, float(CardBattleConstants.LOG_Y) + 5.0, CardBattleConstants.LOG_SCROLL_W, track_h), CardBattleConstants.C_SCROLL_TRACK)
		_view.draw_rect(Rect2(CardBattleConstants.LOG_SCROLL_X, thumb_y, CardBattleConstants.LOG_SCROLL_W, thumb_h), CardBattleConstants.C_SCROLL_THUMB)

	# Zoomed card
	_view.draw_rect(Rect2(0, CardBattleConstants.ZOOM_Y, CardBattleConstants.LEFT_W, CardBattleConstants.ZOOM_H), CardBattleConstants.C_ZOOM_BG)
	_view.draw_rect(Rect2(0, CardBattleConstants.ZOOM_Y, CardBattleConstants.LEFT_W, CardBattleConstants.ZOOM_H), CardBattleConstants.C_BLACK, false, 1.0)
	if not _hover_card.is_empty():
		_draw_zoomed_card(_hover_card, _hover_state)

	# Player info — Figma 4:346 (You 10px; Life / Mana 14px); no stroke on identity strip
	_view.draw_rect(Rect2(0, CardBattleConstants.PINFO_Y, CardBattleConstants.LEFT_W, CardBattleConstants.PINFO_H), CardBattleConstants.C_PINFO_BG)
	_str("You", CardBattleConstants.PINFO_TEXT_X, float(CardBattleConstants.PINFO_Y) + CardBattleConstants.PINFO_LINE_1_Y, 10, CardBattleConstants.C_TEXT)
	_str("Life: %d" % player_hp, CardBattleConstants.PINFO_TEXT_X, float(CardBattleConstants.PINFO_Y) + CardBattleConstants.PINFO_LINE_2_Y, 14,
		CardBattleConstants.C_HP_RED if player_hp <= CardBattleConstants.LOW_LIFE_THRESHOLD else CardBattleConstants.C_TEXT)
	_str("Mana: %d" % player_mana, CardBattleConstants.PINFO_TEXT_X, float(CardBattleConstants.PINFO_Y) + CardBattleConstants.PINFO_LINE_3_Y, 14, CardBattleConstants.C_TEXT)
	var turn_col: Color = CardBattleConstants.C_SEL if is_player_turn else CardBattleConstants.C_TURN_AI
	var turn_cy: float = float(CardBattleConstants.PINFO_Y) + float(CardBattleConstants.PINFO_H) * 0.5 + CardBattleConstants.TURN_CIRCLE_Y_OFF
	_view.draw_circle(Vector2(CardBattleConstants.LEFT_W - 10.0, turn_cy), 6.0, turn_col)

	# END TURN button (Figma: x=96, y=431, 78×24 — pinfo strip)
	var eb := CardBattleLayout.end_btn_rect()
	var ea := is_player_turn and not _animating and not _ended
	_view.draw_rect(eb, CardBattleConstants.C_END_TURN if ea else CardBattleConstants.C_END_TURN_DIM)
	_view.draw_rect(eb, CardBattleConstants.C_BLACK, false, 1.0)
	_str_in_rect_center("END TURN", eb, 9, CardBattleConstants.C_TEXT_LT if ea else CardBattleConstants.C_TEXT_ON_DARK_DIM)


# ══════════════════════════════════════════════════════════════════
# DRAWING — board
# ══════════════════════════════════════════════════════════════════
func _draw_board() -> void:
	if enemy_front.is_empty():
		_str_c("— empty —", float(CardBattleConstants.BOARD_X) + float(CardBattleConstants.BOARD_W) * 0.5,
			float(CardBattleConstants.EFFRONT_Y) + CardBattleConstants.ROW_H * 0.5 - 4.0, 7, CardBattleConstants.C_BOARD_EMPTY_TEXT)
	if enemy_rear.is_empty():
		_str_c("— empty —", float(CardBattleConstants.BOARD_X) + float(CardBattleConstants.BOARD_W) * 0.5,
			float(CardBattleConstants.EFREAR_Y) + CardBattleConstants.ROW_H * 0.5 - 4.0,  7, CardBattleConstants.C_BOARD_EMPTY_TEXT)
	if player_front.is_empty():
		_str_c("— empty —", float(CardBattleConstants.BOARD_X) + float(CardBattleConstants.BOARD_W) * 0.5,
			float(CardBattleConstants.PFFRONT_Y) + CardBattleConstants.ROW_H * 0.5 - 4.0, 7, CardBattleConstants.C_BOARD_EMPTY_TEXT)
	if player_rear.is_empty():
		_str_c("— empty —", float(CardBattleConstants.BOARD_X) + float(CardBattleConstants.BOARD_W) * 0.5,
			float(CardBattleConstants.PFREAR_Y) + CardBattleConstants.ROW_H * 0.5 - 4.0,  7, CardBattleConstants.C_BOARD_EMPTY_TEXT)

	for i in enemy_front.size():
		_draw_mini_card(CardBattleLayout.mini_rect(enemy_front, CardBattleConstants.EFFRONT_Y, i), enemy_front[i],
			_mode == Mode.ATTACKING, false)
	for i in enemy_rear.size():
		var tgt := _mode == Mode.ATTACKING and enemy_front.is_empty()
		_draw_mini_card(CardBattleLayout.mini_rect(enemy_rear, CardBattleConstants.EFREAR_Y, i), enemy_rear[i], tgt, false)
	for i in player_front.size():
		var sel: bool = (_ctx_idx == i and _ctx_is_front) or (_mode == Mode.ATTACKING and _sel_idx == i)
		_draw_mini_card(CardBattleLayout.mini_rect(player_front, CardBattleConstants.PFFRONT_Y, i), player_front[i], false, sel)
	for i in player_rear.size():
		var sel_rear: bool = _ctx_idx == i and not _ctx_is_front
		_draw_mini_card(CardBattleLayout.mini_rect(player_rear, CardBattleConstants.PFREAR_Y, i), player_rear[i], false, sel_rear)

	# Click minion: green outline + MOVE / EFF. only (no attack arrow)
	if _ctx_idx >= 0:
		var ctx_row2: Array = player_front if _ctx_is_front else player_rear
		var ctx_y2: int = CardBattleConstants.PFFRONT_Y if _ctx_is_front else CardBattleConstants.PFREAR_Y
		if _ctx_idx < ctx_row2.size():
			var cr_ctx := CardBattleLayout.mini_rect(ctx_row2, ctx_y2, _ctx_idx)
			var d_ctx: Dictionary = ctx_row2[_ctx_idx]
			var ab_ctx: String = d_ctx["data"].get("ability", "")
			var ol_ctx := CardBattleLayout.selection_outline_rect(cr_ctx)
			_view.draw_rect(ol_ctx, Color(0.25, 0.88, 0.32), false, 2.0)
			var can_move_c: bool = is_player_turn and not _moved_this_turn and not _animating
			var can_eff_c: bool = is_player_turn and not _animating and not d_ctx.get("exhausted", false) \
				and _has_exhaust_activation(ab_ctx)
			if can_move_c:
				var mr_c := CardBattleLayout.context_move_btn_rect(cr_ctx)
				_view.draw_rect(mr_c, Color(0.22, 0.26, 0.18))
				_view.draw_rect(mr_c, CardBattleConstants.C_DIV, false, 1.0)
				_str_c("MOVE", mr_c.get_center().x, mr_c.get_center().y - 4.0, 8, CardBattleConstants.C_TEXT)
			if can_eff_c:
				var er_c: Rect2 = CardBattleLayout.context_eff_btn_rect(cr_ctx) if can_move_c else CardBattleLayout.context_move_btn_rect(cr_ctx)
				_view.draw_rect(er_c, Color(0.22, 0.26, 0.18))
				_view.draw_rect(er_c, CardBattleConstants.C_DIV, false, 1.0)
				_str_c("EFF.", er_c.get_center().x, er_c.get_center().y - 4.0, 8, CardBattleConstants.C_TEXT)

	# Attack mode: outline always; arrow + type-adv preview only while dragging aim (LMB + past threshold)
	if _mode == Mode.ATTACKING and _sel_idx >= 0 and _sel_idx < player_front.size():
		var cr_atk := CardBattleLayout.mini_rect(player_front, CardBattleConstants.PFFRONT_Y, _sel_idx)
		var ol_atk := CardBattleLayout.selection_outline_rect(cr_atk)
		_view.draw_rect(ol_atk, Color(0.25, 0.88, 0.32), false, 2.0)

		var start := CardBattleLayout.board_world_pos(_get_row(true, true), true, true, _sel_idx)
		if _atk_show_attack_arrow():
			_draw_arrow(start, _mouse_pos, CardBattleConstants.C_SEL)
			if not _hover_card.is_empty() and _hover_state.has("data"):
				var att_sub: String = player_front[_sel_idx]["data"].get("subtype", "")
				var def_sub: String = _hover_card.get("subtype", "")
				var bonus := _type_advantage(att_sub, def_sub)
				if bonus > 0:
					var mid := (start + _mouse_pos) * 0.5
					_str_c("Type Adv +%d dmg" % bonus, mid.x, mid.y - 10.0, 8, CardBattleConstants.C_TEXT)

	# DIRECT ATTACK — always visible on your turn; enabled = face legal (Figma 17:183 / 17:184)
	if is_player_turn and not _animating and not _ended:
		var da_legal: bool = _direct_attack_face_legal()
		var db := CardBattleLayout.direct_attack_btn_rect()
		if da_legal:
			_view.draw_rect(db, CardBattleConstants.C_DIRECT_ATTACK_ON)
			var accent := Rect2(db.position.x, db.position.y + db.size.y - 2.0, db.size.x, 2.0)
			_view.draw_rect(accent, CardBattleConstants.C_LOG_BORDER)
			_str_in_rect_center("DIRECT ATTACK", db, 8, CardBattleConstants.C_TEXT_LT)
		else:
			_view.draw_rect(db, CardBattleConstants.C_DIRECT_ATTACK_OFF)
			_str_in_rect_center("DIRECT ATTACK", db, 8, CardBattleConstants.C_DIRECT_ATTACK_OFF_TEXT)


# ══════════════════════════════════════════════════════════════════
# DRAWING — right sidebar
# ══════════════════════════════════════════════════════════════════
func _draw_right_sidebar() -> void:
	_draw_side_sec(0, "GRAVE",   enemy_gy.size(),    {})
	_draw_side_sec(1, "ARSENAL", -1,                 enemy_arsenal)
	_draw_side_sec(2, "DECK",    enemy_deck.size(),  {})
	_draw_side_sec(3, "DECK",    player_deck.size(), {})
	_draw_side_sec(4, "ARSENAL", -1,                 player_arsenal)
	_draw_side_sec(5, "GRAVE",   player_gy.size(),   {})


func _side_label_top_y(r: Rect2) -> float:
	if r.size.y <= 54.0:
		return r.position.y + 4.0
	return r.position.y + 5.0


func _side_count_baseline(r: Rect2) -> float:
	if r.size.y <= 54.0:
		return r.position.y + 22.0
	return r.position.y + 28.0


## Figma 8:133 — 12px count + 8px `cards`, same baseline, left-aligned with label
func _draw_side_zone_count_line(x_left: float, baseline_y: float, count: int) -> void:
	var f: Font = _fnt()
	var fs_n: int = _fs(12)
	var fs_c: int = _fs(8)
	var num_s: String = str(count)
	_view.draw_string(f, Vector2(_tx(x_left), _tx(baseline_y)), num_s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs_n, CardBattleConstants.C_TEXT_LT)
	var wn: float = f.get_string_size(num_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_n).x
	_view.draw_string(f, Vector2(_tx(x_left + wn + 2.0), _tx(baseline_y)), "cards",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs_c, CardBattleConstants.C_TEXT_LT)


## Figma 8:137 — `ARSENAL` stacked vertically, centered (empty tile)
func _draw_side_arsenal_vertical_label(inner: Rect2) -> void:
	var word := "ARSENAL"
	var fs: int = _fs(8)
	var f: Font = _fnt()
	var step: float = 10.0
	var total_h: float = float(word.length()) * step
	var cx: float = inner.position.x + inner.size.x * 0.5
	var y0: float = inner.position.y + (inner.size.y - total_h) * 0.5
	for i in word.length():
		var ch: String = word[i]
		var tw: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y_line: float = y0 + float(i) * step
		_view.draw_string(f, Vector2(_tx(cx - tw * 0.5), _tx(y_line + float(fs))), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CardBattleConstants.C_TEXT)


func _draw_side_sec(sec: int, label: String, count: int, card: Dictionary) -> void:
	var r := Rect2(float(CardBattleConstants.SIDE_ZONE_X), CardBattleConstants.SIDE_BAND_Y[sec], float(CardBattleConstants.SIDE_ZONE_RW), CardBattleConstants.SIDE_BAND_H[sec])
	var tx: float = r.position.x + 4.0
	var inner_h: float = minf(r.size.y, 110.0)
	var inner: Rect2 = Rect2(r.position.x + CardBattleConstants.SIDE_CARD_INSET, r.position.y, CardBattleConstants.SIDE_CARD_W, inner_h)

	if count >= 0:
		if label == "GRAVE":
			_view.draw_rect(Rect2(r.position.x, r.position.y, float(CardBattleConstants.SIDE_ZONE_W), r.size.y), CardBattleConstants.C_GRAVE_BG)
		else:
			_view.draw_rect(inner, CardBattleConstants.C_DECK_BG)
		_str(label, tx, _side_label_top_y(r), 8, CardBattleConstants.C_TEXT_LT)
		_draw_side_zone_count_line(tx, _side_count_baseline(r), count)
	else:
		_view.draw_rect(inner, CardBattleConstants.C_ARSENAL_BG)
		_view.draw_rect(inner, CardBattleConstants.C_SIDE_ARSENAL_BORDER, false, 2.0)
		if not card.is_empty():
			var cx: float = inner.position.x + (inner.size.x - float(CardBattleConstants.MINI_W)) * 0.5
			var cy: float = inner.position.y + (inner.size.y - float(CardBattleConstants.MINI_H)) * 0.5
			var full := Rect2(cx, cy, float(CardBattleConstants.MINI_W), float(CardBattleConstants.MINI_H))
			_draw_hand_card(full, card, false, false)
		else:
			_draw_side_arsenal_vertical_label(inner)


# ══════════════════════════════════════════════════════════════════
# DRAWING — hand
# ══════════════════════════════════════════════════════════════════
func _draw_hand() -> void:
	if player_hand.is_empty():
		_str("(empty hand)", CardBattleConstants.HAND_ROW_PAD,
			float(CardBattleConstants.HAND_Y) + (float(CardBattleConstants.HAND_CH) - 8.0) * 0.5, 8, CardBattleConstants.C_MUTED)
		return
	for i in player_hand.size():
		if _drag_active and _drag_hand_idx == i: continue
		var r    := CardBattleLayout.hand_rect(i, player_hand.size())
		var card: Dictionary = player_hand[i]
		var gray: bool = card.get("cost", 0) > player_mana
		_draw_hand_card(r, card, false, gray)


# ══════════════════════════════════════════════════════════════════
# DRAWING — card renders
# ══════════════════════════════════════════════════════════════════
func _mini_shows_effect_label(card: Dictionary) -> bool:
	if card.get("type", "demon") == "demon":
		if str(card.get("ability", "")).strip_edges() != "":
			return true
		return str(card.get("ability_desc", "")).strip_edges() != ""
	return str(card.get("effect", "")).strip_edges() != "" \
		or str(card.get("ability_desc", "")).strip_edges() != ""


func _draw_mini_card(r: Rect2, d: Dictionary, targetable: bool, selected: bool) -> void:
	var card: Dictionary = d["data"]
	var is_dem: bool = card.get("type", "demon") == "demon"
	var ex: bool = d.get("exhausted", false)
	var fill_c: Color = CardBattleConstants.C_SPELL_BG
	if is_dem:
		fill_c = CardBattleConstants.C_DEMON_BG if not ex else CardBattleConstants.C_CARD_MINI
	_view.draw_rect(r, fill_c)

	var border: Color = CardBattleConstants.C_SEL if selected \
		else (CardBattleConstants.C_TARGET if targetable else CardBattleConstants.C_MINI_BORDER)
	_view.draw_rect(r, border, false, 2.0)

	if d.get("taunt", false):
		_view.draw_rect(r, Color(1.0, 0.85, 0.1), false, 3.0)

	var nm_col: Color = CardBattleConstants.C_EXHAUST_TEXT if ex else CardBattleConstants.C_TEXT
	var nm: String = card.get("name", "")
	if nm.length() > 8: nm = nm.left(8) + "..."
	_str(nm, r.position.x + 5.0, r.position.y + 2.0, 8, nm_col)

	var art_bg_c: Color = fill_c
	var art_r := Rect2(r.position.x + 8.0, r.position.y + CardBattleConstants.MINI_ART_TOP, CardBattleConstants.MINI_ART_SIZE, CardBattleConstants.MINI_ART_SIZE)
	_view.draw_rect(art_r, Color(art_bg_c.r * 0.85, art_bg_c.g * 0.85, art_bg_c.b * 0.85))

	if _mini_shows_effect_label(card):
		var art_bot: float = r.position.y + CardBattleConstants.MINI_ART_TOP + CardBattleConstants.MINI_ART_SIZE
		var fs_e: int = _fs(8)
		var eff_col: Color = CardBattleConstants.C_EXHAUST_TEXT if ex else CardBattleConstants.C_TEXT
		_str("Effect", r.position.x + 5.0, art_bot - 2.0 - float(fs_e), 8, eff_col)

	if is_dem:
		var max_hp: int = card.get("hp", 1)
		var cur_hp: int = d.get("hp", max_hp)
		var atk_v: int = d.get("atk", card.get("atk", 0))
		var base_atk: int = card.get("atk", 0)
		var base_hp: int = card.get("hp", 1)
		_str_r_atk_hp(atk_v, cur_hp, max_hp, r.position.x + r.size.x - 3.0,
			r.position.y + r.size.y - 12.0, 10, ex, base_atk, base_hp)

	var cost_fill: Color = CardBattleConstants.C_EXHAUST_BADGE if ex else CardBattleConstants.C_COST_BADGE
	var cost_lbl: Color = CardBattleConstants.C_EXHAUST_TEXT if ex else CardBattleConstants.C_TEXT_LT
	# Mana — bottom-left (same as hand; field minis are not centered)
	_draw_cost_badge_rect(Rect2(r.position.x, r.position.y + float(CardBattleConstants.MINI_H - CardBattleConstants.HAND_COST_H),
		float(CardBattleConstants.HAND_COST_W), float(CardBattleConstants.HAND_COST_H)), card.get("cost", 0), cost_fill, cost_lbl)

	if ex:
		var zcx: float = r.position.x + r.size.x * 0.5
		var zcy: float = r.position.y + CardBattleConstants.MINI_ART_TOP + CardBattleConstants.MINI_ART_SIZE * 0.5 - 6.0
		_str_c("ZZZ", zcx, zcy, 10, CardBattleConstants.C_EXHAUST_TEXT)


func _draw_hand_card(r: Rect2, card: Dictionary, selected: bool, grayed: bool) -> void:
	var is_dem: bool = card.get("type", "demon") == "demon"
	_view.draw_rect(r, CardBattleConstants.C_DEMON_BG if is_dem else CardBattleConstants.C_SPELL_BG)
	var border_col: Color = CardBattleConstants.C_SEL if selected else CardBattleConstants.C_MINI_BORDER
	_view.draw_rect(r, border_col, false, 2.0)
	if grayed: _view.draw_rect(r, CardBattleConstants.C_GRAYED_CARD_OVERLAY)

	var nm: String = card.get("name", "")
	if nm.length() > 8: nm = nm.left(8) + "..."
	_str(nm, r.position.x + 5.0, r.position.y + 2.0, 8, CardBattleConstants.C_TEXT)

	var art_bg: Color = CardBattleConstants.C_DEMON_BG if is_dem else CardBattleConstants.C_SPELL_BG
	var art := Rect2(r.position.x + 8.0, r.position.y + CardBattleConstants.MINI_ART_TOP, CardBattleConstants.MINI_ART_SIZE, CardBattleConstants.MINI_ART_SIZE)
	_view.draw_rect(art, Color(art_bg.r * 0.84, art_bg.g * 0.84, art_bg.b * 0.84))
	_view.draw_rect(art, _mix_white(CardBattleConstants.C_MINI_BORDER, 0.35), false, 1.0)

	if _mini_shows_effect_label(card):
		var art_bot: float = r.position.y + CardBattleConstants.MINI_ART_TOP + CardBattleConstants.MINI_ART_SIZE
		var fs_e: int = _fs(8)
		_str("Effect", r.position.x + 5.0, art_bot - 2.0 - float(fs_e), 8, CardBattleConstants.C_TEXT)

	if is_dem:
		var max_hp: int = card.get("hp", 1)
		_str_r_atk_hp(card.get("atk", 0), card.get("hp", 1), max_hp,
			r.position.x + r.size.x - 3.0, r.position.y + r.size.y - 12.0, 10)
	else:
		_str_c("SPELL", r.get_center().x, r.position.y + r.size.y - 14.0, 8, Color(0.24, 0.40, 0.08))

	# Mana — Figma hand: 20×19 badge flush bottom-left
	_draw_cost_badge_rect(Rect2(r.position.x, r.position.y + float(CardBattleConstants.HAND_CH - CardBattleConstants.HAND_COST_H),
		float(CardBattleConstants.HAND_COST_W), float(CardBattleConstants.HAND_COST_H)), card.get("cost", 0))


func _draw_zoomed_card(card: Dictionary, state: Dictionary) -> void:
	# Figma 3:74 — x=8 y=172 w=165 h=230
	var cr := Rect2(8.0, float(CardBattleConstants.ZOOM_Y), 165.0, 230.0)
	var is_dem: bool = card.get("type", "demon") == "demon"
	_view.draw_rect(cr, CardBattleConstants.C_DEMON_BG if is_dem else CardBattleConstants.C_SPELL_BG)
	_view.draw_rect(cr, CardBattleConstants.C_MINI_BORDER, false, 2.0)

	_str_wrap(card.get("name", ""), cr.position.x + 6.0, cr.position.y + 6.0,
		cr.size.x - 14.0, 12, CardBattleConstants.C_TEXT)

	# Mana badge — Figma 20×19 @ top-right (local ~143, 2)
	_draw_cost_badge_rect(Rect2(cr.position.x + cr.size.x - 22.0, cr.position.y + 2.0, 20.0, 19.0),
		card.get("cost", 0))

	# Art placeholder — below up-to-2-line title (fixes.md long names)
	var art := Rect2(cr.position.x + 18.0, cr.position.y + 30.0, 128.0, 128.0)
	var art_bg := CardBattleConstants.C_DEMON_BG if is_dem else CardBattleConstants.C_SPELL_BG
	_view.draw_rect(art, Color(art_bg.r * 0.80, art_bg.g * 0.80, art_bg.b * 0.80))
	_view.draw_rect(art, _mix_white(CardBattleConstants.C_MINI_BORDER, 0.28), false, 1.0)

	# Effect text — just below art
	var ab_desc: String = card.get("ability_desc", card.get("desc", ""))
	if ab_desc != "":
		_str_wrap_ml(ab_desc, cr.position.x + 6.0, cr.position.y + 162.0,
			cr.size.x - 12.0, 7, CardBattleConstants.C_TEXT)

	# Type line (local 7,216)
	if is_dem:
		_str("DEMON - %s" % card.get("subtype", "dark").to_upper(),
			cr.position.x + 7.0, cr.position.y + 216.0, 7, CardBattleConstants.C_MUTED)
	else:
		_str_c("SPELL", cr.get_center().x, cr.position.y + 216.0, 7, Color(0.24, 0.40, 0.08))

	# ATK/HP — Figma 12px bottom-right
	if is_dem:
		var max_hp: int = card.get("hp", 1)
		var cur_hp: int = state.get("hp", max_hp)
		var atk_v: int = state.get("atk", card.get("atk", 0))
		var base_atk: int = card.get("atk", 0)
		var base_hp: int = card.get("hp", 1)
		_str_r_atk_hp(atk_v, cur_hp, max_hp, cr.position.x + cr.size.x - 6.0, cr.position.y + 203.0, 12,
			false, base_atk, base_hp)


func _draw_cost_badge_rect(r: Rect2, cost: int, fill: Color = CardBattleConstants.C_COST_BADGE, label_color: Color = CardBattleConstants.C_TEXT_LT) -> void:
	var x: int = int(floor(r.position.x))
	var y: int = int(floor(r.position.y))
	var w: int = maxi(1, int(floor(r.size.x)))
	var h: int = maxi(1, int(floor(r.size.y)))
	_view.draw_rect(r, fill)
	_view.draw_rect(r, CardBattleConstants.C_BLACK, false, 1.0)
	var fs: int = clampi(mini(w, h) - 4, CardBattleConstants.FONT_MIN, 12)
	var s: String = str(cost)
	var f: Font = _fnt()
	var tw: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline: float = float(y + h) - 3.0
	_view.draw_string(f, Vector2(float(x) + (float(w) - tw) * 0.5, baseline),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, label_color)


func _draw_cost_badge(pos: Vector2, cost: int, px: int = 14) -> void:
	_draw_cost_badge_rect(Rect2(pos.x, pos.y, float(px), float(px)), cost)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	if (to - from).length() < 10.0: return
	var norm := (to - from).normalized()
	var perp := Vector2(-norm.y, norm.x)
	_view.draw_line(from, to, color, 2.0)
	_view.draw_line(to, to - norm * 10.0 + perp * 5.0, color, 2.0)
	_view.draw_line(to, to - norm * 10.0 - perp * 5.0, color, 2.0)


func _draw_toast() -> void:
	if _toast_timer <= 0.0: return
	var ty: float = (float(CardBattleConstants.H) - CardBattleConstants.TOAST_H) * 0.5
	var tr := Rect2(CardBattleConstants.TOAST_X, ty, CardBattleConstants.TOAST_W, CardBattleConstants.TOAST_H)
	_view.draw_rect(tr, CardBattleConstants.C_GRAVE_BG)
	_str_in_rect_center_fit(_toast_text, tr, 14, CardBattleConstants.C_TEXT_LT)


func _draw_modal() -> void:
	var mx: float = float(CardBattleConstants.BOARD_X)
	var mw: float = float(CardBattleConstants.MODAL_PANEL_W)
	var mh: float = float(CardBattleConstants.H)
	_view.draw_rect(Rect2(mx, 0.0, mw, mh), CardBattleConstants.C_GRAVE_BG)
	var title: String = "%s - %d cards" % [_modal_title, _modal_cards.size()]
	_str(title, 183.0, 7.0, 10, CardBattleConstants.C_TEXT_LT)
	_str_r("CLOSE", 638.0, 6.0, 12, CardBattleConstants.C_TEXT_LT)
	var sx: float = CardBattleConstants.MODAL_GRID_X0
	var sy0: float = CardBattleConstants.MODAL_GRID_Y0
	for i in _modal_cards.size():
		var row: int = i / CardBattleConstants.MODAL_COLS
		var col: int = i % CardBattleConstants.MODAL_COLS
		var cy: float = sy0 + float(row) * CardBattleConstants.MODAL_ROW_H
		if cy + float(CardBattleConstants.HAND_CH) > mh:
			break
		var cr := Rect2(sx + float(col) * CardBattleConstants.MODAL_COL_W, cy, float(CardBattleConstants.HAND_CW), float(CardBattleConstants.HAND_CH))
		_draw_hand_card(cr, _modal_cards[i], false, false)


# ══════════════════════════════════════════════════════════════════
# TEXT HELPERS  (pixel font, AA off, integer baselines)
# ══════════════════════════════════════════════════════════════════
func _ensure_battle_font() -> void:
	if _battle_font != null:
		return
	var src: Resource = null
	if ResourceLoader.exists(CardBattleConstants.FONT_PATH_PRIMARY):
		src = load(CardBattleConstants.FONT_PATH_PRIMARY)
	if src == null and ResourceLoader.exists(CardBattleConstants.FONT_PATH_FALLBACK):
		src = load(CardBattleConstants.FONT_PATH_FALLBACK)
	if src is FontFile:
		var ff: FontFile = (src as FontFile).duplicate(true) as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_battle_font = ff
		(_battle_font as Font).clear_cache()
		return
	var th: Theme = ThemeDB.get_default_theme()
	var df: Font = th.get_default_font()
	if df is FontFile:
		var ff2: FontFile = (df as FontFile).duplicate(true) as FontFile
		ff2.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff2.hinting = TextServer.HINTING_NONE
		ff2.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_battle_font = ff2
		(_battle_font as Font).clear_cache()
	elif df != null:
		_battle_font = df
	else:
		_battle_font = ThemeDB.fallback_font


func _fnt() -> Font:
	if _battle_font != null:
		return _battle_font
	return ThemeDB.fallback_font


func _tx(x: float) -> int:
	return int(floor(x))


func _fs(sz: int) -> int:
	return maxi(sz, CardBattleConstants.FONT_MIN)


func _str(text: String, x: float, y: float, sz: int = 9, color: Color = CardBattleConstants.C_TEXT) -> void:
	var fs: int = _fs(sz)
	_view.draw_string(_fnt(), Vector2(_tx(x), _tx(y + float(fs))), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _str_c(text: String, cx: float, cy: float, sz: int = 9, color: Color = CardBattleConstants.C_TEXT) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_view.draw_string(f, Vector2(_tx(cx - tw * 0.5), _tx(cy + float(fs) * 0.5)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _str_r(text: String, rx: float, y: float, sz: int = 9, color: Color = CardBattleConstants.C_TEXT) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_view.draw_string(f, Vector2(_tx(rx - tw), _tx(y + float(fs))), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## Center label in a Figma rect (e.g. END TURN 78×24 @ y=431)
func _str_in_rect_center(text: String, r: Rect2, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx: float = r.position.x + (r.size.x - tw) * 0.5
	var baseline: float = r.position.y + r.size.y * 0.5 + float(fs) * 0.35
	_view.draw_string(f, Vector2(_tx(cx), _tx(baseline)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## One line, ellipsis to stay inside `r` (toast / long labels).
func _str_in_rect_center_fit(text: String, r: Rect2, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var max_w: float = maxf(8.0, r.size.x - 16.0)
	var t: String = text
	while t.length() > 2 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		t = t.left(t.length() - 1)
	if t != text:
		t = t.left(t.length() - 1) + "."
	var tw: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx: float = r.position.x + (r.size.x - tw) * 0.5
	var baseline: float = r.position.y + r.size.y * 0.5 + float(fs) * 0.35
	_view.draw_string(f, Vector2(_tx(cx), _tx(baseline)), t,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## Right-aligned `atk/hp` (Figma bottom-right). With `stat_base_*` set: green buff / red debuff or damage vs printed.
func _str_r_atk_hp(atk_v: int, cur_hp: int, max_hp: int, rx: float, y: float, sz: int, exhausted: bool = false, stat_base_atk: int = -99999, stat_base_hp: int = -99999) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var part_a: String = str(atk_v) + "/"
	var part_b: String = str(cur_hp)
	var w1: float = f.get_string_size(part_a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2: float = f.get_string_size(part_b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0: float = rx - (w1 + w2)
	var baseline: float = y + float(fs)
	var hp_col: Color
	var atk_col: Color
	if exhausted:
		atk_col = CardBattleConstants.C_EXHAUST_TEXT
		hp_col = CardBattleConstants.C_EXHAUST_TEXT
	elif stat_base_atk == -99999:
		atk_col = CardBattleConstants.C_TEXT
		hp_col = CardBattleConstants.C_HP_RED if cur_hp < max_hp else CardBattleConstants.C_TEXT
	else:
		if atk_v > stat_base_atk:
			atk_col = CardBattleConstants.C_STAT_BUFF
		elif atk_v < stat_base_atk:
			atk_col = CardBattleConstants.C_HP_RED
		else:
			atk_col = CardBattleConstants.C_TEXT
		if cur_hp > stat_base_hp:
			hp_col = CardBattleConstants.C_STAT_BUFF
		elif cur_hp < stat_base_hp:
			hp_col = CardBattleConstants.C_HP_RED
		else:
			hp_col = CardBattleConstants.C_TEXT
	_view.draw_string(f, Vector2(_tx(x0), _tx(baseline)), part_a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, atk_col)
	_view.draw_string(f, Vector2(_tx(x0 + w1), _tx(baseline)), part_b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, hp_col)


func _str_fit(text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var t: String = text
	while t.length() > 2 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		t = t.left(t.length() - 1)
	if t != text:
		t = t.left(t.length() - 1) + "."
	_view.draw_string(f, Vector2(_tx(x), _tx(y + float(fs))), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _str_wrap(text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var l1: String = ""
	var l2: String = ""
	for word in text.split(" "):
		var test: String = (l1 + " " + word).strip_edges()
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			l1 = test
		else:
			l2 = (l2 + " " + word).strip_edges()
	_view.draw_string(f, Vector2(_tx(x), _tx(y + float(fs))), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	if l2 != "":
		var s: String = l2 if f.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w \
				else l2.left(l2.length() - 2) + ".."
		_view.draw_string(f, Vector2(_tx(x), _tx(y + float(fs) * 2.0 + 2.0)), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func _str_wrap_ml(text: String, x: float, y: float, max_w: float, sz: int, color: Color) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var line: String = ""
	var cy: float = y + float(fs)
	for word in text.split(" "):
		var test: String = (line + " " + word).strip_edges()
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
			line = test
		else:
			if line != "":
				_view.draw_string(f, Vector2(_tx(x), _tx(cy)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
				cy += float(fs) + 2.0
			line = word
	if line != "":
		_view.draw_string(f, Vector2(_tx(x), _tx(cy)), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
