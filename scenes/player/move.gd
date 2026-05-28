extends PlayerState

func _enter() -> void:
	obj.play_anim("", obj.get_direction())

func _update(delta: float) -> void:
	if not obj.alive:
		change_state(fsm.states.dead)
		return
	obj._tick_timers(delta)
	var dir := get_input_dir()
	if dir == Vector2i.ZERO:
		change_state(fsm.states.idle)
		return
	obj.set_direction(dir)
	obj._tick_movement(delta)
	obj._update_visual(delta)
	obj.play_anim("", obj.get_direction())
