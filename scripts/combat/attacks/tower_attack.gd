@tool
class_name TowerAttack
extends Resource
## Stateless delivery strategy; runtime flight/target state belongs to CombatSystem.
@export_range(0.0, 10.0, 0.1, "or_greater") var damage_multiplier := 1.0
@export var effects: Array[HitEffect] = []
@export var color := Color("8c8c8c")

func configuration_error() -> String:
	if get_script().get_global_name() == &"TowerAttack":
		return "請選擇 ArrowAttack、BeamAttack、ProjectileAttack 或自訂攻擊類別"
	if not is_finite(damage_multiplier) or damage_multiplier < 0:
		return "攻擊傷害倍率必須為非負有限數值"
	for effect in effects:
		if effect != null and not effect.configuration_error().is_empty():
			return effect.configuration_error()
	return ""

func fire(_combat: Node, _tower: Node3D, _target: Node3D) -> void:
	push_error("TowerAttack subclasses must implement fire()")

func select_target(combat: Node, tower: Node3D) -> Node3D:
	return combat.default_target(tower)
