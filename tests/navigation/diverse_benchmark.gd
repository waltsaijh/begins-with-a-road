extends Node3D
## Same real scenes and seeds on native and single-thread Web; no rendering timed.
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Parameters = preload("res://scripts/map/tile/tile_parameter_store.gd")
const Profile = preload("res://scripts/enemies/troops/troop.gd")

func _ready() -> void:
	var cases := []
	for scene_name in ["9x9", "11x11big"]:
		var scene: Node3D = load("res://scenes/"+scene_name+".tscn").instantiate()
		for child_name in ["PortalOverlay", "PortalMap"]:
			var child := scene.get_node(child_name)
			scene.remove_child(child)
			child.free()
		add_child(scene)
		var map: GridMap = scene.get_node("TileMap")
		var start := map.local_to_map(map.to_local(scene.get_node("Start").global_position))
		var goal := map.local_to_map(map.to_local(scene.get_node("Goal").global_position))
		for threshold in [10.0, 25.0, INF]:
			var raw := {"cold_total": [], "query": [], "search": [], "sample": [], "cache": []}
			var latest := {}
			var check := {}
			for round_index in 23:
				var began := Time.get_ticks_usec()
				var snapshot := Snapshot.capture(map)
				var builder: RefCounted = ClassDB.instantiate("RoadPortalGraph")
				var graph: Dictionary = builder.build(snapshot.cells, snapshot.ports, Vector2i(start.x, start.z), Vector2i(goal.x, goal.z), false)
				var records := Parameters.new()
				records.sync(graph.tiles)
				var evaluated := records.evaluate(Profile.new())
				var planner: RefCounted = ClassDB.instantiate("RoadRoutePlanner")
				var prepared: Dictionary = planner.prepare(graph)
				var query_began := Time.get_ticks_usec()
				var plan: Dictionary = planner.find_paths("bench", evaluated.costs, -1, -1, threshold, 1.0, 64)
				var query_end := Time.get_ticks_usec()
				var local: Dictionary = planner.get_region_paths("bench")
				var ended := Time.get_ticks_usec()
				assert(prepared.valid and plan.valid and plan.reachable and not plan.has("rank"))
				assert(plan.score == (23 if scene_name == "9x9" else 33) and plan.attempts <= 64)
				var cache_began := Time.get_ticks_usec()
				for repeat in 20:
					assert(planner.find_paths("bench", evaluated.costs, -1, -1, threshold, 1.0, 64).cached)
				var cache_end := Time.get_ticks_usec()
				var samples := []
				var sample_began := Time.get_ticks_usec()
				for seed in 256:
					samples.append(planner.sample_route("bench", seed))
				var sample_end := Time.get_ticks_usec()
				var unique := {}
				var indices := {}
				var max_score := 0.0
				var sample_fingerprint := 0
				var late_departures := 0
				for route: Dictionary in samples:
					assert(not route.is_empty() and route.score == route.length and route.score-plan.score < threshold)
					assert(route.nodes[0] == graph.start_node and route.nodes[-1] == graph.goal_node)
					var seen := {}
					for id: int in route.nodes:
						assert(not seen.has(id))
						seen[id] = true
					for n in range(1, route.cells.size()):
						var delta: Vector2 = route.cells[n]-route.cells[n-1]
						assert(absi(int(delta.x))+absi(int(delta.y)) == 1)
					unique[str(route.edges)] = true
					indices[route.route_index] = true
					max_score = maxf(max_score, route.score)
					var late := false
					for n in range(1, route.nodes.size()-1):
						var at: Vector2i = graph.nodes[route.nodes[n]].cell
						var next: Vector2i = graph.nodes[route.nodes[n+1]].cell
						if at.y == 0 and at.x >= 12 and next.y != 0:
							for j in range(n+2, route.nodes.size()):
								var later: Vector2i = graph.nodes[route.nodes[j]].cell
								if later.y == 0 and later.x > at.x:
									late = true
					late_departures += int(late)
					sample_fingerprint = int((sample_fingerprint*31+hash(route.cells)) % 2147483647)
				check = {"unique_vertex_routes_in_256_samples": unique.size(), "pool_entries_sampled": indices.size(), "max_sample_score": max_score, "late_main_road_departures_and_rejoins": late_departures, "fingerprint": sample_fingerprint}
				if round_index >= 3:
					raw.cold_total.append(ended-began)
					raw.query.append(query_end-query_began)
					raw.search.append(plan.search_us)
					raw.cache.append(float(cache_end-cache_began)/20)
					raw.sample.append(float(sample_end-sample_began)/256)
				latest = {"tiles": graph.stats.tiles, "vertices": graph.nodes.size(), "directed_choices": plan.choice_edges, "best": plan.score, "routes": plan.routes, "attempts": plan.attempts, "used_directed_edges": plan.used_edges, "stop_reason": plan.stop_reason, "rejected": plan.rejected, "duplicates": plan.duplicates, "geometry_bytes_estimate": prepared.geometry_bytes, "plan_bytes_estimate": plan.plan_bytes}
				assert(not local.is_empty())
				await get_tree().process_frame
			cases.append({"scene": scene_name, "sha256": FileAccess.get_sha256("res://scenes/"+scene_name+".tscn"), "threshold": "inf" if is_inf(threshold) else str(threshold), "raw_us": raw, "plan": latest, "distribution": check})
		scene.queue_free()
		await get_tree().process_frame
	print("DIVERSE_BENCHMARK:"+JSON.stringify({"platform": OS.get_name(), "warmup": 3, "rounds": 20, "penalty": 1.0, "search_budget": 64, "cases": cases}))
	if not OS.has_feature("web"):
		get_tree().quit()
