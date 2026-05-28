extends PlayerState

func _enter() -> void:
	obj.play_anim("idle", obj.get_direction())

func _update(delta: float) -> void:
	if not obj.alive:
		change_state(fsm.states.dead)
		return
	obj._tick_timers(delta)
	obj._update_visual(delta)
	var dir := get_input_dir()
	if dir != Vector2i.ZERO:
		obj.step(dir)
		change_state(fsm.states.move)
		return
	obj.play_anim("idle", obj.get_direction())
