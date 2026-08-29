class_name LevelData

const LEVELS: Array = [
	{
		"name": "Level 1 - Tập sự",
		"cols": 20, "rows": 14,
		"basic_count": 3, "shooter_count": 0, "restorer_count": 0,
		"items": [],
		"item_interval": 18.0,
		"time_limit": 90.0,
		"enemy_speed": 55.0,
	},
	{
		"name": "Level 2 - Nóng dần",
		"cols": 22, "rows": 16,
		"basic_count": 4, "shooter_count": 1, "restorer_count": 0,
		"items": [],
		"item_interval": 14.0,
		"time_limit": 100.0,
		"enemy_speed": 65.0,
	},
	{
		"name": "Level 3 - Hỗn loạn",
		"cols": 24, "rows": 16,
		"basic_count": 5, "shooter_count": 2, "restorer_count": 1,
		"items": ["invincibility", "speed", "freeze"],
		"item_interval": 12.0,
		"time_limit": 110.0,
		"enemy_speed": 72.0,
	},
	{
		"name": "Level 4 - Ác mộng",
		"cols": 26, "rows": 18,
		"basic_count": 6, "shooter_count": 2, "restorer_count": 2,
		"items": ["invincibility", "speed", "freeze"],
		"item_interval": 10.0,
		"time_limit": 120.0,
		"enemy_speed": 80.0,
	},
	{
		"name": "Level 5 - Địa ngục",
		"cols": 28, "rows": 18,
		"basic_count": 8, "shooter_count": 3, "restorer_count": 2,
		"items": ["invincibility", "speed", "freeze"],
		"item_interval": 8.0,
		"time_limit": 130.0,
		"enemy_speed": 90.0,
	},
]

static func get_level(id: int) -> Dictionary:
	var idx := id - 1
	if idx < 0 or idx >= LEVELS.size():
		return {}
	return LEVELS[idx]

static func count() -> int:
	return LEVELS.size()
