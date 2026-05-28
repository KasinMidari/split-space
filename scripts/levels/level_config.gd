@tool
class_name LevelConfig
extends Node

@export var level_name: String = ""
@export var cols: int = 20:
	set(v):
		cols = v
		_auto_regen()
@export var rows: int = 14:
	set(v):
		rows = v
		_auto_regen()
@export var items: Array[String] = []
@export var item_interval: float = 18.0

# (0,0) = auto-center at runtime. Set manually or click button below.
@export var grid_position: Vector2 = Vector2.ZERO

@export_tool_button("Regenerate Grid Tiles", "Refresh")
var _regen_btn = regen_tiles

@export_tool_button("Center in 800x600", "Play")
var _center_btn = center_in_viewport

func center_in_viewport() -> void:
	if not Engine.is_editor_hint():
		return
	var effective_ts := 16.0
	var active_layer := get_node_or_null("TileActive") as TileMapLayer
	if active_layer and active_layer.tile_set:
		effective_ts = active_layer.tile_set.tile_size.x * active_layer.scale.x
	grid_position = Vector2(
		int((800.0 - cols * effective_ts) * 0.5),
		int((600.0 - rows * effective_ts) * 0.5)
	)
	notify_property_list_changed()

func to_dict() -> Dictionary:
	return {
		"name": level_name,
		"cols": cols,
		"rows": rows,
		"items": items,
		"item_interval": item_interval,
		"grid_position": grid_position,
	}

func get_border_layer() -> TileMapLayer:
	return get_node_or_null("TileBorder") as TileMapLayer

func get_active_layer() -> TileMapLayer:
	return get_node_or_null("TileActive") as TileMapLayer

func get_decoration_layers() -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	for child in get_children():
		if child is TileMapLayer and child.name != "TileBorder" and child.name != "TileActive":
			result.append(child as TileMapLayer)
	return result

func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_auto_regen")
		return
	var active := get_node_or_null("TileActive") as TileMapLayer
	if active:
		active.visible = false

func _auto_regen() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var border := get_node_or_null("TileBorder") as TileMapLayer
	var active := get_node_or_null("TileActive") as TileMapLayer
	if not border or not active:
		return
	if border.get_used_cells().size() > 0 or active.get_used_cells().size() > 0:
		return
	regen_tiles()

func regen_tiles() -> void:
	if not is_inside_tree():
		return
	var border := get_node_or_null("TileBorder") as TileMapLayer
	var active := get_node_or_null("TileActive") as TileMapLayer
	if not border or not active:
		return
	border.clear()
	active.clear()
	var bc: Array[Vector2i] = []
	var ac: Array[Vector2i] = []
	for y in range(rows):
		for x in range(cols):
			if x == 0 or y == 0 or x == cols - 1 or y == rows - 1:
				bc.append(Vector2i(x, y))
			else:
				ac.append(Vector2i(x, y))
	if not bc.is_empty():
		border.set_cells_terrain_connect(bc, 0, 1)
	if not ac.is_empty():
		active.set_cells_terrain_connect(ac, 0, 0)
