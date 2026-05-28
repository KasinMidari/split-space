class_name ItemInvincibility
extends ItemBase

@export var color_body: Color = Color(1.0, 0.9, 0.1)
@export var color_star: Color = Color(1.0, 1.0, 0.5, 0.5)
@export var bob_speed: float = 3.5
@export var bob_amplitude: float = 2.5

func _draw() -> void:
	var h := _tile_size * 0.35
	var bob := sin(_bob_timer * bob_speed) * bob_amplitude
	draw_rect(Rect2(-h, -h + bob, h * 2, h * 2), color_body)
	draw_rect(Rect2(-h + 3, -h + 3 + bob, (h - 3) * 2, (h - 3) * 2), Color(1, 1, 1, 0.4))
	draw_rect(Rect2(-h, -h + bob, h * 2, h * 2), color_body.lightened(0.3), false, 1.5)
	for i in range(4):
		var a := i * TAU * 0.25 + _bob_timer * 2.0
		draw_line(Vector2(0, bob),
				  Vector2(cos(a), sin(a)) * (h + 5) + Vector2(0, bob),
				  color_star, 1.5)
