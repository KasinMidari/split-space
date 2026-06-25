class_name EnemyBase
extends Node2D

signal died(enemy: EnemyBase)

@export_group("Movement")
@export var speed: float = 55.0

var pixel_pos: Vector2
var velocity: Vector2
var alive: bool = true
var frozen: bool = false
var dying: bool = false
var _frozen_timer: float = 0.0
var _dying_timer: float = 0.0
var _gm: GridManager
var _tile_size: int = 16  # cache từ _gm.tile_size khi setup() được gọi
var fsm: FSM = null

@onready var _states: Node = get_node_or_null("States")
@onready var _state_move: FSMState = get_node_or_null("States/Move")
@onready var _state_frozen: FSMState = get_node_or_null("States/Frozen")
@onready var _state_dying: FSMState = get_node_or_null("States/Dying")
@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	if _states != null and _state_move != null:
		fsm = FSM.new(self, _states, _state_move)

func setup(gm: GridManager, px: float, py: float, vel: Vector2) -> void:
	_gm = gm
	_tile_size = gm.tile_size
	pixel_pos = Vector2(px, py)
	position = pixel_pos
	velocity = vel.normalized() * speed
	alive = true
	frozen = false
	dying = false
	_frozen_timer = 0.0
	_dying_timer = 0.0
	if fsm != null and _state_move != null:
		fsm.change_state(_state_move)

func freeze(dur: float) -> void:
	frozen = true
	_frozen_timer = dur
	if fsm != null and _state_frozen != null:
		fsm.change_state(_state_frozen)

func die() -> void:
	if not alive:
		return
	alive = false
	dying = true
	_dying_timer = 0.3
	if fsm != null and _state_dying != null:
		fsm.change_state(_state_dying)

func get_grid_pos() -> Vector2i:
	var local := pixel_pos - _gm.position
	return Vector2i(int(local.x) / _tile_size, int(local.y) / _tile_size)

func overlaps_player(player_world: Vector2) -> bool:
	return pixel_pos.distance_to(player_world) < _tile_size * 0.72

func overlaps_trail() -> bool:
	var gp := get_grid_pos()
	return _gm.get_tile(gp.x, gp.y) == GridManager.T_TRAIL

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
	var gp := get_grid_pos()
	if _should_bounce(GridManager.T_CUT) and _gm.get_tile(gp.x, gp.y) == GridManager.T_CUT:
		die()
		return
	_move(delta)
	_on_alive_update(delta)
	position = pixel_pos
	queue_redraw()

func _tick_frozen(delta: float) -> void:
	if not alive:
		return
	_frozen_timer -= delta
	if _frozen_timer <= 0.0:
		frozen = false
		if fsm != null and _state_move != null:
			fsm.change_state(_state_move)
	queue_redraw()

func _tick_dying(delta: float) -> void:
	_dying_timer -= delta
	queue_redraw()
	if _dying_timer <= 0.0:
		dying = false
		emit_signal("died", self)

func _on_alive_update(_delta: float) -> void:
	pass

func _move(delta: float) -> void:
	var ts := float(_tile_size)
	var half := ts * 0.46
	var new_pos := pixel_pos + velocity * delta
	var off := _gm.position

	if velocity.x != 0.0:
		var cx := new_pos.x + (half if velocity.x > 0.0 else -half)
		var gx := int((cx - off.x) / ts)
		var gy := int((pixel_pos.y - off.y) / ts)
		if _should_bounce(_gm.get_tile(gx, gy)):
			velocity.x = -velocity.x
			new_pos.x = pixel_pos.x

	if velocity.y != 0.0:
		var gx2 := int((new_pos.x - off.x) / ts)
		var cy := new_pos.y + (half if velocity.y > 0.0 else -half)
		var gy2 := int((cy - off.y) / ts)
		if _should_bounce(_gm.get_tile(gx2, gy2)):
			velocity.y = -velocity.y
			new_pos.y = pixel_pos.y

	pixel_pos = new_pos
	_update_sprite_direction()

func _update_sprite_direction() -> void:
	if _sprite == null or velocity.x == 0.0:
		return
	_sprite.flip_h = velocity.x < 0.0

func _should_bounce(t: int) -> bool:
	return t == GridManager.T_BORDER or t == GridManager.T_CUT

func _draw_dying() -> void:
	var t := 1.0 - (_dying_timer / 0.3)
	var r := _tile_size * 0.6 * t
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.1, 0.8 * (1.0 - t)))
	draw_circle(Vector2.ZERO, r * 0.5, Color(1.0, 0.92, 0.4, (1.0 - t) * 0.9))

func _draw() -> void:
	pass
