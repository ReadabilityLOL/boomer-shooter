# RevolverEquipped.gd
extends WeaponEquipped
func attack() -> void:
	# Instead of just printing, we now call the hitscan logic from our base class.
	fire_hitscan()
