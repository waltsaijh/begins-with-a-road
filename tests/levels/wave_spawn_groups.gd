extends Node
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func group(profile: Troop, start: int, count: int, interval: int, batch := 1, origin := 0) -> WaveSpawnGroup:
	var result := WaveSpawnGroup.new()
	result.troop = profile
	result.start_tick = start
	result.enemy_count = count
	result.interval_ticks = interval
	result.batch_size = batch
	result.start_index = origin
	return result

func wait_map(scene: Node) -> void:
	for i in 120:
		var controller: Node = scene.get_node("PortalMap")
		if not controller.computing and controller.plan.get("reachable", false): return
		await get_tree().process_frame
	check(false, "Map did not become ready")

func clear_enemies(wave: Node) -> void:
	for enemy in wave.living_enemies(): enemy.take_damage(1000000)

func verify() -> void:
	var profile := (TroopCatalog.find("soldier").duplicate() as Troop)
	var recipe := group(profile, 2, 5, 3, 2)
	check(recipe.end_tick() == 8 and recipe.count_at(1) == 0 and recipe.count_at(2) == 2 and recipe.count_at(5) == 4 and recipe.count_at(8) == 5, "Batch duration/count preview disagrees with integer ticks")
	recipe.interval_ticks = 0
	check(recipe.end_tick() == 2 and recipe.count_at(2) == 5, "Zero interval is not an instantaneous group")
	recipe.start_tick = -1
	check(not recipe.configuration_error().is_empty(), "Negative schedule accepted")
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.show_button = false
	add_child(scene)
	await wait_map(scene)
	wave.set_process(false)
	scene.get_node("TowerMap").combat.enabled = false
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	var done := [0]
	wave.wave_finished.connect(func(): done[0] += 1)
	var definition := WaveDefinition.new()
	var fast := (TroopCatalog.find("quickfeet").duplicate() as Troop)
	fast.speed_multiplier = 1.5 # Freeze this fixture independently of authored balance.
	fast.max_health = 50
	var heavy := (TroopCatalog.find("heavy").duplicate() as Troop)
	heavy.max_health = 500 # Explicit fixture value; game balance remains editable.
	definition.groups = [group(profile, 2, 3, 2, 2), group(fast, 2, 2, 1), group(heavy, 12, 1, 0)]
	check(wave.apply_definition(definition) and wave.start_wave(), "Mixed wave failed to start")
	# Neither authored edits nor profile edits may change committed future spawns.
	heavy.max_health = 900
	definition.groups[2].start_tick = 100
	wave._process(0.49)
	check(wave.spawned == 0 and wave.elapsed_tick == 1, "Enemy spawned before its quarter-second boundary")
	wave._process(0.01)
	check(wave.spawned == 3 and wave.elapsed_tick == 2, "Simultaneous groups/batches did not spawn at tick 2")
	var troops := {}
	for enemy in wave.living_enemies():
		troops[enemy.troop.troop_name] = int(troops.get(enemy.troop.troop_name, 0))+1
		if enemy.troop == fast: check(is_equal_approx(enemy.move_speed, 3.75) and enemy.max_health == 50, "Mixed enemy stats were taken from the first group")
	check(troops.get("soldier", 0) == 2 and troops.get("quickfeet", 0) == 1, "Mixed batch used the wrong troops")
	wave._process(0.25)
	check(wave.spawned == 4, "Second quickfeet was not scheduled at tick 3")
	wave._process(0.25)
	check(wave.spawned == 5, "Partial final soldier batch was not scheduled at tick 4")
	clear_enemies(wave)
	check(wave.active and wave.alive == 0 and done[0] == 0, "Empty interval ended the wave before a future group")
	wave._process(1.99)
	check(wave.spawned == 5 and wave.elapsed_tick == 11, "Future group spawned too early")
	wave._process(0.01)
	check(wave.spawned == 6 and wave.alive == 1 and wave.living_enemies()[0].max_health == 500, "Future spawn moved or changed its frozen stats")
	clear_enemies(wave)
	check(not wave.active and done[0] == 1, "Final clear did not finish exactly once")
	await get_tree().process_frame
	definition.groups = [group(profile, 0, 5, 1)]
	check(wave.apply_definition(definition) and wave.start_wave(), "Catch-up wave failed to start")
	wave._process(1.0)
	check(wave.spawned == 5 and wave.elapsed_tick == 4, "A slow frame shifted or skipped scheduled batches")
	clear_enemies(wave)
	await get_tree().process_frame
	definition.groups = [group(profile, 0, 5, 0, 2)]
	check(wave.apply_definition(definition) and wave.start_wave(), "Instant wave failed to start")
	wave._process(0.0)
	check(wave.spawned == 5, "Zero-interval batches were spread across frames")
	clear_enemies(wave)
	await get_tree().process_frame
	fast.score_threshold = 0
	definition.groups = [group(profile, 0, 1, 0), group(fast, 4, 1, 0)]
	check(wave.apply_definition(definition) and not wave.start_wave() and not wave.active and wave._pending.is_empty(), "Invalid later route started a partial wave")
	scene.queue_free()
	await get_tree().process_frame
	# Quotas are pooled by troop+entrance across all groups, independent of IDs.
	var cells: Array[Vector2i] = []
	for x in range(-2, 11): cells.append(Vector2i(x, 2))
	for x in range(0, 9):
		cells.append(Vector2i(x, 0)); cells.append(Vector2i(x, 4))
	for x in [0, 8]:
		cells.append(Vector2i(x, 1)); cells.append(Vector2i(x, 3))
	scene = Fixture.scene_for(cells, Vector2i(-2, 2), Vector2i(10, 2))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	await wait_map(scene)
	definition.groups = [group(profile, 0, 2, 1), group(profile, 8, 3, 2)]
	var schedule := WaveSpawnSchedule.build(definition, scene.get_node("PortalMap"), 100)
	var histogram := [0, 0, 0]
	var assigned := {}
	for entry: Dictionary in schedule.pending:
		histogram[entry.route.route_index] += 1
		assigned[entry.allocation_index] = entry.route.route_index
		check(entry.allocation_total == 5, "Groups split the whole-wave route quota")
		check(entry.spawn_tick in ([0, 1] if entry.group_index == 0 else [8, 10, 12]), "Shuffle moved an enemy outside its group schedule")
	check(histogram == [2, 2, 1], "Two soldier groups/five enemies did not preserve a 2/2/1 quota")
	var repeated := WaveSpawnSchedule.build(definition, scene.get_node("PortalMap"), 10000)
	for entry: Dictionary in repeated.pending:
		check(entry.route.route_index == assigned[entry.allocation_index], "Global enemy IDs changed deterministic quotas")
	scene.queue_free()
	await get_tree().process_frame
	# Authored entrances remain independent within one mixed wave.
	scene = load("res://scenes/11x11big.tscn").instantiate()
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	await wait_map(scene)
	definition.groups = [group(profile, 0, 1, 0), group(profile, 4, 1, 0, 1, 1)]
	schedule = WaveSpawnSchedule.build(definition, scene.get_node("PortalMap"), 0)
	check(schedule.pending.size() == 2 and schedule.pending[0].route.cells[0] != schedule.pending[1].route.cells[0], "Mixed wave ignored the second entrance")
	scene.queue_free()
	await get_tree().process_frame
	print("WAVE_SPAWN_GROUPS_CHECK:"+JSON.stringify({"failures": failures, "quarter_ticks": true, "overlap": true, "future_gap": true, "snapshot": true, "absolute_schedule": true, "pooled_quotas": true, "multiple_entrances": true}))
	get_tree().quit(1 if failures else 0)
