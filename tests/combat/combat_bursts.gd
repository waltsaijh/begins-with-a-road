extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func verify() -> void:
	var cells: Array[Vector2i] = []
	for z in 5:
		for x in 8: cells.append(Vector2i(x, z))
	var scene := Fixture.scene_for(cells, Vector2i(0, 2), Vector2i(7, 2))
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.enemy_count = 3
	wave.batch_size = 3
	add_child(scene)
	while scene.get_node("PortalMap").computing or scene.get_node("PortalMap").plan.is_empty(): await frames(1)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	var combat: Node = scene.get_node("TowerMap").combat
	combat.enabled = false
	combat.set_process(false)
	combat.visuals.set_process(false)
	var emitter: Node3D = wave.visuals.death_effects
	emitter.automatic = false
	check(wave.start_wave(), "Burst fixture wave did not start")
	wave._process(0.0)
	var units: Array[Node3D] = wave.living_enemies()
	var map: GridMap = scene.get_node("TileMap")
	map.scale = Vector3(1.2, 1, 1.4)
	map.rotation.y = 0.2
	units[0].global_position = map.to_global(map.map_to_local(Vector3i(2, 0, 2)))
	var slot: int = wave.visuals._slots[units[0]]
	wave.visuals._offsets[slot] = Vector2(0.12, -0.08)
	wave.visuals.update_enemy(units[0])
	var expected := units[0].global_position+map.global_basis*Vector3(0.12*map.cell_size.x, 0, -0.08*map.cell_size.z)
	units[0].take_damage(100000)
	units[0].take_damage(100000)
	check(wave.killed == 1 and wave.visuals.units.size() == 2 and emitter.active.size() == 1, "Death did not emit exactly one burst and release its renderer slot")
	var first: Node3D = emitter.active[0]
	check(first.global_position.is_equal_approx(expected), "Death burst ignored visual avoidance offset")
	check(first.global_basis.is_equal_approx(map.global_basis*Basis.from_scale(map.cell_size)), "Death burst did not follow the map plane and scale")
	check(first.radius < 0.8*0.5 and first.duration == 0.3 and not first.get_node("Core").visible, "Death burst no longer uses compact prototype geometry")
	units[1]._process(10000)
	check(wave.completed == 1 and emitter.active.size() == 1, "Reaching the goal incorrectly emitted a death burst")
	units[2].queue_free()
	await frames()
	check(emitter.active.size() == 1 and not wave.active, "External cleanup emitted a burst or kept a finished wave active")
	var second: Node3D = emitter.emit_at(expected+Vector3.RIGHT)
	first.advance(first.duration*0.5)
	var faded: StandardMaterial3D = first.get_node("Ring").material_override
	var fresh: StandardMaterial3D = second.get_node("Ring").material_override
	check(faded != fresh and is_equal_approx(faded.albedo_color.a, 0.5) and fresh.albedo_color.a == 1.0, "Burst fade mutated another instance's material")
	emitter.clear()
	emitter.max_active = 2
	var pooled_ids: Array[int] = []
	for i in 2: pooled_ids.append(emitter.emit_at(expected).get_instance_id())
	check(emitter.emit_at(expected) == null and emitter.active.size() == 2, "Burst cap did not bound mass-death allocation")
	emitter.advance(1.0)
	check(emitter.active.is_empty() and not emitter.is_processing(), "Expired bursts stayed active")
	var recycled: Node3D = emitter.emit_at(expected)
	check(recycled.get_instance_id() in pooled_ids and recycled.age == 0.0 and recycled.visible, "Pool did not reuse/reset an existing scene")
	emitter.clear()
	map.scale = Vector3.ONE
	map.rotation.y = 0.0
	var death: Node3D = emitter.emit_at(map.to_global(map.map_to_local(Vector3i(2, 0, 2))))
	death.advance(death.duration*0.35)
	var impact_at := map.to_global(map.map_to_local(Vector3i(5, 0, 2)))
	combat.visuals.add_impact(impact_at, 1.5, Color.WHITE, map)
	combat.visuals._process(0.14)
	check(combat.visuals.impacts.size() == 1, "AOE did not use the shared burst scene")
	var impact: Node3D = combat.visuals.impacts[0]
	check(impact.get_script() == death.get_script() and impact.get_node("Core").visible, "AOE did not share the burst style or show its core")
	check(is_equal_approx(impact._reach, 1.5*0.65), "AOE visual radius was not reduced independently of damage range")
	check(impact.get_node("Shards").get_child_count() == 6, "Prototype fragment count changed")
	var camera: Camera3D = scene.get_node("Camera3D")
	camera.focus = map.to_global(map.map_to_local(Vector3i(4, 0, 2)))
	camera.size = 6.0
	camera.update_pose()
	scene.get_node("TileVisuals").finish()
	scene.get_node("CardPlacement/Hand").hide()
	wave.controls.hide()
	await frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("combat/combat_bursts.png"))
	combat.visuals._process(1.0)
	check(combat.visuals.impacts.is_empty(), "AOE burst did not finish independently of projectile damage")
	print("COMBAT_BURSTS_CHECK:"+JSON.stringify({"failures": failures, "exact_death": true, "visual_offset": true, "map_transform": true, "pooled_cap": true, "material_isolation": true, "aoe_shared_style": true, "compact_radius": true}))
	get_tree().quit(1 if failures else 0)
