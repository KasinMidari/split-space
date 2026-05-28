class_name Player
extends Node2D

const TILE_SIZE := 16

signal trail_started(gx: int, gy: int)
signal trail_extended(gx: int, gy: int)
signal trail_closed()
signal self_intersected()
signal died()
signal hit()

@export var base_speed: float = 7.0  # tiles/second
@export var spawn_grid_pos: Vector2i = Vector2i(1, 0)

var grid_pos: Vector2 = Vector2(1, 0)
var alive: bool = true
var is_cutting: bool = false
var speed_multiplier: float = 1.0
var is_invincible: bool = false

var _gm: GridManager
var _visual_pos: Vector2
var _move_timer: float = 0.0
var _inv_timer: float = 0.0
var _spd_timer: float = 0.0
var _blink: float = 0.0
var fsm: FSM = null

var direction: Vector2i = Vector2i(0, 1)

@onready var _states: Node = get_node_or_null("States")
@onready var _state_idle: FSMState = get_node_or_null("States/Idle")
@onready var _state_dead: FSMState = get_node_or_null("States/Dead")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if _states != null and _state_idle != null:
		fsm = FSM.new(self, _states, _state_idle)

func _anim_for_dir(prefix: String, dir: Vector2i) -> String:
	var base := ""
	if dir == Vector2i(0, -1):
		base = "up"
	elif dir == Vector2i(0, 1):
		base = "down"
	elif dir == Vector2i(-1, 0):
		base = "left"
	elif dir == Vector2i(1, 0):
		base = "right"
	else:
		base = "down"
	if prefix == "":
		return base
	return "%s_%s" % [prefix, base]


func play_anim(prefix: String, dir: Vector2i) -> void:
	var sprite := animated_sprite
	if sprite == null:
		return
	var name = _anim_for_dir(prefix, dir)
	if sprite.animation != name:
		sprite.play(name)
	

func setup(gm: GridManager, gx: int, gy: int) -> void:
	_gm = gm
	grid_pos = Vector2i(gx, gy)
	_visual_pos = _target_world()
	position = _visual_pos
	is_cutting = false
	alive = true
	is_invincible = false
	speed_multiplier = 1.0
	_move_timer = 0.0
	_inv_timer = 0.0
	_spd_timer = 0.0
	_blink = 0.0
	if fsm != null and _state_idle != null:
		fsm.change_state(_state_idle)
	queue_redraw()

func apply_invincibility(dur: float) -> void:
	is_invincible = true
	_inv_timer = dur

func apply_speed(dur: float) -> void:
	speed_multiplier = 2.0
	_spd_timer = dur

func kill() -> void:
	if is_invincible:
		return
	alive = false
	emit_signal("died")
	if fsm != null and _state_dead != null:
		fsm.change_state(_state_dead)

func take_hit() -> void:
	if is_invincible:
		return
	is_cutting = false
	apply_invincibility(3.0)
	emit_signal("hit")

func _process(delta: float) -> void:
	if fsm != null:
		fsm._update(delta)
		return
	_tick_timers(delta)
	_tick_movement(delta)
	_update_visual(delta)

func _tick_timers(delta: float) -> void:
	if _gm == null:
		return
	if not alive:
		return
	if is_invincible:
		_inv_timer -= delta
		_blink += delta * 12.0
		if _inv_timer <= 0.0:
			is_invincible = false
			_blink = 0.0
	if speed_multiplier > 1.0:
		_spd_timer -= delta
		if _spd_timer <= 0.0:
			speed_multiplier = 1.0

func _tick_movement(delta: float) -> void:
	if _gm == null:
		return
	if not alive:
		return
	var interval := 1.0 / (base_speed * speed_multiplier)
	_move_timer += delta
	if _move_timer >= interval:
		_move_timer -= interval
		_apply_move(direction)

func set_direction(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	direction = dir

func get_direction() -> Vector2i:
	return direction

func step(dir: Vector2i) -> void:
	if _gm == null:
		return
	if not alive:
		return
	if dir == Vector2i.ZERO:
		return
	set_direction(dir)
	_move_timer = 0.0
	_apply_move(dir)
	_update_visual(0.0)

func _apply_move(dir: Vector2) -> void:
	var np = grid_pos + dir
	# Clamp to grid
	if np.x < 0 or np.y < 0 or np.x >= _gm.cols or np.y >= _gm.rows:
		return

	var tile := _gm.get_tile(np.x, np.y)

	if tile == GridManager.T_TRAIL:
		emit_signal("self_intersected")
		return

	grid_pos = np

	if tile == GridManager.T_ACTIVE:
		if not is_cutting:
			is_cutting = true
			emit_signal("trail_started", grid_pos.x, grid_pos.y)
		else:
			emit_signal("trail_extended", grid_pos.x, grid_pos.y)
	elif tile == GridManager.T_BORDER or tile == GridManager.T_CUT:
		if is_cutting:
			is_cutting = false
			emit_signal("trail_closed")

func _update_visual(delta: float) -> void:
	if _gm == null:
		return
	var target := _target_world()
	if is_cutting:
		_visual_pos = target
	else:
		_visual_pos = _visual_pos.lerp(target, 0.35)
	position = _visual_pos
	if animated_sprite != null:
		animated_sprite.visible = not is_invincible or (fmod(_blink, 2.0) < 1.0)
	queue_redraw()

func stop_motion() -> void:
	_move_timer = 0.0

func _target_world() -> Vector2:
	if _gm == null:
		return position
	var ts := float(_gm.tile_size)
	return _gm.position + Vector2(
		grid_pos.x * ts + ts * 0.5,
		grid_pos.y * ts + ts * 0.5
	)
