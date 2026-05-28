extends Node

var unlocked_levels: Array = [1]
var best_times: Dictionary = {}
var best_stars: Dictionary = {}
var current_level: int = 1

const SAVE_PATH := "user://save.dat"

func _ready() -> void:
	_load()

func unlock_next(from_level: int) -> void:
	var next := from_level + 1
	if next not in unlocked_levels:
		unlocked_levels.append(next)
		_save()

func is_unlocked(level: int) -> bool:
	return level in unlocked_levels

func record_time(level: int, t: float) -> void:
	var key := str(level)
	if key not in best_times or t < best_times[key]:
		best_times[key] = t
		_save()

func best_time(level: int) -> float:
	return best_times.get(str(level), -1.0)

func record_stars(level: int, stars: int) -> void:
	var key := str(level)
	if key not in best_stars or stars > best_stars[key]:
		best_stars[key] = stars
		_save()

func get_best_stars(level: int) -> int:
	return int(best_stars.get(str(level), 0))

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"ul": unlocked_levels, "bt": best_times, "bs": best_stars}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		var ul = d.get("ul", [1])
		unlocked_levels = []
		for v in ul:
			unlocked_levels.append(int(v))
		best_times = d.get("bt", {})
		best_stars = d.get("bs", {})
