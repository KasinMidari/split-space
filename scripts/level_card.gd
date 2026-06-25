class_name LevelCard
extends Control

signal card_clicked(id: int)


@export var color_locked: Color = Color(0.4, 0.4, 0.5)


# Màu sao chưa đạt được (mờ tối) so với sao đã đạt (trắng sáng).
const STAR_EARNED := Color.WHITE
const STAR_EMPTY  := Color(0.0, 0.0, 0.0, 0.35)

@onready var _num_label: Label    = $VBox/Labels/NumLabel
@onready var _best_label: Label   = $VBox/Labels/BestLabel
@onready var _Star_rate: HBoxContainer   = $VBox/StarRate
@onready var _stars: Array[TextureRect] = [
	$VBox/StarRate/Star1,
	$VBox/StarRate/Star2,
	$VBox/StarRate/Star3,
]

var _level_id: int = 0
var _unlocked: bool = false

func setup(id: int, level_name: String, unlocked: bool, best: float, stars: int = 0) -> void:
	_level_id = id
	_unlocked = unlocked

	_num_label.text = str(id)
	_update_stars(stars)

	if best >= 0.0:
		_best_label.text = "%d:%02d" % [int(best / 60), int(best) % 60]
		_set_level_state_UI(true)
		_update_stars(stars)
	else:
		_set_level_state_UI(false)

	if unlocked:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		modulate = Color.WHITE
	else:
		modulate = color_locked

func _gui_input(ev: InputEvent) -> void:
	if _unlocked and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("card_clicked", _level_id)

func _set_level_state_UI(is_unclock: bool) -> void:
	_best_label.visible = is_unclock
	_Star_rate.visible = is_unclock

func _update_stars(earned: int) -> void:
	for i in _stars.size():
		_stars[i].modulate = STAR_EARNED if i < earned else STAR_EMPTY
	
