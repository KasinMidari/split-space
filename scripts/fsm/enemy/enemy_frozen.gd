extends FSMState

func _update(delta: float) -> void:
	obj._tick_frozen(delta)
