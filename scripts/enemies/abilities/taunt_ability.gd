@tool
class_name TauntAbility
extends EnemyAbility
## Draws single-target attacks that could already hit this enemy. Checked only
## after range/eligibility filtering; area-all attacks are never redirected.
@export_range(0.0, 10.0, 0.1, "or_greater") var radius := 3.5
## Higher wins; ties go to the tower-nearest enemy, then the earlier spawn.
@export_range(0, 10, 1) var priority := 1

func taunt_rank(distance: float) -> int:
	return priority if radius > 0 and distance <= radius else -1

func describe(english: bool) -> String:
	return (GameText.text("text.taunt_ability.1",{},english)) % str(snappedf(radius,0.01))

func configuration_error() -> String:
	if not is_finite(radius) or radius < 0: return "嘲諷半徑必須非負且有限"
	return ""
