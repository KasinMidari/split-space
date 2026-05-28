class_name ItemSpeed
extends ItemBase

@export var color_body: Color = Color(0.2, 0.8, 1.0)
@export var bob_speed: float = 3.5
@export var bob_amplitude: float = 2.5

func _draw() -> void:
	var h := _tile_size * 0.35
	var bob := sin(_bob_timer * bob_speed) * bob_amplitude
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-h, -h * 0.4 + bob), Vector2(0, -h + bob),
			Vector2(h, -h * 0.4 + bob), Vector2(h * 0.4, -h * 0.4 + bob),
			Vector2(h * 0.4, h + bob), Vector2(-h * 0.4, h + bob),
			Vector2(-h * 0.4, -h * 0.4 + bob)
		]),
		color_body
	)
	draw_rect(Rect2(-h, -h + bob, h * 2, h * 2), color_body.lightened(0.4), false, 1.0)
