extends Node
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void: run.call_deferred()

func run() -> void:
	var cells: Array[Vector2i] = []
	for x in 14: cells.append(Vector2i(x,0))
	var scene := preload("res://tests/fixtures/portal_fixture.gd").scene_for(cells,cells.front(),cells.back())
	var wave: Node = scene.get_node("EnemyWave")
	var visual: Node = scene.get_node("TileVisuals")
	visual.opening_drop = true
	wave.auto_start = false
	var boss := WaveSpawnGroup.new()
	boss.troop = preload("res://assets/data/troops/ravager.tres")
	boss.enemy_count = 1
	var soldier := WaveSpawnGroup.new()
	soldier.troop = TroopCatalog.find("soldier")
	soldier.enemy_count = 1
	soldier.start_tick = 16
	var definition := WaveDefinition.new()
	definition.groups = [boss,soldier]
	wave.definition = definition
	add_child(scene)
	for i in 5: await get_tree().process_frame
	var start := Vector3i.ZERO
	var goal := Vector3i(13,0,0)
	check(visual.jobs.has(start) and visual.jobs.has(goal) and visual.jobs[start].age < visual.jobs[goal].age,"Opening tiles fall outward from base")
	visual.finish()
	var controller: Node = scene.get_node("PortalMap")
	var defended := Vector2i(6,0)
	controller.tile_parameters.get_tile(defended).num_towers_around = 4
	check(wave.start_wave(),"Boss wave starts")
	var route: Dictionary = wave._pending[0].route
	check(Vector2i(route.cells[3]) == defended and Vector2i(route.cells[-1]) == cells.back(),"Boss joins defended tile and reaches goal")
	check(Vector2i(wave._pending[1].route.cells[0]) == cells.front() and wave._pending[1].spawn_tick == 16,"Ordinary group retains its entrance and timing")
	var original_tiles: int = controller.map.get_used_cells().size()
	wave._process(0.1)
	var enemy: Node3D = wave.visuals.units[0]
	check(enemy.global_position.y > enemy.waypoints[0].y+4.0 and enemy.waypoints[0] != scene.get_node("Start").global_position,"Boss starts above the clearing")
	check(wave._boss_ground.get_child_count() == 10 and controller.map.get_used_cells().size() == original_tiles,"Connector and nine tiles leave ordinary navigation intact")
	if DisplayServer.get_name() != "headless":
		await enemy.landed
	else:
		enemy._process(0.7)
	check(enemy.global_position.distance_to(enemy.waypoints[0]) < 0.1 and wave.has_node("ImpactDebris"),"Landing emits debris at the clearing")
	check(scene.get_node("Camera3D")._shake != null,"Landing triggers camera shake")
	if DisplayServer.get_name() != "headless":
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(preload("res://tests/fixtures/test_artifacts.gd").path("enemies/boss_arrival.png"))
	enemy.take_damage(999999.0)
	check(wave.active and wave._pending.size() == 1,"Boss death preserves later regular group")
	wave._process(4.0)
	wave.visuals.units[0].take_damage(999999.0)
	check(not wave.active and wave._boss_ground == null,"Clearing leaves with the completed wave")
	print("BOSS_ARRIVAL failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
