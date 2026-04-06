## Pixel-perfect layout, palette, and shared battle tokens for CardBattle.
## https://www.figma.com/design/iRJDqyetz1RTxvQOd1a7mU/test?node-id=1-3
class_name CardBattleConstants

# ── Layout (640 × 576) ─────────────────────────────────────────────
const W: int        = 640
const H: int        = 576
const LEFT_W: int   = 176
const RAIL_LINE_X: int = 549
const SIDE_ZONE_X: int = 552
const RIGHT_W: int     = W - RAIL_LINE_X
const SIDE_ZONE_RW: int = W - SIDE_ZONE_X
const BOARD_X: int     = LEFT_W
const BOARD_W: int     = RAIL_LINE_X - BOARD_X
const SIDE_ZONE_W: int = 83
const SIDE_CARD_INSET: float = 2.0
const SIDE_CARD_W: float = 79.0

const EINFO_H: int  = 49
const LOG_Y: int    = 49
const LOG_X: int    = 8
const LOG_W: int    = 163
const LOG_H: int    = 113
const LINE_Y_LOG_ZOOM: int = 167
const LINE_Y_PINFO_HAND: int = 407
const ZOOM_Y: int   = 172
const ZOOM_H: int   = 241
const PINFO_Y: int  = 413
const PINFO_H: int  = 52
const HAND_Y: int   = 465
const HAND_H: int   = H - HAND_Y

const ROW_H: int       = 110
const EFREAR_Y: int    = 53
const EFFRONT_Y: int   = 173
const BOARD_DIV_Y: int = 288
const PFFRONT_Y: int   = 293
const PFREAR_Y: int    = 411

const MINI_W: int   = 79
const MINI_H: int   = 110
const MINI_GAP: int = 6
const MINI_ART_TOP: float  = 15.0
const MINI_ART_SIZE: float = 64.0
const HAND_CW: int  = 79
const HAND_CH: int  = 110
const HAND_COST_W: int = 20
const HAND_COST_H: int = 19
const HAND_ROW_PAD: float = 8.0
const MAX_ROW: int  = 4

const CTX_OUTLINE_W: float = 83
const CTX_OUTLINE_H: float = 114
const CTX_PAD: float       = 2.0
const CTX_BTN_W: float     = 51.0
const CTX_BTN_H: float     = 24.0
const CTX_BTN_GAP_Y: float = 2.0

const SIDE_BAND_Y: Array = [0.0, 57.0, 173.0, 293.0, 409.0, 524.0]
const SIDE_BAND_H: Array = [53.0, 110.0, 110.0, 110.0, 110.0, 52.0]

const STARTING_HP: int = 15
const LOW_LIFE_THRESHOLD: int = maxi(3, (STARTING_HP * 5) / 15)
const STARTING_HAND: int = 5
const FONT_MIN: int      = 8
const LOG_LINE_H: int    = 10
const LOG_VISIBLE: int   = 8
const TOAST_DUR: float   = 2.2
const TOAST_X: float = 151.0
const TOAST_W: float = 338.0
const TOAST_H: float = 110.0
## Drag hand / attack-aim requires this many pixels before drag or attack mode (slightly less sensitive).
const ATTACK_DRAG_THRESH: float = 12.0
## After player ends turn: show interstitial banner, then AI (see `fixes.md`).
const ENEMY_TURN_LEAD_SEC: float = 3.0
## Uniform mini / hand / zoom card outline (rarity no longer tints border).
const C_MINI_BORDER: Color = Color("#7F6F01")
## Field minion ATK/HP higher than printed stat.
const C_STAT_BUFF: Color = Color("#009944")

const EINFO_TEXT_X: float   = 8.0
const EINFO_LINE_1_Y: float = 2.0
const EINFO_LINE_2_Y: float = 14.0
const EINFO_LINE_3_Y: float = 30.0
const LOG_TITLE_X: float    = 13.0
const LOG_TITLE_Y: float    = 4.0
const LOG_BODY_X: float     = 13.0
const LOG_BODY_Y0: float    = 19.0
const LOG_SCROLL_X: float   = 162.0
const LOG_SCROLL_W: float   = 5.0
const LOG_TEXT_MAX_W: float = 145.0
const PINFO_TEXT_X: float   = 8.0
const PINFO_LINE_1_Y: float = 0.0
const PINFO_LINE_2_Y: float = 14.0
const PINFO_LINE_3_Y: float = 32.0
const TURN_CIRCLE_Y_OFF: float = -18.0
const MODAL_PANEL_W: int = W - BOARD_X
const MODAL_GRID_X0: float = 182.0
const MODAL_GRID_Y0: float = 30.0
const MODAL_COL_W: float   = 87.0
const MODAL_ROW_H: float   = 118.0
const MODAL_COLS: int      = 5

const TYPE_ADV: Dictionary = {
	"fire":  "beast",
	"beast": "dark",
	"dark":  "fire",
}

# ── Colours ───────────────────────────────────────────────────────
const C_BG: Color          = Color("#D9D9D9")
const C_LEFT_BG: Color     = Color("#D9D9D9")
const C_BOARD_BG: Color    = Color("#D9D9D9")
const C_EINFO_BG: Color    = Color("#D9D9D9")
const C_LOG_BG: Color      = Color("#C5FBE1")
const C_LOG_BORDER: Color  = Color("#3C1E15")
const C_ZOOM_BG: Color     = Color("#D9D9D9")
const C_PINFO_BG: Color    = Color("#D9D9D9")
const C_GRAVE_BG: Color    = Color("#000000")
const C_DECK_BG: Color     = Color("#513100")
const C_ARSENAL_BG: Color  = Color("#FFFFFF")
const C_SIDE_ARSENAL_BORDER: Color = Color("#787878")
const C_BLACK: Color       = Color("#000000")
const C_DIV: Color         = C_BLACK
const C_LINE_H: Color      = C_BLACK
const C_CHROME_V: Color    = C_BLACK
const C_SCROLL_TRACK: Color = Color("#FFFFFF")
const C_SCROLL_THUMB: Color = Color("#3C1E15")

const C_TEXT: Color        = C_BLACK
const C_TEXT_LT: Color     = Color("#FFFFFF")
const C_LOG_TITLE: Color   = Color("#6653CB")
const C_LOG_BODY: Color    = Color("#3C1E15")
const C_MUTED: Color       = Color("#404040")
const C_HP_RED: Color      = Color("#FF2060")
const C_SEL: Color         = Color("#00CC00")
const C_TARGET: Color      = Color("#FF4400")
const C_TURN_AI: Color     = Color("#DD2222")
const C_EXHAUST_TEXT: Color  = Color("#7C7C7C")
const C_EXHAUST_BADGE: Color = Color("#B8B8B8")
const C_END_TURN_DIM: Color       = Color("#5C3D2E")
const C_TEXT_ON_DARK_DIM: Color   = Color("#A0A0A0")
const C_TEXT_MUTED_SOLID: Color   = Color("#888888")
const C_ROW_DROP_FRONT: Color     = Color("#B8F0B8")
const C_ROW_DROP_REAR: Color      = Color("#B8D4F0")
const C_GRAYED_CARD_OVERLAY: Color = Color("#555555")
const C_BOARD_EMPTY_TEXT: Color    = Color("#8A8A8A")
const C_DEMON_BG: Color    = Color("#F4E4D9")
const C_CARD_MINI: Color   = Color("#FFFFFF")
const C_SPELL_BG: Color    = Color("#A1B467")

const RARITY_COL: Dictionary = {
	"common"   : Color("#7C7C7C"),
	"uncommon" : Color("#0257F7"),
	"rare"     : Color("#0257F7"),
	"mythic"   : Color("#6844FC"),
	"legendary": Color("#F83902"),
}

const C_DIRECT_ATTACK_ON: Color = Color("#6653CB")
const C_DIRECT_ATTACK_OFF: Color = Color("#90ADBB")
const C_DIRECT_ATTACK_OFF_TEXT: Color = Color("#56689D")
const C_END_TURN: Color      = Color("#8B4513")
const C_COST_BADGE: Color    = Color("#3C1E15")

const FONT_PATH_PRIMARY: String  = "res://assets/fonts/Nudge Orb.ttf"
const FONT_PATH_FALLBACK: String = "res://assets/fonts/PressStart2P-Regular.ttf"
