@tool
class_name HealAbility
extends EnemyAbility
## Periodically heals living, injured allies in range (itself included), never
## above maximum health.
@export_range(0.0, 1000.0, 1.0, "or_greater") var amount := 18.0
@export_range(0.1, 20.0, 0.1, "or_greater") var interval := 3.0
@export_range(0.0, 10.0, 0.1, "or_greater") var radius := 2.5
var clock := 0.0

func start() -> void:
	clock = interval

func update(host: Node, delta: float) -> void:
	if amount <= 0: return
	clock -= delta
	if clock > 0: return
	# One pulse per frame, bounded work after a stall; no accumulated burst.
	clock = interval
	var restored := 0.0
	for ally in host.enemies_near(enemy.global_position, radius):
		restored += ally.heal(amount)
	if restored > 0:
		host.heals += 1
		host.visual(enemy).heal_pulse()

func describe(english: bool) -> String:
	return (GameText.text("text.heal_ability.1",{},english)) % ([str(snappedf(interval,0.01)),str(snappedf(amount,0.01)),str(snappedf(radius,0.01))] if english else [str(snappedf(interval,0.01)),str(snappedf(radius,0.01)),str(snappedf(amount,0.01))])

func configuration_error() -> String:
	if not is_finite(amount) or amount < 0 or not is_finite(radius) or radius < 0: return "治療量與半徑必須非負且有限"
	if not is_finite(interval) or interval <= 0: return "治療間隔必須為正有限數值"
	return ""
