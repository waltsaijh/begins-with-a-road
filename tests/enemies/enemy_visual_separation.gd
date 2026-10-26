extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Solver = preload("res://scripts/enemies/rendering/enemy_visual_separation.gd")
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func pair(positions: PackedVector2Array, normals: PackedVector2Array) -> void:
	var solver := Solver.new()
	var offsets := solver.solve(positions, normals, PackedInt64Array([0, 1]), PackedFloat32Array([0, 0]))
	var before := positions[0].distance_to(positions[1])
	var after := (positions[0]+normals[0]*offsets[0]).distance_to(positions[1]+normals[1]*offsets[1])
	check(after > before+0.1, "Pair did not separate, including across a tile boundary")
	for offset in offsets:
		check(is_finite(offset) and absf(offset) <= EnemyRenderConstants.VISUAL_MAX_OFFSET+0.00001, "Offset outside safe tile width")
	var reversed := solver.solve(PackedVector2Array([positions[1], positions[0]]), PackedVector2Array([normals[1], normals[0]]), PackedInt64Array([1, 0]), PackedFloat32Array([0, 0]))
	check(is_equal_approx(offsets[0], reversed[1]) and is_equal_approx(offsets[1], reversed[0]), "Pair tie depends on dense slot order")

func verify_turning() -> void:
	var solver := Solver.new()
	var positions := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	var normals := PackedVector2Array([Vector2.RIGHT, Vector2.UP])
	var ids := PackedInt64Array([0, 1])
	var previous := PackedFloat32Array([0.12, -0.12])
	for ignored in [PackedByteArray([1, 0]), PackedByteArray([0, 1]), PackedByteArray([1, 1])]:
		check(solver.solve(positions, normals, ids, previous, ignored) == previous, "Turning actor still pushed itself or its straight neighbor")
	check(solver.candidate_checks == 0, "Fully turning crowd still performs contact checks")
	# Test either direction: retain the existing lane shift while the model turns,
	# then restore ordinary separation after its heading settles.
	for direction: Vector3 in [Vector3.LEFT, Vector3.RIGHT]:
		var batch := Batch.new()
		add_child(batch)
		batch.set_process(false)
		var units: Array[Node3D] = []
		var points := PackedVector3Array([Vector3.ZERO, Vector3.FORWARD*4])
		for i in 2:
			var unit: Node3D = Enemy.instantiate()
			add_child(unit)
			unit.follow(i, {}, points)
			unit.set_process(false)
			batch.add_enemy(unit)
			units.append(unit)
		for frame in 60: batch._process(1.0/60)
		var held := batch._offsets[0]
		var neighbor_target := batch._targets[1]
		units[0].move_direction = direction
		for frame in 12:
			batch._process(1.0/60)
			check(batch._poses[0].turning and not batch._poses[1].turning, "Turn gate did not distinguish turning and straight actors")
			check(batch._offsets[0] == held and batch._targets[1] == neighbor_target, "A turn changed lateral offsets or kept pushing the straight actor")
			check(units[0].global_position == Vector3.ZERO and units[0].waypoints == points and units[0]._next == 1, "Ignoring turning contacts changed logical motion")
		for frame in 30: batch._process(1.0/60)
		check(not batch._poses[0].turning and batch._offsets[0] != held, "Separation did not resume after the turn")
		batch._countdown = 0
		batch._process(1.0/60)
		check(batch.separation.candidate_checks > 0, "Settled actors never rejoined collision sampling")
		for unit in units: unit.free()
		batch.free()

func verify_smoothing() -> void:
	var final_offsets: Array[Vector2] = []
	for fps in [30, 60, 120]:
		var batch := Batch.new()
		add_child(batch)
		batch.set_process(false)
		var units: Array[Node3D] = []
		for i in 2:
			var unit: Node3D = Enemy.instantiate()
			add_child(unit)
			unit.follow(i, {}, PackedVector3Array([Vector3.ZERO, Vector3.FORWARD*20]))
			unit.set_process(false)
			batch.add_enemy(unit)
			units.append(unit)
		batch._process(1.0/fps)
		check(batch._offsets[0].length() < absf(batch._targets[0])*0.1, "Avoidance begins with an abrupt lateral jump")
		for i in fps/2-1: batch._process(1.0/fps)
		final_offsets.append(batch._offsets[0])
		check(batch._offsets[0].length() > absf(batch._targets[0])*0.65 and batch._offsets[0].length() < absf(batch._targets[0])*0.95, "Avoidance no longer makes a gradual half-second transition")
		for i in fps*2: batch._process(1.0/fps)
		var retained := batch._offsets[0]
		units[1].position = Vector3(10, 0, 0)
		for i in fps*2: batch._process(1.0/fps)
		check(batch._offsets[0].distance_to(retained) < 0.0001 and batch._offsets[0].length() > 0.1, "Enemy returned to the centre after its neighbor left")
		for unit in units: unit.free()
		check(batch._offset_velocities.is_empty(), "Dense-slot removal left avoidance velocity behind")
		batch.free()
	check(final_offsets[0].distance_to(final_offsets[1]) < 0.00001 and final_offsets[1].distance_to(final_offsets[2]) < 0.00001, "Avoidance smoothing depends on frame rate")

func verify() -> void:
	pair(PackedVector2Array([Vector2(0.5, 0.5), Vector2(0.5, 0.5)]), PackedVector2Array([Vector2.RIGHT, Vector2.RIGHT]))
	pair(PackedVector2Array([Vector2(0.5, 0.98), Vector2(0.5, 1.02)]), PackedVector2Array([Vector2.RIGHT, Vector2.RIGHT]))
	pair(PackedVector2Array([Vector2(-0.02, -0.5), Vector2(0.02, -0.5)]), PackedVector2Array([Vector2.RIGHT, Vector2.RIGHT]))
	pair(PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), PackedVector2Array([Vector2.RIGHT, Vector2.LEFT]))
	pair(PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), PackedVector2Array([Vector2.RIGHT, Vector2.UP]))
	var solver := Solver.new()
	var cases := []
	for count in [64, 256, 1024, 4096]:
		var positions := PackedVector2Array()
		var normals := PackedVector2Array()
		var ids := PackedInt64Array()
		var offsets := PackedFloat32Array()
		positions.resize(count)
		normals.resize(count)
		ids.resize(count)
		offsets.resize(count)
		positions.fill(Vector2(0.5, 0.5))
		normals.fill(Vector2.RIGHT)
		for i in count:
			ids[i] = i
		# Everyone in ONE tile is the case that breaks an uncapped pairwise scan.
		offsets = solver.solve(positions, normals, ids, offsets)
		check(solver.candidate_checks == count*EnemyRenderConstants.VISUAL_SAMPLES_PER_TILE*EnemyRenderConstants.VISUAL_SEPARATION_ITERATIONS, "Crowded tile work is not strictly bounded per unit")
		for offset in offsets:
			check(is_finite(offset) and absf(offset) <= EnemyRenderConstants.VISUAL_MAX_OFFSET+0.00001, "Dense crowd offset escaped bounds")
		cases.append({"units": count, "candidate_checks": solver.candidate_checks})
	# Exercise every adjacent bucket, not just a single crowded bucket.
	var positions := PackedVector2Array()
	var normals := PackedVector2Array()
	var ids := PackedInt64Array()
	for y in range(-4, 5):
		for x in range(-4, 5):
			for j in 3:
				ids.append(ids.size())
				positions.append(Vector2(x+0.5, y+0.5))
				normals.append(Vector2.RIGHT)
	var targets := PackedFloat32Array()
	targets.resize(ids.size())
	solver.solve(positions, normals, ids, targets)
	check(solver.candidate_checks <= ids.size()*9*EnemyRenderConstants.VISUAL_SAMPLES_PER_TILE*EnemyRenderConstants.VISUAL_SEPARATION_ITERATIONS, "Neighbor checks exceed linear bound")
	# Integrated display-only movement, smoothing and slot compaction.
	var batch := Batch.new()
	add_child(batch)
	batch.set_process(false)
	var map := GridMap.new()
	map.cell_size = Vector3.ONE
	add_child(map)
	map.position = Vector3(7, 1, -4)
	map.rotation.y = 0.4
	map.scale = Vector3.ONE*1.5
	batch.map = map
	var units: Array[Node3D] = []
	var points := PackedVector3Array([Vector3(0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(1.5, 0, -0.5)])
	for i in points.size():
		points[i] = map.to_global(points[i])
	for i in 2:
		var unit := Enemy.instantiate()
		add_child(unit)
		unit.follow(i, {}, points)
		batch.add_enemy(unit)
		unit.set_process(false)
		units.append(unit)
	for frame in 60:
		batch._process(1.0/60)
	check(batch._offsets[0].distance_to(batch._offsets[1]) > 0.3, "Integrated display separation failed")
	for i in 2:
		check(units[i].global_position == points[0] and units[i].waypoints == points and units[i]._next == 1, "Visual solver changed logical movement")
		if DisplayServer.get_name() != "headless":
			var displayed := batch.multimesh.get_instance_transform(i).origin
			check(displayed.distance_to(units[i].position) > 0.1, "MultiMesh did not receive the visual offset")
		units[i]._process(0.2)
	check(units[0].global_position.is_equal_approx(units[1].global_position), "Separation changed movement speed")
	for unit in units:
		unit._process(0.5) # cross the corner while the display offsets turn smoothly
	batch._process(1.0/60)
	check(units[0].global_position.is_equal_approx(units[1].global_position), "Turn separation changed logical progress")
	for offset in batch._offsets:
		check(offset.length() <= EnemyRenderConstants.VISUAL_MAX_OFFSET+0.00001, "Smoothed turn escaped its display radius")
	var before := batch._offsets[1]
	units[0].free()
	check(batch.units[0] == units[1] and batch._offsets[0] == before, "Slot compaction lost the visual state")
	units[1].free()
	check(batch._offsets.is_empty() and batch._targets.is_empty() and not batch.is_processing(), "Empty visual solver kept state or processing")
	batch.free()
	map.free()
	verify_turning()
	verify_smoothing()
	var report := {"platform": OS.get_name(), "failures": failures, "boundary_pairs": 5, "turns_ignore_contacts": true, "straight_neighbor_unchanged": true, "separation_resumes": true, "logical_motion_unchanged": true, "smooth_longer_transition": true, "no_return_to_center": true, "frame_rate_independent": true, "cases": cases}
	print("ENEMY_SEPARATION_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		var file := FileAccess.open(Artifacts.path("enemies/enemy_visual_separation_windows.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ")+"\n")
		get_tree().quit(1 if failures else 0)
