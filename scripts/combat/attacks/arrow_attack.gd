@tool
class_name ArrowAttack
extends TowerAttack
## Fast single-target flight. Damage and effects are applied on arrival.
## World units per second. Arrow and trail dimensions below use world units too.
@export_range(1.0, 100.0, 1.0, "or_greater") var speed := 24.0
@export_range(0.05, 1.0, 0.01) var arrow_length := 0.36
@export_range(0.005, 0.1, 0.005) var arrow_width := 0.025
@export_range(0.0, 2.0, 0.05, "or_greater") var trail_length := 0.8
@export_range(0.005, 0.1, 0.005) var trail_width := 0.035

func configuration_error() -> String:
	var error := super.configuration_error()
	if not error.is_empty():
		return error
	for value: float in [speed, arrow_length, arrow_width, trail_width]:
		if not is_finite(value) or value <= 0:
			return "箭矢速度、長度與寬度必須為正有限數值"
	return "拖尾長度必須為非負有限數值" if not is_finite(trail_length) or trail_length < 0 else ""

func fire(combat: Node, tower: Node3D, target: Node3D) -> void:
	combat.fire_arrow(tower, target, self)
