extends SceneTree
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	for name in ["9x9", "11x11big"]:
		var scene: Node3D = load("res://scenes/"+name+".tscn").instantiate()
		root.add_child(scene)
		var controller: Node = scene.get_node("PortalMap")
		while controller.computing:
			await process_frame
		var map: GridMap = scene.get_node("TileMap")
		var start := map.local_to_map(map.to_local(scene.get_node("Start").global_position))
		var goal := map.local_to_map(map.to_local(scene.get_node("Goal").global_position))
		var snapshot := Snapshot.capture(map)
		var builder: RefCounted = ClassDB.instantiate("RoadPortalGraph")
		var full: Dictionary = builder.build(snapshot.cells, snapshot.ports, Vector2i(start.x, start.z), Vector2i(goal.x, goal.z))
		var shape: Dictionary = builder.build(snapshot.cells, snapshot.ports, Vector2i(start.x, start.z), Vector2i(goal.x, goal.z), false)
		assert(full.valid and shape.valid and shape.local_routes.is_empty())
		for key in ["tiles", "nodes", "corridors", "quads", "borders", "quad_regions", "border_regions"]:
			assert(full[key] == shape[key])
		for r in full.regions.size():
			for key in ["cells", "nodes", "route_links", "route_node_cells"]:
				assert(full.regions[r][key] == shape.regions[r][key])
		var first: RefCounted = ClassDB.instantiate("RoadRoutePlanner")
		var second: RefCounted = ClassDB.instantiate("RoadRoutePlanner")
		assert(first.prepare(full).valid and second.prepare(shape).valid)
		for mode in 3:
			var costs := PackedFloat64Array()
			for i in shape.tiles.size():
				costs.append(1.0 if mode == 0 else 2.5 if mode == 1 else (i%5+1)*0.5)
			var a: Dictionary = first.find_paths("test", costs)
			var b: Dictionary = second.find_paths("test", costs)
			for key in ["valid", "reachable", "score", "routes", "steps", "directions", "choice_edges", "used_edges"]:
				assert(a[key] == b[key])
			assert(first.get_region_paths("test") == second.get_region_paths("test"))
			for seed in 32:
				assert(first.sample_route("test", seed) == second.sample_route("test", seed))
			# Returned metadata/packed-array edits must not corrupt future cache hits.
			var steps: PackedInt32Array = b.steps.duplicate()
			var directions: PackedVector2Array = b.directions.duplicate()
			b.steps[0] = -999
			b.directions[0] = Vector2(-999, -999)
			b.score = -999
			var cached: Dictionary = second.find_paths("test", costs)
			assert(cached.cached and cached.steps == steps and cached.directions == directions and cached.score == a.score)
		scene.queue_free()
		await process_frame
	print("PASS: geometry-only/full build equality, weighted local fields, every same-cost route, exact seeded samples, bulk packing and mutation-safe cached results on both real scenes")
	quit()
