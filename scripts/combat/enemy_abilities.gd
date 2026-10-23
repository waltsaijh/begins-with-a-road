extends Node
## One shared post-movement pass; ability clocks belong to individual enemies.
const AbilityVisual = preload("res://scripts/enemies/rendering/ability_visual.gd")
var combat: Node
var heals := 0
var disables := 0

func _ready() -> void:
	process_priority = 40
	if is_instance_valid(combat.wave) and combat.wave.has_signal("wave_finished"):
		combat.wave.wave_finished.connect(clear)

func _process(delta: float) -> void:
	if not is_instance_valid(combat.wave) or not is_instance_valid(combat.tower_map): return
	combat._index.rebuild(combat.wave.living_enemies(),combat.map)
	combat.friendly_index_ready = true
	advance(maxf(0,delta))

func clear() -> void:
	for tower: DefenseTower in combat.tower_map.towers.values(): tower.clear_disable()
	for enemy in combat.wave.living_enemies():
		enemy.cast_target = null
		enemy.cast_remaining = 0.0
		enemy.skill_progress = -1.0
		if is_instance_valid(enemy.ability_visual): enemy.ability_visual.stop_cast()

func advance(delta: float) -> void:
	for tower: DefenseTower in combat.tower_map.towers.values(): tower.advance_disable(delta)
	if not combat.wave.active: return
	for enemy in combat.wave.living_enemies():
		var settings: Dictionary = enemy.abilities
		if settings.get("heal_amount",0.0) > 0:
			enemy.heal_clock -= delta
			if enemy.heal_clock <= 0:
				# One pulse per frame, bounded work after a stall; no accumulated burst.
				enemy.heal_clock = settings.heal_interval
				var restored := 0.0
				for ally in combat._index.targets_near(enemy.global_position,settings.heal_radius):
					restored += ally.heal(settings.heal_amount)
				if restored > 0:
					heals += 1
					_visual(enemy).heal_pulse()
		if settings.get("sabotage_radius",0.0) <= 0: continue
		if enemy.cast_remaining > 0:
			var target := enemy.cast_target.get_ref() as DefenseTower if enemy.cast_target != null else null
			if not _legal_target(enemy,target):
				_cancel_cast(enemy)
				continue
			enemy.cast_remaining = maxf(0,enemy.cast_remaining-delta)
			enemy.skill_progress = 1.0-enemy.cast_remaining/settings.sabotage_windup
			_visual(enemy).casting(enemy.skill_progress)
			combat.visuals.add_beam(enemy.global_position+Vector3.UP*0.5,target.global_position+Vector3.UP*0.8,Color("e0ac63"),0.025,0.12)
			if enemy.cast_remaining <= 0:
				target.apply_disable(enemy,settings.sabotage_duration)
				disables += 1
				_cancel_cast(enemy)
			continue
		enemy.sabotage_clock -= delta
		if enemy.sabotage_clock > 0: continue
		var candidates: Array[DefenseTower] = []
		for tower: DefenseTower in combat.tower_map.towers.values():
			if _legal_target(enemy,tower): candidates.append(tower)
		candidates.sort_custom(func(a: DefenseTower,b: DefenseTower):
			var da: float = enemy.global_position.distance_squared_to(a.global_position)
			var db: float = enemy.global_position.distance_squared_to(b.global_position)
			if not is_equal_approx(da,db): return da < db
			return a.grid_cell.x < b.grid_cell.x if a.grid_cell.x != b.grid_cell.x else a.grid_cell.y < b.grid_cell.y)
		if not candidates.is_empty():
			enemy.cast_target = weakref(candidates[0])
			enemy.cast_remaining = settings.sabotage_windup
			enemy.skill_progress = 0.0
			_visual(enemy).casting(0.0)

func _cancel_cast(enemy: Node3D) -> void:
	enemy.cast_target = null
	enemy.cast_remaining = 0.0
	enemy.skill_progress = -1.0
	enemy.sabotage_clock = enemy.abilities.sabotage_interval
	if is_instance_valid(enemy.ability_visual): enemy.ability_visual.stop_cast()

func _legal_target(enemy: Node3D, tower: DefenseTower) -> bool:
	if not is_instance_valid(tower) or tower.is_queued_for_deletion() or tower.health <= 0: return false
	if tower.attack == null and tower.deployment == null: return false
	return combat.barracks.distance(enemy.global_position,tower.global_position) <= enemy.abilities.sabotage_radius

func _visual(enemy: Node3D) -> Node3D:
	if not is_instance_valid(enemy.ability_visual):
		enemy.ability_visual = AbilityVisual.new()
		enemy.add_child(enemy.ability_visual)
	return enemy.ability_visual

## Called only AFTER attack eligibility/range filtering. Stable priority, then
## distance to the tower, then spawn ID; never taunts an ALL-target attack.
func preferred(tower: DefenseTower, candidates: Array[Node3D]) -> Node3D:
	var best: Node3D
	var priority := -1
	var distance := INF
	for enemy in candidates:
		var radius := float(enemy.abilities.get("taunt_radius",0.0))
		if radius <= 0: continue
		var at: float = combat.barracks.distance(enemy.global_position,tower.combat_origin())
		if at > radius: continue
		var rank := int(enemy.abilities.get("taunt_priority",1))
		if best == null or rank > priority or (rank == priority and (at < distance or (is_equal_approx(at,distance) and enemy.enemy_id < best.enemy_id))):
			best = enemy
			priority = rank
			distance = at
	return best
