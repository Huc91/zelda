class_name InitiativeScreen extends CanvasLayer
const PixelFont = preload("res://core/ui/pixel_font.gd")

signal result_ready(player_goes_first: bool)

var DICE_NORMAL: Texture2D
var DICE_RESULT: Texture2D
const FRAME_W: int = 22
const FRAME_H_NORMAL: int = 22
const FRAME_H_RESULT: int = 24
const FONT_PATH: String = "res://assets/fonts/Nudge Orb.ttf"

var _p_first_attacker: bool = false
var _enemy_difficulty: String = "easy"
var _rolling: bool = true
var _roll_timer: float = 0.0
const ROLL_DURATION: float = 1.0
const SHOW_DURATION: float = 3.0
var _anim_frame: int = 1
var _result_player_roll: int = 0
var _result_enemy_roll: int = 0
var _result_player_bonus: int = 0
var _result_enemy_bonus: int = 0
var _result_luck: bool = false
var _player_goes_first: bool = true
var _show_timer: float = 0.0
var _done: bool = false
var _font: Font

class _View extends Control:
	var b: InitiativeScreen
	func _draw() -> void:
		b._on_draw()
	func _process(dt: float) -> void:
		b._tick(dt)

var _view: _View


func setup(p_first_attacker: bool, enemy: Node) -> void:
	_p_first_attacker = p_first_attacker
	if enemy != null and "difficulty" in enemy:
		_enemy_difficulty = str(enemy.difficulty)
	DICE_NORMAL = load("res://GUI_plugin/die/dice_full_normal.png") as Texture2D
	DICE_RESULT = load("res://GUI_plugin/die/dice_full_dragging.png") as Texture2D
	_font = PixelFont.nudge_orb()
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = _View.new()
	_view.b = self
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_view)
	_roll_timer = 0.0
	_rolling = true
	_anim_frame = 1


func _tick(dt: float) -> void:
	if _done:
		return
	if _rolling:
		_roll_timer += dt
		_anim_frame = 1 + (int(_roll_timer * 10.0) % 6)
		if _roll_timer >= ROLL_DURATION:
			_finish_roll()
		_view.queue_redraw()
	else:
		# Wait for Z / interact press to start the battle.
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("b"):
			_done = true
			result_ready.emit(_player_goes_first)
		_view.queue_redraw()


func _finish_roll() -> void:
	_rolling = false
	_result_player_roll = randi_range(1, 6)
	_result_enemy_roll = randi_range(1, 6)
	_result_player_bonus = 2 if _p_first_attacker else 0
	_result_enemy_bonus = 0 if _p_first_attacker else 2
	_result_player_bonus += Global.get_total_initiative_bonus()
	_result_luck = Global.roll_luck()
	if _result_luck:
		_result_player_bonus += 1
	var player_total: int = _result_player_roll + _result_player_bonus
	var enemy_total: int = _result_enemy_roll + _result_enemy_bonus
	if player_total == enemy_total:
		# Tie — reroll both dice until no longer tied.
		while player_total == enemy_total:
			_result_player_roll = randi_range(1, 6)
			_result_enemy_roll = randi_range(1, 6)
			player_total = _result_player_roll + _result_player_bonus
			enemy_total = _result_enemy_roll + _result_enemy_bonus
	_player_goes_first = player_total > enemy_total
	_show_timer = 0.0
	_anim_frame = _result_player_roll
	_view.queue_redraw()


func _on_draw() -> void:
	if _font == null:
		return
	var w: float = float(_view.size.x)
	var h: float = float(_view.size.y)
	var cx: float = w * 0.5
	var cy: float = h * 0.5

	# Background
	_view.draw_rect(Rect2(0, 0, int(w), int(h)), Color(0.05, 0.05, 0.1))

	# Battle type label
	var is_lethal: bool = _enemy_difficulty == "hard" or _enemy_difficulty == "boss"
	var battle_label: String = "LETHAL BATTLE" if is_lethal else "SKIRMISH BATTLE"
	var label_col: Color = Color(1.0, 0.2, 0.1) if is_lethal else Color(0.2, 0.8, 1.0)
	var lw: float = _font.get_string_size(battle_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_view.draw_string(_font, Vector2(int(cx - lw * 0.5), int(cy - 100.0)), battle_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_col)

	# Dice positions
	var die_scale: float = 3.0
	var die_w: int = int(float(FRAME_W) * die_scale)
	var die_h: int = int(float(FRAME_H_NORMAL) * die_scale)
	var player_die_x: int = int(cx) - die_w - 40
	var enemy_die_x: int = int(cx) + 40
	var die_y: int = int(cy) - die_h / 2

	if _rolling:
		_draw_die(_view, player_die_x, die_y, _anim_frame, DICE_NORMAL, FRAME_H_NORMAL, die_scale, Color(1, 1, 1))
		_draw_die(_view, enemy_die_x, die_y, _anim_frame, DICE_NORMAL, FRAME_H_NORMAL, die_scale, Color(1.0, 0.18, 0.18))
		_view.draw_string(_font, Vector2(int(cx) - 6, int(cy) + 4), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1))
	else:
		var rh: int = int(float(FRAME_H_RESULT) * die_scale)
		_draw_die(_view, player_die_x, int(cy) - rh / 2, _result_player_roll, DICE_RESULT, FRAME_H_RESULT, die_scale, Color(1, 1, 1))
		_draw_die(_view, enemy_die_x, int(cy) - rh / 2, _result_enemy_roll, DICE_RESULT, FRAME_H_RESULT, die_scale, Color(1.0, 0.18, 0.18))

		# Result text
		var result_str: String = "Player goes first!" if _player_goes_first else "Enemy goes first!"
		var rst_col: Color = Color(0.2, 1.0, 0.3) if _player_goes_first else Color(1.0, 0.3, 0.2)
		var rw: float = _font.get_string_size(result_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_view.draw_string(_font, Vector2(int(cx - rw * 0.5), int(cy) + 50), result_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, rst_col)

		# Press Z hint
		var press_str: String = "Press Z to start battle"
		var pw: float = _font.get_string_size(press_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_view.draw_string(_font, Vector2(int(cx - pw * 0.5), int(cy) + 100), press_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 1.0, 0.4))

		# Bonus breakdown
		var bonus_y: int = int(cy) + 66
		var soul_bonus: int = Global.get_total_initiative_bonus()
		if _result_player_bonus > 0:
			var attacker_part: int = 2 if _p_first_attacker else 0
			var parts: Array = []
			if attacker_part > 0:
				parts.append("+%d attacker" % attacker_part)
			if soul_bonus > 0:
				parts.append("+%d sword" % soul_bonus)
			if _result_luck:
				parts.append("+1 luck")
			var bonus_str: String = "You: %d  %s" % [_result_player_roll, "  ".join(parts)]
			var bw: float = _font.get_string_size(bonus_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			_view.draw_string(_font, Vector2(int(cx - bw * 0.5), bonus_y), bonus_str,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))
		elif _result_enemy_bonus > 0:
			var bonus_str: String = "Enemy: %d  +2 attacker" % _result_enemy_roll
			var bw: float = _font.get_string_size(bonus_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			_view.draw_string(_font, Vector2(int(cx - bw * 0.5), bonus_y), bonus_str,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))


func _draw_die(ctrl: Control, x: int, y: int, frame: int, tex: Texture2D, frame_h: int, scale: float, modulate: Color) -> void:
	var fw: int = int(float(FRAME_W) * scale)
	var fh: int = int(float(frame_h) * scale)
	var frame_idx: int = clampi(frame, 1, 6)
	var src: Rect2 = Rect2(frame_idx * FRAME_W, 0, FRAME_W, frame_h)
	ctrl.draw_texture_rect_region(tex, Rect2(x, y, fw, fh), src, modulate)
