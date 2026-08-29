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

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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
# Các ô T_BORDER nối liền với mép ngoài của grid (viền ngoài thật sự).
# Ô border KHÔNG thuộc tập này là "đảo terrain" bên trong map.
var _outer_border: Dictionary = {}
# Trail + đất vừa cắt của lượt perform_fill gần nhất (dùng cho capture_empty_pockets).
var _last_fill_cells: Array = []

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
	# Đọc tile_size từ TileSet.tile_size * scale của layer Border (terrain luôn
	# hiển thị → là chuẩn căn ô). Nếu thiếu Border thì fallback sang Active.
	# Ví dụ: TileSet có tile 16x16, scale=(1.5,1.5) → tile_size = 24.
	var ref: TileMapLayer = border if border != null else active
	if ref != null and ref.tile_set:
		tile_size = roundi(ref.tile_set.tile_size.x * ref.scale.x)

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
	_compute_outer_border()
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
# Chỉ các vùng ACTIVE kề với đường trail vừa chốt mới được xét cắt — vùng
# ACTIVE tách rời sẵn (do terrain có lỗ/lõm chia cắt map) không bị đụng tới.
func perform_fill(enemy_grid_positions: Array) -> Array:
	var trail_cells: Array = _trail.duplicate()
	for t in _trail:
		_grid[_idx(t.x, t.y)] = T_CUT
	_trail.clear()

	var enemy_set: Dictionary = {}
	for ep in enemy_grid_positions:
		enemy_set[Vector2i(ep.x, ep.y)] = true

	var cut_cells: Array = []
	for comp in _components_adjacent_to(trail_cells):
		if _component_has_enemy(comp, enemy_set):
			continue
		for p in comp:
			_grid[_idx(p.x, p.y)] = T_CUT
			cut_cells.append(p)

	_last_fill_cells = trail_cells + cut_cells
	_recalc_active()
	if _has_tilemaps:
		_refresh_tilemaps()
	queue_redraw()
	return cut_cells

# Tìm các connected component T_ACTIVE kề 4-hướng với origin_cells.
# Mỗi component trả về là một Dictionary dùng như set {Vector2i: true}.
func _components_adjacent_to(origin_cells: Array) -> Array:
	var visited: Dictionary = {}
	var comps: Array = []
	for oc in origin_cells:
		for d in DIRS:
			var s: Vector2i = oc + d
			if s in visited or get_tile(s.x, s.y) != T_ACTIVE:
				continue
			var comp: Dictionary = {s: true}
			visited[s] = true
			var queue: Array = [s]
			while not queue.is_empty():
				var cur: Vector2i = queue.pop_front()
				for d2 in DIRS:
					var nb: Vector2i = cur + d2
					if nb not in visited and get_tile(nb.x, nb.y) == T_ACTIVE:
						visited[nb] = true
						comp[nb] = true
						queue.append(nb)
			comps.append(comp)
	return comps

func _component_has_enemy(comp: Dictionary, enemy_set: Dictionary) -> bool:
	for gp in enemy_set:
		if gp in comp:
			return true
	return false

# BFS qua các ô T_BORDER từ mép grid để đánh dấu viền ngoài thật sự.
# Border cells không bao giờ đổi trong lúc chơi nên chỉ cần tính 1 lần lúc setup.
func _compute_outer_border() -> void:
	_outer_border.clear()
	var queue: Array = []
	for x in range(cols):
		for y in [0, rows - 1]:
			var p := Vector2i(x, y)
			if get_tile(p.x, p.y) == T_BORDER and p not in _outer_border:
				_outer_border[p] = true
				queue.append(p)
	for y in range(rows):
		for x in [0, cols - 1]:
			var p := Vector2i(x, y)
			if get_tile(p.x, p.y) == T_BORDER and p not in _outer_border:
				_outer_border[p] = true
				queue.append(p)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in DIRS:
			var nb: Vector2i = cur + d
			if nb not in _outer_border and get_tile(nb.x, nb.y) == T_BORDER \
					and nb.x >= 0 and nb.y >= 0 and nb.x < cols and nb.y < rows:
				_outer_border[nb] = true
				queue.append(nb)

# Ô này có phải viền ngoài không (out-of-bounds cũng tính là viền ngoài).
func _is_outer_border_at(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= cols or p.y >= rows:
		return true
	return p in _outer_border

# Tổng số ô ĐẤT sẽ bị bắt nếu chốt trail ngay bây giờ (không tính trail,
# không thay đổi grid). Chỉ xét các vùng kề trail, giống perform_fill.
func preview_cut_area(enemy_grid_positions: Array) -> int:
	var enemy_set: Dictionary = {}
	for ep in enemy_grid_positions:
		enemy_set[Vector2i(ep.x, ep.y)] = true
	var area := 0
	for comp in _components_adjacent_to(_trail):
		if not _component_has_enemy(comp, enemy_set):
			area += comp.size()
	return area

# Bounding box (cột × hàng) của chính đường trail hiện tại.
func trail_bbox_size() -> Vector2i:
	if _trail.is_empty():
		return Vector2i.ZERO
	var min_x := cols
	var min_y := rows
	var max_x := -1
	var max_y := -1
	for t in _trail:
		min_x = mini(min_x, t.x); max_x = maxi(max_x, t.x)
		min_y = mini(min_y, t.y); max_y = maxi(max_y, t.y)
	return Vector2i(max_x - min_x + 1, max_y - min_y + 1)

# Đếm số enemy bị bao mà không thay đổi grid (trail đang là T_TRAIL = tường tạm).
func preview_enclosed_count(enemy_grid_positions: Array) -> int:
	var enemy_set: Dictionary = {}
	for ep in enemy_grid_positions:
		enemy_set[Vector2i(ep.x, ep.y)] = true

	var comps := _components_adjacent_to(_trail)

	# would_cut = tổng ô của các vùng kề trail không chứa enemy (mirrors perform_fill)
	var would_cut := 0
	for comp in comps:
		if not _component_has_enemy(comp, enemy_set):
			would_cut += comp.size()

	var kill_count := 0
	for ep in enemy_grid_positions:
		var gp := Vector2i(ep.x, ep.y)

		# Enemy đứng trên trail / ngoài vùng ACTIVE → thành T_CUT sau fill → chết
		if get_tile(gp.x, gp.y) != T_ACTIVE:
			kill_count += 1
			continue

		# Tìm component chứa enemy (vùng của nó sau khi trail thành tường)
		var region: Dictionary = {}
		for comp in comps:
			if gp in comp:
				region = comp
				break
		if region.is_empty():
			# Vùng của enemy không kề trail → cú cắt này không đụng tới nó
			continue

		# Mô phỏng is_enemy_enclosed: vùng có chạm viền NGOÀI không?
		var can_reach_border := false
		for p in region:
			for d in DIRS:
				if _is_outer_border_at(p + d):
					can_reach_border = true
					break
			if can_reach_border:
				break
		if not can_reach_border:
			kill_count += 1
			continue

		# Minority check: vùng bắt được lớn hơn vùng enemy đang đứng
		if would_cut > 0 and would_cut > region.size():
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
		for d in DIRS:
			var nb = cur + d
			if _is_outer_border_at(nb):
				return false  # còn đường ra viền ngoài → không bị bao vây
			if get_tile(nb.x, nb.y) == T_ACTIVE and nb not in visited:
				visited[nb] = true
				queue.append(nb)
	return true  # không thể reach viền ngoài → bị bao vây (đảo terrain không tính)

# Capture các vùng T_ACTIVE trống (không còn enemy sống) KỀ với vùng vừa cắt
# ở lượt perform_fill gần nhất. Vùng ACTIVE tách rời sẵn ở nơi khác giữ nguyên.
func capture_empty_pockets(alive_enemy_positions: Array) -> Array:
	var enemy_set: Dictionary = {}
	for ep in alive_enemy_positions:
		enemy_set[Vector2i(ep.x, ep.y)] = true
	var captured: Array = []
	for comp in _components_adjacent_to(_last_fill_cells):
		if _component_has_enemy(comp, enemy_set):
			continue
		for p in comp:
			_grid[_idx(p.x, p.y)] = T_CUT
			captured.append(p)
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
	_compute_outer_border()
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
