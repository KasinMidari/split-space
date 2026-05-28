class_name ShooterEnemy
extends EnemyBase

signal fire_projectile(from_pos: Vector2, direction: Vector2)

@export var color_body: Color = Color(1.0, 0.75, 0.0)
@export var color_frozen: Color = Color(0.5, 0.75, 1.0)
@export var color_aim: Color = Color(1.0, 0.9, 0.4, 0.6)
@export var fire_interval: float = 3.0

var _fire_timer: float = 0.0

func setup_shooter(gm: GridManager, px: float, py: float, vel: Vector2) -> void:
	setup(gm, px, py, vel)
	_fire_timer = fire_interval * randf_range(0.4, 1.0)

func _on_alive_update(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		emit_signal("fire_projectile", pixel_pos, Vector2.ZERO)
