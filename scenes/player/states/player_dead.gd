extends PlayerState

func _enter() -> void:
	obj.alive = false
	obj.stop_motion()
	obj.play_anim("idle", obj.get_direction())

func _update(delta: float) -> void:
	obj._update_visual(delta)
