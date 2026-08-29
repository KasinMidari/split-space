class_name TutorialOverlay
extends CanvasLayer

## Overlay tutorial dạng spotlight: màn tối khoét lỗ vào đối tượng đang giải
## thích, kèm text. Bấm phím / chạm để qua bước, nút Bỏ qua để thoát sớm.
## Chạy được khi get_tree().paused = true (process_mode = ALWAYS).

signal finished

const TEXT_MARGIN := 24.0   # khoảng cách tối thiểu tới mép màn hình
const PANEL_GAP := 6.0      # khoảng cách panel ↔ lỗ spotlight
# Box tutorial rộng tối đa bấy nhiêu phần màn hình (tính cả scale của panel)
const MAX_WIDTH_RATIO := 0.50

var _steps: Array = []
var _idx: int = -1
var _tween: Tween

@onready var _dim: ColorRect = $Root/Dim
@onready var _text: Label = $Root/TextPanel/Text
@onready var _panel: PanelContainer = $Root/TextPanel
@onready var _hint: Label = $Root/Hint
@onready var _skip: Button = $Root/SkipBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_skip.pressed.connect(_finish)

## steps: Array[Dictionary] với {target_rect: Rect2 (tọa độ màn hình), text: String}
func run(steps: Array) -> void:
	_steps = steps
	_idx = -1
	_next_step()

func _unhandled_input(event: InputEvent) -> void:
	# Chỉ Enter (kể cả Enter bàn phím số) mới qua bước tiếp theo
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		_next_step()

func _next_step() -> void:
	_idx += 1
	if _idx >= _steps.size():
		_finish()
		return
	var st: Dictionary = _steps[_idx]
	var r: Rect2 = (st.get("target_rect", Rect2()) as Rect2).grow(10.0)
	_text.text = str(st.get("text", ""))
	_hint.text = "Press Enter to continue (%d/%d)" % [_idx + 1, _steps.size()]
	_move_hole(r)
	_place_text(r)

func _move_hole(r: Rect2) -> void:
	var mat := _dim.material as ShaderMaterial
	mat.set_shader_parameter("screen_size", _dim.size)
	var target := Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
	if _idx == 0:
		mat.set_shader_parameter("hole_rect", target)
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(mat, "shader_parameter/hole_rect", target, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _place_text(hole: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var sc: Vector2 = _panel.scale
	# Padding ngang thực tế của stylebox panel (đổi style vẫn đúng)
	var sb := _panel.get_theme_stylebox("panel")
	var pad: float = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	# Giới hạn box tối đa MAX_WIDTH_RATIO màn hình (tính cả scale của panel);
	# câu dài hơn sẽ tự wrap xuống dòng nhờ autowrap.
	var max_w: float = min(vp.x * MAX_WIDTH_RATIO, vp.x - TEXT_MARGIN * 2.0) / sc.x
	# Co width panel theo bề rộng thật của text: câu ngắn → panel nhỏ gọn.
	var font := _text.get_theme_font("font")
	var fs := _text.get_theme_font_size("font_size")
	var natural: float = font.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w: float = clamp(natural + pad + 4.0, 60.0, max_w)
	# Ép width label trước để autowrap tính đúng chiều cao (đo ở width 0 sẽ
	# cho min height khổng lồ và PanelContainer không tự co lại).
	_text.custom_minimum_size = Vector2(w - pad, 0)
	_panel.custom_minimum_size = Vector2(w, 0)
	await get_tree().process_frame
	_panel.size = _panel.get_combined_minimum_size()
	# Kích thước hiển thị thật trên màn hình (sau scale) để canh vị trí
	var eff_w := _panel.size.x * sc.x
	var eff_h := _panel.size.y * sc.y
	var x: float = clamp(hole.get_center().x - eff_w * 0.5, TEXT_MARGIN, vp.x - eff_w - TEXT_MARGIN)
	# Đặt sát bên dưới lỗ nếu còn chỗ, không thì đặt bên trên
	var y := hole.end.y + PANEL_GAP
	if y + eff_h > vp.y - TEXT_MARGIN:
		y = hole.position.y - eff_h - PANEL_GAP
	y = clamp(y, TEXT_MARGIN, vp.y - eff_h - TEXT_MARGIN)
	_panel.position = Vector2(x, y)

func _finish() -> void:
	if _idx >= _steps.size() + 1:
		return
	_idx = _steps.size() + 1
	finished.emit()
	queue_free()
