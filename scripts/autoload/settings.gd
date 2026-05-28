extends Node

signal changed

const SAVE_PATH := "user://settings.json"

var sfx_volume: float = 0.8
var music_volume: float = 0.8
var muted: bool = false
var fullscreen: bool = false

func _ready() -> void:
	_load()
	_apply_all()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_save()
	emit_signal("changed")

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_save()
	emit_signal("changed")

func set_muted(v: bool) -> void:
	muted = v
	_apply_audio()
	_save()
	emit_signal("changed")

func set_fullscreen(v: bool) -> void:
	fullscreen = v
	_apply_display()
	_save()
	emit_signal("changed")

func get_sfx_db() -> float:
	return _to_db(sfx_volume)

func get_music_db() -> float:
	return _to_db(music_volume)

func _apply_all() -> void:
	_apply_audio()
	_apply_display()

func _apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, muted)

func _apply_display() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _to_db(v: float) -> float:
	return linear_to_db(maxf(v, 0.001))

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		return
	var data := {
		"sfx": sfx_volume,
		"music": music_volume,
		"muted": muted,
		"fullscreen": fullscreen,
	}
	f.store_string(JSON.stringify(data))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		sfx_volume = clampf(float(data.get("sfx", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(data.get("music", music_volume)), 0.0, 1.0)
		muted = bool(data.get("muted", muted))
		fullscreen = bool(data.get("fullscreen", fullscreen))
