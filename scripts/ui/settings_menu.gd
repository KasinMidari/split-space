extends Control

signal closed

@export var pause_game: bool = false

@onready var _sfx_slider: HSlider = $Card/Content/SfxRow/SfxSlider
@onready var _music_slider: HSlider = $Card/Content/MusicRow/MusicSlider
@onready var _mute_check: CheckBox = $Card/Content/MuteRow/MuteCheck
@onready var _fullscreen_check: CheckBox = $Card/Content/FullscreenRow/FullscreenCheck
@onready var _menu_btn: Button = $Card/Content/ButtonRow/MenuBtn
@onready var _back_btn: Button = $Card/Content/ButtonRow/BackBtn

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

var _previous_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_from_settings()
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_mute_check.toggled.connect(_on_mute_toggled)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_menu_btn.pressed.connect(_on_main_menu)
	_back_btn.pressed.connect(_close)
	# Ẩn nút MENU khi đang ở sẵn Main Menu (tránh nút thừa).
	var cur := get_tree().current_scene
	if cur and cur.scene_file_path == MAIN_MENU_SCENE:
		_menu_btn.visible = false
	if pause_game:
		_previous_paused = get_tree().paused
		get_tree().paused = true

func _exit_tree() -> void:
	if pause_game and get_tree():
		get_tree().paused = _previous_paused

func _sync_from_settings() -> void:
	var settings := get_node_or_null("/root/Settings") as Settings
	if not settings:
		return
	_sfx_slider.value = settings.sfx_volume * 100.0
	_music_slider.value = settings.music_volume * 100.0
	_mute_check.button_pressed = settings.muted
	_fullscreen_check.button_pressed = settings.fullscreen

func _on_sfx_changed(v: float) -> void:
	var settings := get_node_or_null("/root/Settings") as Settings
	if settings:
		settings.set_sfx_volume(v / 100.0)

func _on_music_changed(v: float) -> void:
	var settings := get_node_or_null("/root/Settings") as Settings
	if settings:
		settings.set_music_volume(v / 100.0)

func _on_mute_toggled(pressed: bool) -> void:
	var settings := get_node_or_null("/root/Settings") as Settings
	if settings:
		settings.set_muted(pressed)

func _on_fullscreen_toggled(pressed: bool) -> void:
	var settings := get_node_or_null("/root/Settings") as Settings
	if settings:
		settings.set_fullscreen(pressed)

func _on_main_menu() -> void:
	AudioManager.play_click()
	# Bỏ pause trước khi đổi scene, nếu không Main Menu sẽ bị đứng (đang paused).
	get_tree().paused = false
	emit_signal("closed")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _close() -> void:
	emit_signal("closed")
	queue_free()
