## Append-only JSON Lines battle logs for offline analysis (player / AI actions + board snapshots).
## Primary path: **project folder** `res://battle_logs/` (same directory as `project.godot` — visible in the repo).
## Fallback if that is not writable: `user://battle_logs/` (OS app data).
##
## Toggle at runtime: Shift+F9 (see Global) or `BattleFileLogger.set_file_logging_enabled(false)`.
## Turning off mid-battle closes the current log with `t: logging_stopped` and stops further writes.
class_name BattleFileLogger
extends RefCounted

## When false, new battles do not open log files; use [method set_file_logging_enabled] to flip at runtime.
static var file_logging_enabled: bool = true
static var _active: Array[BattleFileLogger] = []

var _file: FileAccess
var battle_id: String = ""
## WeakRef(CardBattle) or null — untyped so we can clear to null.
var _owner_battle: Variant = null


static func set_file_logging_enabled(on: bool) -> void:
	file_logging_enabled = on
	if not on:
		for lg: BattleFileLogger in _active.duplicate():
			lg._abandon_for_shutdown()
		_active.clear()


func open_session(extra_meta: Dictionary, owner_battle: CardBattle = null) -> bool:
	if not file_logging_enabled:
		return false
	battle_id = "%d_%05d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var fname: String = "battle_%s.jsonl" % battle_id
	var path_res: String = "res://battle_logs/%s" % fname
	var path_abs: String = ""
	_file = null
	var project_root: String = ProjectSettings.globalize_path("res://")
	if not project_root.is_empty():
		var log_dir: String = "%s/battle_logs" % project_root.rstrip("/")
		DirAccess.make_dir_recursive_absolute(log_dir)
		path_abs = "%s/%s" % [log_dir, fname]
		_file = FileAccess.open(path_abs, FileAccess.WRITE)
	if _file == null:
		var user_dir: DirAccess = DirAccess.open("user://")
		if user_dir != null:
			user_dir.make_dir_recursive("battle_logs")
		path_res = "user://battle_logs/%s" % fname
		_file = FileAccess.open(path_res, FileAccess.WRITE)
		path_abs = ProjectSettings.globalize_path(path_res)
	if _file == null:
		push_warning("BattleFileLogger: could not open log (tried res://battle_logs/ then user://)")
		return false
	_owner_battle = weakref(owner_battle) if owner_battle != null else null
	_active.append(self)
	var start: Dictionary = extra_meta.duplicate(true)
	start["t"] = "battle_start"
	start["battle_id"] = battle_id
	start["ts_unix"] = Time.get_unix_time_from_system()
	start["log_path"] = path_res
	start["log_path_abs"] = path_abs
	_write_line(start)
	print("BattleFileLogger: writing ", path_abs)
	return true


func _write_line(obj: Dictionary) -> void:
	if _file == null:
		return
	var row: Dictionary = obj.duplicate(true)
	row["battle_id"] = battle_id
	if not row.has("ts_unix"):
		row["ts_unix"] = Time.get_unix_time_from_system()
	var line: String = JSON.stringify(row)
	_file.store_line(line)


func log_event(obj: Dictionary) -> void:
	_write_line(obj)


func close_session(outcome: String, final_snapshot: Dictionary) -> void:
	if _file == null:
		return
	_remove_from_active()
	var end_row: Dictionary = {
		"t": "battle_end",
		"outcome": outcome,
		"ts_unix": Time.get_unix_time_from_system(),
	}
	if not final_snapshot.is_empty():
		end_row["snapshot"] = final_snapshot
	_write_line(end_row)
	_file.close()
	_file = null
	_owner_battle = null


func _remove_from_active() -> void:
	var i: int = _active.find(self)
	if i >= 0:
		_active.remove_at(i)


func _abandon_for_shutdown() -> void:
	if _file == null:
		_remove_from_active()
		_owner_battle = null
		return
	_write_line({"t": "logging_stopped"})
	_file.close()
	_file = null
	_remove_from_active()
	var o: Variant = null
	if _owner_battle != null:
		o = (_owner_battle as WeakRef).get_ref()
	_owner_battle = null
	if o is CardBattle:
		(o as CardBattle)._detach_battle_file_logger()


static func minion_row(rows: Array) -> Array:
	var out: Array = []
	for d: Dictionary in rows:
		if not d.has("data"):
			continue
		var data: Dictionary = d["data"]
		out.append({
			"id": str(data.get("id", "")),
			"name": str(data.get("name", "")),
			"atk": int(d.get("atk", 0)),
			"hp": int(d.get("hp", 0)),
			"exhausted": bool(d.get("exhausted", false)),
			"frozen": bool(d.get("frozen", false)),
			"taunt": bool(d.get("taunt", false)),
			"aerial": bool(d.get("aerial", false)),
			"unblockable": bool(d.get("unblockable", false)),
		})
	return out


static func hand_card_ids(hand: Array) -> Array:
	var ids: Array = []
	for c: Variant in hand:
		if typeof(c) == TYPE_DICTIONARY:
			ids.append(str((c as Dictionary).get("id", "")))
	return ids


static func deck_card_ids(deck: Array) -> Array:
	return hand_card_ids(deck)


static func build_snapshot(b: CardBattle) -> Dictionary:
	return {
		"is_player_turn": b.is_player_turn,
		"player_turn_num": b.player_turn_num,
		"enemy_turn_num": b.enemy_turn_num,
		"player_hp": b.player_hp,
		"enemy_hp": b.enemy_hp,
		"player_mana": b.player_mana,
		"enemy_mana": b.enemy_mana,
		"hand_p": hand_card_ids(b.player_hand),
		"hand_e": hand_card_ids(b.enemy_hand),
		"deck_p": b.player_deck.size(),
		"deck_e": b.enemy_deck.size(),
		"gy_p": b.player_gy.size(),
		"gy_e": b.enemy_gy.size(),
		"pf": minion_row(b.player_front),
		"pr": minion_row(b.player_rear),
		"ef": minion_row(b.enemy_front),
		"er": minion_row(b.enemy_rear),
	}
