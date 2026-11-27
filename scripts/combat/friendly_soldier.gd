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
## Optional cloth hung from the shoulders: trails back while walking, flicks on a lunge.
var cape: Node3D
var _rest_yaw := 0.0
var _cape_angle := 0.0
var _cape_speed := 0.0
var _normal: Material
var _hit: StandardMaterial3D
var respawn_pulse := 0.0
var _max_health := 40.0
var ranged_timer := 0.0
var slot_index := 0
var temporary := false
var shield := 0.0
var shield_seconds := 0.0
func initialize(owner_tower: DefenseTower, slot: int, owner_manager: Node, rally_cell := Vector2i.ZERO) -> void:
	slot_index = slot
	tower = owner_tower
	manager = owner_manager
	temporary = tower == null
	settings = preload("res://assets/data/towers/barracks.tres").deployment if temporary else tower.deployment
	health = settings.health
	_max_health = settings.health
	if not temporary: tower.stats_changed.connect(_refresh_stats)
	home = rally_cell if temporary else tower.garrison_cell()
	var facing := 0 if temporary else tower.rotation_steps
	var side := Vector2(BuildCard.rotate_cell(Vector2i(1,0),facing))*(6.0/48.0 if slot == 1 else (-6.0/48.0 if slot == 0 else 0.0))
	home_position = manager.world(home)+manager.map.global_basis*Vector3(side.x*manager.map.cell_size.x,0,side.y*manager.map.cell_size.z)
	if slot >= 2:
		var back := Vector2(BuildCard.rotate_cell(Vector2i(0,1),tower.rotation_steps))*0.18
		home_position += manager.map.global_basis*Vector3(back.x*manager.map.cell_size.x,0,back.y*manager.map.cell_size.z)
	global_position = home_position
	rotation.y = -facing*PI/2
	# Rest facing: away from the barracks, looking out over the road it guards.
	if not temporary and is_instance_valid(tower):
		var out := home_position-tower.global_position
		if Vector2(out.x, out.z).length_squared() > 0.0001: rotation.y = atan2(-out.x, -out.z)
	_rest_yaw = rotation.y
	model = settings.unit_model.instantiate()
	add_child(model)
	for child in model.find_children("*","Node3D",true,false):
		if child.has_meta("gait_sign") or child.has_meta("arm_sign"): limbs.append(child)
		if child.has_meta("friendly_skin"): skin = child
		if child.has_meta("cape_sway"): cape = child
	if skin != null:
		_normal = skin.material_override
		_hit = SolidMaterials.opaque(Color("f7e8c6"))
	var bar := MeshInstance3D.new()
	bar.mesh = QuadMesh.new()
	bar.mesh.size = Vector2(0.35,0.035)
	bar.position.y = float(model.get_meta("bar_height", 0.8))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color("173039")
	bar.material_override = mat
	add_child(bar)
	# Billboarding drops node scale and turns node offsets with the soldier, so
	# the fill is sized and shifted inside its own mesh (camera-facing space).
	health_fill = MeshInstance3D.new()
	health_fill.mesh = QuadMesh.new()
	health_fill.material_override = mat.duplicate()
	health_fill.material_override.albedo_color = Color("64dfc2")
	bar.add_child(health_fill)
	_fill_ratio = -1.0
	_refresh_bar()
func release() -> void:
	if is_instance_valid(target) and target.engaged_by == self: target.engaged_by = null
	target = null
	attack_timer = 0
	enemy_timer = 0

func _refresh_stats() -> void:
	health = health/_max_health*settings.health
	_max_health = settings.health
	_refresh_bar()
func take_damage(amount: float) -> void:
	if dead: return
	var absorbed := minf(shield, amount)
	shield -= absorbed
	amount -= absorbed
	health = maxf(0,health-amount)
	_refresh_bar()
	flash = 0.15
	manager.effect(global_position,"hit")
	if health <= 0:
		dead = true
		shield = 0.0
		if temporary: hide()
		respawn_timer = settings.respawn_seconds
		release()
		manager.effect(global_position,"death")
func advance(delta: float) -> void:
	shield_seconds = maxf(0.0, shield_seconds-delta)
	if shield_seconds <= 0: shield = 0.0
	if not temporary and (not is_instance_valid(tower) or tower.is_queued_for_deletion()):
		release()
		queue_free()
		return
	if not temporary and tower.is_disabled():
		release()
		return
	if dead:
		if temporary: return
		respawn_timer = maxf(0,respawn_timer-delta)
		visible = respawn_timer > settings.respawn_seconds-0.2
		scale = Vector3.ONE*maxf(0.01,(respawn_timer-settings.respawn_seconds+0.2)/0.2)
		if respawn_timer == 0 and manager.road(home):
			dead = false
			health = settings.health
			_refresh_bar()
			global_position = home_position
			visible = true
			scale = Vector3.ONE
			respawn_pulse = 1
			manager.effect(global_position,"respawn")
			tower.present_deployment()
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
		var preferred: Node3D = null if temporary else manager.combat.enemy_abilities.preferred(tower,eligible)
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
			if BalanceTrace.enabled and not temporary: BalanceTrace.event("intercept",BalanceTrace.tower_id(tower),{"target":target.enemy_id,"slot":slot_index})
			attack_timer = settings.interval
			enemy_timer = target.melee_interval
		attack_timer -= delta
		enemy_timer -= delta
		if BalanceTrace.enabled and not temporary: BalanceTrace.sample(tower,"interception_unit_seconds",delta)
		if attack_timer <= 0:
			attack_timer += settings.interval
			pulse = 1
			target.take_damage(settings.damage,"reinforcement" if temporary else (BalanceTrace.tower_id(tower) if BalanceTrace.enabled else "barracks"))
		if is_instance_valid(target) and target.can_be_targeted() and target.stun_remaining <= 0 and enemy_timer <= 0:
			enemy_timer += target.melee_interval
			take_damage(target.melee_damage)
	if not temporary and not dead and tower.has_relic(&"sharpshooter") and (not is_instance_valid(target) or target.engaged_by != self) and ranged_timer <= 0:
		var ranged: Array[Node3D] = manager.combat._index.targets_near(global_position,tower.relic_value(&"sharpshooter", &"range"))
		ranged.sort_custom(func(a,b): return a.enemy_id < b.enemy_id)
		var preferred: Node3D = manager.combat.enemy_abilities.preferred(tower,ranged)
		if preferred != null:
			ranged.erase(preferred)
			ranged.push_front(preferred)
		if not ranged.is_empty():
			var victim: Node3D = ranged[0]
			manager.combat.visuals.add_beam(global_position+Vector3.UP*0.5,victim.global_position+Vector3.UP*0.25,Color("ead5a2"),0.035,0.18)
			victim.take_damage(settings.damage,BalanceTrace.tower_id(tower) if BalanceTrace.enabled else "sharpshooter")
			ranged_timer = tower.relic_value(&"sharpshooter", &"interval")*settings.interval/tower.definition.deployment.interval
			pulse = 1.0
	var motion := global_position-previous
	if motion.length_squared() > 0.000001: look_at(global_position+Vector3(motion.x,0,motion.z))
	elif is_instance_valid(target):
		var direction := target.global_position-global_position
		if Vector2(direction.x,direction.z).length_squared() > 0.000001: look_at(global_position+Vector3(direction.x,0,direction.z))
	else:
		# Back at the post with nothing to fight: turn to face out again, instead of
		# keeping the last walking direction (which points at the barracks).
		rotation.y = lerp_angle(rotation.y, _rest_yaw, 1.0-exp(-6.0*delta))
	phase += manager.distance(global_position,previous)*13.0
	# Attack: a spear thrust (wind back, lunge, recover) with the shield raised.
	if pulse >= 1.0: _strike = 0.0
	elif _strike >= 0.0:
		_strike += delta
		if _strike >= STRIKE_SECONDS: _strike = -1.0
	var thrust := _thrust_pose(_strike/STRIKE_SECONDS) if _strike >= 0.0 else Vector3.ZERO
	for limb in limbs:
		limb.rotation.x = sin(phase)*0.48*float(limb.get_meta("gait_sign",limb.get_meta("arm_sign",0.0))) if motion.length_squared() > 0.000001 else 0.0
		if limb.has_meta("arm_sign"): limb.rotation.x += thrust.x if float(limb.get_meta("arm_sign")) < 0.0 else thrust.y
	model.position = Vector3(0,absf(sin(phase))*0.012, thrust.z)
	if cape != null:
		# A damped spring toward a target lean: back while moving (negative tips the hem
		# backward), trailing behind the body as it lunges, and a faint idle drift.
		var moving := motion.length_squared() > 0.000001
		var goal := (-0.32+sin(phase*2.0)*0.06 if moving else sin(Time.get_ticks_msec()*0.0021+slot_index)*0.03)+thrust.z*2.2
		_cape_speed += ((goal-_cape_angle)*90.0-_cape_speed*12.0)*delta
		_cape_angle = clampf(_cape_angle+_cape_speed*delta, -0.7, 0.35)
		cape.rotation.x = _cape_angle
	_refresh_bar()
const STRIKE_SECONDS := 0.42
var _strike := -1.0

## (weapon arm angle, shield arm angle, body forward offset) at strike progress t.
## Negative arm angles tip the held weapon forward; -Z is forward for the model.
static func _thrust_pose(t: float) -> Vector3:
	var shield := -0.55*sin(PI*clampf(t, 0.0, 1.0))
	if t < 0.3:
		var w := t/0.3
		return Vector3(0.45*w, shield, 0.03*w)
	if t < 0.5:
		var k := ease((t-0.3)/0.2, 0.4)
		return Vector3(lerpf(0.45, -1.15, k), shield, lerpf(0.03, -0.14, k))
	var r := ease((t-0.5)/0.5, 2.0)
	return Vector3(lerpf(-1.15, 0.0, r), shield, lerpf(-0.14, 0.0, r))

const BAR_WIDTH := 0.35
const BAR_HEIGHT := 0.035
var _fill_ratio := -1.0

## Left-anchored fill; rebuilt only when the ratio changes.
func _refresh_bar() -> void:
	if not is_instance_valid(health_fill) or settings == null: return
	var ratio := clampf(health/settings.health, 0.0, 1.0)
	if is_equal_approx(ratio, _fill_ratio): return
	_fill_ratio = ratio
	var quad: QuadMesh = health_fill.mesh
	health_fill.visible = ratio > 0.0
	quad.size = Vector2(maxf(0.001, BAR_WIDTH*ratio), BAR_HEIGHT)
	# Slightly toward the camera so the fill never z-fights its background.
	quad.center_offset = Vector3(-(BAR_WIDTH-BAR_WIDTH*ratio)*0.5, 0.0, 0.004)

func _exit_tree() -> void: release()
