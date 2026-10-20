extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Index = preload("res://scripts/combat/enemy_spatial_index.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fixture() -> Node3D:
	var cells: Array[Vector2i] = []
	for y in 5:
		for x in 8:
			cells.append(Vector2i(x, y))
	var scene := Fixture.scene_for(cells, Vector2i(0, 2), Vector2i(7, 2))
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.enemy_count = 3
	wave.batch_size = 3
	# Freeze balance/delivery for these checks, independently of designer edits.
	var test_tower: DefenseTower = load("res://scenes/towers/sentry.tscn").instantiate()
	test_tower.definition = test_tower.definition.duplicate(true)
	test_tower.definition.default_damage = 20.0
	test_tower.definition.max_health = 200.0
	test_tower.definition.attack_interval = 1.0
	test_tower.definition.attack = ArrowAttack.new()
	var test_tower_scene := PackedScene.new()
	test_tower_scene.pack(test_tower)
	test_tower.free()
	scene.get_node("TowerMap").tower_scene = test_tower_scene
	add_child(scene)
	scene.get_node("TowerMap").combat.set_process(false)
	scene.get_node("TowerMap").combat.visuals.set_process(false)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	await ready_map(scene)
	return scene

func ready_map(scene: Node) -> void:
	for i in 120:
		var controller: Node = scene.get_node("PortalMap")
		if not controller.computing and controller.plan.get("reachable", false):
			return
		await get_tree().process_frame
	check(false, "Combat fixture failed to prepare")

func position_unit(unit: Node3D, map: GridMap, cell: Vector2i, offset := Vector2.ZERO) -> void:
	var position := map.map_to_local(Vector3i(cell.x, 0, cell.y))
	position += Vector3(offset.x*map.cell_size.x, 0.025, offset.y*map.cell_size.z)
	unit.global_position = map.to_global(position)

func verify_aim(tower: DefenseTower) -> void:
	var original := tower.transform
	# Placement may rotate the tower or inherit a transformed scene.
	tower.transform = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE*1.5), original.origin)
	var visual: Node3D = tower.get_node("Visual")
	var base: Node3D = visual.get_node("Base")
	var pivot: Node3D = visual.get_node("AimPivot")
	var muzzle: Marker3D = pivot.get_node("ArrowRelease")
	var root_pose := visual.global_transform
	var base_pose := base.global_transform
	for direction: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3(1, -0.3, 1), Vector3.UP, Vector3.DOWN]:
		var target := pivot.global_position+direction*3
		tower.aim_at(target, 1.0)
		var start := tower.muzzle_position()
		check(start.is_equal_approx(muzzle.global_position), "Shot did not originate at the arrow tip")
		check((-pivot.global_basis.z).normalized().dot((target-start).normalized()) > 0.9999, "Arrow and shot direction disagree")
		check(visual.global_transform.is_equal_approx(root_pose) and base.global_transform.is_equal_approx(base_pose), "Aiming rotated the fixed tower base")
	var aimed_pose := pivot.transform
	tower.aim_at(pivot.global_position, 1.0)
	check(pivot.transform.is_equal_approx(aimed_pose), "Coincident target changed aim")
	tower.transform = original

func verify() -> void:
	await verify_arrows()
	await verify_tracking()
	check(Index.covered_cells(Vector2i.ZERO, 3).size() == 29, "Aiming grid differs from threat coverage")
	var scene: Node3D = await fixture()
	var manager: Node = scene.get_node("TowerMap")
	var combat: Node = manager.combat
	var wave: Node = scene.get_node("EnemyWave")
	var map: GridMap = scene.get_node("TileMap")
	var tower: DefenseTower = manager.place_tower(Vector3i(3, 0, 1))
	check(tower != null and tower.attack is ArrowAttack and tower.health == 200 and tower.damage == 20, "Sentry combat defaults missing")
	tower.attack = load("res://assets/data/towers/attacks/sentry_beam.tres").duplicate(true)
	# Keep the cooldown fixture independent of designer edits to the sentry asset.
	tower.attack_interval = 1.0
	verify_aim(tower)
	tower.attack_radius = 1
	await ready_map(scene)
	check(wave.start_wave(), "Beam wave failed to start")
	wave._process(0)
	var units: Array[Node3D] = wave.living_enemies()
	# Equal-cell targets are selected by enemy_id, independently of departure order.
	units.sort_custom(func(a: Node3D, b: Node3D): return a.enemy_id < b.enemy_id)
	# Non-unit world scale must not change which tile is covered.
	map.scale = Vector3(5, 1, 7)
	position_unit(units[0], map, Vector2i(4, 1), Vector2(0.49, 0.49))
	position_unit(units[1], map, Vector2i(4, 2), Vector2(-0.49, -0.49))
	position_unit(units[2], map, Vector2i(0, 4))
	tower.aim_at(combat.aim_position(units[0], tower.attack), 1.0)
	combat._process(0)
	check(units[0].health == 80 and units[1].health == 100, "Beam used world distance instead of full tile coverage")
	check(combat.visuals.beams.size() == 1, "Beam did not produce a trail")
	check(Vector3(combat.visuals.beams[0].start).is_equal_approx(tower.get_node("Visual/AimPivot/ArrowRelease").global_position), "Beam missed the arrow release marker")
	combat._process(0.5)
	check(units[0].health == 80, "Tower ignored its attack interval")
	combat._process(0.5)
	check(units[0].health == 60 and combat.shots_fired == 2, "Tower did not fire after cooldown")
	tower.damage = 1000
	combat._process(1)
	check(wave.killed == 1 and wave.alive == 2 and wave.completed == 0 and wave.visuals.units.size() == 2, "Enemy death did not release logical/render slots")
	combat._process(1)
	check(combat.shots_fired == 3 and units[1].health == 100, "Dead or out-of-range target was selected")
	tower.take_damage(1000)
	check(manager.towers.is_empty() and manager.occupied.is_empty(), "Destroyed tower did not release its obstacle")
	units[1].take_damage(1000)
	units[2].take_damage(1000)
	check(wave.killed == 3 and wave.alive == 0 and not wave.active and wave.visuals.units.is_empty(), "An all-killed wave did not finish")
	scene.queue_free()
	await get_tree().process_frame

	scene = await fixture()
	manager = scene.get_node("TowerMap")
	combat = manager.combat
	wave = scene.get_node("EnemyWave")
	map = scene.get_node("TileMap")
	tower = manager.place_tower(Vector3i(3, 0, 1))
	var attack: ProjectileAttack = load("res://assets/data/towers/attacks/explosive_projectile.tres").duplicate(true)
	attack.flight_time = 1
	attack.splash_radius = 1
	tower.attack = attack
	tower.damage = 40
	await ready_map(scene)
	check(wave.start_wave(), "Projectile wave failed to start")
	wave._process(0)
	units = wave.living_enemies()
	position_unit(units[0], map, Vector2i(3, 2))
	position_unit(units[1], map, Vector2i(4, 2))
	position_unit(units[2], map, Vector2i(6, 4))
	tower.aim_at(combat.aim_position(units[0], tower.attack), 1.0)
	combat._process(0)
	combat.enabled = false
	check(combat.projectiles.size() == 1 and units[0].health == 100, "Projectile dealt damage at launch")
	check(Vector3(combat.projectiles[0].start).is_equal_approx(tower.get_node("Visual/AimPivot/ArrowRelease").global_position), "Projectile missed the arrow release marker")
	tower.damage = 999
	attack.splash_radius = 99
	attack.effects[0].duration = 99
	combat._process(0.5)
	check(units[1].health == 100, "Projectile dealt damage before impact")
	position_unit(units[0], map, Vector2i(7, 4))
	position_unit(units[2], map, Vector2i(3, 2))
	check(manager.remove_tower(Vector3i(3, 0, 1)), "Source tower could not be removed")
	await get_tree().process_frame
	combat._process(0.5)
	check(combat.projectiles.is_empty(), "Completed projectile retained its state")
	check(units[0].health == 100 and units[1].health == 60 and units[2].health == 60, "Splash failed to use landing tile/current occupants/frozen damage")
	check(units[2]._slows.size() == 1 and units[2]._slows[0] == Vector2(0.5, 2), "On-hit effect was not snapshotted/applied")
	units[2].move_speed = 2
	units[2]._process(0.5)
	check(is_equal_approx(units[2].travelled_distance, 0.5), "Slow did not affect logical movement")
	units[2]._process(1.5)
	var before: float = units[2].travelled_distance
	units[2]._process(0.1)
	check(is_equal_approx(units[2].travelled_distance-before, 0.2), "Expired slow did not restore movement speed")
	combat.visuals._process(0)
	check(combat.visuals.impacts.size() == 1 and combat.visuals.impacts[0].visible, "Projectile impact burst was not shown")
	combat.visuals._process(1)
	check(combat.visuals._instance.mesh == null and combat.visuals.impacts.is_empty(), "Expired attack visuals were not released")
	scene.queue_free()
	await get_tree().process_frame
	var report := {"failures": failures, "continuous_tracking": true, "one_tile_lookahead": true, "smooth_first_aim": true, "flying_arrow": true, "arrow_trail": true, "arrow_target_cleanup": true, "instant_beam": true, "arrow_tip_origin": true, "fixed_base": true, "aim_alignment": true, "tile_range": true, "cooldown": true, "kill_cleanup": true, "tower_destruction": true, "delayed_splash": true, "movable_targets": true, "source_independent": true, "payload_snapshot": true, "slow_and_expiry": true, "visual_cleanup": true}
	print("COMBAT_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		FileAccess.open("res://reports/combat/combat_windows.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ")+"\n")
		get_tree().quit(1 if failures else 0)

func verify_tracking() -> void:
	var scene: Node3D = await fixture()
	var manager: Node = scene.get_node("TowerMap")
	var combat: Node = manager.combat
	var wave: Node = scene.get_node("EnemyWave")
	var map: GridMap = scene.get_node("TileMap")
	var tower: DefenseTower = manager.place_tower(Vector3i(3, 0, 1))
	tower.attack = load("res://assets/data/towers/attacks/sentry_beam.tres").duplicate(true)
	tower.attack_interval = 1.0
	tower.attack_radius = 1.0
	await ready_map(scene)
	check(wave.start_wave(), "Tracking wave failed to start")
	wave._process(0)
	var units: Array[Node3D] = wave.living_enemies()
	# Equal-cell targets are selected by enemy_id, independently of departure order.
	units.sort_custom(func(a: Node3D, b: Node3D): return a.enemy_id < b.enemy_id)
	position_unit(units[0], map, Vector2i(7, 4))
	position_unit(units[1], map, Vector2i(0, 4))
	position_unit(units[2], map, Vector2i(7, 3))
	var pivot: Node3D = tower.get_node("Visual/AimPivot")
	var base: Node3D = tower.get_node("Visual/Base")
	var base_pose := base.global_transform
	var initial := pivot.quaternion
	# An enemy appearing directly inside range must not force an instant first shot.
	position_unit(units[0], map, Vector2i(4, 1))
	combat._process(0.02)
	check(combat.shots_fired == 0 and not pivot.quaternion.is_equal_approx(initial), "First attack bypassed gradual aiming")
	pivot.quaternion = initial
	position_unit(units[0], map, Vector2i(7, 4))
	combat._process(0.05)
	check(pivot.quaternion.is_equal_approx(initial), "Tower tracked an enemy beyond its lookahead range")
	# Exactly one tile outside firing range: turn early, but never fire here.
	position_unit(units[0], map, Vector2i(5, 1))
	combat._process(0.05)
	var point: Vector3 = combat.aim_position(units[0], tower.attack)
	var direction := (point-pivot.global_position).normalized()
	var dot := (-pivot.global_basis.z).normalized().dot(direction)
	check(not pivot.quaternion.is_equal_approx(initial) and dot < cos(TowerConstants.AIM_TOLERANCE), "Lookahead aim snapped or failed to move")
	check(combat.shots_fired == 0 and units[0].health == 100, "Lookahead extended the firing range")
	for i in 20:
		combat._process(0.05)
	check((-pivot.global_basis.z).normalized().dot(direction) > 0.9999 and combat.shots_fired == 0, "Tower failed to pre-aim outside its firing range")
	position_unit(units[0], map, Vector2i(4, 1))
	for i in 10:
		combat._process(0.05)
		if combat.shots_fired == 1:
			break
	check(combat.shots_fired == 1 and units[0].health == 80, "Pre-aimed enemy was not attacked after entering range")
	var before := pivot.quaternion
	tower.muzzle_position()
	check(pivot.quaternion.is_equal_approx(before), "Reading the muzzle snapped aim")
	# A target moving around the tower must still be followed during cooldown.
	position_unit(units[0], map, Vector2i(3, 2))
	combat._process(0.05)
	check(not pivot.quaternion.is_equal_approx(before) and combat.shots_fired == 1, "Cooldown stopped tracking or fired early")
	position_unit(units[0], map, Vector2i(7, 4))
	position_unit(units[1], map, Vector2i(2, 1))
	before = pivot.quaternion
	combat._process(0.05)
	check(not pivot.quaternion.is_equal_approx(before) and combat.shots_fired == 1, "Tower did not reacquire another enemy during cooldown")
	units[1].take_damage(1000)
	before = pivot.quaternion
	combat._process(0.05)
	check(pivot.quaternion.is_equal_approx(before), "Tower kept following a dead target")
	check(base.global_transform.is_equal_approx(base_pose), "Continuous tracking moved the fixed base")
	# A fixed turn speed must give the same pose across frame rates.
	pivot.quaternion = Quaternion.IDENTITY
	point = pivot.global_position+Vector3(2, -0.4, 1)
	tower.aim_at(point, 0.1)
	var single_step := pivot.quaternion
	pivot.quaternion = Quaternion.IDENTITY
	tower.aim_at(point, 0.05)
	tower.aim_at(point, 0.05)
	check(absf(single_step.dot(pivot.quaternion)) > 0.99999, "Tracking depends on frame rate")
	point = pivot.global_position+Vector3(1, -0.5, 0)
	tower.aim_at(point, 1.0)
	var tracks_fast_target := true
	for i in 60:
		var angle := (i+1)*3.75/60.0
		point = pivot.global_position+Vector3(cos(angle), -0.5, sin(angle))
		tracks_fast_target = tower.aim_at(point, 1.0/60.0) and tracks_fast_target
	check(tracks_fast_target, "Moving target kept aim perpetually outside firing tolerance")
	scene.queue_free()
	await get_tree().process_frame

func verify_arrows() -> void:
	var scene: Node3D = await fixture()
	var manager: Node = scene.get_node("TowerMap")
	var combat: Node = manager.combat
	var wave: Node = scene.get_node("EnemyWave")
	var map: GridMap = scene.get_node("TileMap")
	var tower: DefenseTower = manager.place_tower(Vector3i(3, 0, 1))
	check(tower.attack is ArrowAttack and tower.attack.configuration_error().is_empty(), "Default arrow settings invalid")
	await ready_map(scene)
	check(wave.start_wave(), "Arrow wave failed to start")
	wave._process(0)
	var units: Array[Node3D] = wave.living_enemies()
	# Equal-cell targets are selected by enemy_id, independently of departure order.
	units.sort_custom(func(a: Node3D, b: Node3D): return a.enemy_id < b.enemy_id)
	position_unit(units[0], map, Vector2i(5, 1))
	position_unit(units[1], map, Vector2i(5, 1))
	position_unit(units[2], map, Vector2i(0, 4))
	tower.aim_at(combat.aim_position(units[0], tower.attack), 1.0)
	combat._process(0)
	combat.enabled = false
	check(combat.projectiles.size() == 1 and units[0].health == 100 and combat.visuals.beams.is_empty(), "Arrow hit instantly or retained the old beam")
	var shot: Dictionary = combat.projectiles[0]
	check(Vector3(shot.start).is_equal_approx(tower.get_node("Visual/AimPivot/ArrowRelease").global_position), "Arrow did not launch from the arrow tip")
	combat.visuals._process(0)
	check(combat.visuals._instance.mesh != null, "New arrow could not render on its launch frame")
	# Runtime data is copied at launch, including speed and damage.
	tower.damage = 999
	tower.attack.speed = 1
	combat._process(0.03)
	check(is_equal_approx(shot.travelled, 0.72) and units[0].health == 100, "Arrow did not fly at its snapshotted speed before impact")
	combat.visuals._process(0)
	check(combat.visuals._instance.mesh.get_surface_count() == 1, "Arrow shaft/head/trail did not share one surface")
	var colors: PackedColorArray = combat.visuals._instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var has_fade := false
	var has_tail := false
	for color in colors:
		has_fade = has_fade or (color.a > 0 and color.a < 1)
		has_tail = has_tail or color.a == 0
	check(has_fade and has_tail, "Arrow trail did not fade to transparent")
	position_unit(units[0], map, Vector2i(5, 2))
	check(manager.remove_tower(Vector3i(3, 0, 1)), "Arrow source could not be removed")
	await get_tree().process_frame
	combat._process(0.2)
	check(combat.projectiles.is_empty() and units[0].health == 80 and units[1].health == 100 and combat.visuals.impacts.is_empty(), "Arrow failed to hit its moving target once without splash after source removal")
	combat.visuals._process(0)
	check(combat.visuals._instance.mesh == null, "Finished arrow retained its visual mesh")
	# A target killed during flight must not be replaced by another nearby enemy.
	tower = manager.place_tower(Vector3i(3, 0, 1))
	combat.fire_arrow(tower, units[1], tower.attack)
	units[1].take_damage(1000)
	await get_tree().process_frame
	combat._process(1)
	check(combat.projectiles.is_empty() and units[0].health == 80 and units[2].health == 100, "Arrow retained a dead target or damaged a replacement")
	scene.queue_free()
	await get_tree().process_frame
