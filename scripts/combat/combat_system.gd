extends Node
## One post-movement combat pass. No per-tower timers, physics bodies or raycasts.
const SpatialIndex = preload("res://scripts/combat/enemy_spatial_index.gd")
const Visuals = preload("res://scenes/effects/attack_visuals.tscn")
var tower_map: Node3D
var wave: Node
var map: GridMap
var enabled := true
var elapsed := 0.0
var shots_fired := 0
var projectiles: Array[Dictionary] = []
var visuals: Node3D
var _index := SpatialIndex.new()

func _ready() -> void:
	process_priority = 50
	_index.map = map
	visuals = Visuals.instantiate()
	add_child(visuals)
	visuals.projectiles = projectiles

func _process(delta: float) -> void:
	if map == null or not is_instance_valid(wave) or not is_instance_valid(tower_map):
		return
	var step := maxf(0.0, delta)
	elapsed += step
	if wave.alive == 0 and projectiles.is_empty():
		return
	if tower_map.towers.is_empty() and projectiles.is_empty():
		return
	_index.rebuild(wave.living_enemies(), map)
	# Existing flights age before new shots; a shot fired this frame starts at zero.
	for i in range(projectiles.size()-1, -1, -1):
		var shot: Dictionary = projectiles[i]
		if shot.get("arrow", false):
			if _advance_arrow(shot, step):
				projectiles.remove_at(i)
			continue
		shot.age += step
		if shot.age >= shot.duration:
			for target in _index.targets_in(shot.cell, shot.radius):
				shot.payload.apply(target)
			visuals.add_impact(shot.end, shot.radius, shot.color, map)
			projectiles.remove_at(i)
	if not enabled:
		return
	for tower: DefenseTower in tower_map.towers.values():
		if tower.is_queued_for_deletion() or tower.health <= 0 or tower.attack == null:
			continue
		var target: Node3D
		if tower.definition != null and tower.definition.attack_area != null:
			# An outside tile must never steal a shot from an asymmetric shape.
			target = _index.target_in_offsets(tower.grid_cell, tower.attack_offsets())
		else:
			# Circular lookahead preserves nearest-first priority in one query.
			target = _index.target_for(tower.grid_cell, tower.attack_radius+TowerConstants.AIM_LOOKAHEAD_TILES)
		if target == null:
			continue
		var aligned := tower.aim_at(aim_position(target, tower.attack), step)
		if elapsed < tower.next_attack_time or not aligned:
			continue
		if not tower.covers_cell(_index.cell_for(target.global_position)):
			continue
		if not tower.attack.configuration_error().is_empty() or not is_finite(tower.attack_interval) or tower.attack_interval <= 0:
			continue
		tower.attack.fire(self, tower, target)
		tower.next_attack_time = elapsed+tower.attack_interval
		shots_fired += 1

func aim_position(target: Node3D, attack: TowerAttack) -> Vector3:
	if attack is ProjectileAttack:
		var cell := _index.cell_for(target.global_position)
		return map.to_global(map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*0.08)
	return _arrow_target_position(target)

func fire_beam(tower: Node3D, target: Node3D, attack: BeamAttack) -> void:
	var end: Vector3 = target.global_position+map.global_basis*Vector3(0, 0.3, 0)
	visuals.add_beam(tower.muzzle_position(), end, attack.color, attack.trail_width, attack.trail_duration)
	AttackPayload.new(tower, target, attack).apply(target)

func fire_arrow(tower: Node3D, target: Node3D, attack: ArrowAttack) -> void:
	var end := _arrow_target_position(target)
	var start: Vector3 = tower.muzzle_position()
	projectiles.append({"arrow": true, "start": start, "position": start, "end": end, "direction": (end-start).normalized(), "target": weakref(target), "travelled": 0.0, "speed": attack.speed, "length": attack.arrow_length, "width": attack.arrow_width, "trail_length": attack.trail_length, "trail_width": attack.trail_width, "color": attack.color, "payload": AttackPayload.new(tower, target, attack)})

func _arrow_target_position(target: Node3D) -> Vector3:
	return target.global_position+map.global_basis*Vector3(0, 0.3, 0)

func _advance_arrow(shot: Dictionary, delta: float) -> bool:
	var target := shot.target.get_ref() as Node3D
	# Follow only the original target; if it dies or exits, finish at its last position.
	if target != null and target.can_be_targeted():
		shot.end = _arrow_target_position(target)
	var offset: Vector3 = shot.end-shot.position
	var distance := offset.length()
	if distance > 0.000001:
		shot.direction = offset/distance
	var travel := minf(distance, shot.speed*delta)
	shot.position += shot.direction*travel
	shot.travelled += travel
	if travel < distance:
		return false
	shot.payload.apply(target)
	return true

func fire_projectile(tower: Node3D, target: Node3D, attack: ProjectileAttack) -> void:
	var cell := _index.cell_for(target.global_position)
	var end := aim_position(target, attack)
	projectiles.append({"start": tower.muzzle_position(), "end": end, "cell": cell, "age": 0.0, "duration": attack.flight_time, "radius": attack.splash_radius, "arc": attack.arc_height, "visual_size": attack.visual_size, "color": attack.color, "payload": AttackPayload.new(tower, target, attack)})
