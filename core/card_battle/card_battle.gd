class_name CardBattle extends CanvasLayer

class _View extends Control:
	var b
	func _draw() -> void:                   b._on_draw()
	func _gui_input(e: InputEvent) -> void: b._on_input(e)
	func _process(dt: float) -> void:       b._tick(dt)


## Attack aim drawn above `_view` (hand, chrome, modal) via max z_index.
class _ArrowOverlay extends Control:
	var b: CardBattle
	func _process(_dt: float) -> void:
		if b == null or b._ended:
			return
		# Always redraw so the arrow is cleared the moment mode leaves ATTACKING.
		queue_redraw()
	func _draw() -> void:
		if b == null:
			return
		b._paint_attack_arrow_overlay(self)


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
var _pay_arsenal_pitch_start: int = 0
var _moved_this_turn   := false
var _stashed_this_turn := false
var _enemy_stashed_this_turn := false
var _soul_collector_drew_this_turn: bool = false
var _enemy_soul_collector_drew_this_turn: bool = false

var player_mana     := 0
var player_turn_num := 0
var enemy_mana      := 0
var enemy_turn_num  := 0

var _ai_type       := "midrange"
var is_player_turn := false
var _animating     := false
var _ended         := false

enum Mode { IDLE, CHOOSE_ROW, ATTACKING, CHOOSE_ARSENAL, CHOOSE_ENEMY_TARGET, CHOOSE_ALLY_TARGET, CHOOSE_PAY_MANA }
var _mode          := Mode.IDLE
var _pending_card:  Dictionary = {}
var _pending_hand_idx := -1
## Pay for a card: pitch other hand cards until `player_mana` ≥ cost, then auto-play `_pay_card_id`.
var _pay_card_id: String = ""
## Hand index of the card being paid for (-1 = from arsenal).
var _pay_hand_idx: int = -1
var _pay_cost: int = 0
var _pay_to_front: bool = true
var _pay_from_arsenal: bool = false
## Visual-only: animation time for mana-pay "stack" vortex on the board.
var _pay_stack_t: float = 0.0
## Pay-stack preview: use drop point on the row instead of row center.
var _pay_stack_use_drop_anchor: bool = false
var _pay_stack_anchor: Vector2 = Vector2.ZERO
## CHOOSE_ROW after paying from Arsenal: mana already spent; do not charge again on place.
var _pending_skip_mana_on_place: bool = false
var _choose_row_mana_refund: int = 0
## Modal: "" = browse grave/deck; "chaos_pick" = select Regalia/Obscura to summon Chaos King.
var _modal_kind: String = ""
var _chaos_hand_idx: int = -1
var _chaos_to_front: bool = true
var _chaos_from_arsenal: bool = false
## Selected indices in `player_gy` for Chaos King cost (exactly 3 Regalia + 3 Obscura).
var _chaos_selected: Dictionary = {}
var _sel_idx          := -1
## Log label while player must click an enemy minion to freeze (Frost Mage, Frost Bolt, etc.).
var _freeze_target_source_name: String = ""
var _ally_target_pending_card: Dictionary = {}
var _ally_target_source_name: String = ""

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

var _drag_active:    bool = false
var _drag_card:      Dictionary = {}
var _drag_hand_idx:  int = -1
var _drag_pos:       Vector2 = Vector2.ZERO
var _drag_start_pos: Vector2 = Vector2.ZERO
## When entering CHOOSE_ROW via a hand-card click, restore here on cancel (-1 = arsenal).
var _pending_hand_restore_idx: int = -1

## Context menu: `_ctx_idx` indexes `player_front` or `player_rear` depending on `_ctx_is_front`.
## Front minion: drag past threshold = attack aim (arrow). Rear: click toggles context only.
var _ctx_idx: int = -1
var _ctx_is_front: bool = true
var _atk_drag_idx: int = -1
var _atk_drag_start: Vector2 = Vector2.ZERO
var _rear_pick_idx: int = -1
var _rear_pick_start: Vector2 = Vector2.ZERO

## Enemy attack preview: set by AI before dealing damage so arrow is visible.
var _enemy_atk_from_idx: int = -1
var _enemy_atk_target_type: String = ""  ## "face", "front", "rear"
var _enemy_atk_target_idx: int = -1

var _toast_text:  String = ""
var _toast_timer: float  = 0.0
## True after End Turn opened the Arsenal choice — stashing should finish the turn without a second End press.
var _pending_finish_after_arsenal: bool = false

var _modal_open:  bool   = false
var _modal_cards: Array  = []
var _modal_title: String = ""

var _enemy_spell_preview: Dictionary = {}
var _enemy_spell_preview_t: float = 0.0

var _view: _View
var _arrow_overlay: _ArrowOverlay
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
	_arrow_overlay = _ArrowOverlay.new()
	_arrow_overlay.b = self
	_arrow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrow_overlay.z_as_relative = false
	_arrow_overlay.z_index = 4096
	add_child(_arrow_overlay)
	_ai_runner = CardBattleAIRunner.new(self)
	_start_battle()


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if not event.is_pressed() or event.is_echo():
		return
	var want_cancel: bool = event.is_action_pressed("pause")
	if not want_cancel and event is InputEventKey:
		var kk: InputEventKey = event as InputEventKey
		want_cancel = kk.keycode == KEY_ESCAPE or kk.physical_keycode == KEY_ESCAPE
	if not want_cancel:
		return
	if _mode == Mode.CHOOSE_PAY_MANA:
		_cancel_pay_mana()
	elif _modal_kind == "chaos_pick":
		_cancel_chaos_summon()
	elif _mode == Mode.CHOOSE_ROW:
		_cancel_choose_row()
	elif _mode == Mode.CHOOSE_ENEMY_TARGET:
		_log("Freeze cancelled.")
		_finish_choose_enemy_target_idle()
	elif _mode == Mode.CHOOSE_ALLY_TARGET:
		_log("Target cancelled (spell fizzled).")
		_finish_choose_ally_target_idle()
	else:
		return
	get_viewport().set_input_as_handled()
	_view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# BATTLE FLOW
# ══════════════════════════════════════════════════════════════════
func _start_battle() -> void:
	player_deck = CardDB.deck_from_card_ids(Global.get_battle_deck_card_ids())
	var diff: String = "easy"
	var prebuilt_enemy_deck: Array = []
	if is_instance_valid(enemy_actor) and "difficulty" in enemy_actor:
		diff = str(enemy_actor.difficulty)
		if enemy_actor.has_method("get_battle_deck"):
			prebuilt_enemy_deck = enemy_actor.call("get_battle_deck")
	enemy_deck  = prebuilt_enemy_deck if not prebuilt_enemy_deck.is_empty() else CardDB.enemy_deck_for_difficulty(diff)
	_ai_type    = _ai_runner.detect_ai_type_from_deck(enemy_deck)
	player_hp = Global.player_hp
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
		if hand.size() >= CardBattleConstants.MAX_HAND:
			break
		_draw_one(hand, deck)
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
	Global.set_hp(player_hp)
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func (): battle_ended.emit(player_won))


func _draw_n(hand: Array, deck: Array, n: int) -> void:
	for _i in n:
		if deck.is_empty(): return
		if hand.size() >= CardBattleConstants.MAX_HAND:
			return
		hand.append(deck.pop_front())


func _draw_one(hand: Array, deck: Array) -> void:
	if hand.size() >= CardBattleConstants.MAX_HAND:
		return
	if not deck.is_empty(): hand.append(deck.pop_front())
	if hand == player_hand:
		_check_osiris_combo_win()
		# Star Prophet: only during your turn (not opening draw or end-of-turn hand refresh).
		if is_player_turn:
			for row in [player_front, player_rear]:
				for obs in row:
					if "draw_pings" in str(obs["data"].get("ability", "")):
						_deal_damage_to_enemy(1)
	elif hand == enemy_hand:
		if not is_player_turn:
			for row in [enemy_front, enemy_rear]:
				for obs in row:
					if "draw_pings" in str(obs["data"].get("ability", "")):
						_deal_damage_to_player(1)


func _log(s: String) -> void:
	_battle_log.append({"text": s, "color": CardBattleConstants.C_LOG_BODY})
	var flat: Array = _log_flat_lines()
	_log_scroll = maxi(0, flat.size() - CardBattleConstants.LOG_VISIBLE)
	_clamp_log_scroll()
	_view.queue_redraw()


func _log_colored(s: String, color: Color) -> void:
	_battle_log.append({"text": s, "color": color})
	var flat: Array = _log_flat_lines()
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
	_soul_collector_drew_this_turn = false
	_mode              = Mode.IDLE
	_sel_idx           = -1
	_ctx_idx           = -1
	_ctx_is_front      = true
	_atk_drag_idx      = -1
	_rear_pick_idx     = -1
	_pending_card      = {}
	_begin_turn_refresh_exhaustion_for_side(true)
	_refresh_mimic_minions_and_front_atk_auras()
	_apply_start_of_turn_board_effects(true)
	_log("--- Your turn %d — %d mana (play cards; pitch only to pay costs) ---" % [player_turn_num, player_mana])
	_show_toast("Your Turn")
	_view.queue_redraw()


## End Turn button: optional Arsenal stash first (see _handle_end_turn_click).
func _finish_end_player_turn() -> void:
	if not is_player_turn or _animating or _ended: return
	if _mode == Mode.CHOOSE_PAY_MANA:
		_cancel_pay_mana()
	if _modal_kind == "chaos_pick":
		_cancel_chaos_summon()
	## Return limbo cards before discarding hand / clearing pending (guards edge paths).
	if _mode == Mode.CHOOSE_ROW:
		_cancel_choose_row()
	if _mode == Mode.CHOOSE_ENEMY_TARGET:
		_finish_choose_enemy_target_idle()
	if _mode == Mode.CHOOSE_ALLY_TARGET:
		_finish_choose_ally_target_idle()
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
	## Pitched for mana only: bottom of deck in random order — never graveyard.
	_pitched_this_turn.shuffle()
	for c in _pitched_this_turn: player_deck.append(c)
	_pitched_this_turn.clear()
	## Leftover hand (not played, not stashed to Arsenal): graveyard — not deck.
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
	if _mode == Mode.CHOOSE_PAY_MANA:
		_log("Esc cancels paying mana, or keep pitching.")
		return
	if _modal_kind == "chaos_pick":
		_log("Esc or CLOSE cancels Chaos King — or press SUMMON when ready.")
		return
	if _mode == Mode.ATTACKING or _mode == Mode.CHOOSE_ROW or _mode == Mode.CHOOSE_ENEMY_TARGET or _mode == Mode.CHOOSE_ALLY_TARGET:
		_log("Choose a target first.")
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
	_enemy_soul_collector_drew_this_turn = false
	## Previous turn’s unplayed hand — graveyard (pitched cards already left hand earlier).
	for c in enemy_hand: enemy_gy.append(c)
	enemy_hand.clear()
	if not _draw_mandatory_refresh(enemy_hand, enemy_deck, CardBattleConstants.STARTING_HAND, false):
		_animating = false
		return
	_begin_turn_refresh_exhaustion_for_side(false)
	_refresh_mimic_minions_and_front_atk_auras()
	_apply_start_of_turn_board_effects(false)
	_log("--- Enemy turn %d ---" % enemy_turn_num)
	_view.queue_redraw()
	await _ai_runner.play_phase()
	if _ended: return
	await _ai_runner.attack_phase()
	if _ended: return
	## Pitched for mana only: bottom of deck in random order — never graveyard.
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
			var regen_amt: int = 0
			if _kwrd(ab, "taunt_regen_2"):
				regen_amt = 2
			elif _kwrd(ab, "taunt_regen"):
				regen_amt = 1
			if regen_amt == 0:
				continue
			var mx: int = int(d.get("hp_intrinsic", int(d["data"].get("hp", 1)))) + int(d.get("hp_aura_bonus", 0))
			if d["hp"] >= mx:
				continue
			d["hp"] = mini(d["hp"] + regen_amt, mx)
			_log("%s restores %d HP." % [str(d["data"].get("name", "?")), regen_amt])


## Freeze — show exhausted (ZZZ) on the target until end of that minion owner's next turn (then thaw).
func _apply_freeze(d: Dictionary) -> void:
	d["frozen"] = true
	d["exhausted"] = true


func _begin_choose_enemy_to_freeze(source_name: String) -> void:
	_freeze_target_source_name = source_name
	_mode = Mode.CHOOSE_ENEMY_TARGET
	_ctx_idx = -1
	_ctx_is_front = true
	_atk_drag_idx = -1
	_rear_pick_idx = -1
	_sel_idx = -1
	_show_toast("Choose enemy to freeze")
	_log("%s — click an enemy minion." % source_name)
	_view.queue_redraw()


func _finish_choose_enemy_target_idle() -> void:
	_mode = Mode.IDLE
	_freeze_target_source_name = ""


func _complete_choose_enemy_freeze(target: Dictionary) -> void:
	_apply_freeze(target)
	_log("%s freezes %s!" % [_freeze_target_source_name, str(target["data"].get("name", "?"))])
	_finish_choose_enemy_target_idle()
	_check_auto_lose_no_resources(true)
	_check_game_over()
	_view.queue_redraw()


func _begin_choose_ally_target(source_name: String, card: Dictionary) -> void:
	_ally_target_source_name = source_name
	_ally_target_pending_card = card
	_mode = Mode.CHOOSE_ALLY_TARGET
	_ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1; _sel_idx = -1
	_show_toast("Choose a friendly demon")
	_log("%s — click one of your demons." % source_name)
	_view.queue_redraw()


func _finish_choose_ally_target_idle() -> void:
	_mode = Mode.IDLE
	_ally_target_source_name = ""
	_ally_target_pending_card = {}


func _complete_choose_ally_target(target: Dictionary) -> void:
	var card: Dictionary = _ally_target_pending_card
	var effect: String = str(card.get("effect", ""))
	var val: int = int(card.get("value", 0))
	var cname: String = str(card.get("name", "Spell"))
	var tname: String = str(target["data"].get("name", "?"))
	match effect:
		"buff_hp":
			target["hp"] += val
			target["hp_intrinsic"] = target.get("hp_intrinsic", int(target["data"].get("hp", 1))) + val
			_log("%s: +%d HP to %s!" % [cname, val, tname])
		"give_divine_shield":
			target["divine_active"] = true
			_log("%s: Divine Shield on %s!" % [cname, tname])
		"buff_target_stats":
			target["atk_intrinsic"] = target.get("atk_intrinsic", int(target["data"].get("atk", 0))) + val
			target["hp"] += val
			target["hp_intrinsic"] = target.get("hp_intrinsic", int(target["data"].get("hp", 1))) + val
			_log("%s: +%d/+%d to %s!" % [cname, val, val, tname])
	_finish_choose_ally_target_idle()
	_apply_after_spell_cast(true)
	_refresh_mimic_minions_and_front_atk_auras()
	_check_game_over()
	_view.queue_redraw()


func _ai_freeze_highest_atk_on_player_board() -> void:
	var all_e: Array = []
	for o in player_front: all_e.append(o)
	for o in player_rear: all_e.append(o)
	if all_e.is_empty():
		return
	var hi: Dictionary = all_e[0]
	for o in all_e:
		if o["atk"] > hi["atk"]:
			hi = o
	_apply_freeze(hi)


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


## Iron Warden: spells cost +1 per Warden on the opponent's board.
func _spell_tax_against_caster(is_player_caster: bool) -> int:
	var rows: Array = [enemy_front, enemy_rear] if is_player_caster else [player_front, player_rear]
	var n: int = 0
	for row in rows:
		for d in row:
			if "tax_spells" in str(d["data"].get("ability", "")):
				n += 1
	return n


func _battlecry_auto_reposition_ally(d: Dictionary, pf: Array, pr: Array) -> void:
	if pf.size() >= 2 and pr.size() < CardBattleConstants.MAX_ROW:
		for i in range(pf.size()):
			if pf[i] != d:
				pr.append(pf[i])
				pf.remove_at(i)
				return
	if pr.size() >= 1 and pf.size() < CardBattleConstants.MAX_ROW:
		for i in range(pr.size()):
			if pr[i] != d:
				pf.append(pr[i])
				pr.remove_at(i)
				return


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
		d["atk_intrinsic"] = tot
		d["hp_intrinsic"] = tot
	if "battlecry_freeze_target" in ab:
		if is_player:
			if enemy_front.is_empty() and enemy_rear.is_empty():
				_log("No enemy to freeze.")
			else:
				_begin_choose_enemy_to_freeze(str(card.get("name", "?")))
			_check_auto_lose_no_resources(is_player)
			_refresh_mimic_minions_and_front_atk_auras()
			return
		_ai_freeze_highest_atk_on_player_board()
	_resolve_battlecry(d, is_player)
	_refresh_mimic_minions_and_front_atk_auras()


func _make_board_demon(card: Dictionary) -> Dictionary:
	var ab: String = card.get("ability", "")
	var a0: int = int(card.get("atk", 0))
	var h0: int = int(card.get("hp", 1))
	return {
		"data"         : card,
		"hp"           : h0,
		"hp_intrinsic" : h0,
		"hp_aura_bonus": 0,
		"atk"          : a0,
		"atk_intrinsic": a0,
		"rage_stacks"  : 0,
		"exhausted"    : not _kwrd(ab, "haste"),
		"attacked"     : 0,
		"divine_active": _kwrd(ab, "divine_shield"),
		"poisonous"    : _kwrd(ab, "poisonous"),
		"lifesteal"    : _kwrd(ab, "lifesteal"),
		"taunt"        : _kwrd(ab, "taunt"),
		"unblockable"  : _kwrd(ab, "unblockable"),
		"aerial"       : _kwrd(ab, "aerial"),
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
	elif "battlecry_aoe_all_1"         in ab:
		for o in of_.duplicate(): _hit_demon(o, 1, false)
		for o in or_.duplicate(): _hit_demon(o, 1, false)
		for o in pf.duplicate():
			if o != d: _hit_demon(o, 1, false)
		for o in pr.duplicate():
			if o != d: _hit_demon(o, 1, false)
		_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
		_process_deaths(pf, is_player, true); _process_deaths(pr, is_player, false)
	elif "battlecry_aoe_1"             in ab:
		for o in of_.duplicate(): _hit_demon(o, 1, false)
		for o in or_.duplicate(): _hit_demon(o, 1, false)
		_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
	elif "battlecry_aoe_2"             in ab:
		for o in of_.duplicate(): _hit_demon(o, 2, false)
		for o in or_.duplicate(): _hit_demon(o, 2, false)
		_process_deaths(of_, not is_player, true); _process_deaths(or_, not is_player, false)
	elif "battlecry_buff_all_atk"      in ab:
		for ally in pf:
			if ally != d:
				ally["atk_intrinsic"] = ally.get("atk_intrinsic", int(ally["data"].get("atk", 0))) + 1
		for ally in pr:
			if ally != d:
				ally["atk_intrinsic"] = ally.get("atk_intrinsic", int(ally["data"].get("atk", 0))) + 1
	elif "battlecry_buff_beast"       in ab:
		for ally in pf:
			if ally != d and ally["data"].get("subtype", "") == "terresta":
				ally["atk_intrinsic"] = ally.get("atk_intrinsic", int(ally["data"].get("atk", 0))) + 1
		for ally in pr:
			if ally != d and ally["data"].get("subtype", "") == "terresta":
				ally["atk_intrinsic"] = ally.get("atk_intrinsic", int(ally["data"].get("atk", 0))) + 1
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
		if is_player: _heal_player(3)
		else:         enemy_hp  = mini(enemy_hp  + 3, CardBattleConstants.STARTING_HP)
	elif "battlecry_summon_imps"       in ab:
		_summon(CardDB.get_card("token_imp"), is_player, true)
		_summon(CardDB.get_card("token_imp"), is_player, true)
	elif "battlecry_summon_imp"        in ab:
		_summon(CardDB.get_card("token_imp"), is_player, true)
	elif "battlecry_freeze_all" in ab:
		for o in of_: _apply_freeze(o)
		for o in or_: _apply_freeze(o)
	elif "battlecry_rear_strike" in ab:
		var nrear: int = or_.size()
		if nrear > 0:
			if is_player: _deal_damage_to_enemy(nrear)
			else: _deal_damage_to_player(nrear)
	elif "battlecry_equalize_hp" in ab:
		player_hp = 5
		enemy_hp = 5
	elif "battlecry_buff_all_hp" in ab:
		for ally in pf:
			if ally != d:
				ally["hp"] = ally.get("hp", 1) + 2
				ally["hp_intrinsic"] = ally.get("hp_intrinsic", int(ally["data"].get("hp", 1))) + 2
		for ally in pr:
			if ally != d:
				ally["hp"] = ally.get("hp", 1) + 2
				ally["hp_intrinsic"] = ally.get("hp_intrinsic", int(ally["data"].get("hp", 1))) + 2
	elif "battlecry_buff_target_2_2" in ab:
		var allies_all: Array = []
		for ally in pf:
			if ally != d: allies_all.append({"d": ally})
		for ally in pr:
			if ally != d: allies_all.append({"d": ally})
		if not allies_all.is_empty():
			var picked: Dictionary = allies_all[randi() % allies_all.size()]["d"]
			picked["atk_intrinsic"] = picked.get("atk_intrinsic", int(picked["data"].get("atk", 0))) + 2
			picked["hp"] = picked.get("hp", 1) + 2
			picked["hp_intrinsic"] = picked.get("hp_intrinsic", int(picked["data"].get("hp", 1))) + 2
			_log("%s buffed %s +2/+2." % [d["data"].get("name", "?"), picked["data"].get("name", "?")])
	elif "battlecry_buff_random_ally_1_atk" in ab:
		var pool_a: Array = []
		for ally in pf:
			if ally != d: pool_a.append(ally)
		for ally in pr:
			if ally != d: pool_a.append(ally)
		if not pool_a.is_empty():
			var tgt: Dictionary = pool_a[randi() % pool_a.size()]
			tgt["atk_intrinsic"] = tgt.get("atk_intrinsic", int(tgt["data"].get("atk", 0))) + 1
			_log("%s gives +1 ATK to %s." % [d["data"].get("name", "?"), tgt["data"].get("name", "?")])
	elif "wormoyf_power" in ab:
		var subtypes_seen: Dictionary = {}
		for row_w: Array in [pf, pr, of_, or_]:
			for dm: Dictionary in row_w:
				if dm == d: continue
				var st: String = str(dm["data"].get("subtype", ""))
				if st != "": subtypes_seen[st] = true
		var spell_count: int = 0
		var pg_w: Array = player_gy if is_player else enemy_gy
		var og_w: Array = enemy_gy if is_player else player_gy
		for c in pg_w:
			if str(c.get("type", "")) == "spell": spell_count += 1
		for c in og_w:
			if str(c.get("type", "")) == "spell": spell_count += 1
		var bonus: int = subtypes_seen.size() + spell_count
		if bonus > 0:
			d["atk_intrinsic"] = d.get("atk_intrinsic", int(d["data"].get("atk", 0))) + bonus
			d["hp"] = d.get("hp", 1) + bonus
			d["hp_intrinsic"] = d.get("hp_intrinsic", int(d["data"].get("hp", 1))) + bonus
			_log("Wormoyf absorbs power: +%d/+%d." % [bonus, bonus])
	elif "battlecry_destroy_weak" in ab:
		var killed: bool = false
		for o in of_.duplicate():
			if o["hp"] <= 3:
				o["hp"] = 0
				_process_deaths(of_, not is_player, true)
				killed = true
				break
		if not killed:
			for o in or_.duplicate():
				if o["hp"] <= 3:
					o["hp"] = 0
					_process_deaths(or_, not is_player, false)
					break
	elif "battlecry_discard_enemy" in ab:
		var opp_hand: Array = enemy_hand if is_player else player_hand
		var opp_gy: Array = enemy_gy if is_player else player_gy
		if not opp_hand.is_empty():
			var dc0: Dictionary = opp_hand[0]
			opp_hand.remove_at(0)
			opp_gy.append(dc0)
	elif "battlecry_damage_random_2" in ab:
		var pool: Array = []
		for o in of_.duplicate():
			pool.append({"row": of_, "d": o, "front": true})
		for o in or_.duplicate():
			pool.append({"row": or_, "d": o, "front": false})
		if not pool.is_empty():
			var z: Dictionary = pool[randi() % pool.size()]
			_hit_demon(z["d"], 2, false)
			_process_deaths(z["row"], not is_player, z["front"])
	elif "battlecry_aoe_rear_2" in ab:
		for o in or_.duplicate():
			_hit_demon(o, 2, false)
		_process_deaths(or_, not is_player, false)
	elif "battlecry_face_per_spell_gy" in ab:
		var gya: Array = player_gy if is_player else enemy_gy
		var sns: int = 0
		for c in gya:
			if str(c.get("type", "")) == "spell":
				sns += 1
		if sns > 0:
			if is_player: _deal_damage_to_enemy(sns)
			else: _deal_damage_to_player(sns)
	elif "battlecry_aoe_per_spell" in ab:
		var gyb: Array = player_gy if is_player else enemy_gy
		var snb: int = 0
		for c in gyb:
			if str(c.get("type", "")) == "spell":
				snb += 1
		if snb > 0:
			for _rep in snb:
				for o in of_.duplicate(): _hit_demon(o, 1, false)
				for o in or_.duplicate(): _hit_demon(o, 1, false)
			_process_deaths(of_, not is_player, true)
			_process_deaths(or_, not is_player, false)
	elif "battlecry_replay_spell" in ab:
		var gyc: Array = player_gy if is_player else enemy_gy
		var rep: Dictionary = {}
		for ii in range(gyc.size() - 1, -1, -1):
			if str(gyc[ii].get("type", "")) == "spell":
				rep = gyc[ii]
				break
		if not rep.is_empty():
			_log("Echo: replays %s." % str(rep.get("name", "spell")))
			_resolve_spell(rep.duplicate(true), is_player)
	elif "battlecry_reposition_enemy" in ab:
		if not of_.is_empty() and or_.size() < CardBattleConstants.MAX_ROW:
			var mvv: Dictionary = of_.pop_at(0)
			or_.append(mvv)
	elif "battlecry_reposition_ally" in ab:
		_battlecry_auto_reposition_ally(d, pf, pr)
	elif "chaos_dragon" in ab:
		if is_player:
			var eg: int = enemy_gy.size()
			var cdmg: int = eg * 2
			if cdmg > 0:
				_deal_damage_to_enemy(cdmg)
			_log("Chaos King: %d to enemy (%d cards in their graveyard)." % [cdmg, eg])
		else:
			var pg: int = player_gy.size()
			var pdmg: int = pg * 2
			if pdmg > 0:
				_deal_damage_to_player(pdmg)
			_log("Enemy Chaos King: %d to you (%d in your graveyard)." % [pdmg, pg])
	_check_auto_lose_no_resources(is_player)


func _schedule_instant_win(msg: String) -> void:
	if _ended: return
	_ended = true
	_log(msg)
	_show_toast("YOU WIN!")
	_view.queue_redraw()
	Global.set_hp(player_hp)
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func (): battle_ended.emit(true))


func _schedule_instant_lose(msg: String) -> void:
	if _ended: return
	_ended = true
	_log(msg)
	_show_toast("YOU LOSE...")
	_view.queue_redraw()
	Global.set_hp(0)
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


func _is_chaos_king_card(card: Dictionary) -> bool:
	return "chaos_dragon" in str(card.get("ability", ""))


func _find_hand_idx_by_id(id: String) -> int:
	for i in player_hand.size():
		if str(player_hand[i].get("id", "")) == id:
			return i
	return -1


func _cancel_pay_mana() -> void:
	if _mode != Mode.CHOOSE_PAY_MANA:
		return
	var cards_to_return: Array = _pitched_this_turn.slice(_pay_arsenal_pitch_start)
	for c in cards_to_return:
		player_mana = maxi(0, player_mana - int(c.get("mana_value", 1)))
		player_hand.append(c)
	_pitched_this_turn.resize(_pay_arsenal_pitch_start)
	_mode = Mode.IDLE
	_pay_card_id = ""
	_pay_cost = 0
	_pay_from_arsenal = false
	_pay_arsenal_pitch_start = 0
	_pay_stack_t = 0.0
	_pay_stack_use_drop_anchor = false
	Sound.play(preload("res://data/sfx/to use/Cancel.wav"))
	_log("Cancelled paying mana.")
	_view.queue_redraw()


func _cancel_choose_row() -> void:
	if _mode != Mode.CHOOSE_ROW:
		return
	if _pending_card.is_empty():
		_mode = Mode.IDLE
		return
	if _pending_skip_mana_on_place:
		player_mana = mini(player_mana + _choose_row_mana_refund, 10)
		_pending_skip_mana_on_place = false
		_choose_row_mana_refund = 0
	if _pending_hand_idx >= 0 and _pending_hand_idx <= player_hand.size():
		player_hand.insert(_pending_hand_idx, _pending_card.duplicate(true))
	elif _pending_hand_restore_idx >= 0:
		# Came from hand-click flow: card was removed before entering CHOOSE_ROW.
		var ri: int = mini(_pending_hand_restore_idx, player_hand.size())
		player_hand.insert(ri, _pending_card.duplicate(true))
		_pending_hand_restore_idx = -1
	else:
		player_arsenal = _pending_card.duplicate(true)
	_pending_card = {}
	_pending_hand_idx = -1
	_pending_hand_restore_idx = -1
	_mode = Mode.IDLE
	Sound.play(preload("res://data/sfx/to use/Cancel.wav"))
	_log("Summon cancelled.")
	_view.queue_redraw()


func _cancel_chaos_summon() -> void:
	_modal_open = false
	_modal_kind = ""
	_modal_cards.clear()
	_chaos_selected.clear()
	_chaos_hand_idx = -1
	_chaos_from_arsenal = false
	Sound.play(preload("res://data/sfx/to use/Cancel.wav"))
	_log("Chaos King summon cancelled.")
	_view.queue_redraw()


func _try_finish_pay_mana() -> void:
	if _mode != Mode.CHOOSE_PAY_MANA:
		return
	if player_mana < _pay_cost:
		return
	if _pay_from_arsenal:
		if player_arsenal.is_empty() or str(player_arsenal.get("id", "")) != _pay_card_id:
			_cancel_pay_mana()
			return
		var acard: Dictionary = player_arsenal.duplicate(true)
		var paid_mana: int = _pay_cost
		player_mana -= _pay_cost
		player_arsenal = {}
		_pay_from_arsenal = false
		_mode = Mode.IDLE
		_pay_card_id = ""
		_pay_cost = 0
		if str(acard.get("type", "")) == "demon":
			var aab: String = str(acard.get("ability", ""))
			if "taunt" in aab:
				_summon(acard, true, true)
				## Demon goes to GY only on death.
				_log("Arsenal: %s to front!" % acard.get("name", "?"))
			else:
				_pending_skip_mana_on_place = true
				_choose_row_mana_refund = paid_mana
				_pending_card = acard
				_pending_hand_idx = -1
				_mode = Mode.CHOOSE_ROW
				_log("Choose row for %s." % acard.get("name", "?"))
		else:
			_resolve_spell(acard, true)
			player_gy.append(acard)
			_log("Arsenal: %s!" % acard.get("name", "?"))
		_pay_stack_t = 0.0
		_pay_stack_use_drop_anchor = false
		_view.queue_redraw()
		_check_game_over()
		return
	var idx: int = _find_hand_idx_by_id(_pay_card_id)
	if idx < 0 or idx >= player_hand.size():
		_cancel_pay_mana()
		return
	var card: Dictionary = player_hand[idx]
	player_mana -= _pay_cost
	player_hand.remove_at(idx)
	if str(card.get("type", "")) == "demon":
		_summon(card, true, _pay_to_front)
		## Demons go to GY only on death — not on summon.
	else:
		_resolve_spell(card, true)
		player_gy.append(card)
	if _mode != Mode.CHOOSE_ENEMY_TARGET:
		_mode = Mode.IDLE
	_pay_card_id = ""
	_pay_cost = 0
	_log("Played %s." % str(card.get("name", "?")))
	_pay_stack_t = 0.0
	_pay_stack_use_drop_anchor = false
	_view.queue_redraw()
	_check_game_over()


func _begin_pay_mana(card: Dictionary, _hand_idx: int, to_front: bool, drop_pos: Vector2 = Vector2(-1.0e9, -1.0e9)) -> void:
	_mode = Mode.CHOOSE_PAY_MANA
	_pay_from_arsenal = false
	_pay_card_id = str(card.get("id", ""))
	_pay_hand_idx = _hand_idx
	var base_cost: int = int(card.get("cost", 0))
	if "spell_cost_reduce_per_spell_gy" in str(card.get("ability", "")):
		var spell_count_gy: int = 0
		for c_gy in player_gy:
			if str(c_gy.get("type", "")) == "spell":
				spell_count_gy += 1
		base_cost = maxi(0, base_cost - spell_count_gy)
	_pay_cost = base_cost + (_spell_tax_against_caster(true) if str(card.get("type", "")) == "spell" else 0)
	_pay_to_front = to_front
	_pay_stack_t = 0.0
	_pay_arsenal_pitch_start = _pitched_this_turn.size()
	var rr0: Rect2 = CardBattleLayout.row_drop_rect(to_front)
	if rr0.has_point(drop_pos):
		_pay_stack_anchor = drop_pos
		_pay_stack_use_drop_anchor = true
	else:
		_pay_stack_use_drop_anchor = false
	_show_toast("Pitch until you can pay — Esc cancels")
	_log("Need %d mana — right-click hand cards to pitch, or Esc to cancel." % _pay_cost)
	_view.queue_redraw()


func _pay_stack_card() -> Dictionary:
	if _mode != Mode.CHOOSE_PAY_MANA or _pay_card_id.is_empty():
		return {}
	if _pay_from_arsenal:
		if player_arsenal.is_empty() or str(player_arsenal.get("id", "")) != _pay_card_id:
			return {}
		return player_arsenal
	var pix: int = _find_hand_idx_by_id(_pay_card_id)
	if pix < 0 or pix >= player_hand.size():
		return {}
	return player_hand[pix]


func _pay_stack_preview_rect() -> Rect2:
	var rr: Rect2 = CardBattleLayout.row_drop_rect(_pay_to_front)
	var cw: float = float(CardBattleConstants.MINI_W)
	var ch: float = float(CardBattleConstants.MINI_H)
	var cx: float
	var cy: float
	if _pay_stack_use_drop_anchor:
		cx = clampf(_pay_stack_anchor.x - cw * 0.5, rr.position.x, rr.position.x + rr.size.x - cw)
		cy = clampf(_pay_stack_anchor.y - ch * 0.5, rr.position.y, rr.position.y + rr.size.y - ch)
	else:
		cx = rr.position.x + (rr.size.x - cw) * 0.5
		cy = rr.position.y + (rr.size.y - ch) * 0.5
	return Rect2(cx, cy, cw, ch)


func _draw_pay_stack_vortex(center: Vector2) -> void:
	var t: float = _pay_stack_t
	var n: int = 14
	var i: int = 0
	while i < n:
		var ang: float = t * 2.8 + float(i) * TAU / float(n)
		var rad: float = 40.0 + float((i * 2) % 5)
		var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * rad
		var al: float = 0.35 + 0.4 * sin(t * 5.0 + float(i) * 0.7)
		_view.draw_circle(Vector2(float(_tx(p.x)), float(_tx(p.y))), 2.0,
			_opaque_rgb_fade(Color(0.42, 0.22, 0.78), al))
		i += 1
	i = 0
	while i < n:
		var ang2: float = -t * 2.2 + float(i) * TAU / float(n) + 0.4
		var rad2: float = 52.0 + float((i * 3) % 4)
		var p2: Vector2 = center + Vector2(cos(ang2), sin(ang2)) * rad2
		var al2: float = 0.22 + 0.38 * sin(t * 4.2 + float(i))
		_view.draw_circle(Vector2(float(_tx(p2.x)), float(_tx(p2.y))), 1.5,
			_opaque_rgb_fade(Color(0.55, 0.88, 1.0), al2))
		i += 1


func _draw_pay_stack_pending() -> void:
	var c: Dictionary = _pay_stack_card()
	if c.is_empty():
		return
	var r: Rect2 = _pay_stack_preview_rect()
	var ctr: Vector2 = r.get_center()
	_draw_pay_stack_vortex(ctr)
	_draw_hand_card(r, c, false, false)
	var ol: Rect2 = CardBattleLayout.selection_outline_rect(r)
	_view.draw_rect(ol, Color(0.72, 0.52, 0.98), false, 2.0)


func _chaos_count_selected_lineage(lineage: String) -> int:
	var n: int = 0
	for k in _chaos_selected:
		var ii: int = int(k)
		if ii < 0 or ii >= player_gy.size():
			continue
		if str(player_gy[ii].get("subtype", "")) == lineage:
			n += 1
	return n


func _chaos_summon_button_rect() -> Rect2:
	return Rect2(
		CardBattleConstants.MODAL_CHAOS_BTN_X,
		CardBattleConstants.MODAL_CHAOS_BTN_Y,
		CardBattleConstants.MODAL_CHAOS_BTN_W,
		CardBattleConstants.MODAL_CHAOS_BTN_H
	)


func _chaos_toggle_gy_index(i: int) -> void:
	if i < 0 or i >= player_gy.size():
		return
	var c: Dictionary = player_gy[i]
	if str(c.get("type", "")) != "demon":
		_log("Only demons can be banished for Chaos King.")
		return
	var st: String = str(c.get("subtype", ""))
	if _chaos_selected.get(i, false):
		_chaos_selected.erase(i)
		_view.queue_redraw()
		return
	var nr: int = _chaos_count_selected_lineage("regalia")
	var no: int = _chaos_count_selected_lineage("obscura")
	if st == "regalia" and nr < 3:
		_chaos_selected[i] = true
	elif st == "obscura" and no < 3:
		_chaos_selected[i] = true
	else:
		_log("Select up to 3 Regalia and 3 Obscura from your graveyard.")
	_view.queue_redraw()


func _handle_chaos_modal_click(pos: Vector2) -> bool:
	if not _modal_open or _modal_kind != "chaos_pick":
		return false
	if _chaos_summon_button_rect().has_point(pos):
		_complete_chaos_summon()
		return true
	# CLOSE (top-right)
	if pos.x >= 600.0 and pos.y <= 22.0:
		_cancel_chaos_summon()
		return true
	var hi: int = _modal_hover_index()
	if hi >= 0 and hi < player_gy.size():
		_chaos_toggle_gy_index(hi)
		return true
	return true


func _complete_chaos_summon() -> void:
	if _chaos_count_selected_lineage("regalia") != 3 or _chaos_count_selected_lineage("obscura") != 3:
		_log("Select exactly 3 Regalia and 3 Obscura.")
		return
	var chao: Dictionary = {}
	if _chaos_from_arsenal:
		if player_arsenal.is_empty():
			_cancel_chaos_summon()
			return
		chao = player_arsenal.duplicate(true)
	else:
		if _chaos_hand_idx < 0 or _chaos_hand_idx >= player_hand.size():
			_cancel_chaos_summon()
			return
		chao = player_hand[_chaos_hand_idx]
		if not _is_chaos_king_card(chao):
			_cancel_chaos_summon()
			return
	var idxs: Array[int] = []
	for k in _chaos_selected:
		if _chaos_selected[k]:
			idxs.append(int(k))
	idxs.sort()
	idxs.reverse()
	for ii in idxs:
		if ii >= 0 and ii < player_gy.size():
			player_gy.remove_at(ii)
	if _chaos_from_arsenal:
		player_arsenal = {}
	else:
		var hix: int = _find_hand_idx_by_id(str(chao.get("id", "")))
		if hix >= 0:
			player_hand.remove_at(hix)
	_modal_open = false
	_modal_kind = ""
	_modal_cards.clear()
	_chaos_selected.clear()
	_chaos_hand_idx = -1
	_chaos_from_arsenal = false
	var pf_room: bool = player_front.size() < CardBattleConstants.MAX_ROW
	var pr_room: bool = player_rear.size() < CardBattleConstants.MAX_ROW
	if not pf_room and not pr_room:
		if player_hand.size() < CardBattleConstants.MAX_HAND:
			player_hand.insert(0, chao)
			_log("Board full — Chaos King returned to hand.")
		else:
			player_gy.append(chao)
			_log("Board full and hand full — Chaos King discarded.")
		_view.queue_redraw()
		return
	if _chaos_to_front and not pf_room and pr_room:
		_chaos_to_front = false
	elif not _chaos_to_front and not pr_room and pf_room:
		_chaos_to_front = true
	_summon(chao, true, _chaos_to_front)
	## Demon goes to GY only on death.
	_log("Chaos King Dragon enters the battlefield!")
	_view.queue_redraw()
	_check_game_over()


func _begin_chaos_summon_hand(hand_idx: int, to_front: bool) -> void:
	if hand_idx < 0 or hand_idx >= player_hand.size():
		return
	var card: Dictionary = player_hand[hand_idx]
	if not _is_chaos_king_card(card):
		return
	var row: Array = player_front if to_front else player_rear
	var other: Array = player_rear if to_front else player_front
	if row.size() >= CardBattleConstants.MAX_ROW and other.size() >= CardBattleConstants.MAX_ROW:
		_log("Board is full!")
		return
	_chaos_hand_idx = hand_idx
	_chaos_to_front = to_front
	_chaos_from_arsenal = false
	_chaos_selected.clear()
	_modal_kind = "chaos_pick"
	_modal_title = "Banish 3 Regalia + 3 Obscura"
	_modal_cards = player_gy.duplicate()
	_modal_open = true
	_show_toast("Select 6 cards, then SUMMON")
	_log("Banish 3 Regalia and 3 Obscura from your graveyard to summon Chaos King.")
	_view.queue_redraw()


func _begin_chaos_summon_arsenal() -> void:
	if player_arsenal.is_empty():
		return
	var card: Dictionary = player_arsenal
	if not _is_chaos_king_card(card):
		return
	if player_front.size() >= CardBattleConstants.MAX_ROW and player_rear.size() >= CardBattleConstants.MAX_ROW:
		_log("Board is full!")
		return
	_chaos_hand_idx = -1
	_chaos_to_front = player_front.size() < CardBattleConstants.MAX_ROW
	_chaos_from_arsenal = true
	_chaos_selected.clear()
	_modal_kind = "chaos_pick"
	_modal_title = "Banish 3 Regalia + 3 Obscura"
	_modal_cards = player_gy.duplicate()
	_modal_open = true
	_show_toast("Select 6 cards, then SUMMON")
	_log("Banish 3 Regalia and 3 Obscura from your graveyard to summon Chaos King.")
	_view.queue_redraw()


func _refresh_demon_keywords(d: Dictionary) -> void:
	var ab: String = str(d["data"].get("ability", ""))
	d["poisonous"]     = _kwrd(ab, "poisonous")
	d["lifesteal"]     = _kwrd(ab, "lifesteal")
	d["taunt"]         = _kwrd(ab, "taunt")
	d["unblockable"]   = _kwrd(ab, "unblockable")
	d["aerial"]        = _kwrd(ab, "aerial")
	d["rage"]          = _kwrd(ab, "rage")
	d["double_attack"] = _kwrd(ab, "double_attack")
	d["divine_active"] = _kwrd(ab, "divine_shield")


## Mimic totals, Blood Banner (+1 ATK to other front), Iron Sigil (+2 HP to other front), Warlord (other front haste).
func _refresh_mimic_minions_and_front_atk_auras() -> void:
	var tot: int = player_front.size() + player_rear.size() + enemy_front.size() + enemy_rear.size()
	for side in [true, false]:
		var pf: Array = player_front if side else enemy_front
		var pr: Array = player_rear if side else enemy_rear
		for d in pf:
			var abm: String = str(d["data"].get("ability", ""))
			if "mimic_board_count" in abm:
				d["atk_intrinsic"] = tot
				d["hp_intrinsic"] = tot
		for d in pr:
			var abm2: String = str(d["data"].get("ability", ""))
			if "mimic_board_count" in abm2:
				d["atk_intrinsic"] = tot
				d["hp_intrinsic"] = tot
		for i in range(pf.size()):
			var d: Dictionary = pf[i]
			var atk_b: int = 0
			for j in range(pf.size()):
				if i == j:
					continue
				if "aura_front_atk_1" in str(pf[j]["data"].get("ability", "")):
					atk_b += 1
			# Same as Komainu: Cultist aura applies from rear row too (Regalia often sits back).
			for j in range(pr.size()):
				if "aura_front_atk_1" in str(pr[j]["data"].get("ability", "")):
					atk_b += 1
			var hp_b: int = 0
			for j in range(pf.size()):
				if i == j:
					continue
				if "aura_front_hp_2" in str(pf[j]["data"].get("ability", "")):
					hp_b += 2
			# Also check rear row as aura source so Komainu buffs front regardless of placement.
			for j in range(pr.size()):
				if "aura_front_hp_2" in str(pr[j]["data"].get("ability", "")):
					hp_b += 2
			var old_hp_aura: int = int(d.get("hp_aura_bonus", 0))
			d["hp_aura_bonus"] = hp_b
			var hpin: int = int(d.get("hp_intrinsic", int(d["data"].get("hp", 1))))
			var max_hp: int = hpin + hp_b
			if hp_b != old_hp_aura:
				d["hp"] += hp_b - old_hp_aura
			d["hp"] = mini(int(d["hp"]), max_hp)
			# Only prevent death from aura removal; never override actual combat damage.
			if hp_b != old_hp_aura:
				d["hp"] = maxi(int(d["hp"]), 1)
			var rgs: int = int(d.get("rage_stacks", 0))
			var aintr: int = int(d.get("atk_intrinsic", int(d["data"].get("atk", 0))))
			d["atk"] = aintr + atk_b + rgs
			var warlord_haste: bool = false
			for j in range(pf.size()):
				if i == j:
					continue
				if "aura_front_haste" in str(pf[j]["data"].get("ability", "")):
					warlord_haste = true
					break
			if not warlord_haste:
				for j in range(pr.size()):
					if "aura_front_haste" in str(pr[j]["data"].get("ability", "")):
						warlord_haste = true
						break
			if warlord_haste and not d.get("frozen", false):
				var max_atk: int = 2 if d.get("double_attack", false) else 1
				if int(d.get("attacked", 0)) < max_atk:
					d["exhausted"] = false
		for d in pr:
			var rgs2: int = int(d.get("rage_stacks", 0))
			var aintr2: int = int(d.get("atk_intrinsic", int(d["data"].get("atk", 0))))
			d["atk"] = aintr2 + rgs2
	_view.queue_redraw()


func _process_global_death_triggers(dead: Dictionary, dead_owner_is_player: bool) -> void:
	# ── Dying creature sees its own death (like MTG last gasp) ──────────
	var dead_ab: String = str(dead["data"].get("ability", ""))
	var dead_name: String = str(dead["data"].get("name", "?"))
	var dead_who: String = "Your" if dead_owner_is_player else "Enemy"
	if "any_death_drain" in dead_ab:
		_log("%s %s drains from the grave!" % [dead_who, dead_name])
		if dead_owner_is_player: _deal_damage_to_enemy(1)
		else: _deal_damage_to_player(1)
	if "any_death_draw" in dead_ab and "any_death_draw_own_turn" not in dead_ab:
		_log("%s %s draws from the grave!" % [dead_who, dead_name])
		if dead_owner_is_player: _draw_one(player_hand, player_deck)
		else: _draw_one(enemy_hand, enemy_deck)
	if "ally_death_mana" in dead_ab:
		_log("%s %s: +1 mana on its own death!" % [dead_who, dead_name])
		if dead_owner_is_player: player_mana = mini(player_mana + 1, 10)
		else: enemy_mana = mini(enemy_mana + 1, 10)
	if "ally_death_lifegain" in dead_ab:
		_log("%s %s: +1 HP on its own death!" % [dead_who, dead_name])
		if dead_owner_is_player: _heal_player(1)
		else: enemy_hp = mini(enemy_hp + 1, CardBattleConstants.STARTING_HP)
	# ── Living creatures triggered by the death ───────────────────────
	for row in [player_front, player_rear]:
		for obs in row:
			if "any_death_drain" in str(obs["data"].get("ability", "")):
				_log("Your %s drains 1!" % obs["data"].get("name","?"))
				_deal_damage_to_enemy(1)
	for row in [enemy_front, enemy_rear]:
		for obs in row:
			if "any_death_drain" in str(obs["data"].get("ability", "")):
				_log("Enemy %s drains 1!" % obs["data"].get("name","?"))
				_deal_damage_to_player(1)
	for row in [player_front, player_rear, enemy_front, enemy_rear]:
		for obs in row:
			if "feed_on_death" in str(obs["data"].get("ability", "")):
				obs["atk_intrinsic"] = obs.get("atk_intrinsic", int(obs["data"].get("atk", 0))) + 1
				obs["hp_intrinsic"] = obs.get("hp_intrinsic", int(obs["data"].get("hp", 1))) + 1
				obs["hp"] = int(obs["hp"]) + 1
				_log("%s feeds on death! (+1/+1)" % obs["data"].get("name","?"))
	if dead_owner_is_player:
		for row in [player_front, player_rear]:
			for obs in row:
				if "ally_death_mana" in str(obs["data"].get("ability", "")):
					_log("Your %s gains +1 mana!" % obs["data"].get("name","?"))
					player_mana = mini(player_mana + 1, 10)
	else:
		for row in [enemy_front, enemy_rear]:
			for obs in row:
				if "ally_death_mana" in str(obs["data"].get("ability", "")):
					_log("Enemy %s gains +1 mana!" % obs["data"].get("name","?"))
					enemy_mana = mini(enemy_mana + 1, 10)
	for row in [player_front, player_rear]:
		for obs in row:
			var obs_ab: String = str(obs["data"].get("ability", ""))
			if "any_death_draw_own_turn" in obs_ab:
				if is_player_turn and not _soul_collector_drew_this_turn:
					_soul_collector_drew_this_turn = true
					_log("Your %s draws a card!" % obs["data"].get("name","?"))
					_draw_one(player_hand, player_deck)
			elif "any_death_draw" in obs_ab:
				_log("Your %s draws a card!" % obs["data"].get("name","?"))
				_draw_one(player_hand, player_deck)
	for row in [enemy_front, enemy_rear]:
		for obs in row:
			var obs_ab2: String = str(obs["data"].get("ability", ""))
			if "any_death_draw_own_turn" in obs_ab2:
				if not is_player_turn and not _enemy_soul_collector_drew_this_turn:
					_enemy_soul_collector_drew_this_turn = true
					_log("Enemy %s draws a card!" % obs["data"].get("name","?"))
					_draw_one(enemy_hand, enemy_deck)
			elif "any_death_draw" in obs_ab2:
				_log("Enemy %s draws a card!" % obs["data"].get("name","?"))
				_draw_one(enemy_hand, enemy_deck)
	if dead_owner_is_player:
		var nlg: int = 0
		for row in [player_front, player_rear]:
			for obs in row:
				if "ally_death_lifegain" in str(obs["data"].get("ability", "")):
					nlg += 1
		if nlg > 0:
			_log("Your lifegain creatures heal +%d!" % nlg)
			_heal_player(nlg)
	else:
		var nlg2: int = 0
		for row in [enemy_front, enemy_rear]:
			for obs in row:
				if "ally_death_lifegain" in str(obs["data"].get("ability", "")):
					nlg2 += 1
		if nlg2 > 0:
			_log("Enemy lifegain creatures heal +%d!" % nlg2)
			enemy_hp = mini(enemy_hp + nlg2, CardBattleConstants.STARTING_HP)


func _apply_after_spell_cast(is_player: bool) -> void:
	var pf: Array = player_front if is_player else enemy_front
	var pr: Array = player_rear if is_player else enemy_rear
	var of_: Array = enemy_front if is_player else player_front
	var or_: Array = enemy_rear if is_player else player_rear
	for row in [pf, pr]:
		for d in row:
			var ab: String = str(d["data"].get("ability", ""))
			if "spell_lifegain" in ab:
				if is_player:
					_heal_player(1)
				else:
					enemy_hp = mini(enemy_hp + 1, CardBattleConstants.STARTING_HP)
			if "spell_aoe" in ab:
				var aoe_name: String = d["data"].get("name", "?")
				_log("%s: spell triggers AOE — 1 damage to all enemies!" % aoe_name)
				for o in of_.duplicate():
					_hit_demon(o, 1, false)
				for o in or_.duplicate():
					_hit_demon(o, 1, false)
				_process_deaths(of_, not is_player, true)
				_process_deaths(or_, not is_player, false)


func _face_attack_followup(att: Dictionary, attacker_is_player: bool) -> void:
	var ab: String = str(att["data"].get("ability", ""))
	var aname: String = att["data"].get("name", "?")
	var who: String = "Your" if attacker_is_player else "Enemy"
	if "haste_face_draw" in ab:
		_log("%s %s draws after face attack!" % [who, aname])
		if attacker_is_player:
			_draw_one(player_hand, player_deck)
		else:
			_draw_one(enemy_hand, enemy_deck)
	if "haste_face_mana" in ab or "face_damage_mana" in ab:
		_log("%s %s gains +1 mana after face attack!" % [who, aname])
		if attacker_is_player:
			player_mana = mini(player_mana + 1, 10)
		else:
			enemy_mana = mini(enemy_mana + 1, 10)


const ALLY_TARGET_EFFECTS: Array[String] = ["buff_hp", "give_divine_shield", "buff_target_stats"]

const _EXPLOSION_EFFECTS: Array = ["destroy_all_both", "aoe_all_2", "aoe_all_hp"]
const _THUNDER_EFFECTS: Array = ["damage", "deal_face", "deal_and_gain_mana", "deal_face_drain",
	"face_per_graveyard", "aoe_enemy_and_face", "deal_face_if_low", "chaos_damage",
	"aoe_enemy", "aoe_demon_dmg"]

func _resolve_spell(card: Dictionary, is_player: bool) -> void:
	if is_player and str(card.get("effect", "")) in ALLY_TARGET_EFFECTS:
		var pf: Array = player_front
		var pr: Array = player_rear
		if not pf.is_empty() or not pr.is_empty():
			_begin_choose_ally_target(str(card.get("name", "Spell")), card)
			return
	var eff: String = str(card.get("effect", ""))
	if eff in _EXPLOSION_EFFECTS:
		Sound.play(preload("res://data/sfx/to use/Explosion.wav"))
	elif eff in _THUNDER_EFFECTS:
		Sound.play(preload("res://data/sfx/to use/Thunder.wav"))
	CardBattleSpellEffects.resolve(self, card, is_player)
	_apply_after_spell_cast(is_player)
	_refresh_mimic_minions_and_front_atk_auras()


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
	if type_bonus > 0:
		_log("%s has type advantage over %s (+%d dmg)!" % [att["data"].get("name","?"), def_["data"].get("name","?"), type_bonus])
	Sound.play(preload("res://data/sfx/to use/Gun.wav"))
	_spawn_float(CardBattleLayout.board_world_pos(_get_row(a_is_player, a_is_front), a_is_player, a_is_front, a_idx),      "-%d" % def_atk, CardBattleConstants.C_HP_RED)
	_spawn_float(CardBattleLayout.board_world_pos(_get_row(not a_is_player, d_is_front), not a_is_player, d_is_front, d_idx),  "-%d" % (att_atk + type_bonus), CardBattleConstants.C_HP_RED)
	var att_ab: String = str(att["data"].get("ability", ""))
	if _kwrd(att_ab, "on_attack_buff_2"):
		att["atk_intrinsic"] = att.get("atk_intrinsic", int(att["data"].get("atk", 0))) + 2
		_log("%s charges up: +2 ATK this turn!" % att["data"].get("name","?"))
	_hit_demon(def_, att_atk + type_bonus, att_poi)
	_hit_demon(att,  def_atk, def_poi)
	var def_died: bool = def_.get("hp", 1) <= 0
	if att.get("lifesteal", false) and att_atk > 0:
		if a_is_player: _heal_player(att_atk)
		else:           enemy_hp  = mini(enemy_hp  + att_atk, CardBattleConstants.STARTING_HP)
		_log("%s leeches %d HP!" % [att["data"].get("name","?"), att_atk])
	if _kwrd(att_ab, "on_kill_both_lose_life") and def_died:
		_deal_damage_to_player(1)
		_deal_damage_to_enemy(1)
		_log("%s venom: both players lose 1 life!" % att["data"].get("name","?"))
	_process_deaths(a_board, a_is_player,     a_is_front)
	_process_deaths(d_board, not a_is_player, d_is_front)


func _hit_demon(d: Dictionary, dmg: int, source_poi: bool) -> void:
	if dmg <= 0: return
	if d.get("divine_active", false):
		d["divine_active"] = false
		_log("%s's Divine Shield absorbs the hit!" % d["data"].get("name","?"))
		return
	if d.get("rage", false):
		d["rage_stacks"] = int(d.get("rage_stacks", 0)) + 1
		_log("%s rages! (+1 ATK)" % d["data"].get("name","?"))
	d["hp"] -= dmg
	if source_poi:
		_log("%s is poisoned!" % d["data"].get("name","?"))
		d["hp"] = 0


func _process_deaths(board: Array, is_player: bool, is_front: bool) -> void:
	for i in range(board.size() - 1, -1, -1):
		if board[i]["hp"] <= 0:
			var dead: Dictionary = board[i]
			_spawn_death_fx(CardBattleLayout.board_world_pos(_get_row(is_player, is_front), is_player, is_front, i))
			board.remove_at(i)
			_process_global_death_triggers(dead, is_player)
			_resolve_deathrattle(dead, is_player, is_front)
	_refresh_mimic_minions_and_front_atk_auras()
	_check_auto_lose_no_resources(is_player)
	_view.queue_redraw()


func _resolve_deathrattle(d: Dictionary, is_player: bool, is_front: bool) -> void:
	var ab: String = d["data"].get("ability", "")
	var dname: String = d["data"].get("name", "?")
	var who: String = "Your" if is_player else "Enemy"
	var gy := player_gy if is_player else enemy_gy
	gy.append(d["data"])
	if   "deathrattle_damage_2"     in ab:
		_log("%s %s's deathrattle: 2 face damage!" % [who, dname])
		if is_player: _deal_damage_to_enemy(2)
		else:         _deal_damage_to_player(2)
	elif "deathrattle_summon_zombie" in ab:
		_log("%s %s's deathrattle: summons a Zombie!" % [who, dname])
		_summon(CardDB.get_card("token_zombie"), is_player, is_front)
	elif "deathrattle_summon_ash_wraith" in ab:
		_log("%s %s's deathrattle: summons Ash Wraith!" % [who, dname])
		_summon(CardDB.get_card("token_ash_wraith"), is_player, is_front)
	elif "deathrattle_return_hand"   in ab:
		var hand := player_hand if is_player else enemy_hand
		if hand.size() < CardBattleConstants.MAX_HAND:
			_log("%s %s's deathrattle: returns to hand!" % [who, dname])
			gy.remove_at(gy.size() - 1)
			hand.append(d["data"])
		else:
			_log("%s %s's deathrattle fizzles (hand full)." % [who, dname])
	elif "deathrattle_buff_all"      in ab:
		_log("%s %s's deathrattle: buffs allies +1/+1!" % [who, dname])
		var pf := player_front if is_player else enemy_front
		var pr := player_rear  if is_player else enemy_rear
		for ally in pf:
			ally["atk_intrinsic"] = ally.get("atk_intrinsic", int(ally["data"].get("atk", 0))) + 1
			ally["hp_intrinsic"] = ally.get("hp_intrinsic", int(ally["data"].get("hp", 1))) + 1
			ally["hp"] += 1
		for ally in pr:
			ally["atk_intrinsic"] = ally.get("atk_intrinsic", int(ally["data"].get("atk", 0))) + 1
			ally["hp_intrinsic"] = ally.get("hp_intrinsic", int(ally["data"].get("hp", 1))) + 1
			ally["hp"] += 1
	elif "deathrattle_summon_2_imps" in ab:
		_log("%s %s's deathrattle: summons 2 Imps!" % [who, dname])
		_summon(CardDB.get_card("token_imp"), is_player, is_front)
		_summon(CardDB.get_card("token_imp"), is_player, is_front)
	elif "deathrattle_draw_1" in ab:
		var hand_dr := player_hand if is_player else enemy_hand
		var deck_dr := player_deck if is_player else enemy_deck
		_log("%s %s's deathrattle: draw 1!" % [who, dname])
		_draw_one(hand_dr, deck_dr)


func _heal_player(n: int) -> void:
	if n <= 0: return
	player_hp = mini(player_hp + n, Global.get_effective_max_hp())
	Sound.play(preload("res://data/sfx/to use/Drink.wav"))


func _deal_damage_to_player(n: int) -> void:
	player_hp -= n
	Sound.play(preload("res://data/sfx/Hurt.wav"))
	_spawn_float(Vector2(float(CardBattleConstants.LEFT_W) * 0.5, float(CardBattleConstants.PINFO_Y) + 10.0), "-%d" % n, CardBattleConstants.C_HP_RED)
	_log_colored("You take %d face damage!" % n, CardBattleConstants.C_HP_RED)
	_view.queue_redraw()
	_check_game_over()


func _deal_damage_to_enemy(n: int) -> void:
	Sound.play(preload("res://data/sfx/to use/Crunch.wav"))
	enemy_hp -= n
	_spawn_float(Vector2(float(CardBattleConstants.LEFT_W) * 0.5, float(CardBattleConstants.EINFO_H) * 0.5), "-%d" % n, CardBattleConstants.C_HP_RED)
	_log_colored("Enemy takes %d face damage!" % n, CardBattleConstants.C_HP_RED)
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
		Global.set_hp(player_hp)
		battle_ended.emit(true); return true
	if player_hp <= 0:
		_ended = true; _log("YOU LOSE!")
		_show_toast("YOU LOSE...")
		_view.queue_redraw()
		await get_tree().create_timer(2.5, true).timeout
		Global.set_hp(player_hp)
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


func ai_spell_tax_for_enemy() -> int:
	return _spell_tax_against_caster(false)


func ai_face_attack_followup(att: Dictionary) -> void:
	_face_attack_followup(att, false)


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


func ai_set_enemy_atk_preview(from_idx: int, tgt_type: String, tgt_idx: int) -> void:
	_enemy_atk_from_idx = from_idx
	_enemy_atk_target_type = tgt_type
	_enemy_atk_target_idx = tgt_idx
	_arrow_overlay.queue_redraw()


func ai_clear_enemy_atk_preview() -> void:
	_enemy_atk_from_idx = -1
	_enemy_atk_target_type = ""
	_enemy_atk_target_idx = -1
	_arrow_overlay.queue_redraw()


func ai_show_enemy_spell_preview(card: Dictionary) -> void:
	_enemy_spell_preview = card
	_enemy_spell_preview_t = 2.0
	_view.queue_redraw()


func ai_clear_enemy_spell_preview() -> void:
	_enemy_spell_preview = {}
	_enemy_spell_preview_t = 0.0
	_view.queue_redraw()


func ai_type_advantage(att_sub: String, def_sub: String) -> int:
	return _type_advantage(att_sub, def_sub)


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
				var fl: Array = _log_flat_lines()
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
				var fl2: Array = _log_flat_lines()
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
			var fl3: Array = _log_flat_lines()
			_log_scroll = mini(_log_scroll + 1, maxi(0, fl3.size() - CardBattleConstants.LOG_VISIBLE))
			_clamp_log_scroll()
			_view.queue_redraw()
			_view.accept_event()
		return

	# Modal: Figma — black panel x≥176; browse closes on click. Chaos pick handles its own hits.
	if mb.pressed and _modal_open and pos.x >= float(CardBattleConstants.BOARD_X):
		if _modal_kind == "chaos_pick":
			_handle_chaos_modal_click(pos)
			_view.queue_redraw()
			_view.accept_event()
			return
		_modal_open = false
		_modal_kind = ""
		_modal_cards.clear()
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
	if _mode == Mode.CHOOSE_ENEMY_TARGET:
		_finish_choose_enemy_target_idle()
		_log("Freeze cancelled.")
		_view.queue_redraw()
		return
	if _mode == Mode.CHOOSE_ALLY_TARGET:
		_finish_choose_ally_target_idle()
		_log("Target cancelled (spell fizzled).")
		_view.queue_redraw()
		return
	if not is_player_turn or _animating or _ended: return
	if _mode != Mode.CHOOSE_PAY_MANA: return
	for i in player_hand.size():
		if CardBattleLayout.hand_rect(i, player_hand.size()).has_point(pos):
			if i == _pay_hand_idx:
				_log("Pitch a different card — not the one you are casting.")
				_view.queue_redraw()
				return
			_pitch_card(i)
			_try_finish_pay_mana()
			_view.queue_redraw()
			return


func _on_left_press(pos: Vector2) -> void:
	if _ended: return
	# Modal open: left strip (x<176) stays interactive for hover/log; block board actions here
	if _modal_open and pos.x < float(CardBattleConstants.BOARD_X):
		return

	# Sidebar: grave / deck → modal (blocked while paying mana — finish pitching first)
	if _mode != Mode.CHOOSE_PAY_MANA and CardBattleLayout.side_grave_rect(true).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		_open_modal(enemy_gy, "Enemy Graveyard"); return
	if _mode != Mode.CHOOSE_PAY_MANA and CardBattleLayout.side_grave_rect(false).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		_open_modal(player_gy, "Your Graveyard"); return
	if _mode != Mode.CHOOSE_PAY_MANA and CardBattleLayout.side_deck_rect(true).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		var s := enemy_deck.duplicate(); s.shuffle(); _open_modal(s, "Enemy Deck (random)"); return
	if _mode != Mode.CHOOSE_PAY_MANA and CardBattleLayout.side_deck_rect(false).has_point(pos):
		_mode = Mode.IDLE; _sel_idx = -1; _ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
		var s := player_deck.duplicate(); s.shuffle(); _open_modal(s, "Your Deck (random)"); return

	if not is_player_turn or _animating: return

	# Targeting: ally buff spells — click friendly minion (elsewhere cancels)
	if _mode == Mode.CHOOSE_ALLY_TARGET:
		for i in player_front.size():
			if CardBattleLayout.mini_rect(player_front, CardBattleConstants.PFFRONT_Y, i).has_point(pos):
				_complete_choose_ally_target(player_front[i])
				return
		for i in player_rear.size():
			if CardBattleLayout.mini_rect(player_rear, CardBattleConstants.PFREAR_Y, i).has_point(pos):
				_complete_choose_ally_target(player_rear[i])
				return
		_log("Target cancelled (spell fizzled).")
		_finish_choose_ally_target_idle()
		_view.queue_redraw()
		return

	# Targeting: Frost Mage / Frost Bolt — click enemy minion (elsewhere cancels)
	if _mode == Mode.CHOOSE_ENEMY_TARGET:
		for i in enemy_front.size():
			if CardBattleLayout.mini_rect(enemy_front, CardBattleConstants.EFFRONT_Y, i).has_point(pos):
				_complete_choose_enemy_freeze(enemy_front[i])
				return
		for i in enemy_rear.size():
			if CardBattleLayout.mini_rect(enemy_rear, CardBattleConstants.EFREAR_Y, i).has_point(pos):
				_complete_choose_enemy_freeze(enemy_rear[i])
				return
		_log("Freeze cancelled.")
		_finish_choose_enemy_target_idle()
		_view.queue_redraw()
		return

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
		_cancel_choose_row()
		_ctx_idx = -1; _ctx_is_front = true; _atk_drag_idx = -1; _rear_pick_idx = -1
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
			if _mode == Mode.CHOOSE_PAY_MANA and i == _pay_hand_idx:
				_view.queue_redraw()
				return
			_ctx_idx = -1
			_ctx_is_front = true
			_atk_drag_idx = -1
			_rear_pick_idx = -1
			if _mode != Mode.CHOOSE_PAY_MANA:
				_mode = Mode.IDLE
			_sel_idx = -1
			_drag_active = true
			_drag_card = player_hand[i]
			_drag_hand_idx = i
			_drag_pos = pos
			_drag_start_pos = pos
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
	var card: Dictionary = _drag_card
	var hand_idx: int = _drag_hand_idx

	if not is_player_turn or _animating or _ended: _view.queue_redraw(); return
	if _mode == Mode.CHOOSE_ENEMY_TARGET or _mode == Mode.CHOOSE_ALLY_TARGET:
		_log("Choose a target first (or right-click to cancel).")
		_view.queue_redraw()
		return

	if _mode == Mode.CHOOSE_PAY_MANA:
		if CardBattleLayout.pinfo_rect().has_point(pos):
			if hand_idx >= 0 and hand_idx < player_hand.size():
				if hand_idx == _pay_hand_idx:
					_log("Pitch a different card to add mana.")
				else:
					_pitch_card(hand_idx)
					_try_finish_pay_mana()
			_view.queue_redraw()
			return
		var pfront: bool = CardBattleLayout.row_drop_rect(true).has_point(pos)
		var prear: bool = CardBattleLayout.row_drop_rect(false).has_point(pos)
		if pfront or prear:
			if hand_idx >= 0 and str(card.get("id", "")) == _pay_card_id and player_mana >= _pay_cost:
				_pay_to_front = pfront
				var rr_pf: Rect2 = CardBattleLayout.row_drop_rect(pfront)
				if rr_pf.has_point(pos):
					_pay_stack_anchor = pos
					_pay_stack_use_drop_anchor = true
				_try_finish_pay_mana()
		_view.queue_redraw()
		return

	if CardBattleLayout.pinfo_rect().has_point(pos):
		if _mode == Mode.CHOOSE_PAY_MANA and hand_idx >= 0 and hand_idx < player_hand.size():
			_pitch_card(hand_idx)
			_try_finish_pay_mana()
		_view.queue_redraw(); return

	if CardBattleLayout.player_arsenal_rect().has_point(pos):
		if hand_idx >= 0 and not _stashed_this_turn and player_arsenal.is_empty():
			await _on_stash(hand_idx)
		_view.queue_redraw(); return

	var on_front: bool = CardBattleLayout.row_drop_rect(true).has_point(pos)
	var on_rear: bool = CardBattleLayout.row_drop_rect(false).has_point(pos)
	if not on_front and not on_rear:
		if _mode == Mode.CHOOSE_ARSENAL and hand_idx >= 0 and hand_idx < player_hand.size() \
				and not _stashed_this_turn and player_arsenal.is_empty():
			if CardBattleLayout.hand_rect(hand_idx, player_hand.size()).has_point(pos):
				await _on_stash(hand_idx)
			_view.queue_redraw(); return
		# Short drag (click) on a hand card: enter CHOOSE_ROW like the arsenal flow.
		var is_click: bool = pos.distance_to(_drag_start_pos) <= CardBattleConstants.ATTACK_DRAG_THRESH
		if is_click and hand_idx >= 0 and hand_idx < player_hand.size() \
				and _mode != Mode.CHOOSE_PAY_MANA:
			var cc: Dictionary = card
			var cst_c: int = int(cc.get("cost", 0))
			var tax_c: int = _spell_tax_against_caster(true) if str(cc.get("type", "")) == "spell" else 0
			var total_c: int = cst_c + tax_c
			if total_c > player_mana:
				if cst_c <= 10:
					_begin_pay_mana(cc, hand_idx, true)
			elif str(cc.get("type", "")) == "demon":
				var ab_c: String = str(cc.get("ability", ""))
				if "taunt" in ab_c:
					player_hand.remove_at(hand_idx)
					player_mana -= total_c
					_summon(cc, true, true)
					_log("Played %s to front!" % cc.get("name", "?"))
					_view.queue_redraw(); _check_game_over(); return
				player_hand.remove_at(hand_idx)
				player_mana -= total_c
				_pending_card = cc
				_pending_hand_idx = -1
				_pending_hand_restore_idx = hand_idx
				_pending_skip_mana_on_place = true
				_choose_row_mana_refund = total_c
				_mode = Mode.CHOOSE_ROW
			else:
				player_hand.remove_at(hand_idx)
				player_mana -= total_c
				_resolve_spell(cc, true)
				player_gy.append(cc)
				_log("Cast %s!" % cc.get("name", "?"))
				_view.queue_redraw(); _check_game_over(); return
		_view.queue_redraw(); return

	var to_front: bool = on_front
	if not on_front and on_rear:
		to_front = false

	if str(card.get("type", "")) == "demon" and _is_chaos_king_card(card):
		if hand_idx < 0 or hand_idx >= player_hand.size():
			_view.queue_redraw(); return
		var abx: String = str(card.get("ability", ""))
		if not to_front and "taunt" in abx:
			_log("Taunt must go to front!")
			_view.queue_redraw(); return
		_begin_chaos_summon_hand(hand_idx, to_front)
		_view.queue_redraw(); return

	var cost: int = int(card.get("cost", 0))
	var spell_tax: int = _spell_tax_against_caster(true) if str(card.get("type", "")) == "spell" else 0
	var total_cost: int = cost + spell_tax
	if total_cost > player_mana:
		if cost > 10:
			_log("Cost exceeds max mana (10).")
			_view.queue_redraw(); return
		if str(card.get("type", "")) == "demon":
			var abz: String = str(card.get("ability", ""))
			if not to_front and "taunt" in abz:
				_log("Taunt must go to front!")
				_view.queue_redraw(); return
		if hand_idx < 0 or hand_idx >= player_hand.size():
			_view.queue_redraw(); return
		_begin_pay_mana(card, hand_idx, to_front, pos)
		_view.queue_redraw(); return

	if _mode == Mode.CHOOSE_ARSENAL:
		_pending_finish_after_arsenal = false
		_mode = Mode.IDLE
	if str(card.get("type", "")) == "demon":
		var abq: String = str(card.get("ability", ""))
		if not to_front and "taunt" in abq:
			_log("Taunt must go to front!")
			_view.queue_redraw(); return
		if hand_idx >= 0: player_hand.remove_at(hand_idx)
		player_mana -= total_cost
		_summon(card, true, to_front)
		## Demon goes to GY only on death.
		_log("Played %s to %s!" % [card.get("name", "?"), "front" if to_front else "rear"])
	else:
		if hand_idx >= 0: player_hand.remove_at(hand_idx)
		player_mana -= total_cost
		_resolve_spell(card, true)
		player_gy.append(card)
		_log("Cast %s!" % card.get("name", "?"))
	_view.queue_redraw(); _check_game_over()


func _on_left_release(pos: Vector2) -> void:
	if _ended or not is_player_turn or _animating:
		_atk_drag_idx = -1
		_rear_pick_idx = -1
		return
	if _mode == Mode.CHOOSE_ENEMY_TARGET or _mode == Mode.CHOOSE_ALLY_TARGET:
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
	player_mana = mini(player_mana + mv, 10)
	_pitched_this_turn.append(card); player_hand.remove_at(i)
	if _mode != Mode.CHOOSE_PAY_MANA:
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
	if not _pending_skip_mana_on_place:
		player_mana -= int(_pending_card.get("cost", 0))
	_pending_skip_mana_on_place = false
	_choose_row_mana_refund = 0
	if _pending_hand_idx >= 0 and _pending_hand_idx < player_hand.size():
		player_hand.remove_at(_pending_hand_idx)
	_summon(_pending_card, true, to_front)
	## Demon goes to GY only on death.
	_log("Played %s (%s)" % [_pending_card["name"], "front" if to_front else "rear"])
	_pending_card = {}; _pending_hand_idx = -1; _pending_hand_restore_idx = -1
	if _mode != Mode.CHOOSE_ENEMY_TARGET:
		_mode = Mode.IDLE
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
	if att.get("lifesteal", false): _heal_player(att["atk"])
	_face_attack_followup(att, true)
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
	if not att.get("unblockable", false) and not att.get("aerial", false):
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
	var card: Dictionary = player_arsenal
	if _is_chaos_king_card(card):
		_begin_chaos_summon_arsenal()
		_view.queue_redraw()
		return
	var cst: int = int(card.get("cost", 0))
	var taxa: int = _spell_tax_against_caster(true) if str(card.get("type", "")) == "spell" else 0
	var total_cst: int = cst + taxa
	if total_cst > player_mana:
		if cst > 10:
			_log("Cost exceeds max mana (10).")
			_view.queue_redraw(); return
		_mode = Mode.CHOOSE_PAY_MANA
		_pay_from_arsenal = true
		_pay_arsenal_pitch_start = _pitched_this_turn.size()
		_pay_card_id = str(card.get("id", ""))
		_pay_hand_idx = -1
		_pay_cost = total_cst
		_pay_to_front = true
		_pay_stack_t = 0.0
		_show_toast("Pitch until you can pay — Esc cancels")
		_log("Need %d mana — right-click hand cards to pitch, or Esc to cancel." % total_cst)
		_view.queue_redraw(); return
	player_arsenal = {}
	if str(card.get("type", "")) == "demon":
		var ab: String = str(card.get("ability", ""))
		if "taunt" in ab:
			player_mana -= total_cst
			_summon(card, true, true)
			## Demon goes to GY only on death.
			_log("Arsenal: %s to front!" % card.get("name", "?"))
			_view.queue_redraw(); _check_game_over()
		else:
			_pending_card = card
			_pending_hand_idx = -1
			_mode = Mode.CHOOSE_ROW
			_view.queue_redraw()
	else:
		player_mana -= total_cst
		_resolve_spell(card, true)
		player_gy.append(card)
		_log("Arsenal: %s!" % card.get("name", "?"))
		_view.queue_redraw(); _check_game_over()


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
	_modal_kind = ""
	_modal_open = true
	## Copy — never assign `player_gy` / `enemy_gy` by reference; `_modal_cards.clear()` would empty the real zone.
	_modal_cards = cards.duplicate()
	_modal_title = title
	_view.queue_redraw()


# ══════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════
func _kwrd(ability: String, keyword: String) -> bool: return keyword in ability

func _has_exhaust_activation(ability: String) -> bool:
	return ability.contains("exhaust_")

func _type_advantage(att_sub: String, def_sub: String) -> int:
	if CardBattleConstants.TYPE_ADV.get(att_sub, "") == def_sub:
		return CardBattleConstants.TYPE_ADV_DAMAGE_BONUS
	return 0
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
	var flat: Array = _log_flat_lines()
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


func _log_flat_lines() -> Array:
	var acc: Array = []
	for entry in _battle_log:
		var text: String = entry["text"] if entry is Dictionary else str(entry)
		var color: Color = entry["color"] if entry is Dictionary else CardBattleConstants.C_LOG_BODY
		for wl in _wrap_log_lines("_" + text, CardBattleConstants.LOG_TEXT_MAX_W, 8):
			acc.append({"text": wl, "color": color})
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
	if _mode == Mode.CHOOSE_PAY_MANA:
		_pay_stack_t += delta
		changed = true
	if _enemy_spell_preview_t > 0.0:
		_enemy_spell_preview_t = maxf(0.0, _enemy_spell_preview_t - delta)
		if _enemy_spell_preview_t <= 0.0:
			_enemy_spell_preview = {}
		changed = true
	if changed: _view.queue_redraw()
	# Drag past threshold on a front minion → attack aim (arrow); exhausted minions skip
	if _atk_drag_idx >= 0 and not _drag_active and is_player_turn and not _animating and not _ended \
			and _mode != Mode.CHOOSE_ROW and _mode != Mode.CHOOSE_ARSENAL and _mode != Mode.CHOOSE_ENEMY_TARGET \
			and _mode != Mode.CHOOSE_PAY_MANA:
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
	if _mode == Mode.CHOOSE_PAY_MANA:
		_draw_pay_stack_pending()
	_draw_right_sidebar()
	_draw_hand()
	_draw_chrome()
	if _enemy_spell_preview_t > 0.0 and not _enemy_spell_preview.is_empty():
		_draw_enemy_spell_preview()

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

	if _mode == Mode.CHOOSE_ENEMY_TARGET:
		var br := Rect2(float(CardBattleConstants.BOARD_X), float(CardBattleConstants.EFFRONT_Y) - 4.0,
			float(CardBattleConstants.BOARD_W), float(CardBattleConstants.EFREAR_Y) + CardBattleConstants.ROW_H - float(CardBattleConstants.EFFRONT_Y) + 8.0)
		_view.draw_rect(br, Color(0.25, 0.55, 1.0), false, 2.0)
	if _mode == Mode.CHOOSE_ALLY_TARGET:
		var ar := Rect2(float(CardBattleConstants.BOARD_X), float(CardBattleConstants.PFFRONT_Y) - 4.0,
			float(CardBattleConstants.BOARD_W), float(CardBattleConstants.PFREAR_Y) + CardBattleConstants.ROW_H - float(CardBattleConstants.PFFRONT_Y) + 8.0)
		_view.draw_rect(ar, Color(0.25, 0.88, 0.32), false, 2.0)

	if _toast_timer > 0.0: _draw_toast()
	if _modal_open:        _draw_modal()


func _paint_attack_arrow_overlay(ci: CanvasItem) -> void:
	# ── Player attack arrow (drag-to-attack mode) ──────────────────
	if not _ended and is_player_turn \
			and _mode == Mode.ATTACKING and _sel_idx >= 0 and _sel_idx < player_front.size() \
			and _atk_show_attack_arrow():
		var start: Vector2 = CardBattleLayout.board_world_pos(_get_row(true, true), true, true, _sel_idx)
		_draw_arrow_on(ci, start, _mouse_pos, CardBattleConstants.C_SEL)
		if not _hover_card.is_empty() and _hover_state.has("data"):
			var att_sub: String = player_front[_sel_idx]["data"].get("subtype", "")
			var def_sub: String = _hover_card.get("subtype", "")
			var bonus: int = _type_advantage(att_sub, def_sub)
			if bonus > 0:
				var mid: Vector2 = (start + _mouse_pos) * 0.5
				_str_c_on(ci, "Type Adv +%d dmg" % bonus, mid.x, mid.y - 10.0, 10, CardBattleConstants.C_HP_RED)

	# ── Enemy attack preview arrow ─────────────────────────────────
	if _ended or _enemy_atk_from_idx < 0 or _enemy_atk_from_idx >= enemy_front.size():
		return
	var e_start: Vector2 = CardBattleLayout.board_world_pos(enemy_front, false, true, _enemy_atk_from_idx)
	var e_end: Vector2
	match _enemy_atk_target_type:
		"face":
			e_end = Vector2(
				float(CardBattleConstants.LEFT_W) * 0.5,
				float(CardBattleConstants.PINFO_Y) + float(CardBattleConstants.PINFO_H) * 0.5)
		"front":
			if _enemy_atk_target_idx < 0 or _enemy_atk_target_idx >= player_front.size():
				return
			e_end = CardBattleLayout.board_world_pos(player_front, true, true, _enemy_atk_target_idx)
			# Highlight the targeted player card
			var tgt_r: Rect2 = CardBattleLayout.mini_rect(player_front, CardBattleConstants.PFFRONT_Y, _enemy_atk_target_idx)
			ci.draw_rect(tgt_r, CardBattleConstants.C_TURN_AI, false, 2.0)
		"rear":
			if _enemy_atk_target_idx < 0 or _enemy_atk_target_idx >= player_rear.size():
				return
			e_end = CardBattleLayout.board_world_pos(player_rear, true, false, _enemy_atk_target_idx)
			# Highlight the targeted player card
			var tgt_r2: Rect2 = CardBattleLayout.mini_rect(player_rear, CardBattleConstants.PFREAR_Y, _enemy_atk_target_idx)
			ci.draw_rect(tgt_r2, CardBattleConstants.C_TURN_AI, false, 2.0)
		_:
			return
	_draw_arrow_on(ci, e_start, e_end, CardBattleConstants.C_TURN_AI)
	# Type advantage label
	if _enemy_atk_target_type in ["front", "rear"]:
		var tgt_row: Array = player_front if _enemy_atk_target_type == "front" else player_rear
		if _enemy_atk_target_idx >= 0 and _enemy_atk_target_idx < tgt_row.size():
			var att_sub: String = enemy_front[_enemy_atk_from_idx]["data"].get("subtype", "")
			var def_sub: String = tgt_row[_enemy_atk_target_idx]["data"].get("subtype", "")
			var e_bonus: int = _type_advantage(att_sub, def_sub)
			if e_bonus > 0:
				var e_mid: Vector2 = (e_start + e_end) * 0.5
				_str_c_on(ci, "Type Adv +%d dmg" % e_bonus, e_mid.x, e_mid.y - 10.0, 10, CardBattleConstants.C_HP_RED)


func _draw_enemy_spell_preview() -> void:
	const CX: float = float(CardBattleConstants.BOARD_X) + float(CardBattleConstants.BOARD_W) * 0.5
	const CY: float = (float(CardBattleConstants.EFREAR_Y) + float(CardBattleConstants.BOARD_DIV_Y)) * 0.5
	var cx: float = CX - CardZoomDraw.ZOOM_W * 0.5
	var cy: float = CY - CardZoomDraw.ZOOM_H * 0.5
	_view.draw_rect(Rect2(float(CardBattleConstants.BOARD_X), 0.0,
		float(CardBattleConstants.BOARD_W), float(CardBattleConstants.BOARD_DIV_Y)),
		Color(0.0, 0.0, 0.0, 0.55))
	var r := Rect2(cx, cy, CardZoomDraw.ZOOM_W, CardZoomDraw.ZOOM_H)
	CardZoomDraw.draw(_view, _fnt(), r, _enemy_spell_preview, {})
	_str_c("ENEMY CASTS", CX, cy - 14.0, 8, Color(1.0, 0.85, 0.3))


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
	var flat: Array = _log_flat_lines()
	var total_lines: int = flat.size()
	var max_scroll: int = maxi(0, total_lines - CardBattleConstants.LOG_VISIBLE)
	var start: int = clampi(_log_scroll, 0, max_scroll)
	var vis_count: int = mini(CardBattleConstants.LOG_VISIBLE, total_lines - start)
	for i in vis_count:
		var y_line: float = float(CardBattleConstants.LOG_Y) + CardBattleConstants.LOG_BODY_Y0 + float(i) * float(CardBattleConstants.LOG_LINE_H)
		var flat_item: Dictionary = flat[start + i]
		_draw_log_line_at(flat_item["text"], y_line, 8, flat_item["color"])
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

	var ef_tgt: bool = _mode == Mode.ATTACKING or _mode == Mode.CHOOSE_ENEMY_TARGET
	for i in enemy_front.size():
		_draw_mini_card(CardBattleLayout.mini_rect(enemy_front, CardBattleConstants.EFFRONT_Y, i), enemy_front[i],
			ef_tgt, false)
	for i in enemy_rear.size():
		var _sel_aerial: bool = _mode == Mode.ATTACKING and _sel_idx >= 0 and _sel_idx < player_front.size() \
			and player_front[_sel_idx].get("aerial", false)
		var er_tgt: bool = (_mode == Mode.ATTACKING and (enemy_front.is_empty() or _sel_aerial)) or _mode == Mode.CHOOSE_ENEMY_TARGET
		_draw_mini_card(CardBattleLayout.mini_rect(enemy_rear, CardBattleConstants.EFREAR_Y, i), enemy_rear[i], er_tgt, false)
	var ally_pick: bool = _mode == Mode.CHOOSE_ALLY_TARGET
	for i in player_front.size():
		var sel: bool = (_ctx_idx == i and _ctx_is_front) or (_mode == Mode.ATTACKING and _sel_idx == i)
		_draw_mini_card(CardBattleLayout.mini_rect(player_front, CardBattleConstants.PFFRONT_Y, i), player_front[i], ally_pick, sel)
	for i in player_rear.size():
		var sel_rear: bool = _ctx_idx == i and not _ctx_is_front
		_draw_mini_card(CardBattleLayout.mini_rect(player_rear, CardBattleConstants.PFREAR_Y, i), player_rear[i], ally_pick, sel_rear)

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

	# Arrow + type-adv hint: drawn in `_draw_attack_arrow_overlay` last so they sit above all UI.

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
	var ars_vis: Dictionary = player_arsenal
	if _mode == Mode.CHOOSE_PAY_MANA and _pay_from_arsenal and not player_arsenal.is_empty():
		ars_vis = {}
	_draw_side_sec(0, "GRAVE",   enemy_gy.size(),    {})
	_draw_side_sec(1, "ARSENAL", -1,                 enemy_arsenal)
	_draw_side_sec(2, "DECK",    enemy_deck.size(),  {})
	_draw_side_sec(3, "DECK",    player_deck.size(), {})
	_draw_side_sec(4, "ARSENAL", -1,                 ars_vis)
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
	var drew_any: bool = false
	for i in player_hand.size():
		if _mode == Mode.CHOOSE_PAY_MANA and i == _pay_hand_idx:
			continue
		if _drag_active and _drag_hand_idx == i: continue
		drew_any = true
		var r    := CardBattleLayout.hand_rect(i, player_hand.size())
		var card: Dictionary = player_hand[i]
		var gray: bool = card.get("cost", 0) > player_mana or _is_chaos_king_card(card)
		_draw_hand_card(r, card, false, gray)
	if not drew_any and _mode == Mode.CHOOSE_PAY_MANA:
		_str_c("Pitch to pay", float(CardBattleConstants.HAND_ROW_PAD) + 12.0,
			float(CardBattleConstants.HAND_Y) + float(CardBattleConstants.HAND_CH) * 0.5 - 4.0, 8, CardBattleConstants.C_MUTED)


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

	var art_r := Rect2(r.position.x + 8.0, r.position.y + CardBattleConstants.MINI_ART_TOP, CardBattleConstants.MINI_ART_SIZE, CardBattleConstants.MINI_ART_SIZE)
	var _art_tex_mini: Texture2D = CardArt.card_art_1x(str(card.get("id", "")), d.get("foil", false))
	if _art_tex_mini != null:
		_view.draw_texture_rect(_art_tex_mini, art_r, false)

	if _mini_shows_effect_label(card) and _art_tex_mini == null:
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

	var art := Rect2(r.position.x + 8.0, r.position.y + CardBattleConstants.MINI_ART_TOP, CardBattleConstants.MINI_ART_SIZE, CardBattleConstants.MINI_ART_SIZE)
	var _art_hand: Texture2D = CardArt.card_art_1x(str(card.get("id", "")), card.get("foil", false))
	if _art_hand != null:
		_view.draw_texture_rect(_art_hand, art, false)

	if _mini_shows_effect_label(card) and _art_hand == null:
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
	var cr := Rect2(8.0, float(CardBattleConstants.ZOOM_Y), CardZoomDraw.ZOOM_W, CardZoomDraw.ZOOM_H)
	CardZoomDraw.draw(_view, _fnt(), cr, card, state)


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


func _draw_arrow_on(ci: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	if (to - from).length() < 10.0: return
	var norm := (to - from).normalized()
	var perp := Vector2(-norm.y, norm.x)
	ci.draw_line(from, to, color, 2.0)
	ci.draw_line(to, to - norm * 10.0 + perp * 5.0, color, 2.0)
	ci.draw_line(to, to - norm * 10.0 - perp * 5.0, color, 2.0)


func _draw_toast() -> void:
	if _toast_timer <= 0.0: return
	var toast_r := Rect2(float(CardBattleConstants.COMM_X), float(CardBattleConstants.COMM_Y),
		float(CardBattleConstants.COMM_W), float(CardBattleConstants.COMM_H))
	_view.draw_rect(toast_r, CardBattleConstants.C_GRAVE_BG)
	var pad: float = 4.0
	var max_w: float = maxf(8.0, toast_r.size.x - pad * 2.0)
	var fs: int = _fs(CardBattleConstants.COMM_FONT)
	var f: Font = _fnt()
	var lines: Array[String] = _wrap_log_lines(_toast_text, max_w, CardBattleConstants.COMM_FONT)
	var line_h: float = float(fs) + 2.0
	var cy: float = toast_r.position.y + pad + float(fs)
	var bottom: float = toast_r.position.y + toast_r.size.y - pad
	for line in lines:
		if cy > bottom:
			break
		_view.draw_string(f, Vector2(_tx(toast_r.position.x + pad), _tx(cy)), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CardBattleConstants.C_TEXT_LT)
		cy += line_h


func _draw_modal() -> void:
	var mx: float = float(CardBattleConstants.BOARD_X)
	var mw: float = float(CardBattleConstants.MODAL_PANEL_W)
	var mh: float = float(CardBattleConstants.H)
	_view.draw_rect(Rect2(mx, 0.0, mw, mh), CardBattleConstants.C_GRAVE_BG)
	var title: String = "%s - %d cards" % [_modal_title, _modal_cards.size()]
	_str(title, 183.0, 7.0, 10, CardBattleConstants.C_TEXT_LT)
	_str_r("CLOSE", 638.0, 6.0, 12, CardBattleConstants.C_TEXT_LT)
	if _modal_kind == "chaos_pick":
		var nr: int = _chaos_count_selected_lineage("regalia")
		var no: int = _chaos_count_selected_lineage("obscura")
		_str("R:%d/3  O:%d/3" % [nr, no], 320.0, 7.0, 9, CardBattleConstants.C_TEXT_LT)
		var sbr: Rect2 = _chaos_summon_button_rect()
		_view.draw_rect(sbr, Color(0.35, 0.55, 0.28), false, 2.0)
		_str_in_rect_center("SUMMON", sbr, 10, CardBattleConstants.C_TEXT_LT)
	var sx: float = CardBattleConstants.MODAL_GRID_X0
	var sy0: float = CardBattleConstants.MODAL_GRID_Y0
	for i in _modal_cards.size():
		var row: int = i / CardBattleConstants.MODAL_COLS
		var col: int = i % CardBattleConstants.MODAL_COLS
		var cy: float = sy0 + float(row) * CardBattleConstants.MODAL_ROW_H
		if cy + float(CardBattleConstants.HAND_CH) > mh:
			break
		var cr := Rect2(sx + float(col) * CardBattleConstants.MODAL_COL_W, cy, float(CardBattleConstants.HAND_CW), float(CardBattleConstants.HAND_CH))
		var sel: bool = _modal_kind == "chaos_pick" and _chaos_selected.get(i, false)
		_draw_hand_card(cr, _modal_cards[i], sel, false)


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
	_str_c_on(_view, text, cx, cy, sz, color)


func _str_c_on(ci: CanvasItem, text: String, cx: float, cy: float, sz: int = 9, color: Color = CardBattleConstants.C_TEXT) -> void:
	var f: Font = _fnt()
	var fs: int = _fs(sz)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(f, Vector2(_tx(cx - tw * 0.5), _tx(cy + float(fs) * 0.5)), text,
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
