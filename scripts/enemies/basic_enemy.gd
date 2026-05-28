class_name BasicEnemy
extends EnemyBase

@export var color_body: Color = Color(0.9, 0.25, 0.25)
@export var color_frozen: Color = Color(0.5, 0.75, 1.0)

func setup_basic(gm: GridManager, px: float, py: float, vel: Vector2) -> void:
	setup(gm, px, py, vel)

	
