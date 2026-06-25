extends Node2D

const MAX_ITEMS_ALIVE := 3
const TOTAL_STARS := 3
const LEVEL_SCENE_BASE := "res://scenes/levels/Level%d.tscn"

const _PROJECTILE     := preload("res://scenes/Projectile.tscn")
const _HEART_FULL     := preload("res://assets/ui/Heart_Full_64.png")
const _HEART_EMPTY    := preload("res://assets/ui/Heart_Empty_64.png")
const _ITEM_INVINC    := preload("res://scenes/items/ItemInvincibility.tscn")
const _ITEM_SPEED     := preload("res://scenes/items/ItemSpeed.tscn")
const _ITEM_FREEZE    := preload("res://scenes/items/ItemFreeze.tscn")
const _ITEM_STAR      := preload("res://scenes/items/ItemStar.tscn")
const _SETTINGS_SCENE := preload("res://scenes/Settings.tscn")

var _level_cfg: Dictionary = {}
var _level_spawns: Array = []

var _elapsed: float = 0.0
var _time_limit: float = 90.0
var _item_timer: float = 0.0
var _game_over: bool = false
var _paused_internal: bool = false
var _lives: int = 3
var _stars_collected: int = 0

# Level-owned tilemaps (loaded from level scene, added to $Grid at runtime)
var _tm_border: TileMapLayer = null
var _tm_active: TileMapLayer = null
var _tm_cut: TileMapLayer = null
var _tm_decorations: Array[TileMapLayer] = []

@onready var _grid: GridManager        = $Grid
@onready var _player: Player           = $Player
@onready var _enemy_container: Node2D  = $Enemies
@onready var _item_container: Node2D   = $Items
@onready var _star_container: Node2D   = $Stars
@onready var _proj_container: Node2D   = $Projectiles


@onready var _timer_label: Label  = $UI/HUD/TimerLabel
@onready var _effect_label: Label = $UI/HUD/EffectLabel
@onready var _heart1: TextureRect = $UI/HUD/HeartsContainer/Heart1
@onready var _heart2: TextureRect = $UI/HUD/HeartsContainer/Heart2
@onready var _heart3: TextureRect = $UI/HUD/HeartsContainer/Heart3
@onready var _pause_panel: ColorRect = $UI/HUD/PauseOverlay
@onready var _resume_btn: Button  = $UI/HUD/PauseOverlay/Panel/PauseBox/ResumeBtn
@onready var _settings_btn: TextureButton = $UI/HUD/SettingsBtn

var _enemies: Array = []
var _projectiles: Array = []
var _items: Array = []
var _stars: Array = []
var _settings_ui: Node = null

func _ready() -> void:
	_resume_btn.pressed.connect(func(): _toggle_pause())
	_settings_btn.pressed.connect(_on_settings_pressed)
	_player.trail_started.connect(_on_trail_started)
	_player.trail_extended.connect(_on_trail_extended)
	_player.trail_closed.connect(_on_trail_closed)
	_player.self_intersected.connect(_on_self_intersect)
	_player.hit.connect(_on_player_hit)
	start_level(GameState.current_level)

func start_level(level_id: int) -> void:
	_free_level_tilemaps()
	_load_level_scene(level_id)
	_lives = 3
	_stars_collected = 0
	_reset()
	_setup_grid()
	_spawn_enemies()
	_spawn_stars()
	_elapsed = 0.0
	_time_limit = _level_cfg.get("time_limit", 90.0)
	_item_timer = _level_cfg.get("item_interval", 15.0)
	_game_over = false
	_paused_internal = false
	_update_hud()

func _free_level_tilemaps() -> void:
	for tm in ([_tm_border, _tm_active, _tm_cut] as Array) + _tm_decorations:
		if tm != null and is_instance_valid(tm):
			tm.queue_free()
	_tm_border = null
	_tm_active = null
	_tm_cut = null
	_tm_decorations.clear()

func _load_level_scene(level_id: int) -> void:
	_level_spawns.clear()
	var scene_path := LEVEL_SCENE_BASE % level_id
	if ResourceLoader.exists(scene_path):
		var inst: Node = (load(scene_path) as PackedScene).instantiate()
		if inst is LevelConfig:
			var cfg := inst as LevelConfig
			_level_cfg = cfg.to_dict()
			for child in cfg.get_children():
				if child is EnemyBase or child is RestorerEnemy:
					cfg.remove_child(child)
					_level_spawns.append(child)
			var border := cfg.get_border_layer()
			var active := cfg.get_active_layer()
			if border:
				inst.remove_child(border)
				_grid.add_child(border)
				_tm_border = border
			if active:
				inst.remove_child(active)
				_grid.add_child(active)
				_tm_active = active
				# Ép layer Active trùng scale/position với Border. Một số level
				# cấu hình Active sai scale (vd Level1=0.5) khiến trail & terrain
				# lệch ô. Border là chuẩn hiển thị nên các layer phải khớp nó.
				if border != null:
					_tm_active.scale = border.scale
					_tm_active.position = border.position
			for deco in cfg.get_decoration_layers():
				inst.remove_child(deco)
				_grid.add_child(deco)
				_tm_decorations.append(deco)
		inst.free()
	else:
		_level_cfg = LevelData.get_level(level_id)
		if _level_cfg.is_empty():
			_level_cfg = LevelData.get_level(1)

	# Create TileCut dynamically (always starts empty).
	# Lấy scale/position từ Border (terrain hiển thị) để ô cắt khớp với
	# terrain, trail và player. Fallback sang Active nếu không có Border.
	_tm_cut = TileMapLayer.new()
	_tm_cut.name = "TileCut"
	var ref_layer: TileMapLayer = _tm_border if _tm_border != null else _tm_active
	if ref_layer != null:
		_tm_cut.tile_set = ref_layer.tile_set
		_tm_cut.scale = ref_layer.scale
		_tm_cut.position = ref_layer.position
	else:
		_tm_cut.scale = Vector2(1.5, 1.5)
	_grid.add_child(_tm_cut)

func _reset() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	for p in _projectiles:
		if is_instance_valid(p):
			p.queue_free()
	_projectiles.clear()
	for it in _items:
		if is_instance_valid(it):
			it.queue_free()
	_items.clear()
	for s in _stars:
		if is_instance_valid(s):
			s.queue_free()
	_stars.clear()

func _setup_grid() -> void:
	var c: int = _level_cfg.get("cols", 20)
	var r: int = _level_cfg.get("rows", 14)

	if _tm_active != null and _tm_cut != null and _tm_border != null:
		_grid.bind_tilemaps(_tm_active, _tm_border, _tm_cut)
		if _tm_active.get_used_cells().size() > 0:
			_grid.setup_from_tilemaps()
		else:
			_grid.setup(c, r)

	else:
		_grid.setup(c, r)

	_grid.position = _level_cfg.get("grid_position", Vector2.ZERO)
	_player.setup(_grid, _player.spawn_grid_pos.x, _player.spawn_grid_pos.y)

func _on_settings_pressed() -> void:
	if _game_over:
		return
	AudioManager.play_click()
	_open_settings(true)

func _open_settings(pause_game: bool) -> void:
	if _settings_ui and is_instance_valid(_settings_ui):
		return
	var menu := _SETTINGS_SCENE.instantiate()
	menu.pause_game = pause_game
	# Thêm vào CanvasLayer UI để settings vẽ đè lên HUD (timer, tim, nút setting)
	$UI.add_child(menu)
	_settings_ui = menu
	menu.closed.connect(func(): _settings_ui = null)

func _spawn_enemies() -> void:
	var used: Array = []
	for e in _level_spawns:
		var gp := _find_spawn_pos(used)
		if gp == Vector2i(-1, -1):
			break
		used.append(gp)
		_enemy_container.add_child(e)
		if e is BasicEnemy:
			(e as BasicEnemy).setup_basic(_grid, _wx(gp.x), _wy(gp.y), _rvel(1.0))
			e.died.connect(_on_enemy_died)
		elif e is ShooterEnemy:
			(e as ShooterEnemy).setup_shooter(_grid, _wx(gp.x), _wy(gp.y), _rvel(1.0))
			e.fire_projectile.connect(_on_fire_projectile.bind(e))
			e.died.connect(_on_enemy_died)
		elif e is RestorerEnemy:
			(e as RestorerEnemy).setup(_grid, _wx(gp.x), _wy(gp.y), _rvel(1.0))
			e.died.connect(_on_restorer_died)
		_enemies.append(e)

func _spawn_stars() -> void:
	var used: Array = []
	for _i in range(TOTAL_STARS):
		var gp := _find_spawn_pos(used)
		if gp == Vector2i(-1, -1):
			break
		used.append(gp)
		var star: StarCollectible = _ITEM_STAR.instantiate()
		_star_container.add_child(star)
		star.setup(_grid, gp.x, gp.y)
		star.collected.connect(_on_star_collected)
		_stars.append(star)

func _find_spawn_pos(used: Array) -> Vector2i:
	var c: int = _grid.cols
	var r: int = _grid.rows
	var cands: Array = []
	for y in range(2, r - 2):
		for x in range(2, c - 2):
			if _grid.get_tile(x, y) != GridManager.T_ACTIVE:
				continue
			var ok := true
			for up in used:
				if Vector2i(x, y).distance_to(up) < 4:
					ok = false
					break
			if ok:
				cands.append(Vector2i(x, y))
	if cands.is_empty():
		return Vector2i(-1, -1)
	return cands[randi() % cands.size()]

func _wx(gx: int) -> float:
	return _grid.position.x + gx * _grid.tile_size + _grid.tile_size * 0.5

func _wy(gy: int) -> float:
	return _grid.position.y + gy * _grid.tile_size + _grid.tile_size * 0.5

func _rvel(spd: float) -> Vector2:
	var a := int(randf() * 5) * (TAU / 8.0) + randf_range(-0.25, 0.25)
	return Vector2(cos(a), sin(a)) * spd

# ── Player signals ───────────────────────────────────────────────────

func _on_trail_started(gx: int, gy: int) -> void:
	_grid.start_trail(gx, gy)

func _on_trail_extended(gx: int, gy: int) -> void:
	_grid.extend_trail(gx, gy)

func _on_trail_closed() -> void:
	if _game_over:
		return
	var ep: Array = []
	for e in _enemies:
		if is_instance_valid(e) and e.alive:
			ep.append(e.get_grid_pos())
	if _grid.preview_enclosed_count(ep) > 1:
		_grid.clear_trail()
		return

	var cut_cells: Array = _grid.perform_fill(ep)
	if cut_cells.size() > 0:
		AudioManager.play_cut()
	if cut_cells.size() > 6:
		AudioManager.play_big_cut()

	# Xóa tile decoration foreground (z_index >= 0) ở vùng vừa cắt
	# Background như Water (z_index < 0) giữ nguyên
	for deco in _tm_decorations:
		if is_instance_valid(deco) and deco.z_index >= 0:
			for cell in cut_cells:
				deco.erase_cell(cell)

	for e in _enemies.duplicate():
		if not is_instance_valid(e) or not e.alive:
			continue
		var gp = e.get_grid_pos()
		var enclosed := _grid.is_enemy_enclosed(gp)
		if not enclosed and cut_cells.size() > 0:
			enclosed = cut_cells.size() > _grid.get_connected_active_size(gp)
		if not enclosed:
			enclosed = _is_enemy_isolated(e, gp)
		if enclosed:
			AudioManager.play_enemy_die()
			if e is EnemyBase:
				(e as EnemyBase).die()
			elif e is RestorerEnemy:
				(e as RestorerEnemy).die()

	# Sau khi kill xong, capture các vùng T_ACTIVE còn trống (không có enemy nào)
	var alive_ep: Array = []
	for e in _enemies:
		if is_instance_valid(e) and e.alive:
			alive_ep.append(e.get_grid_pos())
	var extra_cells: Array = _grid.capture_empty_pockets(alive_ep)
	for deco in _tm_decorations:
		if is_instance_valid(deco) and deco.z_index >= 0:
			for cell in extra_cells:
				deco.erase_cell(cell)

	_check_win()

func _is_enemy_isolated(enemy: Node, gp: Vector2i) -> bool:
	if _grid.get_tile(gp.x, gp.y) != GridManager.T_ACTIVE:
		return false
	var visited: Dictionary = {gp: true}
	var queue: Array = [gp]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb = cur + d
			if nb not in visited and _grid.get_tile(nb.x, nb.y) == GridManager.T_ACTIVE:
				visited[nb] = true
				queue.append(nb)
	for other in _enemies:
		if not is_instance_valid(other) or not other.alive or other == enemy:
			continue
		if other.get_grid_pos() in visited:
			return false  # có enemy khác cùng vùng → không cô lập
	return true

func _on_self_intersect() -> void:
	if not _player.is_invincible:
		_grid.clear_trail()
		_player.is_cutting = false

func _on_player_hit() -> void:
	if _game_over:
		return
	AudioManager.play_die()
	_grid.clear_trail()
	_lives -= 1
	_update_hud()
	if _lives <= 0:
		_game_over = true
		_player.alive = false
		await get_tree().create_timer(1.2).timeout
		_go_result(false)

# ── Enemy signals ────────────────────────────────────────────────────

func _on_enemy_died(_e) -> void:
	_clean_dead()
	_check_win()

func _on_restorer_died(_e) -> void:
	_clean_dead()
	_check_win()

func _on_fire_projectile(from_pos: Vector2, _dummy: Vector2, _src: Node2D) -> void:
	if not _player.alive:
		return
	var dir := (_player.position - from_pos).normalized()
	var p: Projectile = _PROJECTILE.instantiate()
	_proj_container.add_child(p)
	p.setup(_grid, from_pos, dir)
	p.hit_player.connect(_on_proj_hit_player)
	p.expired.connect(func(): _remove_proj(p))
	_projectiles.append(p)

func _on_proj_hit_player() -> void:
	_player.take_hit()

func _remove_proj(p: Projectile) -> void:
	_projectiles.erase(p)
	if is_instance_valid(p):
		p.queue_free()

# ── Stars ────────────────────────────────────────────────────────────

func _on_star_collected(star: StarCollectible) -> void:
	_stars.erase(star)
	_stars_collected += 1
	AudioManager.play_item()
	_update_hud()
	if is_instance_valid(star):
		star.queue_free()

# ── Items ────────────────────────────────────────────────────────────

func _try_spawn_item() -> void:
	if _items.size() >= MAX_ITEMS_ALIVE:
		return
	var types: Array = _level_cfg.get("items", [])
	if types.is_empty():
		return
	var gp := _find_item_pos()
	if gp == Vector2i(-1, -1):
		return
	var tp: String = types[randi() % types.size()]
	var item: ItemBase
	match tp:
		"invincibility": item = _ITEM_INVINC.instantiate()
		"speed":         item = _ITEM_SPEED.instantiate()
		"freeze":        item = _ITEM_FREEZE.instantiate()
		_:               item = _ITEM_INVINC.instantiate()
	_item_container.add_child(item)
	item.setup(_grid, gp.x, gp.y, tp)
	item.position = Vector2(_wx(gp.x), _wy(gp.y))
	item.collected.connect(_on_item_collected)
	_items.append(item)

func _find_item_pos() -> Vector2i:
	var c: int = _grid.cols
	var r: int = _grid.rows
	var cands: Array = []
	for y in range(1, r - 1):
		for x in range(1, c - 1):
			if _grid.get_tile(x, y) != GridManager.T_ACTIVE:
				continue
			var wp := Vector2(_wx(x), _wy(y))
			if wp.distance_to(_player.position) < _grid.tile_size * 3:
				continue
			var near := false
			for e in _enemies:
				if is_instance_valid(e) and e.alive and e.pixel_pos.distance_to(wp) < _grid.tile_size * 2:
					near = true
					break
			if not near:
				cands.append(Vector2i(x, y))
	if cands.is_empty():
		return Vector2i(-1, -1)
	return cands[randi() % cands.size()]

func _on_item_collected(item: ItemBase) -> void:
	_items.erase(item)
	AudioManager.play_item()
	match item.item_type:
		"invincibility": _player.apply_invincibility(3.0)
		"speed":         _player.apply_speed(5.0)
		"freeze":
			_freeze_all(1.5)
			AudioManager.play_freeze()
	item.queue_free()

func _freeze_all(dur: float) -> void:
	for e in _enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		if e is EnemyBase:
			(e as EnemyBase).freeze(dur)
		elif e is RestorerEnemy:
			(e as RestorerEnemy).freeze(dur)

# ── Helpers ──────────────────────────────────────────────────────────

func _count_alive() -> int:
	var n := 0
	for e in _enemies:
		if is_instance_valid(e) and e.alive:
			n += 1
	return n

func _clean_dead() -> void:
	var live: Array = []
	for e in _enemies:
		if is_instance_valid(e) and (e.alive or e.dying):
			live.append(e)
		elif is_instance_valid(e):
			e.queue_free()
	_enemies = live

# ── Win / Lose ────────────────────────────────────────────────────────

func _check_win() -> void:
	if _game_over:
		return
	if _count_alive() == 0:
		_game_over = true
		await get_tree().create_timer(1.5).timeout
		_go_result(true)

func _go_result(won: bool) -> void:
	var lvl := GameState.current_level
	if won:
		GameState.record_time(lvl, _elapsed)
		GameState.unlock_next(lvl)
		GameState.record_stars(lvl, _stars_collected)
	GameState.set_meta("last_won", won)
	GameState.set_meta("last_time", _elapsed)
	GameState.set_meta("last_level", lvl)
	GameState.set_meta("last_stars", _stars_collected)
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

func _on_time_up() -> void:
	if _game_over:
		return
	_game_over = true
	_player.alive = false
	_grid.clear_trail()
	AudioManager.play_die()
	_elapsed = _time_limit
	_update_hud()
	await get_tree().create_timer(0.8).timeout
	_go_result(false)

# ── Main loop ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _game_over or _paused_internal:
		return

	_elapsed += delta
	if _elapsed >= _time_limit:
		_on_time_up()
		return

	_item_timer -= delta
	if _item_timer <= 0.0:
		_item_timer = _level_cfg.get("item_interval", 15.0)
		_try_spawn_item()

	if not _player.alive:
		return

	for star in _stars.duplicate():
		if is_instance_valid(star):
			star.check_collect(_player.position)

	for item in _items.duplicate():
		if is_instance_valid(item):
			item.check_collect(_player.position)

	for p in _projectiles.duplicate():
		if is_instance_valid(p):
			p.check_player(_player.position)

	for e in _enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var overlaps_pl: bool
		var overlaps_trl: bool
		if e is EnemyBase:
			var eb := e as EnemyBase
			overlaps_pl = eb.overlaps_player(_player.position)
			overlaps_trl = eb.overlaps_trail()
		else:
			var re := e as RestorerEnemy
			overlaps_pl = re.overlaps_player(_player.position)
			overlaps_trl = re.overlaps_trail()

		if overlaps_trl and _player.is_cutting:
			_player.take_hit()
			break
		if overlaps_pl:
			_player.take_hit()
			break

	_update_hud()

	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()

func _update_hud() -> void:
	var remaining: float = max(0.0, _time_limit - _elapsed)
	var m := int(remaining / 60)
	var s := int(remaining) % 60
	_timer_label.text  = "TIME  %02d:%02d" % [m, s]
	if remaining <= 10.0:
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_timer_label.remove_theme_color_override("font_color")
	#_stars_label.text  = "STARS  %d/%d" % [_stars_collected, TOTAL_STARS]
	_heart1.texture = _HEART_FULL if _lives >= 1 else _HEART_EMPTY
	_heart2.texture = _HEART_FULL if _lives >= 2 else _HEART_EMPTY
	_heart3.texture = _HEART_FULL if _lives >= 3 else _HEART_EMPTY
	var fx: Array = []
	if _player.is_invincible:
		fx.append("STAR %.1fs" % _player._inv_timer)
	if _player.speed_multiplier > 1.0:
		fx.append("FAST %.1fs" % _player._spd_timer)
	_effect_label.text = "  ".join(fx)

func _toggle_pause() -> void:
	_paused_internal = not _paused_internal
	_pause_panel.visible = _paused_internal
	get_tree().paused = _paused_internal
