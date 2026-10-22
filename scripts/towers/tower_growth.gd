@tool
class_name TowerGrowth
extends Resource
## Multipliers per added level; no special abilities or hidden diminishing curve.
@export var damage := 1.35
@export var interval := 0.95
@export var health := 1.0
@export var friendly_health := 1.30
@export var friendly_damage := 1.35
@export var max_level := 3

func multiplier(value: float, level: int) -> float:
	return pow(value, level-1)

func configuration_error() -> String:
	for value in [damage, interval, health, friendly_health, friendly_damage]:
		if not is_finite(value) or value <= 0: return "升級倍率必須是正有限數值"
	return "升級上限無效" if max_level < 1 else ""
