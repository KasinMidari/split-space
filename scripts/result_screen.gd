extends Control

@onready var _result_label: Label = $ResultLabel
@onready var _stars_label: Label  = $ButtonBox/StarsLabel
@onready var _time_label: Label   = $ButtonBox/TimeLabel
@onready var _best_label: Label   = $ButtonBox/BestLabel
@onready var _next_btn: Button    = $ButtonBox/NextBtn
@onready var _retry_btn: Button   = $ButtonBox/RetryBtn
@onready var _lvl_btn: Button     = $ButtonBox/LevelBtn

func _ready() -> void:
	var won: bool   = GameState.get_meta("last_won", false)
	var elapsed: float = GameState.get_meta("last_time", 0.0)
	var level: int  = GameState.get_meta("last_level", 1)
	var stars: int  = GameState.get_meta("last_stars", 0)

	_result_label.text = "YOU WIN!" if won else "GAME OVER"

	var star_str := "★".repeat(stars) + "☆".repeat(max(0, 3 - stars))
	_stars_label.text = star_str
	_stars_label.visible = won

	var m := int(elapsed / 60)
	var s := int(elapsed) % 60
	var ms := int(fmod(elapsed, 1.0) * 100)
	_time_label.text = "TIME  %02d:%02d.%02d" % [m, s, ms]

	var best := GameState.best_time(level)
	if best >= 0.0:
		var bm := int(best / 60)
		var bs := int(best) % 60
		_best_label.text = "BEST  %02d:%02d" % [bm, bs]
	else:
		_best_label.visible = false

	_next_btn.visible = won and GameState.is_unlocked(level + 1)
	_next_btn.pressed.connect(func():
		GameState.current_level = level + 1
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	)
	_retry_btn.pressed.connect(func():
		GameState.current_level = level
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	)
	_lvl_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
	)
