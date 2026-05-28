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

func _draw() -> void:
	if not alive:
		return
	var bob_off := sin(_bob) * 3.0
	var outer := 10.0
	var inner := 4.5
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var angle := _spin + i * TAU / 10.0 - TAU / 4.0
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(angle), sin(angle) + bob_off / outer) * r)
	draw_colored_polygon(pts, Color(1.0, 0.88, 0.1))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.65, 0.0, 0.7), 1.0)
	draw_circle(Vector2(0, bob_off), 3.0, Color(1.0, 1.0, 0.7, 0.5))
