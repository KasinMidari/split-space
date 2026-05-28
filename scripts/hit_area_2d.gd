extends Area2D
class_name HitArea2D

# damage of hit
@export var damage = 1

# signal when hit area
signal hitted(area)

func _init() -> void:
	area_entered.connect(_on_area_entered)

# called when hit area
func hit(hurt_area):
	if(hurt_area.has_method("take_damage")):
		var hit_dir:Vector2 = hurt_area.global_position - global_position
		var final_damage = damage
		var weapon_owner = owner # Usually the Player node
		if weapon_owner and weapon_owner.has_method("get_attack_damage"):
			final_damage = weapon_owner.get_attack_damage()
			if final_damage > damage:
				weapon_owner.play_collect_effect("damage_potion") 
		hurt_area.take_damage(hit_dir.normalized(), final_damage)
		print("Hit dealt: ", final_damage)

# called when area entered
func _on_area_entered(area):
	hit(area)
	hitted.emit(area)
