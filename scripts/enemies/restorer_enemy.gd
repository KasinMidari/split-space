class_name RestorerEnemy
extends EnemyBase

@export var color_body: Color = Color(0.35, 0.85, 0.4)
@export var color_inner: Color = Color(0.0, 0.0, 0.0, 0.4)
@export var color_frozen: Color = Color(0.5, 0.75, 1.0)
@export var color_spin: Color = Color(0.8, 1.0, 0.5, 0.7)
@export var restore_interval: float = 0.28

var _restore_cd: float = 0.0

func setup(gm: GridManager, px: float, py: float, vel: Vector2) -> void:
	super.setup(gm, px, py, vel)
	_restore_cd = 0.0

func _on_alive_update(delta: float) -> void:
	_restore_cd -= delta
	if _restore_cd <= 0.0:
		_restore_cd = restore_interval
		_try_restore()

func _try_restore() -> void:
	if _gm == null:
		return
	var gp := get_grid_pos()
	if _gm.get_tile(gp.x, gp.y) == GridManager.T_CUT:
		_gm.restore_tile(gp.x, gp.y)

func _should_bounce(t: int) -> bool:
	return t == GridManager.T_BORDER

func _draw() -> void:
	if dying:
		_draw_dying()
		return
	var h := _tile_size * 0.38
	var col := color_frozen if frozen else color_body
	draw_rect(Rect2(-h, -h, h * 2, h * 2), col)
	draw_rect(Rect2(-h + 3, -h + 3, (h - 3) * 2, (h - 3) * 2),
			  Color(col.r * color_inner.r, col.g * color_inner.g, col.b * color_inner.b, col.a * (1.0 - color_inner.a) + color_inner.a))
	draw_rect(Rect2(-h, -h, h * 2, h * 2), col.lightened(0.4), false, 1.5)
	var t := fmod(Time.get_ticks_msec() * 0.002, TAU)
	for i in range(4):
		var a := t + i * TAU * 0.25
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (h - 2), color_spin, 1.5)
