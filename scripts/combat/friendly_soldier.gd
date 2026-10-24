extends Node3D
## Instance-local friendly state. No enemy pathfinding and no navigation occupancy.
var manager: Node
var tower: DefenseTower
var settings: BarracksDeployment
var home := Vector2i.ZERO
var home_position := Vector3.ZERO
var health := 40.0
var dead := false
var respawn_timer := 0.0
var target: Node3D
var attack_timer := 0.0
var enemy_timer := 0.0
var pulse := 0.0
var flash := 0.0
var phase := 0.0
var model: Node3D
var limbs: Array[Node3D] = []
var health_fill: MeshInstance3D
var skin: MeshInstance3D
var _normal: Material
var _hit: StandardMaterial3D
var respawn_pulse := 0.0
var _max_health := 40.0
var ranged_timer := 0.0
var slot_index := 0
func initialize(owner_tower: DefenseTower, slot: int, owner_manager: Node) -> void:
	slot_index = slot
	tower = owner_tower
	manager = owner_manager
	settings = tower.deployment
	health = settings.health
	_max_health = settings.health
	tower.stats_changed.connect(_refresh_stats)
	home = tower.grid_cell+BuildCard.rotate_cell(Vector2i(0,-1),tower.rotation_steps)
	var side := Vector2(BuildCard.rotate_cell(Vector2i(1,0),tower.rotation_steps))*(6.0/48.0 if slot == 1 else (-6.0/48.0 if slot == 0 else 0.0))
	home_position = manager.world(home)+manager.map.global_basis*Vector3(side.x*manager.map.cell_size.x,0,side.y*manager.map.cell_size.z)
	if slot >= 2:
		var back := Vector2(BuildCard.rotate_cell(Vector2i(0,1),tower.rotation_steps))*0.18
		home_position += manager.map.global_basis*Vector3(back.x*manager.map.cell_size.x,0,back.y*manager.map.cell_size.z)
	global_position = home_position
	rotation.y = -tower.rotation_steps*PI/2
	model = settings.unit_model.instantiate()
	add_child(model)
	for child in model.find_children("*","Node3D",true,false):
		if child.has_meta("gait_sign") or child.has_meta("arm_sign"): limbs.append(child)
		if child.has_meta("friendly_skin"): skin = child
	if skin != null:
		_normal = skin.material_override
		_hit = StandardMaterial3D.new()
		_hit.albedo_color = Color("f7e8c6")
	var bar := MeshInstance3D.new()
	bar.mesh = QuadMesh.new()
	bar.mesh.size = Vector2(0.35,0.035)
	bar.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color("173039")
	bar.material_override = mat
	add_child(bar)
	health_fill = bar.duplicate()
	health_fill.mesh = bar.mesh.duplicate()
	health_fill.position.z = -0.002
	health_fill.material_override = mat.duplicate()
	health_fill.material_override.albedo_color = Color("64dfc2")
	bar.add_child(health_fill)
	health_fill.position.y = 0
func release() -> void:
	if is_instance_valid(target) and target.engaged_by == self: target.engaged_by = null
	target = null
	attack_timer = 0
	enemy_timer = 0

func _refresh_stats() -> void:
	health = health/_max_health*settings.health
	_max_health = settings.health
func take_damage(amount: float) -> void:
	if dead: return
	health = maxf(0,health-amount)
	flash = 0.15
	manager.effect(global_position,"hit")
	if health <= 0:
		dead = true
		respawn_timer = settings.respawn_seconds
		release()
		manager.effect(global_position,"death")
func advance(delta: float) -> void:
	if not is_instance_valid(tower) or tower.is_queued_for_deletion():
		release()
		queue_free()
		return
	if tower.is_disabled():
		release()
		return
	if dead:
		respawn_timer = maxf(0,respawn_timer-delta)
		visible = respawn_timer > settings.respawn_seconds-0.2
		scale = Vector3.ONE*maxf(0.01,(respawn_timer-settings.respawn_seconds+0.2)/0.2)
		if respawn_timer == 0 and manager.road(home):
			dead = false
			health = settings.health
			global_position = home_position
			visible = true
			scale = Vector3.ONE
			respawn_pulse = 1
			manager.effect(global_position,"respawn")
		return
	flash = maxf(0,flash-delta)
	if skin != null: skin.material_override = _hit if flash > 0 else _normal
	respawn_pulse = maxf(0,respawn_pulse-delta*3)
	scale = Vector3.ONE*(1+respawn_pulse*0.1)
	pulse = maxf(0,pulse-delta*5)
	ranged_timer = maxf(0,ranged_timer-delta)
	if is_instance_valid(target):
		if not target.can_be_targeted() or manager.distance(target.global_position,home_position) > settings.engage_radius or (is_instance_valid(target.engaged_by) and target.engaged_by != self): release()
	else: target = null
	if target == null:
		var candidates: Array[Node3D] = manager.combat._index.targets_near(home_position,settings.engage_radius)
		candidates.sort_custom(func(a,b): return a.enemy_id < b.enemy_id)
		var eligible: Array[Node3D] = []
		for enemy in candidates:
			if enemy.troop != null and enemy.troop.has_tag(&"flying"): continue
			if is_instance_valid(enemy.engaged_by) or manager.path(home,manager.cell(enemy.global_position),home,settings.local_radius).is_empty(): continue
			eligible.append(enemy)
		var preferred: Node3D = manager.combat.enemy_abilities.preferred(tower,eligible)
		if preferred != null:
			target = preferred
		elif not eligible.is_empty(): target = eligible[0]
	var previous := global_position
	if target == null: manager.walk(self,home_position,delta)
	elif manager.distance(global_position,target.global_position) > settings.melee_distance:
		manager.walk(self,target.global_position,delta)
	else:
		if not is_instance_valid(target.engaged_by):
			target.engaged_by = self
			attack_timer = settings.interval
			enemy_timer = target.melee_interval
		attack_timer -= delta
		enemy_timer -= delta
		if attack_timer <= 0:
			attack_timer += settings.interval
			pulse = 1
			target.take_damage(settings.damage)
		if is_instance_valid(target) and target.can_be_targeted() and enemy_timer <= 0:
			enemy_timer += target.melee_interval
			take_damage(target.melee_damage)
	if not dead and tower.has_relic(&"sharpshooter") and (not is_instance_valid(target) or target.engaged_by != self) and ranged_timer <= 0:
		var ranged: Array[Node3D] = manager.combat._index.targets_near(global_position,tower.relic_value(&"sharpshooter", &"range"))
		ranged.sort_custom(func(a,b): return a.enemy_id < b.enemy_id)
		var preferred: Node3D = manager.combat.enemy_abilities.preferred(tower,ranged)
		if preferred != null:
			ranged.erase(preferred)
			ranged.push_front(preferred)
		if not ranged.is_empty():
			var victim: Node3D = ranged[0]
			manager.combat.visuals.add_beam(global_position+Vector3.UP*0.5,victim.global_position+Vector3.UP*0.25,Color("ead5a2"),0.035,0.18)
			victim.take_damage(settings.damage)
			ranged_timer = tower.relic_value(&"sharpshooter", &"interval")*settings.interval/tower.definition.deployment.interval
			pulse = 1.0
	var motion := global_position-previous
	if motion.length_squared() > 0.000001: look_at(global_position+Vector3(motion.x,0,motion.z))
	elif is_instance_valid(target):
		var direction := target.global_position-global_position
		if Vector2(direction.x,direction.z).length_squared() > 0.000001: look_at(global_position+Vector3(direction.x,0,direction.z))
	phase += manager.distance(global_position,previous)*13.0
	for limb in limbs:
		limb.rotation.x = sin(phase)*0.48*float(limb.get_meta("gait_sign",limb.get_meta("arm_sign",0.0))) if motion.length_squared() > 0.000001 else 0.0
		if limb.has_meta("arm_sign"): limb.rotation.x -= pulse*0.7
	model.position = Vector3(0,absf(sin(phase))*0.012, -pulse*0.08)
	health_fill.scale.x = maxf(0.001,health/settings.health)
	health_fill.position.x = -(1-health/settings.health)*0.175
func _exit_tree() -> void: release()
