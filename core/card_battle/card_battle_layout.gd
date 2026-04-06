## Hit-testing and layout rects (Figma 640×576). Uses `CardBattleConstants` only — no battle state.
class_name CardBattleLayout
extends RefCounted


static func selection_outline_rect(card_r: Rect2) -> Rect2:
	return Rect2(card_r.position.x - CardBattleConstants.CTX_PAD, card_r.position.y - CardBattleConstants.CTX_PAD,
		float(CardBattleConstants.CTX_OUTLINE_W), float(CardBattleConstants.CTX_OUTLINE_H))


static func context_move_btn_rect(card_r: Rect2) -> Rect2:
	var x: float = card_r.position.x + card_r.size.x + 1.0
	return Rect2(x, card_r.position.y, CardBattleConstants.CTX_BTN_W, CardBattleConstants.CTX_BTN_H)


static func context_eff_btn_rect(card_r: Rect2) -> Rect2:
	var move_r: Rect2 = context_move_btn_rect(card_r)
	return Rect2(move_r.position.x, move_r.position.y + CardBattleConstants.CTX_BTN_H + CardBattleConstants.CTX_BTN_GAP_Y,
		CardBattleConstants.CTX_BTN_W, CardBattleConstants.CTX_BTN_H)


static func mini_rect(board: Array, board_y: int, i: int) -> Rect2:
	var count: int = board.size()
	var total: float = float(count * CardBattleConstants.MINI_W + maxi(count - 1, 0) * CardBattleConstants.MINI_GAP)
	var sx: float = float(CardBattleConstants.BOARD_X) + (float(CardBattleConstants.BOARD_W) - total) * 0.5
	return Rect2(sx + i * (CardBattleConstants.MINI_W + CardBattleConstants.MINI_GAP), float(board_y),
		CardBattleConstants.MINI_W, CardBattleConstants.MINI_H)


static func hand_rect(i: int, hand_count: int) -> Rect2:
	var count: int = hand_count
	var avail: float = float(CardBattleConstants.RAIL_LINE_X) - CardBattleConstants.HAND_ROW_PAD * 2.0
	var w: float = minf(CardBattleConstants.HAND_CW,
		(avail - CardBattleConstants.MINI_GAP * maxi(count - 1, 0)) / maxi(count, 1))
	var sx: float = CardBattleConstants.HAND_ROW_PAD
	return Rect2(sx + i * (w + CardBattleConstants.MINI_GAP), float(CardBattleConstants.HAND_Y), w,
		float(CardBattleConstants.HAND_CH))


static func row_drop_rect(is_front: bool) -> Rect2:
	var y: float = float(CardBattleConstants.PFFRONT_Y) if is_front else float(CardBattleConstants.PFREAR_Y)
	return Rect2(float(CardBattleConstants.BOARD_X), y, float(CardBattleConstants.BOARD_W), float(CardBattleConstants.ROW_H))


static func enemy_face_rect() -> Rect2:
	return Rect2(0.0, 0.0, float(CardBattleConstants.LEFT_W), float(CardBattleConstants.EINFO_H))


static func log_rect() -> Rect2:
	return Rect2(float(CardBattleConstants.LOG_X), float(CardBattleConstants.LOG_Y),
		float(CardBattleConstants.LOG_W), float(CardBattleConstants.LOG_H))


static func direct_attack_btn_rect() -> Rect2:
	var bw: float = 166.0
	var bh: float = 32.0
	var bx: float = float(CardBattleConstants.BOARD_X) + (float(CardBattleConstants.BOARD_W) - bw) * 0.5
	return Rect2(bx, 7.0, bw, bh)


static func pinfo_rect() -> Rect2:
	return Rect2(0.0, float(CardBattleConstants.PINFO_Y), float(CardBattleConstants.LEFT_W), float(CardBattleConstants.PINFO_H))


static func end_btn_rect() -> Rect2:
	return Rect2(96.0, 431.0, 78.0, 24.0)


static func side_grave_rect(is_enemy: bool) -> Rect2:
	var sec: int = 0 if is_enemy else 5
	return Rect2(float(CardBattleConstants.SIDE_ZONE_X), CardBattleConstants.SIDE_BAND_Y[sec],
		float(CardBattleConstants.SIDE_ZONE_RW), CardBattleConstants.SIDE_BAND_H[sec])


static func side_arsenal_rect(is_enemy: bool) -> Rect2:
	var sec: int = 1 if is_enemy else 4
	return Rect2(float(CardBattleConstants.SIDE_ZONE_X), CardBattleConstants.SIDE_BAND_Y[sec],
		float(CardBattleConstants.SIDE_ZONE_RW), CardBattleConstants.SIDE_BAND_H[sec])


static func side_deck_rect(is_enemy: bool) -> Rect2:
	var sec: int = 2 if is_enemy else 3
	return Rect2(float(CardBattleConstants.SIDE_ZONE_X), CardBattleConstants.SIDE_BAND_Y[sec],
		float(CardBattleConstants.SIDE_ZONE_RW), CardBattleConstants.SIDE_BAND_H[sec])


static func player_arsenal_rect() -> Rect2:
	return side_arsenal_rect(false)


## Center of mini `idx` on the given row (for float text / arrows).
static func board_world_pos(row: Array, is_player: bool, is_front: bool, idx: int) -> Vector2:
	var board_y: int = (CardBattleConstants.PFFRONT_Y if is_front else CardBattleConstants.PFREAR_Y) if is_player \
		else (CardBattleConstants.EFFRONT_Y if is_front else CardBattleConstants.EFREAR_Y)
	var count: int = row.size()
	var total: float = float(count * CardBattleConstants.MINI_W + maxi(count - 1, 0) * CardBattleConstants.MINI_GAP)
	var sx: float = float(CardBattleConstants.BOARD_X) + (float(CardBattleConstants.BOARD_W) - total) * 0.5
	return Vector2(sx + idx * (CardBattleConstants.MINI_W + CardBattleConstants.MINI_GAP)
		+ CardBattleConstants.MINI_W * 0.5, float(board_y) + CardBattleConstants.MINI_H * 0.5)
