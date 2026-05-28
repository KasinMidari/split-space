class_name PlayerState
extends FSMState

func get_state(name: String) -> FSMState:
	if fsm == null:
		return null
	return fsm.states.get(name.to_lower())

func try_change(name: String) -> void:
	var state := get_state(name)
	if state != null:
		change_state(state)

func get_input_dir() -> Vector2i:
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("Right"):
		dir = Vector2i(1, 0)
	elif Input.is_action_pressed("Left"):
		dir = Vector2i(-1, 0)
	elif Input.is_action_pressed("Down"):
		dir = Vector2i(0, 1)
	elif Input.is_action_pressed("Up"):
		dir = Vector2i(0, -1)
	return dir


	
