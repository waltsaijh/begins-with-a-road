extends Node3D
## Reproducible stress workloads; production defaults remain untouched.
const Candidates = preload("res://scripts/navigation/candidate_routes.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var report := {"navigation": [], "runtime": [], "failures": []}
var scene: Node3D

func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		report.failures.append(message)
		push_error(message)

func stats(values: Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered: total += value
	return {"mean": total/maxi(1, ordered.size()), "p50": ordered[ordered.size()/2], "p95": ordered[mini(ordered.size()-1, ceili(ordered.size()*0.95)-1)], "p99": ordered[mini(ordered.size()-1, ceili(ordered.size()*0.99)-1)], "max": ordered[-1]}

func make_snapshot(size: int, lattice: bool) -> Dictionary:
	var cells := PackedInt32Array()
	var ports := PackedByteArray()
	for y in size:
		for x in size:
			if lattice and x%2 == 1 and y%2 == 1: continue
			cells.append_array(PackedInt32Array([x, y]))
			ports.append(15)
	return {"cells": cells, "ports": ports}

func navigation_case(size: int, lattice: bool, budget: int, origins: int) -> void:
	var packed := make_snapshot(size, lattice)
	var starts := PackedVector2Array()
	for i in origins: starts.append(Vector2(0, (size-1)*i/maxi(1, origins-1)))
	var label := "%s_%d_budget%d_origins%d" % ["lattice" if lattice else "wide", size, budget, origins]
	var raw := {"graph_ms": [], "plans_ms": [], "allocation1024_ms": [], "bfs_ms": []}
	var structural := {}
	for round_index in 4:
		var began := Time.get_ticks_usec()
		var builder: RefCounted = ClassDB.instantiate("RoadPortalGraph")
		var graph: Dictionary = builder.build(packed.cells, packed.ports, Vector2i(starts[0]), Vector2i(size-1, size-1), false, starts)
		var graph_end := Time.get_ticks_usec()
		check(graph.get("valid", false), label+": invalid graph")
		var planner: RefCounted = ClassDB.instantiate("RoadRoutePlanner")
		var prepared: Dictionary = planner.prepare(graph)
		var candidates := Candidates.new()
		candidates.prepare(graph)
		var keys: Array[String] = []
		var counts := []
		for origin in origins:
			var start_node := -1
			for i in graph.nodes.size():
				if Vector2i(graph.nodes[i].cell) == Vector2i(starts[origin]): start_node = i; break
			check(start_node >= 0, label+": missing terminal")
			for profile_index in 3:
				var profile: Troop = TroopCatalog.find(["soldier", "quickfeet", "heavy"][profile_index]).duplicate()
				profile.search_budget = budget
				var weights := PackedFloat64Array()
				for cell: Vector2i in graph.tiles:
					var threat := float((cell.x*7+cell.y*11)%13)
					weights.append(1.0 if profile_index == 0 else (threat if profile_index == 1 else -threat))
				var key := "%d:%d" % [origin, profile_index]
				var plan: Dictionary = candidates.plan_for(planner, profile, key, start_node, weights)
				check(plan.get("valid", false) and plan.get("reachable", false), label+": failed profile "+key)
				keys.append(key)
				counts.append(plan.get("routes", 0))
		var plans_end := Time.get_ticks_usec()
		var fingerprint := 0
		for i in 1024:
			var route := candidates.allocate(keys[i%keys.size()], i, 1024)
			check(not route.is_empty(), label+": empty allocation")
			fingerprint = int((fingerprint*31+route.cells.size())%2147483647)
		var alloc_end := Time.get_ticks_usec()
		var terminals: Array[Vector2i] = [Vector2i(size-1, size-1)]
		for start in starts: terminals.append(Vector2i(start))
		check(Snapshot.connects_terminals(packed, terminals), label+": BFS connectivity")
		var bfs_end := Time.get_ticks_usec()
		if round_index > 0:
			raw.graph_ms.append((graph_end-began)/1000.0)
			raw.plans_ms.append((plans_end-graph_end)/1000.0)
			raw.allocation1024_ms.append((alloc_end-plans_end)/1000.0)
			raw.bfs_ms.append((bfs_end-alloc_end)/1000.0)
		structural = {"tiles": graph.tiles.size(), "nodes": graph.nodes.size(), "routes_per_plan": counts, "allocation_fingerprint": fingerprint, "geometry_bytes_estimate": prepared.get("geometry_bytes", 0)}
		await get_tree().process_frame
	var entry := {"name": label, "rounds": 3, "warmup": 1, "structure": structural, "raw": raw}
	for key in raw: entry[key] = stats(raw[key])
	report.navigation.append(entry)
	print("STRESS_PROGRESS:"+label+" "+JSON.stringify(entry.plans_ms))

func runtime_case(label: String, count: int, tower_count: int, mixed: bool, clustered: bool, show_status := true, speed := 1.0) -> void:
	var cells: Array[Vector2i] = []
	for y in range(-16, 17):
		for x in range(-20, 21): cells.append(Vector2i(x, y))
	scene = Fixture.scene_for(cells, Vector2i(-20, 0), Vector2i(20, 0))
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.show_button = false
	add_child(scene)
	while scene.get_node("PortalMap").computing: await get_tree().process_frame
	scene.get_node("TileVisuals").finish()
	scene.get_node("CardPlacement").process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = scene.get_node("Camera3D")
	camera.position = Vector3(0, 40, 35)
	camera.look_at(Vector3.ZERO)
	camera.size = 42
	var manager: Node = scene.get_node("TowerMap")
	var combat: Node = manager.combat
	# Build the isolated runtime workload without timing topology edits.
	for i in tower_count:
		var tower: DefenseTower = load("res://scenes/towers/sentry.tscn").instantiate()
		tower.grid_cell = Vector2i(-16+(i%16)*2, -12+(i/16)*3)
		manager.add_child(tower)
		tower.position = manager.map.map_to_local(Vector3i(tower.grid_cell.x, 0, tower.grid_cell.y))
		tower.attack_radius = 4
		tower.damage = 1
		tower.attack_interval = 0.1
		if i%4 == 0: tower.attack = load("res://assets/data/towers/attacks/explosive_projectile.tres").duplicate(true)
		manager.towers[tower.grid_cell] = tower
	var spawn_began := Time.get_ticks_usec()
	for i in count:
		var profile: Troop = TroopCatalog.find(["soldier", "quickfeet", "heavy"][i%3] if mixed else "soldier")
		var x := -16.0 if clustered else -16.0+float(i%65)*0.5
		var z := 0.0 if clustered else -12.0+float((i/65)%25)
		var points := PackedVector3Array([Vector3(x, 0.1, z), Vector3(1000, 0.1, z)])
		wave._spawn_entry({"id": i, "profile": profile, "route": {"cells": PackedVector2Array([Vector2(x, z), Vector2(x+1, z)])}, "points": points, "health": 1e9, "shield": 0.0, "speed": 0.15})
	var spawn_ms := (Time.get_ticks_usec()-spawn_began)/1000.0
	wave.set_process(false)
	wave.visuals.set_process(false)
	wave.visuals.status_overlay.set_process(false)
	wave.visuals.status_overlay.visible = show_status
	combat.set_process(false)
	combat.visuals.set_process(false)
	var enemies: Array[Node3D] = wave.living_enemies()
	for enemy in enemies: enemy.set_process(false)
	var raw := {"frame_ms": [], "movement_ms": [], "combat_ms": [], "batch_ms": [], "effects_ms": []}
	var previous := Time.get_ticks_usec()
	var peak_projectiles := 0
	var measure_started := 0
	for frame in 210:
		var now := Time.get_ticks_usec()
		if frame == 30: measure_started = now
		if frame >= 30: raw.frame_ms.append((now-previous)/1000.0)
		previous = now
		var delta := speed/60.0
		for enemy in enemies: enemy._process(delta)
		var moved := Time.get_ticks_usec()
		combat._process(delta)
		var fought := Time.get_ticks_usec()
		wave.visuals._process(delta)
		if show_status: wave.visuals.status_overlay._process(delta)
		var batched := Time.get_ticks_usec()
		combat.visuals._process(delta)
		var effected := Time.get_ticks_usec()
		if frame >= 30:
			raw.movement_ms.append((moved-now)/1000.0)
			raw.combat_ms.append((fought-moved)/1000.0)
			raw.batch_ms.append((batched-fought)/1000.0)
			raw.effects_ms.append((effected-batched)/1000.0)
		peak_projectiles = maxi(peak_projectiles, combat.projectiles.size())
		await get_tree().process_frame
		if frame >= 89 and Time.get_ticks_usec()-measure_started > 6000000: break
	check(wave.alive == count, label+": unexpected enemy removal")
	var entry := {"name": label, "enemies": count, "towers": tower_count, "mixed_models": mixed, "clustered": clustered, "status": show_status, "speed": speed, "spawn_ms": spawn_ms, "samples": raw.frame_ms.size(), "warmup_frames": 30, "shots": combat.shots_fired, "peak_projectiles": peak_projectiles, "raw": raw,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
	for key in raw: entry[key] = stats(raw[key])
	entry.mean_fps = 1000.0/entry.frame_ms.mean
	report.runtime.append(entry)
	print("STRESS_PROGRESS:"+label+" "+JSON.stringify(entry.frame_ms))
	if OS.get_name() != "Web" and DisplayServer.get_name() != "headless" and label == "combat_2048_128":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://reports/performance/extreme_windows.png")
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func run() -> void:
	seed(20261020)
	report.platform = OS.get_name()
	report.engine = Engine.get_version_info().string
	report.display = DisplayServer.get_name()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.viewport = [get_viewport().size.x, get_viewport().size.y]
	report.method = "manual production system steps at fixed 1/60 (4x uses 4/60); wall intervals include actual rendering; 30 warmup + 60..180 measured frames, stop after 6s with at least 60 samples; uncapped native; VSync/rAF can cap Web"
	for spec in [[50, false, 64, 1], [100, false, 64, 1], [21, true, 64, 1], [41, true, 64, 1], [41, true, 256, 1], [21, true, 64, 8]]:
		await navigation_case(spec[0], spec[1], spec[2], spec[3])
	for spec in [["baseline_128", 128, 0, false, false, true, 1.0], ["crowd_512", 512, 0, false, false, true, 1.0], ["crowd_2048", 2048, 0, false, false, true, 1.0], ["crowd_4096", 4096, 0, false, false, true, 1.0], ["cluster_4096", 4096, 0, false, true, true, 1.0], ["no_status_2048", 2048, 0, false, false, false, 1.0], ["combat_2048_128", 2048, 128, false, false, true, 1.0], ["combat_4x_2048_128", 2048, 128, false, false, true, 4.0], ["mixed_256", 256, 0, true, false, true, 1.0]]:
		await runtime_case(spec[0], spec[1], spec[2], spec[3], spec[4], spec[5], spec[6])
	print("EXTREME_BENCHMARK:"+JSON.stringify(report))
	if not OS.has_feature("web"): get_tree().quit(0 if report.failures.is_empty() else 1)
