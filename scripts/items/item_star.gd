class_name StarCollectible
extends Node2D

signal collected(star: StarCollectible)

var alive: bool = true
var _spin: float = 0.0
var _bob: float = 0.0
var _tile_size: int = 16

func setup(gm: GridManager, gx: int, gy: int) -> void:
	_tile_size = gm.tile_size
	position = Vector2(gm.position.x + gx * _tile_size + _tile_size * 0.5,
					   gm.position.y + gy * _tile_size + _tile_size * 0.5)
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
	_spin += delta * 2.0
	_bob += delta * 3.0
	queue_redraw()
