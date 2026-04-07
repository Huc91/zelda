## Spell `effect` match — mutates boards via `CardBattle` private helpers (same script access rules as before).
class_name CardBattleSpellEffects
extends RefCounted


static func resolve(b: CardBattle, card: Dictionary, is_player: bool) -> void:
	var effect: String = card.get("effect", "")
	var val: int = card.get("value", 0)
	var of_  : Array = b.enemy_front  if is_player else b.player_front
	var or_  : Array = b.enemy_rear   if is_player else b.player_rear
	var pf   : Array = b.player_front if is_player else b.enemy_front
	var pr   : Array = b.player_rear  if is_player else b.enemy_rear
	var own_hand: Array = b.player_hand if is_player else b.enemy_hand
	var own_deck: Array = b.player_deck if is_player else b.enemy_deck

	var gy_local: Array = b.player_gy if is_player else b.enemy_gy

	match effect:
		"damage", "deal_face":
			if is_player: b._deal_damage_to_enemy(val)
			else:         b._deal_damage_to_player(val)
		"heal":
			if is_player: b.player_hp = mini(b.player_hp + val, CardBattleConstants.STARTING_HP)
			else:         b.enemy_hp  = mini(b.enemy_hp  + val, CardBattleConstants.STARTING_HP)
		"draw":
			for _i in val: b._draw_one(own_hand, own_deck)
		"aoe_enemy", "aoe_demon_dmg":
			for dd in of_.duplicate(): b._hit_demon(dd, val, false)
			for dd in or_.duplicate(): b._hit_demon(dd, val, false)
			b._process_deaths(of_, not is_player, true)
			b._process_deaths(or_, not is_player, false)
		"mana_boost", "gain_mana":
			if is_player: b.player_mana = mini(b.player_mana + val, 10)
			else:         b.enemy_mana  = mini(b.enemy_mana  + val, 10)
		"summon_imp":
			b._summon(CardDB.get_card("token_imp"), is_player, true)
		"buff_atk_all", "buff_atk_all_turn":
			for dd in pf: dd["atk"] += val
			for dd in pr: dd["atk"] += val
		"destroy":
			var ti: int = b._find_weakest(of_)
			if ti >= 0:
				of_[ti]["hp"] = 0
				b._process_deaths(of_, not is_player, true)
			else:
				ti = b._find_weakest(or_)
				if ti >= 0:
					or_[ti]["hp"] = 0
					b._process_deaths(or_, not is_player, false)
		"debuff_atk":
			var ti2: int = b._find_strongest(of_)
			if ti2 >= 0:
				of_[ti2]["atk"] = maxi(0, of_[ti2]["atk"] - val)
			else:
				ti2 = b._find_strongest(or_)
				if ti2 >= 0:
					or_[ti2]["atk"] = maxi(0, or_[ti2]["atk"] - val)
		"life_per_demon":
			var gain: int = (pf.size() + pr.size()) * val
			if is_player: b.player_hp = mini(b.player_hp + gain, CardBattleConstants.STARTING_HP)
			else:         b.enemy_hp  = mini(b.enemy_hp  + gain, CardBattleConstants.STARTING_HP)
		"buff_hp":
			var pool: Array = []
			for dd in pf: pool.append(dd)
			for dd in pr: pool.append(dd)
			if pool.is_empty():
				b._check_auto_lose_no_resources(is_player)
				return
			var pick: Dictionary = pool[0]
			for dd in pool:
				if dd["hp"] < pick["hp"]: pick = dd
			pick["hp"] += val
		"buff_hp_all":
			for dd in pf: dd["hp"] += val
			for dd in pr: dd["hp"] += val
		"cure_all_friendly":
			for dd in pf: dd["hp"] += 1
			for dd in pr: dd["hp"] += 1
		"buff_all_stats":
			for dd in pf:
				dd["atk"] += val
				dd["hp"] += val
			for dd in pr:
				dd["atk"] += val
				dd["hp"] += val
		"buff_target_stats":
			if pf.is_empty() and pr.is_empty():
				b._check_auto_lose_no_resources(is_player)
				return
			var pool2: Array = []
			for dd in pf: pool2.append(dd)
			for dd in pr: pool2.append(dd)
			var best: Dictionary = pool2[0]
			for dd in pool2:
				if dd["atk"] > best["atk"]: best = dd
			best["atk"] += val
			best["hp"] += val
		"debuff_atk_all":
			for dd in of_: dd["atk"] = maxi(0, dd["atk"] - val)
			for dd in or_: dd["atk"] = maxi(0, dd["atk"] - val)
		"give_divine_shield":
			if not pf.is_empty(): pf[0]["divine_active"] = true
			elif not pr.is_empty(): pr[0]["divine_active"] = true
		"hp_to_mana":
			if is_player:
				b.player_hp -= val
				b.player_mana = mini(b.player_mana + val, 10)
			else:
				b.enemy_hp -= val
				b.enemy_mana = mini(b.enemy_mana + val, 10)
		"hp_for_draw":
			if is_player: b.player_hp -= val
			else:         b.enemy_hp  -= val
			for _i in val: b._draw_one(own_hand, own_deck)
		"mana_per_demon":
			var add_m: int = (pf.size() + pr.size()) * val
			if is_player: b.player_mana = mini(b.player_mana + add_m, 10)
			else:         b.enemy_mana  = mini(b.enemy_mana  + add_m, 10)
		"mana_per_graveyard":
			var add_g: int = mini(val, gy_local.size())
			if is_player: b.player_mana = mini(b.player_mana + add_g, 10)
			else:         b.enemy_mana  = mini(b.enemy_mana  + add_g, 10)
		"deal_and_gain_mana":
			if is_player:
				b._deal_damage_to_enemy(val)
				b.player_mana = mini(b.player_mana + val, 10)
			else:
				b._deal_damage_to_player(val)
				b.enemy_mana = mini(b.enemy_mana + val, 10)
		"deal_face_drain":
			if is_player:
				b._deal_damage_to_enemy(val)
				b.player_hp = mini(b.player_hp + val, CardBattleConstants.STARTING_HP)
			else:
				b._deal_damage_to_player(val)
				b.enemy_hp = mini(b.enemy_hp + val, CardBattleConstants.STARTING_HP)
		"face_per_graveyard":
			var amt: int = gy_local.size() * val
			if is_player: b._deal_damage_to_enemy(amt)
			else:         b._deal_damage_to_player(amt)
		"aoe_all_2", "aoe_all_hp":
			for row in [b.player_front, b.player_rear, b.enemy_front, b.enemy_rear]:
				for dd in row.duplicate(): b._hit_demon(dd, val, false)
			b._process_deaths(b.player_front, true, true)
			b._process_deaths(b.player_rear, true, false)
			b._process_deaths(b.enemy_front, false, true)
			b._process_deaths(b.enemy_rear, false, false)
		"aoe_enemy_and_face":
			for dd in of_.duplicate(): b._hit_demon(dd, val, false)
			for dd in or_.duplicate(): b._hit_demon(dd, val, false)
			b._process_deaths(of_, not is_player, true)
			b._process_deaths(or_, not is_player, false)
			if is_player: b._deal_damage_to_enemy(val)
			else:         b._deal_damage_to_player(val)
		"deal_face_if_low":
			if is_player:
				if b.enemy_hp <= val: b._deal_damage_to_enemy(val)
			else:
				if b.player_hp <= val: b._deal_damage_to_player(val)
		"chaos_damage":
			var r: int = randi_range(1, 8)
			if is_player: b._deal_damage_to_enemy(r)
			else:         b._deal_damage_to_player(r)
		"freeze_all_enemy":
			for dd in of_: b._apply_freeze(dd)
			for dd in or_: b._apply_freeze(dd)
		"freeze_one_demon":
			var all_e: Array = []
			for dd in of_: all_e.append(dd)
			for dd in or_: all_e.append(dd)
			if all_e.is_empty():
				b._check_auto_lose_no_resources(is_player)
				return
			if is_player:
				b._begin_choose_enemy_to_freeze(str(card.get("name", "Spell")))
				return
			var hi: Dictionary = all_e[0]
			for dd in all_e:
				if dd["atk"] > hi["atk"]: hi = dd
			b._apply_freeze(hi)
		"destroy_low_atk":
			for row in [of_, or_]:
				for dd in row.duplicate():
					if dd["atk"] <= val: dd["hp"] = 0
				var is_f: bool = (row == of_)
				b._process_deaths(row, not is_player, is_f)
		"destroy_damaged":
			for row in [of_, or_]:
				var is_f2: bool = (row == of_)
				for dd in row.duplicate():
					var max_hp: int = dd["data"].get("hp", dd["hp"])
					if dd["hp"] < max_hp: dd["hp"] = 0
				b._process_deaths(row, not is_player, is_f2)
		"silence_demon":
			var si: int = b._find_strongest(of_)
			var srow: Array = of_
			if si < 0:
				si = b._find_strongest(or_)
				srow = or_
			if si < 0:
				b._check_auto_lose_no_resources(is_player)
				return
			srow[si]["data"]["ability"] = ""
			b._refresh_demon_keywords(srow[si])
		"transform_1_1":
			var wi: int = b._find_weakest(of_)
			var wrow: Array = of_
			if wi < 0:
				wi = b._find_weakest(or_)
				wrow = or_
			if wi < 0:
				b._check_auto_lose_no_resources(is_player)
				return
			var vic: Dictionary = wrow[wi]
			vic["atk"] = 1
			vic["hp"] = 1
			vic["data"]["ability"] = ""
			b._refresh_demon_keywords(vic)
		"return_demon":
			var ri: int = b._find_strongest(of_)
			var rrow: Array = of_
			if ri < 0:
				ri = b._find_strongest(or_)
				rrow = or_
			if ri < 0:
				b._check_auto_lose_no_resources(is_player)
				return
			var bounced: Dictionary = rrow[ri]
			rrow.remove_at(ri)
			var card_back: Dictionary = bounced["data"].duplicate(true)
			if is_player:
				if b.enemy_hand.size() < CardBattleConstants.MAX_HAND:
					b.enemy_hand.append(card_back)
			else:
				if b.player_hand.size() < CardBattleConstants.MAX_HAND:
					b.player_hand.append(card_back)
		"steal_demon":
			var sti: int = b._find_weakest(of_)
			var srow2: Array = of_
			if sti < 0:
				sti = b._find_weakest(or_)
				srow2 = or_
			if sti < 0:
				b._check_auto_lose_no_resources(is_player)
				return
			var st_minion: Dictionary = srow2[sti]
			srow2.remove_at(sti)
			if is_player:
				if b.player_front.size() < CardBattleConstants.MAX_ROW: b.player_front.append(st_minion)
				elif b.player_rear.size() < CardBattleConstants.MAX_ROW: b.player_rear.append(st_minion)
			else:
				if b.enemy_front.size() < CardBattleConstants.MAX_ROW: b.enemy_front.append(st_minion)
				elif b.enemy_rear.size() < CardBattleConstants.MAX_ROW: b.enemy_rear.append(st_minion)
		"destroy_all_both":
			for dd in b.player_front: dd["hp"] = 0
			for dd in b.player_rear: dd["hp"] = 0
			for dd in b.enemy_front: dd["hp"] = 0
			for dd in b.enemy_rear: dd["hp"] = 0
			b._process_deaths(b.player_front, true, true)
			b._process_deaths(b.player_rear, true, false)
			b._process_deaths(b.enemy_front, false, true)
			b._process_deaths(b.enemy_rear, false, false)
		"resurrect":
			if gy_local.is_empty():
				b._check_auto_lose_no_resources(is_player)
				return
			var top: Dictionary = gy_local.pop_back()
			if own_hand.size() >= CardBattleConstants.MAX_HAND:
				gy_local.append(top)
				return
			own_hand.append(top)
		"resurrect_all":
			for i in range(gy_local.size() - 1, -1, -1):
				if own_hand.size() >= CardBattleConstants.MAX_HAND:
					break
				var rc: Dictionary = gy_local[i]
				if rc.get("type", "") == "demon":
					own_hand.append(rc)
					gy_local.remove_at(i)
		"reanimate_top", "reanimate_demon":
			var best_ii: int = -1
			var best_co: int = -1
			for i in gy_local.size():
				var gc: Dictionary = gy_local[i]
				if gc.get("type", "") != "demon": continue
				var co: int = gc.get("cost", 0)
				if co > best_co:
					best_co = co
					best_ii = i
			if best_ii < 0:
				b._check_auto_lose_no_resources(is_player)
				return
			var pulled: Dictionary = gy_local[best_ii]
			gy_local.remove_at(best_ii)
			b._summon(pulled, is_player, true)
		"poison_all_enemy":
			for dd in of_.duplicate(): b._hit_demon(dd, 1, false)
			for dd in or_.duplicate(): b._hit_demon(dd, 1, false)
			b._process_deaths(of_, not is_player, true)
			b._process_deaths(or_, not is_player, false)
		"poison_one_enemy":
			var pi: int = b._find_strongest(of_)
			var prow: Array = of_
			if pi < 0:
				pi = b._find_strongest(or_)
				prow = or_
			if pi >= 0:
				b._hit_demon(prow[pi], 1, false)
				b._process_deaths(prow, not is_player, prow == of_)
		"poison_face":
			if is_player: b._deal_damage_to_enemy(val)
			else:         b._deal_damage_to_player(val)
		"double_next_spell":
			b._log("Arcane Mastery — double cast not implemented here; no effect.")
	b._check_game_over()
	b._check_auto_lose_no_resources(is_player)
