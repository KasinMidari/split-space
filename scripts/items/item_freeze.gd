class_name ItemFreeze
extends ItemBase

@export var color_body: Color = Color(0.5, 0.9, 1.0)
@export var color_branch: Color = Color(0.7, 1.0, 1.0)
@export var bob_speed: float = 3.5
@export var bob_amplitude: float = 2.5
@export var spin_speed: float = 1.5

func _draw() -> void:
	var h := _tile_size * 0.35
	var bob := sin(_bob_timer * bob_speed) * bob_amplitude
	for i in range(6):
		var a := i * TAU / 6.0 + _bob_timer * spin_speed
		var p1 := Vector2(cos(a), sin(a)) * h + Vector2(0, bob)
		var p2 := Vector2(cos(a + PI), sin(a + PI)) * h + Vector2(0, bob)
		draw_line(p1, p2, color_body, 2.0)
		var pm := (p1 + Vector2(0, bob)) * 0.5 + Vector2(0, bob * 0.5)
		var a2 := a + TAU / 12.0
		draw_line(pm, pm + Vector2(cos(a2), sin(a2)) * h * 0.3, color_branch, 1.5)
	draw_circle(Vector2(0, bob), 4.0, Color(0.8, 1.0, 1.0))
