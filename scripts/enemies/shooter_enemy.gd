class_name ShooterEnemy
extends EnemyBase

signal fire_projectile(from_pos: Vector2, direction: Vector2)

@export var color_body: Color = Color(1.0, 0.75, 0.0)
@export var color_frozen: Color = Color(0.5, 0.75, 1.0)
@export var color_aim: Color = Color(1.0, 0.9, 0.4, 0.6)
@export var fire_interval: float = 3.0
@export var move_duration: float = 2.0
@export var idle_duration: float = 2.0

var _fire_timer: float = 0.0
var _phase_timer: float = 0.0
var _is_moving: bool = true
var _saved_dir: Vector2 = Vector2.RIGHT

func setup_shooter(gm: GridManager, px: float, py: float, vel: Vector2) -> void:
	setup(gm, px, py, vel)
	_saved_dir = vel.normalized()
	_is_moving = true
	_phase_timer = move_duration * randf_range(0.4, 1.0)
	if _sprite:
		_sprite.play("move")

func _on_alive_update(delta: float) -> void:
	_phase_timer -= delta

	if _is_moving:
		if _phase_timer <= 0.0:
			_enter_idle()
	else:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = fire_interval
			emit_signal("fire_projectile", pixel_pos, Vector2.ZERO)
		if _phase_timer <= 0.0:
			_enter_move()

func _enter_idle() -> void:
	_is_moving = false
	_phase_timer = idle_duration
	if velocity.length() > 0.01:
		_saved_dir = velocity.normalized()
	velocity = Vector2.ZERO
	_fire_timer = 0.4
	if _sprite:
		_sprite.play("idle")

func _enter_move() -> void:
	_is_moving = true
	_phase_timer = move_duration
	velocity = _saved_dir * speed
	if _sprite:
		_sprite.play("move")
