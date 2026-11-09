@tool
class_name SabotageAbility
extends EnemyAbility
## Picks the nearest legal towers, winds up visibly, then disables them. A cast
## is cancelled when its first target becomes illegal; casting or cancelling
## restarts the cooldown. Disables end when this source dies or leaves.
@export_range(0.0, 10.0, 0.1, "or_greater") var radius := 3.0
@export_range(0.1, 30.0, 0.1, "or_greater") var interval := 6.0
@export_range(0.1, 5.0, 0.1, "or_greater") var windup := 1.0
@export_range(0.1, 10.0, 0.1, "or_greater") var duration := 2.5
@export_range(1, 4, 1) var targets := 1
const BEAM_COLOR := Color("e0ac63")
var clock := 0.0
var remaining := 0.0
var marked: Array[WeakRef] = []

func start() -> void:
	clock = interval
	remaining = 0.0
	marked.clear()

func is_casting() -> bool:
	return remaining > 0

func update(host: Node, delta: float) -> void:
	if radius <= 0: return
	if remaining > 0:
		if not _legal(host, target()):
			_cancel()
			return
		remaining = maxf(0, remaining-delta)
		enemy.skill_progress = 1.0-remaining/windup
		host.visual(enemy).casting(enemy.skill_progress)
		for tower in _towers(host):
			host.beam(enemy.global_position+Vector3.UP*0.5, tower.global_position+Vector3.UP*0.8, BEAM_COLOR)
		if remaining <= 0:
			for tower in _towers(host):
				tower.apply_disable(enemy, duration)
				host.disables += 1
			_trace({"phase":"pulse"})
			_cancel()
		return
	clock -= delta
	if clock > 0: return
	var candidates: Array[DefenseTower] = []
	for tower: DefenseTower in host.towers():
		if _legal(host, tower): candidates.append(tower)
	if candidates.is_empty(): return
	candidates.sort_custom(func(a: DefenseTower, b: DefenseTower):
		var da: float = enemy.global_position.distance_squared_to(a.global_position)
		var db: float = enemy.global_position.distance_squared_to(b.global_position)
		if not is_equal_approx(da, db): return da < db
		return a.grid_cell.x < b.grid_cell.x if a.grid_cell.x != b.grid_cell.x else a.grid_cell.y < b.grid_cell.y)
	marked.clear()
	for index in mini(targets, candidates.size()): marked.append(weakref(candidates[index]))
	_trace({"phase":"windup","targets":marked.size()})
	remaining = windup
	enemy.skill_progress = 0.0
	host.visual(enemy).casting(0.0)

func stop() -> void:
	marked.clear()
	remaining = 0.0
	enemy.skill_progress = -1.0
	if is_instance_valid(enemy.ability_visual): enemy.ability_visual.stop_cast()

## The tower the cast is aimed at; null when none or already gone.
func target() -> DefenseTower:
	return marked[0].get_ref() as DefenseTower if not marked.is_empty() else null

func _towers(host: Node) -> Array[DefenseTower]:
	var result: Array[DefenseTower] = []
	for reference in marked:
		var tower: DefenseTower = reference.get_ref()
		if _legal(host, tower): result.append(tower)
	return result

func _cancel() -> void:
	stop()
	clock = interval

func _legal(host: Node, tower: DefenseTower) -> bool:
	if not is_instance_valid(tower) or tower.is_queued_for_deletion() or tower.health <= 0: return false
	if tower.attack == null and tower.deployment == null: return false
	return host.distance(enemy.global_position, tower.global_position) <= radius

func _trace(data: Dictionary) -> void:
	if BalanceTrace.enabled and enemy.troop != null and enemy.troop.has_tag(&"boss"):
		BalanceTrace.event("boss_phase", str(enemy.enemy_id), data)

func describe(english: bool) -> String:
	return (GameText.text("text.sabotage_ability.1",{},english)) % ([str(snappedf(windup,0.01)),targets,str(snappedf(radius,0.01)),str(snappedf(duration,0.01)),str(snappedf(interval,0.01))] if english else [str(snappedf(windup,0.01)),str(snappedf(radius,0.01)),targets,str(snappedf(duration,0.01)),str(snappedf(interval,0.01))])

func configuration_error() -> String:
	if targets < 1 or targets > 4: return "癱瘓目標數必須在 1–4"
	if not is_finite(radius) or radius < 0: return "癱瘓半徑必須非負且有限"
	for value in [interval, windup, duration]:
		if not is_finite(value) or value <= 0: return "癱瘓時間必須為正有限數值"
	return ""
