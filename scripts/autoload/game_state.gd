extends Node

var unlocked_levels: Array = [1]
var best_times: Dictionary = {}
var best_stars: Dictionary = {}
var current_level: int = 1
var tutorial_seen: bool = false
# Các hint tutorial theo tình huống đã hiện (mỗi hint chỉ hiện 1 lần duy nhất)
var hints_seen: Array = []

const SAVE_PATH := "user://save.dat"

func _ready() -> void:
	_load()
	_setup_mouse_cursor()

# Con trỏ chuột custom (cat paw) dùng cho toàn game. Ảnh gốc 16x16 được
# phóng 2x nearest cho dễ nhìn mà vẫn giữ nét pixel art.
func _setup_mouse_cursor() -> void:
	var arrow := _load_cursor("res://assets/ui/Mouse sprites/Catpaw Mouse icon.png")
	var hand := _load_cursor("res://assets/ui/Mouse sprites/Catpaw pointing Mouse icon.png")
	if arrow:
		Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW)
	if hand:
		Input.set_custom_mouse_cursor(hand, Input.CURSOR_POINTING_HAND)

func _load_cursor(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var img := tex.get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

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

func is_tutorial_seen() -> bool:
	return tutorial_seen

func mark_tutorial_seen() -> void:
	if not tutorial_seen:
		tutorial_seen = true
		_save()

# Xóa toàn bộ trạng thái tutorial (intro + hint) để tutorial hiện lại từ đầu
func reset_tutorial() -> void:
	tutorial_seen = false
	hints_seen = []
	_save()

func is_hint_seen(id: String) -> bool:
	return id in hints_seen

func mark_hint_seen(id: String) -> void:
	if id not in hints_seen:
		hints_seen.append(id)
		_save()

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"ul": unlocked_levels, "bt": best_times, "bs": best_stars, "tut": tutorial_seen, "hints": hints_seen}))

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
		tutorial_seen = bool(d.get("tut", false))
		hints_seen = d.get("hints", [])
