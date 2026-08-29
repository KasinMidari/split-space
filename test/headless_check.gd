extends SceneTree

# Chạy: godot --headless -s test/headless_check.gd
# Kiểm tra nhanh thuật toán cắt trên grid thường và grid địa hình khuyết.

var _fails := 0

func _check(name: String, cond: bool) -> void:
	if cond:
		print("PASS: " + name)
	else:
		_fails += 1
		print("FAIL: " + name)

func _make_grid(c: int, r: int) -> GridManager:
	var g := GridManager.new()
	g.setup(c, r)
	return g

func _trail_v(g: GridManager, x: int, y0: int, y1: int) -> void:
	g.start_trail(x, y0)
	for y in range(y0 + 1, y1 + 1):
		g.extend_trail(x, y)

func _init() -> void:
	# ── Test 1: map chữ nhật, hành vi cũ giữ nguyên ──
	var g := _make_grid(12, 10)
	_trail_v(g, 3, 1, 8)
	var cut: Array = g.perform_fill([Vector2i(8, 5)])
	_check("rect: vùng trái (không enemy) bị cắt", g.get_tile(1, 1) == GridManager.T_CUT)
	_check("rect: vùng enemy giữ nguyên", g.get_tile(8, 5) == GridManager.T_ACTIVE)
	_check("rect: số ô cắt = 16", cut.size() == 16)

	# ── Test 2: map bị tường chia đôi sẵn — vùng xa không kề trail phải giữ nguyên ──
	g = _make_grid(12, 10)
	for y in range(1, 9):
		g.set_tile(6, y, GridManager.T_BORDER)
	g._compute_outer_border()
	_trail_v(g, 3, 1, 8)
	cut = g.perform_fill([Vector2i(1, 5)])  # enemy ở vùng trái của trail
	_check("split: vùng phải trail (không enemy) bị cắt", g.get_tile(4, 4) == GridManager.T_CUT)
	_check("split: vùng enemy giữ nguyên", g.get_tile(1, 5) == GridManager.T_ACTIVE)
	_check("split: túi xa không kề trail KHÔNG bị chiếm", g.get_tile(8, 5) == GridManager.T_ACTIVE)

	# ── Test 3: enemy kẹt trong túi chỉ chạm đảo terrain → phải tính là bị bao ──
	g = _make_grid(12, 10)
	g.set_tile(7, 5, GridManager.T_BORDER)  # đảo giữa map
	g._compute_outer_border()
	for y in range(1, 9):
		for x in range(1, 11):
			if g.get_tile(x, y) == GridManager.T_ACTIVE:
				g.set_tile(x, y, GridManager.T_CUT)
	for p in [Vector2i(6, 5), Vector2i(8, 5), Vector2i(7, 4), Vector2i(7, 6)]:
		g.set_tile(p.x, p.y, GridManager.T_ACTIVE)
	_check("island: enemy cạnh đảo terrain vẫn bị bao", g.is_enemy_enclosed(Vector2i(6, 5)))

	# ── Test 4: enemy trong vết lõm nối viền ngoài → KHÔNG bị bao ──
	g = _make_grid(12, 10)
	g._compute_outer_border()
	for y in range(1, 9):
		for x in range(1, 11):
			if x > 3:
				g.set_tile(x, y, GridManager.T_CUT)
	_check("notch: vùng chạm viền ngoài không bị bao", not g.is_enemy_enclosed(Vector2i(2, 5)))

	# ── Test 5: preview_cut_area chỉ đếm vùng kề trail ──
	g = _make_grid(12, 10)
	for y in range(1, 9):
		g.set_tile(6, y, GridManager.T_BORDER)
	g._compute_outer_border()
	_trail_v(g, 3, 1, 8)
	var area: int = g.preview_cut_area([Vector2i(1, 5)])
	_check("preview: area = vùng phải trail (2 cột × 8) = 16", area == 16)

	print("---")
	print("FAILED: %d" % _fails if _fails > 0 else "ALL PASSED")
	quit(1 if _fails > 0 else 0)
