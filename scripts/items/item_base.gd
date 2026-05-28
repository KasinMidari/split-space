class_name ItemBase
extends Node2D

signal collected(item: ItemBase)

var item_type: String = ""
var alive: bool = true
var _bob_timer: float = 0.0
var _tile_size: int = 16  # cache từ GridManager.tile_size khi setup() được gọi

func setup(gm: GridManager, gx: int, gy: int, type: String) -> void:
	item_type = type
	_tile_size = gm.tile_size
	position = gm.position + Vector2(gx * _tile_size + _tile_size * 0.5,
									 gy * _tile_size + _tile_size * 0.5)
	alive = true

func check_collect(player_world: Vector2) -> bool:
	if not alive:
		return false
	if position.distance_to(player_world) < _tile_size * 0.9:
		alive = false
		emit_signal("collected", self)
		return true
	return false

func _process(delta: float) -> void:
	if not alive:
		return
	_bob_timer += delta
	queue_redraw()

func _draw() -> void:
	pass
