extends Node3D
const Distribution = preload("res://scripts/navigation/routes/route_distribution.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func old_indices(count: int, total := 64) -> PackedInt32Array:
	var result := PackedInt32Array()
	var order := PackedInt32Array()
	for seed in total:
		if seed%count == 0:
			order.resize(count)
			for i in count: order[i] = i
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			for i in range(count-1, 0, -1):
				var j := rng.randi_range(0, i)
				var swap := order[i]
				order[i] = order[j]
				order[j] = swap
		result.append(order[seed%count])
	return result

func weighted_indices(cdf: PackedFloat64Array, total := 64) -> PackedInt32Array:
	var result := PackedInt32Array()
	for seed in total:
		result.append(Distribution.sample(cdf, seed))
	return result

func allocated_indices(cdf: PackedFloat64Array, total: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in total:
		result.append(Distribution.allocate(cdf, index, total))
	return result

func stats(indices: PackedInt32Array, scores: PackedFloat64Array, branches: Array[bool]) -> Dictionary:
	var seen := {}
	var sum := 0.0
	var branched := 0
	for index in indices:
		seen[index] = true
		sum += scores[index]
		if not branches.is_empty() and branches[index]: branched += 1
	var result := {"unique_routes": seen.size(), "mean_score": sum/indices.size()}
	if not branches.is_empty():
		result.branched_side = branched
		result.straight = indices.size()-branched
	return result

func median(values: Array[int]) -> int:
	values.sort()
	return values[values.size()>>1]

func ready_map(scene: Node) -> void:
	for i in 120:
		if not scene.get_node("PortalMap").computing and not scene.get_node("PortalMap").plan.is_empty(): return
		await get_tree().process_frame
	check(false, "Distribution fixture failed to prepare")

func verify() -> void:
	check((TroopCatalog.find("soldier").duplicate() as Troop).route_selection == Troop.RouteSelection.UNIFORM, "Soldier must default to Uniform")
	check((TroopCatalog.find("quickfeet").duplicate() as Troop).route_selection == Troop.RouteSelection.SOFTMAX and (TroopCatalog.find("heavy").duplicate() as Troop).route_selection == Troop.RouteSelection.SOFTMAX, "Other troops must default to Softmax")
	var distribution := Distribution.build(PackedFloat64Array([1000, 1004, 1008]), 4)
	var shifted := Distribution.build(PackedFloat64Array([-1000, -996, -992]), 4)
	var probabilities: PackedFloat64Array = distribution.probabilities
	check(is_equal_approx(probabilities[0], 0.665240955774822) and is_equal_approx(probabilities[1], 0.244728471054798), "Softmax sign, temperature or normalization incorrect")
	check(probabilities == shifted.probabilities, "Signed-score shift changed probabilities")
	var equal := Distribution.build(PackedFloat64Array([1, 1, 1, 1, 1, 1, 1, 1, 1]), 4)
	check(is_equal_approx(equal.probabilities[0]*8, 8.0/9.0), "Equal-cost route multiplicity unexpectedly disappeared")
	check(not Distribution.build(PackedFloat64Array([1]), 0).valid and not Distribution.build(PackedFloat64Array([1]), NAN).valid, "Invalid temperature accepted")
	check(Distribution.build(PackedFloat64Array([1, 100]), INF).probabilities == PackedFloat64Array([0.5, 0.5]), "Infinite temperature was not uniform")
	var uniform := Distribution.build(PackedFloat64Array([-100, 0, 100]), NAN, Troop.RouteSelection.UNIFORM)
	check(uniform.valid and uniform.probabilities == PackedFloat64Array([1.0/3.0, 1.0/3.0, 1.0/3.0]), "Uniform depends on scores or temperature")
	check(allocated_indices(uniform.cdf, 5) == PackedInt32Array([0, 0, 1, 1, 2]), "Three uniform routes/five enemies must allocate 2/2/1")
	check(allocated_indices(PackedFloat64Array([0.2, 0.8, 1.0]), 5) == PackedInt32Array([0, 1, 1, 1, 2]), "CDF boundary must belong to the next nonzero interval")
	check(allocated_indices(PackedFloat64Array([0.0, 1.0, 1.0]), 5) == PackedInt32Array([1, 1, 1, 1, 1]), "Allocation selected a zero-probability route")
	check(Distribution.allocate(uniform.cdf, 0, 0) == -1 and Distribution.allocate(uniform.cdf, -1, 5) == -1 and Distribution.allocate(uniform.cdf, 5, 5) == -1 and Distribution.allocate(PackedFloat64Array(), 0, 5) == -1, "Invalid allocation accepted")
	for total in [1, 2, 5, 64, 100]:
		var counts := PackedInt32Array([0, 0, 0])
		for index in allocated_indices(distribution.cdf, total):
			counts[index] += 1
		for i in 3:
			check(absf(counts[i]-total*probabilities[i]) < 1.000001, "Softmax allocation differs from its quota by more than one enemy")
	var uniform_counts := PackedInt32Array([0, 0, 0])
	for seed in 10000:
		uniform_counts[Distribution.sample(uniform.cdf, seed)] += 1
	for count in uniform_counts:
		check(absf(count/10000.0-1.0/3.0) < 0.015, "Uniform sampling is biased")
	check(Distribution.sample(PackedFloat64Array(), 0) == -1, "Empty distribution yielded a route")
	check(not Distribution.build(PackedFloat64Array([INF]), 1).valid, "Infinite score accepted")
	var extreme := Distribution.build(PackedFloat64Array([1e308, -1e308, 1e308]), 0.01)
	for seed in 256:
		check(Distribution.sample(extreme.cdf, seed) == 1, "Zero-probability tail selected or extreme scores overflowed")
	var histogram := PackedInt32Array([0, 0, 0])
	for seed in 10000:
		var selected := Distribution.sample(distribution.cdf, seed)
		check(selected == Distribution.sample(distribution.cdf, seed), "Fixed seed is not deterministic")
		histogram[selected] += 1
	for i in 3:
		check(absf(histogram[i]/10000.0-probabilities[i]) < 0.015, "Observed sampling differs from softmax probabilities")
	var cases := []
	for kind in ["three_corridors", "two_corridors", "upper_ladder", "lower_ladder", "9x9", "11x11big"]:
		var scene: Node3D
		if kind == "three_corridors":
			var cells: Array[Vector2i] = []
			for x in range(-2, 11): cells.append(Vector2i(x, 2))
			for x in range(0, 9):
				cells.append(Vector2i(x, 0))
				cells.append(Vector2i(x, 4))
			for x in [0, 8]:
				cells.append(Vector2i(x, 1))
				cells.append(Vector2i(x, 3))
			scene = Fixture.scene_for(cells, Vector2i(-2, 2), Vector2i(10, 2))
		elif kind in ["9x9", "11x11big"]:
			scene = load("res://scenes/"+kind+".tscn").instantiate()
		else:
			var cells: Array[Vector2i] = []
			for x in range(-2, 11): cells.append(Vector2i(x, 0))
			var side := 1 if kind == "lower_ladder" else -1
			for x in range(0, 9): cells.append(Vector2i(x, side*2))
			cells.append(Vector2i(0, side))
			cells.append(Vector2i(8, side))
			if kind != "two_corridors":
				for x in range(0, 9): cells.append(Vector2i(x, side*4))
				for x in [0, 2, 4, 6, 8]: cells.append(Vector2i(x, side*3))
			scene = Fixture.scene_for(cells, Vector2i(-2, 0), Vector2i(10, 0))
		var wave: Node = scene.get_node("EnemyWave")
		wave.auto_start = false
		wave.enemy_count = 5 if kind == "three_corridors" else 64
		add_child(scene)
		wave.set_process(false)
		await ready_map(scene)
		var controller: Node = scene.get_node("PortalMap")
		var profile: Troop = controller.troop
		for origin in controller.start_nodes.size():
			var plan: Dictionary = controller.plan_for(profile, origin)
			var scores := PackedFloat64Array()
			var branches: Array[bool] = []
			for i in plan.routes:
				var route: Dictionary = controller.sample_for(profile, 0, origin, i)
				scores.append(route.score)
				var branch := false
				for cell: Vector2 in route.cells: branch = branch or cell.y != 0
				if kind not in ["9x9", "11x11big"]: branches.append(branch)
			var variants := []
			for temperature: float in [1.0, 4.0, 16.0, INF]:
				var table := Distribution.build(scores, temperature)
				var observed := stats(weighted_indices(table.cdf), scores, branches)
				var expected_branch := 0.0
				var expected_score := 0.0
				for i in scores.size():
					if not branches.is_empty() and branches[i]: expected_branch += table.probabilities[i]
					expected_score += scores[i]*table.probabilities[i]
				var variant := {"temperature": str(temperature), "observed64": observed, "expected_score": snappedf(expected_score, 0.000001)}
				if not branches.is_empty(): variant.expected_branch_probability = snappedf(expected_branch, 0.000000001)
				variants.append(variant)
			var table := Distribution.build(scores, profile.route_temperature, profile.route_selection)
			check(table.probabilities == plan.route_probabilities, "Gameplay probabilities differ from selected mode")
			var expected := weighted_indices(table.cdf)
			for seed in 64:
				check(controller.next_route_for(profile, seed, origin).route_index == expected[seed], "Gameplay bypassed the weighted sampler")
			wave.start_index = origin
			check(wave.start_wave(), "Weighted wave failed to prepare")
			var first_assignment := {}
			var departure_order := PackedInt32Array()
			for entry: Dictionary in wave._pending:
				check(entry.route.route_index == Distribution.allocate(table.cdf, entry.wave_index, wave.enemy_count), "Wave bypassed index/total allocation")
				first_assignment[entry.wave_index] = entry.route.route_index
				departure_order.append(entry.wave_index)
			check(first_assignment.size() == wave.enemy_count, "Shuffle duplicated or lost an enemy")
			if kind == "three_corridors":
				check(plan.routes == 3 and first_assignment.values().count(0) == 2 and first_assignment.values().count(1) == 2 and first_assignment.values().count(2) == 1, "Actual five-enemy wave did not allocate 2/2/1")
			wave._pending.clear()
			wave.active = false
			check(wave.start_wave(), "Repeated quota wave failed")
			var next_order := PackedInt32Array()
			for entry: Dictionary in wave._pending:
				check(entry.route.route_index == first_assignment[entry.wave_index], "Global enemy IDs or shuffle changed route quotas")
				next_order.append(entry.wave_index)
			check(next_order != departure_order, "Departure order was not shuffled between waves")
			# Remove pending wave state before measuring another origin.
			wave._pending.clear()
			wave.active = false
			var build_us: Array[int] = []
			var weighted_us: Array[int] = []
			var old_us: Array[int] = []
			for trial in 21:
				var began := Time.get_ticks_usec()
				Distribution.build(scores, profile.route_temperature)
				build_us.append(Time.get_ticks_usec()-began)
				began = Time.get_ticks_usec()
				weighted_indices(table.cdf)
				weighted_us.append(Time.get_ticks_usec()-began)
				began = Time.get_ticks_usec()
				old_indices(scores.size())
				old_us.append(Time.get_ticks_usec()-began)
			cases.append({"scene": kind, "origin": origin, "routes": scores.size(), "old_shuffle64": stats(old_indices(scores.size()), scores, branches), "temperatures": variants, "distribution_build_us": median(build_us), "weighted64_us": median(weighted_us), "old_shuffle64_us": median(old_us)})
		# Threshold is still a hard filter, and temperature edits invalidate caches.
		if kind == "two_corridors":
			var saved_temperature: float = profile.route_temperature
			profile.route_temperature = INF
			check(controller.plan_for(profile).route_probabilities == PackedFloat64Array([0.5, 0.5]), "Temperature edit left stale probabilities")
			profile.score_threshold = 4
			check(controller.plan_for(profile).routes == 1, "Threshold boundary was included")
			profile.score_threshold = INF
			profile.route_temperature = saved_temperature
		# Switching via the wave API must invalidate every origin's plan.
		var saved_selection: Troop.RouteSelection = profile.route_selection
		profile.route_selection = Troop.RouteSelection.SOFTMAX
		var before: Array[Dictionary] = []
		for origin in controller.start_nodes.size():
			before.append(controller.plan_for(profile, origin))
		wave.select_route_selection(Troop.RouteSelection.UNIFORM)
		check(profile.route_selection == Troop.RouteSelection.UNIFORM, "Wave API did not select Uniform")
		for origin in controller.start_nodes.size():
			var plan: Dictionary = controller.plan_for(profile, origin)
			check(plan.routes == before[origin].routes and plan.steps == before[origin].steps, "Distribution mode changed accepted candidates")
			for probability: float in plan.route_probabilities:
				check(is_equal_approx(probability, 1.0/plan.routes), "Uniform gameplay candidates are not equally likely")
			check(plan.route_selection == Troop.RouteSelection.UNIFORM, "Origin retained stale mode")
		wave.start_index = 0
		check(wave.start_wave(), "Uniform wave failed to prepare")
		var committed: Dictionary = wave._pending[0].route.duplicate(true)
		wave.select_route_selection(Troop.RouteSelection.SOFTMAX)
		check(profile.route_selection == Troop.RouteSelection.UNIFORM, "Mode can change during an active wave")
		profile.route_selection = Troop.RouteSelection.SOFTMAX
		check(wave._pending[0].route == committed, "Mode edit changed an already committed route")
		wave._pending.clear()
		wave.active = false
		for origin in controller.start_nodes.size():
			var restored: Dictionary = controller.plan_for(profile, origin)
			check(restored.route_probabilities == before[origin].route_probabilities, "Softmax probabilities were not restored")
			wave.start_index = origin
			check(wave.start_wave(), "Softmax quota wave failed")
			var scores := PackedFloat64Array()
			for i in restored.routes:
				scores.append(controller.sample_for(profile, 0, origin, i).score)
			var table := Distribution.build(scores, profile.route_temperature, Troop.RouteSelection.SOFTMAX)
			for entry: Dictionary in wave._pending:
				check(entry.route.route_index == Distribution.allocate(table.cdf, entry.wave_index, wave.enemy_count), "Softmax wave bypassed deterministic weighted quotas")
			wave._pending.clear()
			wave.active = false
		if kind == "two_corridors":
			profile.route_selection = Troop.RouteSelection.UNIFORM
			profile.score_threshold = 4
			check(controller.plan_for(profile).routes == 1, "Uniform included the threshold boundary")
			profile.score_threshold = 0
			check(controller.plan_for(profile).routes == 0 and controller.next_route_for(profile, 0).is_empty(), "Uniform accepted routes at zero threshold")
			profile.score_threshold = INF
		profile.route_selection = saved_selection
		scene.queue_free()
		await get_tree().process_frame
	var report := {"platform": OS.get_name(), "failures": failures, "uniform": true, "mode_switch": true, "stable_softmax": true, "deterministic_quotas": true, "shuffled_departures": true, "uniform_three_routes_five_enemies": [2, 2, 1], "hard_threshold": true, "histogram10000": Array(histogram), "cases": cases}
	print("ROUTE_DISTRIBUTION_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		FileAccess.open("res://reports/navigation/route_distribution_windows.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ")+"\n")
		get_tree().quit(1 if failures else 0)
