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
## Display only: lob a dynamite bundle that lands exactly as the disable applies.
@export var throws_bomb := false
## Fraction of the wind-up spent winding back before the bomb leaves the hand.
@export_range(0.0, 0.9, 0.05) var throw_at := 0.35
const BEAM_COLOR := Color("e0ac63")
const ThrownBomb = preload("res://scripts/enemies/rendering/thrown_bomb.gd")
var bombs: Array = []
var clock := 0.0
var remaining := 0.0
@export var plant_feet := false
## Display only: where the aim line starts, in the caster's frame (x right, y up,
## z forward along its walk), e.g. the boss rider's gun muzzle.
@export var beam_origin := Vector3(0, 0.5, 0)
## Display only: the shot is a lightning bolt from beam_origin to each target.
@export var lightning := false
const HitSparks = preload("res://scripts/combat/rendering/hit_sparks.gd")
const LightningBolt = preload("res://scripts/combat/rendering/lightning_bolt.gd")
const CHARGE_COLOR := Color(0.6, 0.82, 1.0, 0.5)
var marked: Array[WeakRef] = []

func start() -> void:
	clock = interval
	remaining = 0.0
	marked.clear()

func is_casting() -> bool:
	return remaining > 0

func movement_hold_remaining() -> float:
	return remaining if plant_feet else 0.0

func update(host: Node, delta: float) -> void:
	if radius <= 0: return
	if remaining > 0:
		if not _legal(host, target()):
			_cancel()
			return
		remaining = maxf(0, remaining-delta)
		enemy.skill_progress = 1.0-remaining/windup
		host.visual(enemy).casting(enemy.skill_progress, host.world_radius(radius))
		if throws_bomb: _fly_bombs(host)
		else:
			for tower in _towers(host):
				host.beam(_origin(), tower.global_position+Vector3.UP*0.8, CHARGE_COLOR if lightning else BEAM_COLOR, 0.012 if lightning else 0.025)
			# Charging: small arcs crackle around the muzzle, more as the cast fills.
			if lightning and randf() < 0.25+0.6*enemy.skill_progress:
				var spark := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()*0.22
				host.beam(_origin(), _origin()+spark, Color(0.85, 0.94, 1.0), 0.02, 0.05)
		if remaining <= 0:
			if not throws_bomb:
				# The shot: a flash at the muzzle and sparks on each disabled tower.
				HitSparks.hit(_origin(), _origin()-_forward(), "zap" if lightning else "bullet")
				for tower in _towers(host):
					var at := tower.global_position+Vector3.UP*0.8
					HitSparks.hit(at, _origin(), "zap" if lightning else "shell")
					if lightning:
						var bolt: Node = LightningBolt.new()
						bolt.from = _origin()
						bolt.to = at
						bolt.host = host
						host.add_child(bolt)
			for tower in _towers(host):
				tower.apply_disable(enemy, duration)
				host.disables += 1
			for bomb in bombs:
				if is_instance_valid(bomb): bomb.explode()
			bombs.clear()
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
	host.visual(enemy).casting(0.0, host.world_radius(radius))

func stop() -> void:
	for bomb in bombs:
		if is_instance_valid(bomb): bomb.fizzle()
	bombs.clear()
	marked.clear()
	remaining = 0.0
	enemy.skill_progress = -1.0
	if is_instance_valid(enemy.ability_visual): enemy.ability_visual.stop_cast()

func _fly_bombs(host: Node) -> void:
	var t: float = (enemy.skill_progress-throw_at)/maxf(0.01, 1.0-throw_at)
	if t < 0.0: return
	var towers := _towers(host)
	if bombs.is_empty():
		for tower in towers:
			var bomb: Node3D = ThrownBomb.new()
			bomb.caster = weakref(enemy)
			host.add_child(bomb)
			bombs.append(bomb)
	for i in mini(bombs.size(), towers.size()):
		var bomb: Node3D = bombs[i]
		if not is_instance_valid(bomb): continue
		bomb.from = enemy.global_position+Vector3.UP*0.55
		bomb.to = towers[i].global_position+Vector3.UP*1.15   # lands on the tower top, not inside it
		bomb.set_flight(t)

func _forward() -> Vector3:
	var forward: Vector3 = enemy.move_direction
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD

func _origin() -> Vector3:
	var forward := _forward()
	return enemy.global_position+forward.cross(Vector3.UP)*beam_origin.x+Vector3.UP*beam_origin.y+forward*beam_origin.z

## The tower the cast is aimed at; null when none or already gone.
func target() -> DefenseTower:
	var tower := marked[0].get_ref() as DefenseTower if not marked.is_empty() else null
	return tower if _on_battlefield(tower) else null

static func _on_battlefield(tower: DefenseTower) -> bool:
	return is_instance_valid(tower) and tower.is_inside_tree() and not tower.is_queued_for_deletion()

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
	if not _on_battlefield(tower) or tower.health <= 0: return false
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
