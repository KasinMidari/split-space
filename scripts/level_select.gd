extends Control

@export var LEVEL_CARD = preload("res://scenes/LevelCard.tscn")

@onready var _level_grid: GridContainer = $LevelGrid
@onready var _back_btn = $BackBtn

func _ready() -> void:
	_back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_populate_levels()

func _populate_levels() -> void:
	for i in range(LevelData.count()):
		var id := i + 1
		var cfg := LevelData.get_level(id)
		var card: LevelCard = LEVEL_CARD.instantiate()
		_level_grid.add_child(card)
		card.setup(id, cfg.get("name", "Level %d" % id), GameState.is_unlocked(id), GameState.best_time(id), GameState.get_best_stars(id))
		card.card_clicked.connect(_start_level)

func _start_level(id: int) -> void:
	GameState.current_level = id
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
