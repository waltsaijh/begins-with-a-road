@tool
class_name BeamAttack
extends TowerAttack
## Hits now; the short trail is purely visual and cannot hit a second time.
@export_range(0.01, 1.0, 0.01) var trail_duration := 0.12
@export_range(0.005, 0.3, 0.005) var trail_width := 0.035

func configuration_error() -> String:
	var error := super.configuration_error()
	if not error.is_empty():
		return error
	return "軌跡時間與寬度必須為正有限數值" if not is_finite(trail_duration) or trail_duration <= 0 or not is_finite(trail_width) or trail_width <= 0 else ""

func fire(combat: Node, tower: Node3D, target: Node3D) -> void:
	combat.fire_beam(tower, target, self)
