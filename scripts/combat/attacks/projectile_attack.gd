@tool
class_name ProjectileAttack
extends TowerAttack
## Fixed landing tile: enemies can leave the area before impact.
@export_range(0.05, 5.0, 0.05, "or_greater") var flight_time := 0.6
@export_range(0.0, 10.0, 0.5, "or_greater") var splash_radius := 1.5
@export_range(0.0, 4.0, 0.1) var arc_height := 0.8
@export_range(0.02, 0.3, 0.01) var visual_size := 0.09

func configuration_error() -> String:
	var error := super.configuration_error()
	if not error.is_empty():
		return error
	if not is_finite(flight_time) or flight_time <= 0 or not is_finite(splash_radius) or splash_radius < 0:
		return "飛行時間必須為正、爆炸半徑必須非負，且為有限數值"
	return "投射物外觀數值無效" if not is_finite(arc_height) or arc_height < 0 or not is_finite(visual_size) or visual_size <= 0 else ""

func fire(combat: Node, tower: Node3D, target: Node3D) -> void:
	combat.fire_projectile(tower, target, self)
