extends Node3D
const History = preload("res://scripts/navigation/routes/route_history.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func snapshot(cells: Array[Vector2i]) -> Dictionary:
	var packed := PackedInt32Array()
	var ports := PackedByteArray()
	for c in cells:
		packed.append_array(PackedInt32Array([c.x,c.y]))
		ports.append(15)
	return {"cells":packed,"ports":ports}
func add_lane(cells: Array[Vector2i], y: int) -> void:
	for x in 9:
		var c := Vector2i(x,y)
		if not c in cells: cells.append(c)
	for row in range(mini(0,y),maxi(0,y)+1):
		for x in [0,8]:
			var c := Vector2i(x,row)
			if not c in cells: cells.append(c)
func _ready() -> void: run.call_deferred()
func run() -> void:
	var specs := {"rat_swarm":["small",&"ground",&"swarm"],"shield_guardian":["large",&"ground",&"armored",&"guardian"],"blood_mage":["standard",&"ground",&"support"],"winged_beast":["standard",&"flying"],"scout":["small",&"ground",&"scout"],"saboteur":["standard",&"ground",&"saboteur"]}
	for id: String in specs:
		var troop := TroopCatalog.find(id)
		check(troop != null and troop.configuration_error().is_empty(),"valid editable profile "+id)
		for tag: String in specs[id]: check(troop.has_tag(StringName(tag)),id+" tag "+tag)
		check(troop.model != null and troop.icon != null,"model and icon "+id)
	check(TroopCatalog.find("blood_mage").route_selection == Troop.RouteSelection.UNIFORM,"mage Uniform")
	check(TroopCatalog.find("shield_guardian").threat_weight == 0 and TroopCatalog.find("saboteur").threat_weight == 0,"guardian/saboteur no safety seeking")
	var cells: Array[Vector2i] = []
	add_lane(cells,0)
	add_lane(cells,-2)
	var history := History.new()
	var terminals: Array[Vector2i] = [Vector2i(8,0),Vector2i(0,0)]
	history.record(snapshot(cells),terminals)
	var initial: Dictionary = history.candidates(0,false)
	check(initial.valid and initial.birth_wave == 0 and initial.paths.size() >= 2,"all initial paths baseline zero")
	var revision: int = history.revision
	history.wave = 1
	history.record(snapshot(cells),terminals)
	check(history.revision == revision,"cache rebuild does not create birth")
	cells.append(Vector2i(4,1))
	cells.append(Vector2i(4,2))
	history.record(snapshot(cells),terminals)
	check(history.candidates(0,false).birth_wave == 0,"dead-end extension does not refresh old routes")
	cells.erase(Vector2i(4,1))
	cells.erase(Vector2i(4,2))
	history.wave = 2
	add_lane(cells,3)
	history.record(snapshot(cells),terminals)
	add_lane(cells,6)
	history.record(snapshot(cells),terminals)
	var newest: Dictionary = history.candidates(0,false)
	check(newest.valid and newest.birth_wave == 2,"new legal choices get committed wave")
	var on_three := false
	var on_six := false
	for path: Dictionary in newest.paths:
		on_three = on_three or Vector2(4,3) in path.cells
		on_six = on_six or Vector2(4,6) in path.cells
		check(path.birth_wave == 2 and (Vector2(4,3) in path.cells or Vector2(4,6) in path.cells),"old route never revived by weighting")
	check(on_three and on_six,"two new same-wave routes both represented")
	var special = preload("res://scripts/navigation/routes/special_routes.gd").new()
	special.history = history
	var scout := TroopCatalog.find("scout").duplicate() as Troop
	scout.search_budget = 1
	scout.score_threshold = 0
	var old_flag := [{"tags":[&"ground"],"excluded_tags":[],"cells":{Vector2i(4,0):true},"multiplier":1000.0}]
	var plan: Dictionary = special.plan_for(scout,0,old_flag)
	check(plan.valid and plan.routes > 0,"newest eligibility independent of ordinary budget and zero score threshold")
	for i in plan.routes:
		var chosen: Dictionary = special.route_for(scout,0,old_flag,0,1,-1,i)
		check(chosen.birth_wave == 2,"old-route flag cannot restore an ineligible route")
	var shortest: Dictionary = history.candidates(0,true)
	check(shortest.valid and shortest.distance == 8,"physical distance ignores costs")
	for path: Dictionary in shortest.paths: check(path.cells.size() == 9,"only globally shortest grid paths")
	var old_cells: Array[Vector2i] = []
	add_lane(old_cells,0)
	add_lane(old_cells,-2)
	history.wave = 3
	history.record(snapshot(old_cells),terminals)
	check(history.candidates(0,false).birth_wave == 0,"invalid new route safely falls back to surviving batch")
	history.wave = 4
	add_lane(old_cells,3)
	history.record(snapshot(old_cells),terminals)
	check(history.candidates(0,false).birth_wave == 2,"restored old identity retains first birth")
	var native_search: RefCounted = ClassDB.instantiate("RoadSpecialRoutes")
	var limited: Dictionary = native_search.plan(history.current.cells,history.current.ports,Vector2i.ZERO,Vector2i(8,0),history.snapshots,false,1)
	check(not limited.valid and limited.paths.is_empty(),"non-monotone work limit reports failure without silently selecting old paths")
	verify_oracle()
	await verify_schedule(cells)
	var output := {"checks":checks,"failures":failures}
	FileAccess.open(Artifacts.path("synergy/routing.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("SYNERGY_ROUTING:",JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)

func oracle_paths(cells: Array[Vector2i], at: Vector2i, goal: Vector2i, path: Array[Vector2i], result: Array) -> void:
	if at == goal:
		result.append(path.duplicate())
		return
	for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var next: Vector2i = at+d
		if next in cells and not next in path:
			path.append(next)
			oracle_paths(cells,next,goal,path,result)
			path.pop_back()

func verify_oracle() -> void:
	# Exhaustive small grids compare hard eligibility to every simple path.
	for mask in 128:
		var cells: Array[Vector2i] = [Vector2i(0,0),Vector2i(2,2)]
		var bit := 0
		for y in 3:
			for x in 3:
				var cell := Vector2i(x,y)
				if cell in cells: continue
				if mask & (1 << bit): cells.append(cell)
				bit += 1
		var old := cells.duplicate()
		old.erase(Vector2i(1,1))
		var history := History.new()
		history.record(snapshot(old),[Vector2i(2,2),Vector2i.ZERO])
		history.wave = 2
		history.record(snapshot(cells),[Vector2i(2,2),Vector2i.ZERO])
		var all: Array = []
		oracle_paths(cells,Vector2i.ZERO,Vector2i(2,2),[Vector2i.ZERO],all)
		var latest := -1
		var length := 999
		for path: Array in all:
			latest = maxi(latest,2 if Vector2i(1,1) in path else 0)
			length = mini(length,path.size()-1)
		var actual: Dictionary = history.candidates(0,false)
		var fast: Dictionary = history.candidates(0,true)
		check(actual.valid and (actual.paths.is_empty() if all.is_empty() else actual.birth_wave == latest),"oracle newest mask %d" % mask)
		check(fast.valid and (fast.paths.is_empty() if all.is_empty() else fast.distance == length),"oracle shortest mask %d" % mask)

func verify_schedule(cells: Array[Vector2i]) -> void:
	var scene := Fixture.scene_for(cells,Vector2i.ZERO,Vector2i(8,0))
	scene.get_node("EnemyWave").auto_start = false
	var extra := scene.get_node("Start").duplicate() as Node3D
	extra.name = "Start2"
	scene.add_child(extra)
	extra.position = scene.get_node("TileMap").transform*scene.get_node("TileMap").map_to_local(Vector3i(8,0,6))
	scene.get_node("PortalMap").start_paths.append(^"../Start2")
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
		if not scene.get_node("PortalMap").computing: break
	var controller: Node = scene.get_node("PortalMap")
	var rat := TroopCatalog.find("rat_swarm")
	var wave := WaveDefinition.new()
	for count in [12,8]:
		var group := WaveSpawnGroup.new()
		group.troop = rat
		group.enemy_count = count
		group.start_tick = 0 if count == 12 else 40
		wave.groups.append(group)
	for id in ["winged_beast","scout","blood_mage","shield_guardian","saboteur"]:
		var group := WaveSpawnGroup.new()
		group.troop = TroopCatalog.find(id)
		group.enemy_count = 8
		wave.groups.append(group)
	var preview := WaveSpawnSchedule.build(wave,controller,0,false,PackedInt32Array([1]))
	var actual := WaveSpawnSchedule.build(wave,controller,700,true,PackedInt32Array([1]))
	check(not preview.is_empty() and not actual.is_empty(),"actual controller builds six mixed profiles")
	if preview.is_empty() or actual.is_empty():
		scene.queue_free()
		return
	check(actual.pending.size() == 60,"total individuals unchanged across partial cohorts")
	check(RoadFlowForecast.from_pending(preview.pending).all == RoadFlowForecast.from_pending(actual.pending).all,"preview equals shuffled committed per-edge flow")
	check(RoadFlowForecast.from_pending(preview.pending).counts_by_origin == WaveSpawnSchedule.counts_by_origin(wave,PackedInt32Array([1])),"multi-origin roster counts individuals")
	var cohorts := {}
	var rat_total := 0
	for member: Dictionary in actual.pending:
		if member.profile != rat: continue
		rat_total += 1
		if not cohorts.has(member.cohort_id): cohorts[member.cohort_id] = []
		cohorts[member.cohort_id].append(member)
	for members: Array in cohorts.values():
		for member: Dictionary in members:
			check(member.route.cells == members[0].route.cells and member.start_index == members[0].start_index,"cohort intact on one route and entrance")
		check(members.size() <= 5,"no surplus rat in tail cohort")
		for i in range(1,members.size()): check(members[i].spawn_tick-members[i-1].spawn_tick == 1,"cohort short stagger")
	check(rat_total == 20 and cohorts.size() == 5,"12+8 rats produce 5 cohorts not 20 route units")
	var flying := TroopCatalog.find("winged_beast")
	var baseline: Dictionary = controller.plan_for(flying)
	var effect := {"tags":[&"flying"],"excluded_tags":[],"cells":{Vector2i(1,0):true},"multiplier":0.001}
	check(controller.plan_for(flying,0,[effect]).route_probabilities == baseline.route_probabilities,"flying ignores all ground traffic effects")
	for member: Dictionary in actual.pending:
		if member.profile == flying: check(member.points[0].y > scene.get_node("TileMap").global_position.y+1.0,"flight altitude frozen in actual waypoints")
	scene.queue_free()
	await get_tree().process_frame
