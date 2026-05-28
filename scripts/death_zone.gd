extends Area2D

signal player_died(player)

func _on_body_entered(body: Node):
	if body is Player:
		emit_signal("player_died", body)
