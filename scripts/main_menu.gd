extends Control

@onready var _stars: Node2D = $Stars
@onready var _play_btn = $Buttons/PlayBtn
@onready var _how_btn  = $Buttons/HowBtn
@onready var _settings_btn = $Buttons/SettingsBtn
@onready var _quit_btn = $Buttons/QuitBtn

const SETTINGS_SCENE := preload("res://scenes/Settings.tscn")

var _settings_ui: Node = null

func _ready() -> void:
	_play_btn.pressed.connect(_on_play)
	_how_btn.pressed.connect(_on_how_to_play)
	_settings_btn.pressed.connect(func(): _open_settings(false))
	_quit_btn.pressed.connect(func(): get_tree().quit())
	_gen_stars()

func _gen_stars() -> void:
	for i in range(60):
		var dot := ColorRect.new()
		var sz := randf_range(1.0, 2.5)
		dot.size = Vector2(sz, sz)
		dot.position = Vector2(randf() * 800, randf() * 600)
		dot.color = Color(1, 1, 1, randf_range(0.15, 0.45))
		_stars.add_child(dot)

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_how_to_play() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var info := Label.new()
	info.text = """HƯỚNG DẪN CHƠI

🎯 MỤC TIÊU
Cắt toàn bộ không gian phòng và tiêu diệt tất cả kẻ thù.

🕹️ CÁCH CHƠI
• Di chuyển bằng phím mũi tên (← → ↑ ↓)
• Đi vào ô xám → tạo đường cắt (màu đỏ)
• Quay lại vùng an toàn → hoàn thành cắt
• Kẻ thù bị bao vây trong vùng cắt → bị tiêu diệt

☠️ THI THUA
• Kẻ thù chạm vào bạn
• Kẻ thù chạm vào đường đang cắt

🎁 ITEMS
⭐ Bất tử 3s   ⚡ x2 tốc độ   ❄ Đóng băng tất cả

👾 KẺ THÙ
🔴 Đỏ - Phân thân theo đếm ngược
🟡 Vàng - Bắn đạn về phía bạn
🟢 Xanh - Phục hồi ô đã cắt

Nhấn CLICK để quay lại"""
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	info.set_anchor_and_offset(SIDE_LEFT,   0.5, -280)
	info.set_anchor_and_offset(SIDE_RIGHT,  0.5,  280)
	info.set_anchor_and_offset(SIDE_TOP,    0.5, -230)
	info.set_anchor_and_offset(SIDE_BOTTOM, 0.5,  230)
	overlay.add_child(info)

	overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)

func _open_settings(pause_game: bool) -> void:
	if _settings_ui and is_instance_valid(_settings_ui):
		return
	var menu := SETTINGS_SCENE.instantiate()
	menu.pause_game = pause_game
	add_child(menu)
	_settings_ui = menu
	menu.closed.connect(func(): _settings_ui = null)
