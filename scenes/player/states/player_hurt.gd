extends PlayerState

var _timer: float = 0.0

func _enter() -> void:
	obj.is_invincible = true
	obj.is_cutting = false
	obj._blink = 0.0
	_timer = obj.hurt_duration
	obj.stop_motion()
	obj.play_anim("idle", obj.get_direction())

func _update(delta: float) -> void:
	if not obj.alive:
		try_change("dead")
		return

	_timer -= delta
	obj._blink += delta * 12.0

	if obj.speed_multiplier > 1.0:
		obj._spd_timer -= delta
		if obj._spd_timer <= 0.0:
			obj.speed_multiplier = 1.0

	var dir := get_input_dir()
	if dir != Vector2i.ZERO:
		obj.set_direction(dir)
		obj._tick_movement(delta)
		obj.play_anim("", obj.get_direction())
	else:
		obj.play_anim("idle", obj.get_direction())

	obj._update_visual(delta)

	if _timer <= 0.0:
		_exit_hurt()

func _exit() -> void:
	if obj.animated_sprite != null:
		obj.animated_sprite.visible = true

func _exit_hurt() -> void:
	# giữ invincible nếu còn item invincibility đang chạy
	if obj._inv_timer <= 0.0:
		obj.is_invincible = false
		obj._blink = 0.0
	try_change("idle")
