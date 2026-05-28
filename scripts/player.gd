extends Node2D

# tile_size được lấy từ _gm.tile_size khi setup() được gọi
var _tile_size: int = 16

signal trail_started(gx: int, gy: int)
signal trail_extended(gx: int, gy: int)
signal trail_closed()
signal self_intersected()
signal died()

@export var base_speed: float = 7.0  # tiles/second

var grid_pos: Vector2i = Vector2i(1, 0)
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

@onready var _states: Node = get_node_or_null("States")
@onready var _state_alive: FSMState = get_node_or_null("States/Alive")
@onready var _state_dead: FSMState = get_node_or_null("States/Dead")

func _ready() -> void:
	if _states != null and _state_alive != null:
		fsm = FSM.new(self, _states, _state_alive)

func setup(gm: GridManager, gx: int, gy: int) -> void:
	_gm = gm
	_tile_size = gm.tile_size
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
	if fsm != null and _state_alive != null:
		fsm.change_state(_state_alive)
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

func _process(delta: float) -> void:
	if fsm != null:
		fsm._update(delta)
	else:
		_tick_alive(delta)

func _tick_alive(delta: float) -> void:
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

	var interval := 1.0 / (base_speed * speed_multiplier)
	_move_timer += delta
	if _move_timer >= interval:
		_move_timer -= interval
		_handle_input()

	var target := _target_world()
	_visual_pos = target if is_cutting else _visual_pos.lerp(target, 0.55)
	position = _visual_pos
	queue_redraw()

func _handle_input() -> void:
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_right"):
		dir = Vector2i(1, 0)
	elif Input.is_action_pressed("ui_left"):
		dir = Vector2i(-1, 0)
	elif Input.is_action_pressed("ui_down"):
		dir = Vector2i(0, 1)
	elif Input.is_action_pressed("ui_up"):
		dir = Vector2i(0, -1)
	if dir == Vector2i.ZERO:
		return

	var np := grid_pos + dir
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

func _target_world() -> Vector2:
	if _gm == null:
		return position
	return _gm.position + Vector2(
		grid_pos.x * _tile_size + _tile_size * 0.5,
		grid_pos.y * _tile_size + _tile_size * 0.5
	)
