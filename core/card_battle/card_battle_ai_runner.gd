## Enemy AI: play phase, pitch, arsenal stash, attack phase. Calls public `CardBattle` `ai_*` facades only.
class_name CardBattleAIRunner
extends RefCounted

var b: CardBattle


func _init(p_battle: CardBattle) -> void:
	b = p_battle


func detect_ai_type_from_deck(deck: Array) -> String:
	var aggro: int = 0
	var ctrl: int = 0
	for card in deck:
		var cost: int = card.get("cost", 0)
		var ab: String = card.get("ability", "")
		if cost <= 2: aggro += 1
		if cost >= 4: ctrl += 1
		if "haste" in ab: aggro += 1
		if "battlecry_destroy" in ab or "battlecry_aoe" in ab: ctrl += 2
	if aggro > ctrl + 4: return "aggro"
	if ctrl > aggro + 3: return "control"
	return "midrange"


func play_phase() -> void:
	var safety: int = 0
	while safety < 60 and not b.ai_is_battle_ended():
		safety += 1
		if try_play_from_arsenal():
			b.ai_queue_redraw()
			await b.get_tree().create_timer(0.45, true).timeout
			if b.ai_is_battle_ended(): return
			if await b.ai_check_game_over_co(): return
			continue
		var best_i: int = pick_best_play_index()
		if best_i >= 0:
			var card: Dictionary = b.enemy_hand[best_i]
			var play_cost_h: int = int(card.get("cost", 0))
			if str(card.get("type", "")) == "spell":
				play_cost_h += b.ai_spell_tax_for_enemy()
			b.enemy_mana -= play_cost_h
			b.enemy_hand.remove_at(best_i)
			if card["type"] == "demon":
				var to_front: bool = enemy_summon_to_front(card)
				b.ai_enemy_summon(card, to_front)
				b.ai_log_line("Enemy plays %s!" % card["name"])
			else:
				b.ai_show_enemy_spell_preview(card)
				await b.get_tree().create_timer(2.0, true).timeout
				b.ai_clear_enemy_spell_preview()
				b.ai_enemy_resolve_spell(card)
				b.enemy_gy.append(card)
				b.ai_log_line("Enemy casts %s!" % card["name"])
			b.ai_queue_redraw()
			await b.get_tree().create_timer(0.45, true).timeout
			if b.ai_is_battle_ended(): return
			if await b.ai_check_game_over_co(): return
			continue
		if b.enemy_hand.is_empty(): break
		var pi: int = pick_pitch_index()
		if pi < 0: break
		b.ai_enemy_pitch_idx(pi)
		b.ai_queue_redraw()
		await b.get_tree().create_timer(0.28, true).timeout


func stash_arsenal_at_turn_end() -> void:
	if not b.enemy_arsenal.is_empty() or b.ai_enemy_stashed_this_turn() or b.enemy_hand.is_empty():
		return
	var si: int = pick_pitch_index()
	if si < 0: return
	var card: Dictionary = b.enemy_hand[si]
	b.enemy_hand.remove_at(si)
	b.enemy_arsenal = card
	b.ai_set_enemy_stashed(true)
	b.ai_log_line("Enemy stashes %s (Arsenal)" % card["name"])


func try_play_from_arsenal() -> bool:
	if b.enemy_arsenal.is_empty():
		return false
	var ac: Dictionary = b.enemy_arsenal
	if not is_enemy_card_playable(ac):
		return false
	var a_pri: int = play_priority(ac)
	var best_hand_pri: int = -999999
	for i in b.enemy_hand.size():
		var c: Dictionary = b.enemy_hand[i]
		if not is_enemy_card_playable(c):
			continue
		var p: int = play_priority(c)
		if p > best_hand_pri:
			best_hand_pri = p
	if a_pri < best_hand_pri:
		return false
	b.enemy_arsenal = {}
	var play_cost_a: int = int(ac.get("cost", 0))
	if str(ac.get("type", "")) == "spell":
		play_cost_a += b.ai_spell_tax_for_enemy()
	b.enemy_mana -= play_cost_a
	if ac["type"] == "demon":
		var to_front: bool = enemy_summon_to_front(ac)
		b.ai_enemy_summon(ac, to_front)
		b.ai_log_line("Enemy plays %s (Arsenal)!" % ac["name"])
	else:
		b.ai_enemy_resolve_spell(ac)
		b.enemy_gy.append(ac)
		b.ai_log_line("Enemy casts %s (Arsenal)!" % ac["name"])
	return true


func is_enemy_card_playable(card: Dictionary) -> bool:
	var cst: int = int(card.get("cost", 0))
	if str(card.get("type", "")) == "spell":
		cst += b.ai_spell_tax_for_enemy()
	if cst > b.enemy_mana:
		return false
	if card.get("type", "") == "demon":
		return b.enemy_front.size() < CardBattleConstants.MAX_ROW \
			or b.enemy_rear.size() < CardBattleConstants.MAX_ROW
	return true


func pick_best_play_index() -> int:
	var best_i: int = -1
	var best_pri: int = -999999
	for i in b.enemy_hand.size():
		var c: Dictionary = b.enemy_hand[i]
		if not is_enemy_card_playable(c):
			continue
		var pri: int = play_priority(c)
		if pri > best_pri:
			best_pri = pri
			best_i = i
	return best_i


func play_priority(card: Dictionary) -> int:
	var v: int = card_play_value(card)
	var co: int = maxi(1, card.get("cost", 0))
	var eff: int = int((float(v) * 240.0) / float(co))
	var pri: int = eff + v * 3
	var effect: String = card.get("effect", "")
	if effect in ["gain_mana", "mana_boost", "hp_to_mana", "mana_per_demon", "mana_per_graveyard", "deal_and_gain_mana"]:
		var need: int = 0
		for c in b.enemy_hand:
			var cc: int = c.get("cost", 0)
			if cc > b.enemy_mana:
				need = maxi(need, cc - b.enemy_mana)
		if need > 0:
			pri += 20 * mini(card.get("value", 0) + 1, 10)
	return pri


func card_play_value(card: Dictionary) -> int:
	if card.get("type", "") == "demon":
		return demon_play_value(card)
	return spell_play_value(card)


func demon_play_value(card: Dictionary) -> int:
	var atk: int = card.get("atk", 0)
	var hp: int = card.get("hp", 1)
	var ab: String = card.get("ability", "")
	var body: int = atk * 2 + hp * 2 + card.get("cost", 0)
	if "taunt" in ab: body += 6
	if "haste" in ab: body += 7
	if "divine_shield" in ab: body += 4
	if "lifesteal" in ab: body += 4
	if "poisonous" in ab: body += 4
	if "battlecry" in ab: body += 5
	if "deathrattle" in ab: body += 3
	if b.ai_keyword(ab, "unblockable"): body += 3
	if b.ai_keyword(ab, "double_attack"): body += 4
	match b.ai_get_ai_type():
		"aggro":
			body += atk * 2 + mini(hp, 5)
		"control":
			body += mini(hp, 8) * 2 + mini(atk, 4)
		_:
			body += atk + hp
	return body


func spell_play_value(card: Dictionary) -> int:
	var effect: String = card.get("effect", "")
	var val: int = card.get("value", 0)
	var pf: int = b.player_front.size()
	var pr: int = b.player_rear.size()
	var enemy_units: int = b.enemy_front.size() + b.enemy_rear.size()
	var player_units: int = pf + pr
	var base: int = 5
	match effect:
		"damage", "deal_face":
			base = 4 + val * 2
		"draw":
			base = 6 + val * 4
		"gain_mana", "mana_boost":
			base = 6 + val * 3
		"heal":
			base = 3 + val * 2 + (6 if b.enemy_hp < 8 else 0)
		"summon_imp":
			base = 8
		"buff_hp", "buff_target_stats":
			base = 5 + val * 3
		"buff_atk_all", "buff_all_stats":
			base = 6 + val * 3 * maxi(1, enemy_units)
		"aoe_enemy", "aoe_demon_dmg":
			base = 6 + val * 3 * maxi(1, player_units)
		"aoe_all_2", "aoe_all_hp":
			base = 5 + val * 4
		"aoe_enemy_and_face":
			base = 8 + val * 3
		"destroy":
			base = 16 + val * 2
		"debuff_atk", "debuff_atk_all", "destroy_low_atk", "destroy_damaged", "silence_demon", "transform_1_1":
			base = 10 + val * 2
		"deal_and_gain_mana":
			base = 4 + val * 4
		"deal_face_drain":
			base = 6 + val * 3 + (4 if b.enemy_hp < 10 else 0)
		"freeze_all_enemy", "freeze_one_demon":
			base = (12 + val * 2) if player_units > 0 else 3
		"steal_demon":
			base = 22
		"return_demon":
			base = 16
		"hp_to_mana":
			base = 5 + val * 3
			if b.enemy_hp <= 5:
				base -= 12
		"hp_for_draw":
			base = 4 + val * 2
			if b.enemy_hp <= 5:
				base -= 10
		"mana_per_demon":
			base = 4 + val * enemy_units
		"mana_per_graveyard":
			base = 4 + mini(val, b.enemy_gy.size()) * 2
		"face_per_graveyard":
			base = 4 + b.enemy_gy.size() * 2
		"life_per_demon":
			base = 4 + val * enemy_units
		"resurrect", "reanimate_top", "reanimate_demon":
			base = 14 + val * 2
		"resurrect_all":
			base = 12 + b.enemy_gy.size()
		"chaos_damage":
			base = 8 + val
		"deal_face_if_low":
			base = 6 + val
		"poison_all_enemy", "poison_one_enemy":
			base = 8 + player_units
		_:
			base = 6 + val * 2
	match b.ai_get_ai_type():
		"aggro":
			if effect in ["damage", "deal_face", "aoe_enemy", "aoe_demon_dmg", "destroy", "deal_and_gain_mana", "deal_face_drain", "aoe_enemy_and_face", "deal_face_if_low"]:
				base += 5
		"control":
			if effect in ["destroy", "freeze_all_enemy", "return_demon", "debuff_atk", "aoe_enemy", "silence_demon", "destroy_low_atk", "steal_demon"]:
				base += 6
	return base


## Prefer pitching cards that are least valuable to keep / already disposable.
func pick_pitch_index() -> int:
	if b.enemy_hand.is_empty(): return -1
	var best_i: int = 0
	var best_w: int = pitch_keep_weight(0)
	for i in range(1, b.enemy_hand.size()):
		var w: int = pitch_keep_weight(i)
		if w < best_w:
			best_w = w
			best_i = i
	return best_i


func pitch_keep_weight(i: int) -> int:
	var c: Dictionary = b.enemy_hand[i]
	var v: int = card_play_value(c)
	if is_enemy_card_playable(c):
		return v + 400
	var effect: String = c.get("effect", "")
	if effect == "draw" or effect == "gain_mana" or effect == "mana_boost":
		return v + 40
	return v


func enemy_summon_to_front(card: Dictionary) -> bool:
	var ab: String = card.get("ability", "")
	var pf: int = b.enemy_front.size()
	var pr: int = b.enemy_rear.size()
	if pf >= CardBattleConstants.MAX_ROW:
		return false
	if pr >= CardBattleConstants.MAX_ROW:
		return true
	if "taunt" in ab:
		return true
	match b.ai_get_ai_type():
		"control":
			if pf == 0:
				return true
			if pr == 0:
				return false
			if pf > pr:
				return false
			if pr > pf:
				return true
			return randf() < 0.35
		"aggro":
			if pf < pr:
				return true
			if pr < pf:
				return false
			return true
		_:
			if pf < pr:
				return true
			if pr < pf:
				return false
			return randf() < 0.55


func attack_phase() -> void:
	if b.enemy_front.is_empty() and not b.enemy_rear.is_empty():
		var mover: Dictionary = b.enemy_rear.pop_front()
		mover["exhausted"] = mover.get("frozen", false)
		b.enemy_front.append(mover)
		b.ai_log_line("Enemy advances %s!" % mover["data"]["name"])
		b.ai_queue_redraw()
		await b.get_tree().create_timer(0.3, true).timeout
		if b.ai_is_battle_ended(): return

	var attackers: Array = b.enemy_front.duplicate()
	for attacker in attackers:
		if b.ai_is_battle_ended(): return
		if not b.enemy_front.has(attacker): continue
		if attacker["exhausted"]: continue
		var a_idx: int = b.enemy_front.find(attacker)
		if a_idx < 0: continue
		attacker["attacked"] += 1
		var max_atk: int = 2 if attacker.get("double_attack", false) else 1
		attacker["exhausted"] = attacker["attacked"] >= max_atk
		await _do_attack_with_preview(a_idx)
		if await b.ai_check_game_over_co(): return
		await b.get_tree().create_timer(0.15, true).timeout

		if b.ai_is_battle_ended(): return
		if not attacker["exhausted"] and b.enemy_front.has(attacker):
			a_idx = b.enemy_front.find(attacker)
			if a_idx >= 0:
				attacker["attacked"] += 1
				attacker["exhausted"] = true
				await _do_attack_with_preview(a_idx)
				if await b.ai_check_game_over_co(): return
				await b.get_tree().create_timer(0.15, true).timeout
				if b.ai_is_battle_ended(): return


## Shows the attack arrow for ~0.45 s, then resolves the attack.
func _do_attack_with_preview(a_idx: int) -> void:
	if a_idx >= b.enemy_front.size(): return
	var tgt: Dictionary = pick_attack_target(a_idx)
	b.ai_set_enemy_atk_preview(a_idx, tgt.get("type", ""), tgt.get("idx", -1))
	b.ai_queue_redraw()
	await b.get_tree().create_timer(0.45, true).timeout
	b.ai_clear_enemy_atk_preview()
	do_attack(a_idx)
	b.ai_queue_redraw()


## Returns { type: "face"/"front"/"rear", idx: int } for the attack at `a_idx` without resolving it.
func pick_attack_target(a_idx: int) -> Dictionary:
	if a_idx >= b.enemy_front.size(): return {"type": "face", "idx": -1}
	var att: Dictionary = b.enemy_front[a_idx]
	if att.get("unblockable", false):
		return {"type": "face", "idx": -1}
	var taunt_idx: int = b.ai_find_taunt(b.player_front)
	if taunt_idx >= 0:
		return {"type": "front", "idx": taunt_idx}
	if not b.player_front.is_empty():
		return {"type": "front", "idx": pick_target(b.player_front)}
	if b.ai_get_ai_type() == "aggro" or b.player_rear.is_empty():
		return {"type": "face", "idx": -1}
	return {"type": "rear", "idx": pick_target(b.player_rear)}


func do_attack(a_idx: int) -> void:
	if a_idx >= b.enemy_front.size(): return
	var att: Dictionary = b.enemy_front[a_idx]
	var nm: String = att["data"]["name"]
	if att.get("unblockable", false):
		b.ai_deal_damage_to_player(att["atk"])
		if att.get("lifesteal", false):
			b.enemy_hp = mini(b.enemy_hp + att["atk"], CardBattleConstants.STARTING_HP)
		b.ai_face_attack_followup(att)
		b.ai_log_line("%s pierces face for %d!" % [nm, att["atk"]])
		return
	var taunt_idx: int = b.ai_find_taunt(b.player_front)
	if taunt_idx >= 0:
		b.ai_log_line("%s → taunt %s!" % [nm, b.player_front[taunt_idx]["data"]["name"]])
		b.ai_do_combat(b.enemy_front, a_idx, false, true, b.player_front, taunt_idx, true)
		return
	if not b.player_front.is_empty():
		var t: int = pick_target(b.player_front)
		b.ai_log_line("%s → %s!" % [nm, b.player_front[t]["data"]["name"]])
		b.ai_do_combat(b.enemy_front, a_idx, false, true, b.player_front, t, true)
		return
	if b.ai_get_ai_type() == "aggro" or b.player_rear.is_empty():
		b.ai_deal_damage_to_player(att["atk"])
		if att.get("lifesteal", false):
			b.enemy_hp = mini(b.enemy_hp + att["atk"], CardBattleConstants.STARTING_HP)
		b.ai_face_attack_followup(att)
		b.ai_log_line("%s attacks face for %d!" % [nm, att["atk"]])
	else:
		var t2: int = pick_target(b.player_rear)
		b.ai_log_line("%s → rear %s!" % [nm, b.player_rear[t2]["data"]["name"]])
		b.ai_do_combat(b.enemy_front, a_idx, false, true, b.player_rear, t2, false)


func pick_target(board: Array) -> int:
	if board.is_empty(): return -1
	match b.ai_get_ai_type():
		"aggro":
			return b.ai_find_weakest(board)
		"control":
			return b.ai_find_strongest(board)
		_:
			if not b.enemy_front.is_empty():
				var atk_pow: int = b.enemy_front[0]["atk"]
				for i in board.size():
					if board[i]["hp"] <= atk_pow:
						return i
			return b.ai_find_strongest(board)
