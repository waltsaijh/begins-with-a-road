extends Node
## One post-movement combat pass. No per-tower timers, physics bodies or raycasts.
const SpatialIndex = preload("res://scripts/combat/enemy_spatial_index.gd")
const Visuals = preload("res://scenes/effects/attack_visuals.tscn")
const RelicCombat = preload("res://scripts/combat/relic_combat.gd")
var tower_map: Node3D
var wave: Node
var map: GridMap
var enabled := true
var elapsed := 0.0
var shots_fired := 0
var projectiles: Array[Dictionary] = []
var visuals: Node3D
var _index := SpatialIndex.new()
var barracks: Node3D
var friendly_index_ready := false
var enemy_abilities: Node

func _ready() -> void:
	process_priority = 50
	_index.map = map
	visuals = Visuals.instantiate()
	add_child(visuals)
	visuals.projectiles = projectiles
	barracks = preload("res://scripts/combat/barracks_system.gd").new()
	barracks.combat = self
	add_child(barracks)
	enemy_abilities = preload("res://scripts/combat/enemy_abilities.gd").new()
	enemy_abilities.combat = self
	add_child(enemy_abilities)
	if is_instance_valid(wave) and wave.has_signal("wave_finished"):
		wave.wave_finished.connect(func():
			for tower: DefenseTower in tower_map.towers.values(): tower.rapid_remaining = 0)

func _process(delta: float) -> void:
	var reuse_index := friendly_index_ready
	friendly_index_ready = false
	if map == null or not is_instance_valid(wave) or not is_instance_valid(tower_map):
		return
	var step := maxf(0.0, delta)
	elapsed += step
	if wave.alive == 0 and projectiles.is_empty():
		return
	if tower_map.towers.is_empty() and projectiles.is_empty():
		return
	if not reuse_index: _index.rebuild(wave.living_enemies(), map)
	# Existing flights age before new shots; a shot fired this frame starts at zero.
	for i in range(projectiles.size()-1, -1, -1):
		var shot: Dictionary = projectiles[i]
		if shot.get("arrow", false):
			if (_advance_piercing_bolt(shot, step) if shot.get("piercing",false) else _advance_arrow(shot, step)):
				projectiles.remove_at(i)
			continue
		shot.age += step
		if shot.age >= shot.duration:
			if shot.get("mortar",false):
				_impact_mortar(shot)
			elif not shot.get("visual_only",false):
				for target in _index.targets_in(shot.cell, shot.radius):
					shot.payload.apply(target)
			if not shot.get("mortar",false): visuals.add_impact(shot.end, shot.radius, shot.color, map)
			projectiles.remove_at(i)
	if not enabled:
		return
	for tower: DefenseTower in tower_map.towers.values():
		if tower.is_queued_for_deletion() or tower.health <= 0 or tower.attack == null or tower.is_disabled():
			continue
		if wave.active: RelicCombat.advance(self,tower,step)
		var target: Node3D = tower.attack.select_target(self,tower)
		if target == null:
			continue
		var aligned := tower.aim_at(aim_position(target, tower.attack), step)
		if elapsed < tower.next_attack_time or not aligned:
			continue
		if not tower.attack is VolleyAttack and not tower.covers_cell(_index.cell_for(target.global_position)):
			continue
		if not tower.attack.configuration_error().is_empty() or not is_finite(tower.attack_interval) or tower.attack_interval <= 0:
			continue
		tower.prepare_shot(target)
		tower.attack.fire(self, tower, target)
		tower.present_shot(target,visuals)
		tower.next_attack_time = elapsed+tower.attack_interval
		shots_fired += 1

func default_target(tower: DefenseTower) -> Node3D:
	var preferred: Node3D = enemy_abilities.preferred(tower,targets_for(tower))
	if preferred != null: return preferred
	if tower.definition != null and tower.definition.attack_area != null:
		return _index.target_in_offsets(tower.grid_cell,tower.attack_offsets())
	return _index.target_for(tower.grid_cell,tower.attack_radius*tower.range_multiplier+TowerConstants.AIM_LOOKAHEAD_TILES)

func targets_for(tower: DefenseTower, strategy: TowerAttack = null) -> Array[Node3D]:
	if strategy == null: strategy = tower.attack
	var candidates: Array[Node3D]
	if strategy is VolleyAttack and strategy.circular_range:
		candidates = _index.targets_near(tower.combat_origin(),tower.attack_radius*tower.range_multiplier)
	else:
		var center := _index.cell_for(tower.combat_origin()) if tower.has_relic(&"departure") else tower.grid_cell
		candidates = _index.targets_in_offsets(center,tower.attack_offsets())
	return candidates.filter(func(enemy): return tower.can_attack_target(enemy))

func fire_mortar(tower: DefenseTower, target: Node3D, attack: VolleyAttack) -> void:
	tower.mortar_shots += 1
	var special := tower.has_relic(&"explosive_shell") and tower.mortar_shots % maxi(1,int(tower.relic_value(&"explosive_shell", &"every"))) == 0
	var radius := attack.splash_radius*(tower.relic_value(&"explosive_shell", &"radius_multiplier") if special else 1.0)
	var start := tower.muzzle_position()
	# Fixed actual position, including altitude. No cell snap, tracking or leading.
	var end := target.global_position
	var speed := attack.shell_speed*tower.relic_value(&"assembled_cannon", &"speed_multiplier",1.0)
	var distance := map.to_local(start).distance_to(map.to_local(end))/map.cell_size.x
	var duration := maxf(attack.shell_minimum_seconds,distance/attack.shell_speed)/maxf(0.000001,speed/attack.shell_speed)
	projectiles.append({"mortar":true,"start":start,"end":end,"age":0.0,"duration":duration,"radius":radius,"arc":attack.shell_arc_height,"visual_size":0.20 if special else 0.13,"color":Color("f18655") if special else attack.color,"payload":AttackPayload.new(tower,target,attack),"flying":tower.has_relic(&"air_strike"),"friendly":tower.relic_value(&"explosive_shell", &"friendly_multiplier") if special else 0.0})

func _impact_mortar(shot: Dictionary) -> void:
	for target in _index.targets_near(shot.end,shot.radius):
		if RelicCombat.tagged(target,&"flying") and not shot.flying: continue
		var offset := (map.to_local(target.global_position)-map.to_local(shot.end))/map.cell_size
		if offset.length_squared() <= shot.radius*shot.radius: shot.payload.apply(target)
	if shot.friendly > 0:
		# Snapshot values: destroying a tower mutates the live dictionary.
		for tower: DefenseTower in tower_map.towers.values():
			var offset := (map.to_local(tower.global_position)-map.to_local(shot.end))/map.cell_size
			if offset.length_squared() <= shot.radius*shot.radius: tower.take_damage(shot.payload.damage*shot.friendly)
	visuals.restored_bursts.mortar_impact(shot.end,shot.radius*map.cell_size.x)

func fire_piercing_bolt(tower: DefenseTower, target: Node3D, attack: TowerAttack) -> void:
	var start := tower.muzzle_position()
	var direction := target.global_position-start
	direction.y = 0
	if direction.length_squared() < 0.000001: return
	direction = direction.normalized()
	var reach := 0.0
	for offset in tower.attack_offsets(): reach = maxf(reach, Vector2(offset).length()+0.5)
	var distance := reach*map.cell_size.x*map.global_basis.x.length()
	var payload := AttackPayload.new(tower,target,attack)
	payload.knockback *= map.cell_size.x*map.global_basis.x.length()
	projectiles.append({"arrow":true,"piercing":true,"start":start,"position":start,"end":start+direction*distance,"direction":direction,"travelled":0.0,"speed":tower.relic_value(&"powerful_shot", &"speed"),"length":0.65,"width":0.07,"trail_length":0.8,"trail_width":0.04,"color":attack.color,"payload":payload,"hit_ids":{},"hit_width":tower.relic_value(&"powerful_shot", &"width")})

func _advance_piercing_bolt(shot: Dictionary, delta: float) -> bool:
	var before: Vector3 = shot.position
	shot.position = before.move_toward(shot.end, shot.speed*delta)
	shot.travelled += before.distance_to(shot.position)
	for target in _index.targets_along_segment(before,shot.position,shot.hit_width):
		var id := target.get_instance_id()
		if shot.hit_ids.has(id): continue
		shot.hit_ids[id] = true
		shot.payload.apply(target)
		visuals.restored_bursts.emit(target.global_position,"hit")
	return shot.position.is_equal_approx(shot.end)

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
