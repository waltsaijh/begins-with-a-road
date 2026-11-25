extends SceneTree
## Run with --fixed-fps 60 --script res://tests/enemies/enemy_art_wave.gd.
const Fixture = preload("res://tests/fixtures/level_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const IDS := ["quickfeet","winged","scout","rats","soldier","rook","bomber","bloodmage","heavy"]
var failures := 0

func _initialize() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count: await process_frame

func verify() -> void:
	var level := Fixture.level("")
	var terrain := level.terrain.instantiate() as GridMap
	for x in range(8,25): terrain.set_cell_item(Vector3i(x,0,0),3)
	terrain.set_cell_item(Vector3i(6,0,-1),3)
	terrain.get_node("Goal").position.x = terrain.map_to_local(Vector3i(24,0,0)).x
	level.terrain = PackedScene.new()
	level.terrain.pack(terrain)
	terrain.free()
	var recipe := level.acts[0].waves[0]
	recipe.groups.clear()
	recipe.move_speed = 1.5
	for i in IDS.size():
		var group := WaveSpawnGroup.new()
		group.troop = TroopCatalog.find(IDS[i])
		group.enemy_count = group.troop.cohort_size if IDS[i] == "rats" else 1
		group.interval_ticks = 0
		group.start_tick = i*2
		recipe.groups.append(group)
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.level = level
	root.add_child(scene)
	current_scene = scene
	var hud := scene.get_node("LevelHUD")
	var wave := scene.get_node("EnemyWave")
	await frames(40)
	var towers := scene.get_node("TowerMap")
	check(towers.place_tower(Vector3i(6,0,-1)) != null, "Reference sentry placement failed")
	towers.combat.enabled = false
	towers.combat.enemy_abilities.set_process(false)
	await frames(35)
	scene._on_start_requested()
	for i in 900:
		if wave.alive == recipe.total_count(): break
		await process_frame
	if wave.alive != recipe.total_count():
		push_error("Expected all scheduled units. Spawned %d" % wave.spawned)
		quit(1)
		return
	var batch: Node3D = wave.visuals
	var mice: Array[Node3D] = []
	for enemy in wave.living_enemies():
		var slot: int = batch._slots[enemy]
		var view: RefCounted = batch._appearances[slot]
		check(view.gpu_model == enemy.troop.gpu_model and view.instance == null, "Unexpected draw path")
		var expected_count := 1
		if enemy.troop.troop_name == "rats":
			mice.append(enemy)
			expected_count = 5
		check(view.batch.view.multimesh.visible_instance_count == expected_count, "One rendered miniature per enemy")
		check(absf(enemy.position.y - EnemyConstants.GROUND_OFFSET - enemy.troop.flight_height) < .001, "Ground/flight height changed")
		check((-Basis(Vector3.UP,batch._poses[slot].yaw).z).dot(enemy.move_direction) > .999, "Unit faces away from its route")
		check(not batch.inspection_parts(enemy).is_empty(), "Missing pick geometry")
	var sample: Node3D = wave.living_enemies()[0]
	check(mice.size() == 5,"One five-member cohort")
	mice[0].take_damage(1)
	for member in mice:
		check(member.waypoints == mice[0].waypoints,"Cohort members share the trip")
		check(member.health == member.max_health - (1.0 if member == mice[0] else 0.0),"Mouse HP is independent")
	var base_travel := 0.0
	for speed in [1,2,4]:
		check(Engine.time_scale == speed,"Unexpected HUD speed")
		# The frame that dispatches a HUD press already has its previous delta.
		await frames(2)
		var start: float = sample.travelled_distance
		var phases := PackedFloat64Array()
		for view in batch._appearances: phases.append(view.clip_phase)
		await frames(5)
		var distance: float = sample.travelled_distance-start
		if speed == 1: base_travel = distance
		check(distance > 0 and absf(distance-speed*base_travel) < .003, "Travel at %dx was %.4f, expected %.4f" % [speed,distance,speed*base_travel])
		var elapsed_seconds: float = distance / sample.move_speed
		for slot in batch.units.size():
			var view: RefCounted = batch._appearances[slot]
			var expected := fposmod(phases[slot]+elapsed_seconds*TAU/view.gpu_model.clip_length,TAU)
			check(absf(angle_difference(expected,view.clip_phase)) < .005,"Clip differs from movement clock: "+batch.units[slot].troop.troop_name)
		hud.cycle_speed()
	hud.set_paused(true)
	var positions := PackedVector3Array()
	var paused_phases := PackedFloat64Array()
	for slot in batch.units.size():
		positions.append(batch.units[slot].global_position)
		paused_phases.append(batch._appearances[slot].clip_phase)
	await frames(10)
	for slot in batch.units.size():
		check(batch.units[slot].global_position == positions[slot] and batch._appearances[slot].clip_phase == paused_phases[slot],"Pause advanced an enemy or its animation")
	hud.set_paused(false)
	await frames(45)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("enemies/slice_a/battle.png"))
		var camera := root.get_camera_3d()
		camera.size = camera._maximum_view_size()
		for angle in [0,90,180,270]:
			camera.azimuth = deg_to_rad(angle)
			camera.update_pose()
			await frames(2)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(Artifacts.path("enemies/slice_a/far_%d.png" % angle))
	await verify_gestures(scene,batch,wave)
	for enemy in wave.living_enemies(): enemy.take_damage(100000.0)
	check(batch.units.is_empty(),"Killed enemies retained a draw slot")
	scene.queue_free()
	await frames(4)
	print("ENEMY_ART_WAVE: species=9 speeds=1,2,4 pause deaths failures=",failures)
	quit(int(failures > 0))

func verify_gestures(scene: Node3D, batch: Node3D, wave: Node) -> void:
	var mage: Node3D
	var bomber: Node3D
	for unit in wave.living_enemies():
		if unit.troop.troop_name == "bloodmage": mage = unit
		if unit.troop.troop_name == "bomber": bomber = unit
	var heal: HealAbility = mage.ability(HealAbility)
	var cast: SabotageAbility = bomber.ability(SabotageAbility)
	check(bomber.troop.gpu_model.mesh.custom_aabb.size.z < .8, "Walking bomber keeps the flask on its belt")
	var tower: DefenseTower = scene.get_node("TowerMap").towers.values()[0]
	var host: Node = scene.get_node("TowerMap").combat.enemy_abilities
	for i in 180:
		if host.distance(bomber.global_position,tower.global_position) < cast.radius-.05: break
		await process_frame
	mage.take_damage(heal.amount)
	heal.clock = 0.0
	cast.clock = 0.0
	host.set_process(true)
	await frames(2)
	var m: RefCounted = batch._appearances[batch._slots[mage]].action
	var b: RefCounted = batch._appearances[batch._slots[bomber]].action
	check(m != null and b != null and m.active and b.active,"Successful heal and tower windup enter authored gestures")
	if m == null or b == null or not m.active or not b.active: return
	var mage_at := mage.global_position
	var bomber_at := bomber.global_position
	var crystal: MeshInstance3D = m.model.find_child("*StaffCrystal*",true,false)
	var crystal_y := crystal.global_position.y
	await frames(15)
	check(mage.global_position == mage_at and bomber.global_position == bomber_at,"Both casters plant their feet")
	check(mage.health == mage.max_health and crystal.global_position.y > crystal_y+.15 and m.crystal_material.emission_energy_multiplier > 1.0,"Mage lifts and lights the staff on a real heal")
	check(not batch.inspection_parts(mage).is_empty() and not batch.inspection_parts(bomber).is_empty(),"Gestures remain pickable")
	if DisplayServer.get_name() != "headless":
		var camera := root.get_camera_3d()
		camera.focus = (mage_at+bomber_at)*.5+Vector3.UP*.4
		camera.azimuth = deg_to_rad(40)
		camera.size = 4.5
		camera.update_pose()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("enemies/slice_a/cast.png"))
	var hud := scene.get_node("LevelHUD")
	hud.set_paused(true)
	var remaining := cast.remaining
	await frames(5)
	check(cast.remaining == remaining and bomber.global_position == bomber_at,"Pause freezes the windup")
	hud.set_paused(false)
	hud.cycle_speed()
	hud.cycle_speed()
	for i in 50:
		if b.airborne.visible: break
		await process_frame
	check(b.active and b.airborne.visible and not b.flask.visible and not tower.is_disabled(),"Throws one visible flask before the real disable")
	check(not m.active and mage.global_position != mage_at,"Mage resumes the original trip")
	if DisplayServer.get_name() != "headless":
		await frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("enemies/slice_a/throw.png"))
	for i in 35:
		if not b.active: break
		await process_frame
	await frames(2)
	check(tower.is_disabled() and not b.airborne.visible and bomber.global_position != bomber_at,"Throw completes and movement resumes at 4x")
	cast.clock = 0
	await frames(2)
	check(b.active,"Second throw starts")
	tower.health = 0
	await frames(2)
	check(not b.active and not b.airborne.visible and not cast.is_casting(),"Losing the target cancels the throw and releases the walk slot")
	hud.cycle_speed()

