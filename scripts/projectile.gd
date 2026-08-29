class_name Projectile
extends Node2D

signal hit_player()
signal expired()

@export var speed: float = 100
@export var lifetime: float = 4.0
@export var color_body: Color = Color(1.0, 0.55, 0.0)
@export var color_glow: Color = Color(1.0, 0.85, 0.3, 0.5)
@export var color_trail: Color = Color(1.0, 0.7, 0.2, 0.5)

var pixel_pos: Vector2
var velocity: Vector2
var _gm: GridManager
var _tile_size: int = 16
var _timer: float = 0.0

func setup(gm: GridManager, from_world: Vector2, dir: Vector2) -> void:
	_gm = gm
	_tile_size = gm.tile_size
	pixel_pos = from_world
	velocity = dir.normalized() * speed
	position = pixel_pos

func _process(delta: float) -> void:
	_timer += delta
	if _timer > lifetime:
		emit_signal("expired")
		return
	_move(delta)
	position = pixel_pos
	if _is_off_screen():
		emit_signal("expired")
		return
	queue_redraw()

func _move(delta: float) -> void:
	var ts := float(_tile_size)
	var half := ts * 0.3
	var new_pos := pixel_pos + velocity * delta
	var off := _gm.position

	if velocity.x != 0.0:
		var cx := new_pos.x + (half if velocity.x > 0.0 else -half)
		var gx := int((cx - off.x) / ts)
		var gy := int((pixel_pos.y - off.y) / ts)
		if _gm.get_tile(gx, gy) == GridManager.T_CUT:
			velocity.x = -velocity.x
			new_pos.x = pixel_pos.x

	if velocity.y != 0.0:
		var gx2 := int((new_pos.x - off.x) / ts)
		var cy := new_pos.y + (half if velocity.y > 0.0 else -half)
		var gy2 := int((cy - off.y) / ts)
		if _gm.get_tile(gx2, gy2) == GridManager.T_CUT:
			velocity.y = -velocity.y
			new_pos.y = pixel_pos.y

	pixel_pos = new_pos

func _is_off_screen() -> bool:
	var vp_size := get_viewport().get_visible_rect().size
	var screen_pos := get_viewport_transform() * global_position
	var margin := float(_tile_size) * 3.0
	return screen_pos.x < -margin or screen_pos.x > vp_size.x + margin \
		or screen_pos.y < -margin or screen_pos.y > vp_size.y + margin

func check_player(player_world: Vector2) -> bool:
	if pixel_pos.distance_to(player_world) < _tile_size * 0.55:
		emit_signal("hit_player")
		return true
	return false
