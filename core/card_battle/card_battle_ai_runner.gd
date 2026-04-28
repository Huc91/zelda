## Enemy AI: play phase, pitch, arsenal stash, attack phase. Calls public `CardBattle` `ai_*` facades only.
class_name CardBattleAIRunner
extends RefCounted

var b: CardBattle


func _init(p_battle: CardBattle) -> void:
	b = p_battle


func detect_ai_type_from_deck(deck: Array) -> String:
	var has_death_knell: int = 0
	var has_tidal_terror: bool = false
	var has_chaos_dragon: bool = false
	var aggro: int = 0
	var ctrl: int = 0
	for card in deck:
		var id: String = card.get("id", "")
		if id == "demon_030": has_death_knell += 1
		if id == "demon_083": has_tidal_terror = true
		if id == "demon_044": has_chaos_dragon = true
		var cost: int = card.get("cost", 0)
		var ab: String = card.get("ability", "")
		if cost <= 2: aggro += 1
		if cost >= 4: ctrl += 1
		if "haste" in ab: aggro += 1
		if "battlecry_destroy" in ab or "battlecry_aoe" in ab: ctrl += 2
	if has_death_knell >= 2: return "death_ping"
	if has_tidal_terror: return "tidal_terror"
	if has_chaos_dragon: return "reanimator"
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
			var play_cost_h: int = _enemy_effective_cost(card)
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
		# Try pitching a pitcher demon for 2 mana if it enables a better play
		var pitcher_i: int = pick_pitcher_to_pitch_index()
		if pitcher_i >= 0:
			b.ai_enemy_pitch_idx(pitcher_i)   # already logs the pitch internally
			b.ai_queue_redraw()
			await b.get_tree().create_timer(0.28, true).timeout
			continue
		var pi: int = pick_pitch_index()
		if pi < 0: break
		b.ai_enemy_pitch_idx(pi)
		b.ai_queue_redraw()
		await b.get_tree().create_timer(0.28, true).timeout


## Index of the card to protect as arsenal stash candidate (-1 if none).
## Only considers cards that cannot be played this turn.
## Biases toward expensive cards (cost > 4) — they benefit most from being saved.
func _stash_candidate_index() -> int:
	if not b.enemy_arsenal.is_empty() or b.ai_enemy_stashed_this_turn() or b.enemy_hand.is_empty():
		return -1
	# Reanimator: always stash Final Hour if it's in hand (perfect arsenal card per strategy)
	if b.ai_get_ai_type() == "reanimator":
		for i in b.enemy_hand.size():
			if b.enemy_hand[i].get("effect", "") == "final_hour":
				return i
	var best_i: int = -1
	var best_val: int = -1
	for i in b.enemy_hand.size():
		var c: Dictionary = b.enemy_hand[i]
		if is_enemy_card_playable(c): continue
		var v: int = card_play_value(c)
		var cost: int = c.get("cost", 0)
		if cost > 4:
			v += (cost - 4) * 10
		if v > best_val:
			best_val = v
			best_i = i
	return best_i


func stash_arsenal_at_turn_end() -> void:
	var best_i: int = _stash_candidate_index()
	if best_i < 0: return
	var card: Dictionary = b.enemy_hand[best_i]
	b.enemy_hand.remove_at(best_i)
	b.enemy_arsenal = card
	b.ai_set_enemy_stashed(true)
	if Global.dev_mode:
		b.ai_log_line("Enemy stashes %s (Arsenal)" % card["name"])


func try_play_from_arsenal() -> bool:
	if b.enemy_arsenal.is_empty():
		return false
	var ac: Dictionary = b.enemy_arsenal
	if not is_enemy_card_playable(ac):
		return false
	var a_pri: int = play_priority(ac)
	# Play from arsenal if it's the best option OR if hand has nothing playable
	var best_hand_pri: int = -999999
	var hand_has_playable: bool = false
	for i in b.enemy_hand.size():
		var c: Dictionary = b.enemy_hand[i]
		if not is_enemy_card_playable(c):
			continue
		hand_has_playable = true
		var p: int = play_priority(c)
		if p > best_hand_pri:
			best_hand_pri = p
	# Play arsenal if: nothing in hand is playable, OR arsenal card is competitive
	if hand_has_playable and a_pri < best_hand_pri - 10:
		return false
	b.enemy_arsenal = {}
	var play_cost_a: int = _enemy_effective_cost(ac)
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


func _enemy_effective_cost(card: Dictionary) -> int:
	var cst: int = int(card.get("cost", 0))
	if "spell_cost_reduce_per_spell_gy" in str(card.get("ability", "")):
		var spell_count: int = 0
		for c: Dictionary in b.enemy_gy:
			if c.get("type", "") == "spell":
				spell_count += 1
		cst = maxi(0, cst - spell_count)
	return cst


func is_enemy_card_playable(card: Dictionary) -> bool:
	if "chaos_dragon" in str(card.get("ability", "")):
		var obscura: int = 0
		var regalia: int = 0
		for c: Dictionary in b.enemy_gy:
			var sub: String = c.get("subtype", "")
			if sub == "obscura": obscura += 1
			elif sub == "regalia": regalia += 1
		if obscura < 3 or regalia < 3:
			return false
	var cst: int = _enemy_effective_cost(card)
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
	# Prefer flooding the board with demons over most spells
	if card.get("type", "") == "demon":
		pri += 150
	var effect: String = card.get("effect", "")
	# Removal jumps ahead of demons when player has a threatening demon on board
	var removal_effects: Array[String] = ["destroy", "return_demon", "steal_demon",
		"destroy_low_atk", "destroy_damaged", "silence_demon", "aoe_enemy",
		"aoe_demon_dmg", "aoe_enemy_and_face", "freeze_all_enemy",
		"poison_all_enemy", "debuff_atk_all"]
	if effect in removal_effects:
		var best_threat: int = 0
		for row: Array in [b.player_front, b.player_rear]:
			for d: Dictionary in row:
				best_threat = maxi(best_threat, target_threat_score(d))
		if best_threat >= 10:
			pri += 350
	# Mana acceleration urgency — bump if it unlocks something in hand
	if effect in ["gain_mana", "mana_boost", "hp_to_mana", "mana_per_demon", "mana_per_graveyard", "deal_and_gain_mana"]:
		var need: int = 0
		for c: Dictionary in b.enemy_hand:
			var cc: int = c.get("cost", 0)
			if cc > b.enemy_mana:
				need = maxi(need, cc - b.enemy_mana)
		if need > 0:
			pri += 20 * mini(card.get("value", 0) + 1, 10)
	pri += _archetype_priority_bonus(card)
	return pri


func _archetype_priority_bonus(card: Dictionary) -> int:
	var bonus: int = 0
	var id: String = card.get("id", "")
	var ab: String = card.get("ability", "")
	var effect: String = card.get("effect", "")
	match b.ai_get_ai_type():
		"death_ping":
			# Cornerstone: rush Death Knell onto board — massive bonus if not already there
			if id == "demon_030":
				var already_has: bool = false
				for row: Array in [b.enemy_front, b.enemy_rear]:
					for d: Dictionary in row:
						if d.get("data", {}).get("id", "") == "demon_030":
							already_has = true
				if not already_has:
					bonus += 600
			# Cheap bodies — more deaths = more pings
			if card.get("type", "") == "demon" and card.get("cost", 0) <= 2:
				bonus += 120
			# Resurrection refuels the cheap body spam
			if effect == "resurrect":
				var has_fodder: bool = false
				for c: Dictionary in b.enemy_gy:
					if c.get("type", "") == "demon" and c.get("cost", 0) <= 3:
						has_fodder = true
				if has_fodder:
					bonus += 250
		"tidal_terror":
			# Spells build GY toward free Tidal Terror — always prioritize them
			if card.get("type", "") == "spell":
				bonus += 180
			# Tidal Terror: hold until nearly free (effective cost ≤ 2)
			if id == "demon_083":
				var spell_gy: int = 0
				for c: Dictionary in b.enemy_gy:
					if c.get("type", "") == "spell":
						spell_gy += 1
				var effective: int = maxi(0, 7 - spell_gy)
				if effective <= 2:
					bonus += 500
				else:
					bonus -= 999  # don't play until cheap
			# Pyromancer is high-value when we have spells to follow up
			if "spell_aoe" in ab:
				var spell_count: int = 0
				for c: Dictionary in b.enemy_hand:
					if c.get("type", "") == "spell":
						spell_count += 1
				bonus += spell_count * 60
		"reanimator":
			# Resurrection: huge bonus if GY has a strong demon
			if effect == "resurrect":
				var best_val: int = 0
				for c: Dictionary in b.enemy_gy:
					if c.get("type", "") == "demon":
						best_val = maxi(best_val, c.get("cost", 0) * 10 + c.get("atk", 0) + c.get("hp", 0))
				bonus += best_val * 8
			# Final Hour: huge bonus once GY has 3+ demons
			if effect == "final_hour":
				var demon_gy: int = 0
				for c: Dictionary in b.enemy_gy:
					if c.get("type", "") == "demon":
						demon_gy += 1
				if demon_gy >= 3:
					bonus += 400 + demon_gy * 30
				else:
					bonus -= 500  # wait for more demons in GY
			# Big demons should NOT be played — let them go to GY at turn end
			if card.get("type", "") == "demon" and card.get("cost", 0) >= 5:
				var reanimators_in_gy: int = 0
				for c: Dictionary in b.enemy_gy:
					if c.get("effect", "") in ["resurrect", "final_hour"]:
						reanimators_in_gy += 1
				if reanimators_in_gy == 0:
					bonus -= 300  # hold fat demons for GY unless we have no reanimate spells left
	return bonus


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
	if "haste" in ab: body += 9
	if "divine_shield" in ab: body += 4
	if "lifesteal" in ab: body += 4
	if "poisonous" in ab: body += 4
	if "battlecry" in ab: body += 5
	if "deathrattle" in ab: body += 3
	if b.ai_keyword(ab, "unblockable"): body += 3
	if b.ai_keyword(ab, "double_attack"): body += 4
	# Support passives have high board value even on low-stat bodies
	if "mana_per_turn" in ab: body += 14
	if "aura_front_atk" in ab or "aura_front_haste" in ab: body += 12
	if "aura_front_hp" in ab: body += 10
	if "ally_death_mana" in ab: body += 10
	if "ally_death_lifegain" in ab: body += 8
	if "any_death_draw" in ab: body += 10
	if "any_death_drain" in ab: body += 8
	if "feed_on_death" in ab: body += 8
	if "spell_cost_reduce" in ab or "tax_spells" in ab: body += 10
	if "face_damage_mana" in ab: body += 6
	if "spell_lifegain" in ab: body += 6
	if "mimic_board_count" in ab: body += 6
	match b.ai_get_ai_type():
		"aggro":
			body += atk * 2 + mini(hp, 5)
		"control":
			body += mini(hp, 8) * 2 + mini(atk, 4)
		_:
			body += atk + hp
	return body


func demon_is_support(card: Dictionary) -> bool:
	var ab: String = card.get("ability", "")
	for kw: String in ["mana_per_turn", "ally_death_mana", "ally_death_lifegain",
			"any_death_draw", "any_death_drain", "aura_front", "spell_lifegain",
			"spell_cost_reduce", "tax_spells", "feed_on_death", "face_damage_mana",
			"mimic_board_count", "pitcher", "dark_lotus", "draw_pings", "spell_aoe"]:
		if kw in ab:
			return true
	return false


func target_threat_score(demon: Dictionary) -> int:
	var data: Dictionary = demon.get("data", {})
	var ab: String = data.get("ability", "")
	var atk: int = demon.get("atk", 0)
	var hp: int = demon.get("hp", 1)
	var score: int = atk * 3 + hp
	if "mana_per_turn" in ab: score += 18
	if "aura_front" in ab: score += 14
	if "ally_death_mana" in ab or "ally_death_lifegain" in ab: score += 12
	if "any_death_draw" in ab or "any_death_drain" in ab: score += 10
	if "spell_cost_reduce" in ab or "tax_spells" in ab: score += 12
	if "feed_on_death" in ab: score += 8
	if "double_attack" in ab: score += 8
	if "lifesteal" in ab: score += 6
	if "divine_shield" in ab: score += 5
	return score


func is_bad_trade(attacker: Dictionary, target: Dictionary) -> bool:
	var t_data: Dictionary = target.get("data", {})
	var t_ab: String = t_data.get("ability", "")
	if "poisonous" in t_ab:
		var a_data: Dictionary = attacker.get("data", {})
		var a_ab: String = a_data.get("ability", "")
		if "divine_shield" not in a_ab:
			var a_val: int = attacker.get("atk", 0) * 2 + attacker.get("hp", 1) * 2 + int(a_data.get("cost", 0)) * 3
			var t_val: int = target.get("atk", 0) * 2 + target.get("hp", 1) * 2 + int(t_data.get("cost", 0)) * 3
			if a_val > t_val + 8:
				return true
	return false


func pick_best_target_for(attacker: Dictionary, board: Array) -> int:
	if board.is_empty(): return -1
	var best_i: int = 0
	var best_score: int = -99999
	var a_atk: int = attacker.get("atk", 0)
	for i in board.size():
		var tgt: Dictionary = board[i]
		var score: int = target_threat_score(tgt)
		if is_bad_trade(attacker, tgt):
			score -= 25
		if a_atk >= tgt.get("hp", 1):
			score += 8
		if score > best_score:
			best_score = score
			best_i = i
	return best_i


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
			base = 1 + val * 3
			if b.enemy_hp <= 5:
				base -= 12
		"hp_for_draw":
			base = 3 + val * 2
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
			base = 22 + b.enemy_gy.size()
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
## Protects the stash candidate from being pitched. Returns -1 if pitching
## no longer unlocks any card that can't be played with current mana.
func pick_pitch_index() -> int:
	if b.enemy_hand.is_empty(): return -1
	var stash_i: int = _stash_candidate_index()
	# Total mana from pitching all non-stash cards (used as ceiling per target check)
	var pool_mana: int = b.enemy_mana
	for i in b.enemy_hand.size():
		if i == stash_i: continue
		pool_mana += b.enemy_hand[i].get("mana_value", 1)
	# For each unplayable card: check if we can afford it by pitching OTHER non-stash cards.
	# Exclude the card's own mana_value from the pool to avoid circular "pitch-to-play-itself".
	var can_unlock: bool = false
	for i in b.enemy_hand.size():
		var c: Dictionary = b.enemy_hand[i]
		if is_enemy_card_playable(c): continue
		var cost: int = c.get("cost", 0)
		if str(c.get("type", "")) == "spell":
			cost += b.ai_spell_tax_for_enemy()
		var effective_pool: int = pool_mana
		if i != stash_i:
			effective_pool -= c.get("mana_value", 1)
		if cost > b.enemy_mana and cost <= effective_pool:
			can_unlock = true
			break
	# Also check if pitching would afford the arsenal card (which isn't in hand)
	if not can_unlock and not b.enemy_arsenal.is_empty():
		var ac: Dictionary = b.enemy_arsenal
		var ac_cost: int = ac.get("cost", 0)
		if str(ac.get("type", "")) == "spell":
			ac_cost += b.ai_spell_tax_for_enemy()
		var ac_pool: int = pool_mana
		if ac_cost > b.enemy_mana and ac_cost <= ac_pool:
			can_unlock = true
	if not can_unlock: return -1
	# Pitch the lowest-value non-stash card
	var best_i: int = -1
	var best_w: int = 999999
	for i in b.enemy_hand.size():
		if i == stash_i: continue
		var w: int = pitch_keep_weight(i)
		if w < best_w:
			best_w = w
			best_i = i
	return best_i


func pick_pitcher_to_pitch_index() -> int:
	var stash_i: int = _stash_candidate_index()
	for i in b.enemy_hand.size():
		if i == stash_i: continue
		var c: Dictionary = b.enemy_hand[i]
		if c.get("type", "") != "demon": continue
		if "pitcher" not in c.get("ability", ""): continue
		# Check if pitching this for 2 mana would enable a card we can't afford now
		var mana_after: int = b.enemy_mana + 2
		var pitcher_play_val: int = demon_play_value(c)
		for other in b.enemy_hand:
			if other == c: continue
			var cost: int = int(other.get("cost", 0))
			if str(other.get("type", "")) == "spell":
				cost += b.ai_spell_tax_for_enemy()
			if cost > b.enemy_mana and cost <= mana_after:
				var other_val: int = card_play_value(other)
				if other_val > pitcher_play_val + 4:
					return i
	return -1


func pitch_keep_weight(i: int) -> int:
	var c: Dictionary = b.enemy_hand[i]
	var v: int = card_play_value(c)
	if is_enemy_card_playable(c):
		return v + 400
	var effect: String = c.get("effect", "")
	if effect == "draw" or effect == "gain_mana" or effect == "mana_boost":
		return v + 40
	# Reanimator: never pitch fat demons — they need to reach GY via end-of-turn discard
	if b.ai_get_ai_type() == "reanimator" and c.get("type", "") == "demon" and c.get("cost", 0) >= 5:
		return v + 800
	return v


func enemy_summon_to_front(card: Dictionary) -> bool:
	var ab: String = card.get("ability", "")
	var pf: int = b.enemy_front.size()
	var pr: int = b.enemy_rear.size()
	if pf >= CardBattleConstants.MAX_ROW:
		return false
	# Support demons always go rear — even if rear is full they should never be in front
	# (is_enemy_card_playable already blocks play when both rows are full)
	if demon_is_support(card):
		return false
	if pr >= CardBattleConstants.MAX_ROW:
		return true
	if "taunt" in ab:
		return true
	# Glass cannon: high ATK, low HP — wants to attack before being removed
	var atk: int = card.get("atk", 0)
	var hp: int = card.get("hp", 1)
	if atk >= 4 and hp <= 3:
		return true
	if "haste" in ab or "unblockable" in ab or "double_attack" in ab or "rage" in ab:
		return true
	# Frontline demons always go front if space available
	return true


func attack_phase() -> void:
	if b.enemy_front.is_empty() and not b.enemy_rear.is_empty():
		# Prefer a real frontliner — only advance a support as a last resort to absorb hits
		var advance_i: int = -1
		for i in b.enemy_rear.size():
			var d: Dictionary = b.enemy_rear[i]
			if not demon_is_support(d.get("data", {})) and d.get("atk", 0) > 0:
				advance_i = i
				break
		if advance_i < 0:
			return  # no viable frontliner — protect support demons, skip attack
		var mover: Dictionary = b.enemy_rear[advance_i]
		b.enemy_rear.remove_at(advance_i)
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
		if attacker.get("atk", 0) == 0: continue
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

	var ai_type: String = b.ai_get_ai_type()

	# Must attack front row demons before going face — hard rule
	if not b.player_front.is_empty():
		# Poisonous attacker: seek highest-threat target
		var a_data: Dictionary = att.get("data", {})
		if "poisonous" in a_data.get("ability", ""):
			var best_i: int = 0
			var best_score: int = -999
			for i in b.player_front.size():
				var score: int = target_threat_score(b.player_front[i])
				if score > best_score:
					best_score = score
					best_i = i
			return {"type": "front", "idx": best_i}
		return {"type": "front", "idx": pick_best_target_for(att, b.player_front)}

	# Front is clear — can go face or hit rear
	if b.player_rear.is_empty() or ai_type == "aggro":
		return {"type": "face", "idx": -1}
	# Control/midrange: eliminate high-threat rear support before hitting face
	var rear_t: int = pick_best_target_for(att, b.player_rear)
	if target_threat_score(b.player_rear[rear_t]) >= 10:
		return {"type": "rear", "idx": rear_t}
	return {"type": "face", "idx": -1}


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
	var tgt: Dictionary = pick_attack_target(a_idx)
	# Hard rule: cannot hit face or rear while player has front row demons
	if tgt["type"] != "front" and not b.player_front.is_empty():
		tgt = {"type": "front", "idx": b.ai_find_strongest(b.player_front)}
	match tgt["type"]:
		"face":
			b.ai_deal_damage_to_player(att["atk"])
			if att.get("lifesteal", false):
				b.enemy_hp = mini(b.enemy_hp + att["atk"], CardBattleConstants.STARTING_HP)
			b.ai_face_attack_followup(att)
			b.ai_log_line("%s attacks face for %d!" % [nm, att["atk"]])
		"front":
			var t: int = tgt["idx"]
			if t < 0 or t >= b.player_front.size(): return
			b.ai_log_line("%s → %s!" % [nm, b.player_front[t]["data"]["name"]])
			b.ai_do_combat(b.enemy_front, a_idx, false, true, b.player_front, t, true)
		"rear":
			var t: int = tgt["idx"]
			if t < 0 or t >= b.player_rear.size(): return
			b.ai_log_line("%s → rear %s!" % [nm, b.player_rear[t]["data"]["name"]])
			b.ai_do_combat(b.enemy_front, a_idx, false, true, b.player_rear, t, false)


func pick_target(board: Array) -> int:
	if board.is_empty(): return -1
	match b.ai_get_ai_type():
		"aggro":
			return b.ai_find_weakest(board)
		_:
			# Control and midrange: prioritize by threat score
			var best_i: int = 0
			var best_score: int = -999
			for i in board.size():
				var score: int = target_threat_score(board[i])
				if score > best_score:
					best_score = score
					best_i = i
			return best_i
