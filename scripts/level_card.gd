class_name LevelCard
extends Control

signal card_clicked(id: int)


@export var color_locked: Color = Color(0.4, 0.4, 0.5)


@onready var _num_label: Label    = $VBox/Labels/NumLabel
@onready var _best_label: Label   = $VBox/Labels/BestLabel
@onready var _Star_rate: HBoxContainer   = $VBox/StarRate

var _level_id: int = 0
var _unlocked: bool = false

func setup(id: int, level_name: String, unlocked: bool, best: float) -> void:
	_level_id = id
	_unlocked = unlocked

	_num_label.text = str(id)

	if best >= 0.0:
		_best_label.text = "%d:%02d" % [int(best / 60), int(best) % 60]
		_set_level_state_UI(true)
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
		
func _set_level_state_UI(is_unclock:bool) -> void:
	_best_label.visible = is_unclock
	_Star_rate.visible = is_unclock
	
