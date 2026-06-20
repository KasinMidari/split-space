class_name GridManager
extends Node2D

## Kích thước 1 ô tính bằng pixel (trên màn hình, đã nhân scale).
## Được tự động đọc từ TileSet.tile_size * TileMapLayer.scale khi bind_tilemaps() được gọi.
## Có thể override thủ công trong Inspector nếu không dùng TileMapLayer.
@export var tile_size: int = 16

const T_BORDER := 0
const T_CUT    := 1
const T_ACTIVE := 2
const T_TRAIL  := 3

@export_group("Colors - Border")
@export var C_BORDER      : Color = Color(0.10, 0.12, 0.22)
@export var C_BORDER_LINE : Color = Color(0.30, 0.35, 0.55, 0.6)

@export_group("Colors - Cut")
@export var C_CUT       : Color = Color(0.05, 0.06, 0.10)
@export var C_CUT_SHINE : Color = Color(0.12, 0.14, 0.22, 0.3)

@export_group("Colors - Active")
@export var C_ACTIVE      : Color = Color(0.14, 0.22, 0.44)
@export var C_ACTIVE_LINE : Color = Color(0.25, 0.40, 0.70, 0.35)

@export_group("Colors - Trail")
@export var C_TRAIL       : Color = Color(0.92, 0.25, 0.25)
@export var C_TRAIL_BRIGHT: Color = Color(1.0, 0.55, 0.55, 0.6)

@export_group("Border outline")
@export var border_outline_color : Color = Color(0.4, 0.55, 0.9, 0.4)
@export var border_outline_width : float = 2.0

var cols: int = 0
var rows: int = 0
var _grid: PackedByteArray
var _active_count: int = 0
var _initial_active: int = 0
var _trail: Array = []

var _tm_active: TileMapLayer = null
var _tm_border: TileMapLayer = null
var _tm_cut: TileMapLayer = null
var _has_tilemaps: bool = false

func bind_tilemaps(active: TileMapLayer, border: TileMapLayer, cut: TileMapLayer) -> void:
	_tm_active = active
	_tm_border = border
	_tm_cut = cut
	_has_tilemaps = true
	active.z_index = -1
	border.z_index = -1
	cut.z_index = -1
	# Đọc tile_size từ TileSet.tile_size * scale của layer TileActive.
	# Ví dụ: TileSet có tile 16x16, scale=(2,2) → tile_size = 32.
	if active.tile_set:
		tile_size = roundi(active.tile_set.tile_size.x * active.scale.x)

func setup(c: int, r: int) -> void:
	cols = c
	rows = r
	_grid = PackedByteArray()
	_grid.resize(cols * rows)
	_active_count = 0
	for y in range(rows):
		for x in range(cols):
			var is_b := (x == 0 or y == 0 or x == cols - 1 or y == rows - 1)
			_grid[_idx(x, y)] = T_BORDER if is_b else T_ACTIVE
			if not is_b:
				_active_count += 1
	_initial_active = _active_count
	_trail.clear()
	if _has_tilemaps:
		_init_tilemaps()
	queue_redraw()

func get_tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return T_BORDER
	return _grid[_idx(x, y)]

func set_tile(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return
	var old := _grid[_idx(x, y)]
	_grid[_idx(x, y)] = v
	if old == T_ACTIVE and v != T_ACTIVE:
		_active_count -= 1
	elif old != T_ACTIVE and v == T_ACTIVE:
		_active_count += 1
	queue_redraw()

func is_safe(x: int, y: int) -> bool:
	var t := get_tile(x, y)
	return t == T_BORDER or t == T_CUT

func get_percent_cut() -> float:
	if _initial_active == 0:
		return 1.0
	return 1.0 - float(_active_count) / float(_initial_active)

func get_active_count() -> int:
	return _active_count

func start_trail(x: int, y: int) -> void:
	_trail.clear()
	_trail.append(Vector2i(x, y))
	_grid[_idx(x, y)] = T_TRAIL
	queue_redraw()

func extend_trail(x: int, y: int) -> void:
	if Vector2i(x, y) in _trail:
		return
	_trail.append(Vector2i(x, y))
	_grid[_idx(x, y)] = T_TRAIL
	queue_redraw()

func is_on_trail(x: int, y: int) -> bool:
	return Vector2i(x, y) in _trail

func clear_trail() -> void:
	for t in _trail:
		_grid[_idx(t.x, t.y)] = T_ACTIVE
	_trail.clear()
	queue_redraw()

# Returns array of Vector2i cells that got cut (enclosed). Call after trail_closed.
func perform_fill(enemy_grid_positions: Array) -> Array:
	# Convert trail → CUT
	for t in _trail:
		_grid[_idx(t.x, t.y)] = T_CUT
	_active_count -= _trail.size()
	_trail.clear()

	# Flood fill from each enemy's grid position (on ACTIVE tiles only)
	var reachable: Dictionary = {}
	var queue: Array = []
	for ep in enemy_grid_positions:
		var gp := Vector2i(ep.x, ep.y)
		if get_tile(gp.x, gp.y) == T_ACTIVE and gp not in reachable:
			reachable[gp] = true
			queue.append(gp)

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb = cur + d
			if nb not in reachable and get_tile(nb.x, nb.y) == T_ACTIVE:
				reachable[nb] = true
				queue.append(nb)

	# Enclose tiles not reachable by enemies
	var cut_cells: Array = []
	for y in range(rows):
		for x in range(cols):
			if _grid[_idx(x, y)] == T_ACTIVE:
				var p := Vector2i(x, y)
				if p not in reachable:
					_grid[_idx(x, y)] = T_CUT
					cut_cells.append(p)

	_recalc_active()
	if _has_tilemaps:
		_refresh_tilemaps()
	queue_redraw()
	return cut_cells

# Đếm số enemy bị bao mà không thay đổi grid (trail đang là T_TRAIL = tường tạm).
func preview_enclosed_count(enemy_grid_positions: Array) -> int:
	# Collective BFS from all enemies through T_ACTIVE (T_TRAIL acts as wall)
	var reachable: Dictionary = {}
	var queue: Array = []
	for ep in enemy_grid_positions:
		var gp := Vector2i(ep.x, ep.y)
		if get_tile(gp.x, gp.y) == T_ACTIVE and gp not in reachable:
			reachable[gp] = true
			queue.append(gp)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb = cur + d
			if nb not in reachable and get_tile(nb.x, nb.y) == T_ACTIVE:
				reachable[nb] = true
				queue.append(nb)

	# would_cut = T_ACTIVE cells not reachable by any enemy (mirrors cut_cells in perform_fill)
	var would_cut := 0
	for y in range(rows):
		for x in range(cols):
			if _grid[_idx(x, y)] == T_ACTIVE and Vector2i(x, y) not in reachable:
				would_cut += 1

	var kill_count := 0
	for ep in enemy_grid_positions:
		var gp := Vector2i(ep.x, ep.y)

		# Enemy not in reachable → their cell becomes T_CUT after fill → is_enemy_enclosed returns true
		if gp not in reachable:
			kill_count += 1
			continue

		# Simulate is_enemy_enclosed post-fill: BFS within reachable, check if T_BORDER is adjacent.
		# Run to completion so vis2 also gives us the full region size for the minority check.
		var can_reach_border := false
		var vis2: Dictionary = {gp: true}
		var q2: Array = [gp]
		while not q2.is_empty():
			var cur: Vector2i = q2.pop_front()
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nb = cur + d
				var nt = get_tile(nb.x, nb.y)
				if nt == T_BORDER:
					can_reach_border = true
				elif nt == T_ACTIVE and nb in reachable and nb not in vis2:
					vis2[nb] = true
					q2.append(nb)

		if not can_reach_border:
			kill_count += 1
			continue

		# Simulate minority region check: would_cut > connected_active_size post-fill
		if would_cut > 0 and would_cut > vis2.size():
			kill_count += 1

	return kill_count

func get_connected_active_size(gp: Vector2i) -> int:
	if get_tile(gp.x, gp.y) != T_ACTIVE:
		return 0
	var visited: Dictionary = {}
	var queue: Array = [gp]
	visited[gp] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb = cur + d
			if nb not in visited and get_tile(nb.x, nb.y) == T_ACTIVE:
				visited[nb] = true
				queue.append(nb)
	return visited.size()

func is_enemy_enclosed(gp: Vector2i) -> bool:
	var t := get_tile(gp.x, gp.y)
	if t != T_ACTIVE:
		return true
	var visited: Dictionary = {}
	var queue: Array = [gp]
	visited[gp] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb = cur + d
			var nt = get_tile(nb.x, nb.y)
			if nt == T_BORDER:
				return false  # còn đường ra border → không bị bao vây
			if nt == T_ACTIVE and nb not in visited:
				visited[nb] = true
				queue.append(nb)
	return true  # không thể reach border → bị bao vây

# Capture mọi vùng T_ACTIVE không còn enemy nào (pocket trống sau khi kill)
func capture_empty_pockets(alive_enemy_positions: Array) -> Array:
	var reachable: Dictionary = {}
	var queue: Array = []
	for ep in alive_enemy_positions:
		var gp := Vector2i(ep.x, ep.y)
		if get_tile(gp.x, gp.y) == T_ACTIVE and gp not in reachable:
			reachable[gp] = true
			queue.append(gp)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb = cur + d
			if nb not in reachable and get_tile(nb.x, nb.y) == T_ACTIVE:
				reachable[nb] = true
				queue.append(nb)
	var captured: Array = []
	for y in range(rows):
		for x in range(cols):
			if _grid[_idx(x, y)] == T_ACTIVE and Vector2i(x, y) not in reachable:
				_grid[_idx(x, y)] = T_CUT
				captured.append(Vector2i(x, y))
	if not captured.is_empty():
		_recalc_active()
		if _has_tilemaps:
			_refresh_tilemaps()
		queue_redraw()
	return captured

func restore_tile(x: int, y: int) -> void:
	if get_tile(x, y) == T_CUT:
		_grid[_idx(x, y)] = T_ACTIVE
		_active_count += 1
		if _has_tilemaps:
			_refresh_tilemaps()
		queue_redraw()

func grid_to_world(gx: int, gy: int) -> Vector2:
	return Vector2(gx * tile_size + tile_size * 0.5, gy * tile_size + tile_size * 0.5)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / tile_size, int(world_pos.y) / tile_size)

func total_pixel_size() -> Vector2:
	return Vector2(cols * tile_size, rows * tile_size)

func setup_from_tilemaps() -> void:
	var active_cells := _tm_active.get_used_cells()
	var border_cells := _tm_border.get_used_cells()
	if active_cells.is_empty() and border_cells.is_empty():
		return
	var max_x := 0
	var max_y := 0
	for c in active_cells + border_cells:
		max_x = max(max_x, c.x)
		max_y = max(max_y, c.y)
	cols = max_x + 1
	rows = max_y + 1
	_grid = PackedByteArray()
	_grid.resize(cols * rows)
	for i in range(_grid.size()):
		_grid[i] = T_BORDER
	_active_count = 0
	for c in active_cells:
		if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
			_grid[_idx(c.x, c.y)] = T_ACTIVE
			_active_count += 1
	# Border cells always win — overwrite any active cell that overlaps border terrain
	for c in border_cells:
		if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
			if _grid[_idx(c.x, c.y)] == T_ACTIVE:
				_grid[_idx(c.x, c.y)] = T_BORDER
				_active_count -= 1
	_initial_active = _active_count
	_trail.clear()
	_tm_cut.clear()
	queue_redraw()

func _init_tilemaps(rebuild_border: bool = true) -> void:
	_tm_active.clear()
	_tm_cut.clear()
	var active_cells: Array[Vector2i] = []
	var border_cells: Array[Vector2i] = []
	for y in range(rows):
		for x in range(cols):
			var p := Vector2i(x, y)
			if _grid[_idx(x, y)] == T_BORDER:
				border_cells.append(p)
			else:
				active_cells.append(p)
	if rebuild_border:
		_tm_border.clear()
		_tm_border.set_cells_terrain_connect(border_cells, 0, 1)
	_tm_active.set_cells_terrain_connect(active_cells, 0, 0)

func _refresh_tilemaps() -> void:
	_tm_active.clear()
	_tm_cut.clear()
	var active_cells: Array[Vector2i] = []
	var cut_cells: Array[Vector2i] = []
	var border_cells: Array[Vector2i] = []
	for y in range(rows):
		for x in range(cols):
			var t := _grid[_idx(x, y)]
			var p := Vector2i(x, y)
			if t == T_ACTIVE or t == T_TRAIL:
				active_cells.append(p)
			elif t == T_CUT:
				cut_cells.append(p)
			elif t == T_BORDER:
				border_cells.append(p)
	# Render cut area with terrain-1 tiles so it looks like bordered terrain.
	if not cut_cells.is_empty():
		_tm_cut.set_cells_terrain_connect(cut_cells, 0, 1)
	if not active_cells.is_empty():
		# Temporarily place terrain-1 at all non-active positions inside _tm_active.
		# The grass peering bits are all = 0, so the terrain engine only produces
		# edge variants when it sees actual terrain-1 neighbors — not empty cells.
		var context_cells := cut_cells + border_cells
		if not context_cells.is_empty():
			_tm_active.set_cells_terrain_connect(context_cells, 0, 1)
		_tm_active.set_cells_terrain_connect(active_cells, 0, 0)
		# Remove the context scaffolding; active cells keep their computed edge variants.
		for p in context_cells:
			_tm_active.erase_cell(p)

func _idx(x: int, y: int) -> int:
	return y * cols + x

func _recalc_active() -> void:
	_active_count = 0
	for i in range(_grid.size()):
		if _grid[i] == T_ACTIVE:
			_active_count += 1

func _draw() -> void:
	if cols == 0:
		return
	var ts := float(tile_size)
	if _has_tilemaps:
		for t in _trail:
			var r := Rect2(t.x * ts, t.y * ts, ts, ts)
			draw_rect(r, C_TRAIL)
			draw_rect(r, C_TRAIL_BRIGHT, false, 1.5)
		draw_rect(Rect2(0, 0, cols * ts, rows * ts), border_outline_color, false, border_outline_width)
		return
	for y in range(rows):
		for x in range(cols):
			var t := _grid[_idx(x, y)]
			var r := Rect2(x * ts, y * ts, ts, ts)
			match t:
				T_BORDER:
					draw_rect(r, C_BORDER)
					draw_rect(r, C_BORDER_LINE, false, 1.0)
				T_CUT:
					draw_rect(r, C_CUT)
					draw_rect(r, C_CUT_SHINE, false, 0.5)
				T_ACTIVE:
					draw_rect(r, C_ACTIVE)
					draw_rect(r, C_ACTIVE_LINE, false, 0.5)
				T_TRAIL:
					draw_rect(r, C_TRAIL)
					draw_rect(r, C_TRAIL_BRIGHT, false, 1.5)
	draw_rect(Rect2(0, 0, cols * ts, rows * ts), border_outline_color, false, border_outline_width)
