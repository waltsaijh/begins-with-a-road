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
	var specs := {"rats":["small",&"ground",&"swarm"],"rook":["large",&"ground",&"armored",&"guardian"],"bloodmage":["standard",&"ground",&"support"],"winged":["standard",&"flying"],"scout":["small",&"ground",&"scout"],"bomber":["standard",&"ground",&"saboteur"]}
	for id: String in specs:
		var troop := TroopCatalog.find(id)
		check(troop != null and troop.configuration_error().is_empty(),"valid editable profile "+id)
		for tag: String in specs[id]: check(troop.has_tag(StringName(tag)),id+" tag "+tag)
		check(troop.model != null and troop.icon != null,"model and icon "+id)
	check(TroopCatalog.find("bloodmage").route_selection == Troop.RouteSelection.UNIFORM,"mage Uniform")
	check(TroopCatalog.find("rook").threat_weight == 0 and TroopCatalog.find("bomber").threat_weight == 0,"guardian/saboteur no safety seeking")
	var cells: Array[Vector2i] = []
	add_lane(cells,0)
	add_lane(cells,-2)
	var history := History.new()
	var terminals: Array[Vector2i] = [Vector2i(8,0),Vector2i(0,0)]
	history.record(snapshot(cells),terminals)
	var scout := TroopCatalog.find("scout")
	check(reduced_plan(history,cells,scout).size() >= 2,"all initial paths share the newest age")
	var revision: int = history.revision
	history.wave = 1
	history.record(snapshot(cells),terminals)
	check(history.revision == revision,"cache rebuild does not create birth")
	cells.append(Vector2i(4,1))
	cells.append(Vector2i(4,2))
	history.record(snapshot(cells),terminals)
	check(not history.tile_ages().has(Vector2i(4,2)),"dead-end extension does not join a route")
	cells.erase(Vector2i(4,1))
	cells.erase(Vector2i(4,2))
	history.wave = 2
	add_lane(cells,3)
	history.record(snapshot(cells),terminals)
	add_lane(cells,6)
	history.record(snapshot(cells),terminals)
	var on_three := false
	var on_six := false
	for route: Dictionary in reduced_plan(history,cells,scout):
		on_three = on_three or Vector2(4,3) in route.cells
		on_six = on_six or Vector2(4,6) in route.cells
		check(route.score == 0.0 and (Vector2(4,3) in route.cells or Vector2(4,6) in route.cells),"old route never revived")
	check(on_three and on_six,"two new same-wave routes both represented")
	var old_cells: Array[Vector2i] = []
	add_lane(old_cells,0)
	add_lane(old_cells,-2)
	history.wave = 3
	history.record(snapshot(old_cells),terminals)
	check(not reduced_plan(history,old_cells,scout).is_empty() and history.tile_ages().values().max() == 0.0,"invalid new route safely falls back to surviving tiles")
	history.wave = 4
	add_lane(old_cells,3)
	history.record(snapshot(old_cells),terminals)
	check(history.tile_ages()[Vector2i(4,0)] == 2.0 and history.tile_ages()[Vector2i(4,3)] == 0.0,"restored old tiles retain first connection")
	verify_entrances()
	verify_worst_tile()
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

## Reduced routes need only these two members of a PortalMap.
class MapStub:
	extends Node
	var route_history: RefCounted
	var tile_parameters: RefCounted

func reduced_plan(history: RefCounted, cells: Array[Vector2i], profile: Troop, origin := 0, prepare := Callable()) -> Array:
	var stub := MapStub.new()
	stub.route_history = history
	stub.tile_parameters = preload("res://scripts/map/tile/tile_parameter_store.gd").new()
	var packed := PackedVector2Array()
	for cell in cells: packed.append(Vector2(cell))
	stub.tile_parameters.sync(packed)
	stub.tile_parameters.set_road_ages(history.tile_ages())
	if prepare.is_valid(): prepare.call(stub.tile_parameters)
	var search = preload("res://scripts/navigation/routes/reduced_routes.gd").new()
	search.map = stub
	var plan: Dictionary = search.plan_for(profile,origin,[])
	var routes: Array = []
	if plan.get("valid",false): for i in plan.routes: routes.append(search.route_for(profile,origin,[],0,1,-1,i))
	stub.free()
	return routes

func verify_worst_tile() -> void:
	# The short lane holds one dangerous tile; max must take the longer calm lane.
	var cells: Array[Vector2i] = []
	add_lane(cells,0)
	add_lane(cells,2)
	var history := History.new()
	history.record(snapshot(cells),[Vector2i(8,0),Vector2i(0,0)])
	var careful := Troop.new()
	careful.tile_cost_reduce = Troop.TileCostReduce.MAX
	careful.path_base_cost = 0.0
	careful.threat_weight = 1.0
	var routes := reduced_plan(history,cells,careful,0,func(store): store.get_tile(Vector2i(4,0)).threat = 5.0)
	check(not routes.is_empty(),"max keeps a route")
	for route: Dictionary in routes:
		check(route.score == 0.0 and not Vector2(4,0) in route.cells,"max avoids the single worst tile")

func verify_entrances() -> void:
	# A tile only another entrance can use must not hide this entrance's route.
	var cells: Array[Vector2i] = []
	for x in 5: cells.append(Vector2i(x,0))
	var history := History.new()
	history.record(snapshot(cells),[Vector2i(4,0),Vector2i(0,0)])
	history.wave = 2
	cells.append(Vector2i(4,1))
	cells.append(Vector2i(4,2))
	history.record(snapshot(cells),[Vector2i(4,0),Vector2i(0,0),Vector2i(4,2)])
	var scout := TroopCatalog.find("scout")
	check(not reduced_plan(history,cells,scout,0).is_empty(),"entrance falls back to its own newest tiles")
	var fresh := reduced_plan(history,cells,scout,1)
	check(not fresh.is_empty() and fresh[0].score == 0.0,"new entrance sees its own new road")

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
		var through := false
		var around := false
		for path: Array in all:
			through = through or Vector2i(1,1) in path
			around = around or not Vector2i(1,1) in path
		var routes := reduced_plan(history,cells,TroopCatalog.find("scout"))
		check(routes.is_empty() == all.is_empty(),"oracle reachability mask %d" % mask)
		if through and around:
			for route: Dictionary in routes: check(Vector2(1,1) in route.cells,"oracle newest mask %d" % mask)

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
	var rat := TroopCatalog.find("rats")
	var wave := WaveDefinition.new()
	for count in [12,8]:
		var group := WaveSpawnGroup.new()
		group.troop = rat
		group.enemy_count = count
		group.start_tick = 0 if count == 12 else 40
		wave.groups.append(group)
	for id in ["winged","scout","bloodmage","rook","bomber"]:
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
	var flying := TroopCatalog.find("winged")
	var baseline: Dictionary = controller.plan_for(flying)
	var shortest_length: int = Fixture.road_distance(controller.route_history.current,Vector2i.ZERO,Vector2i(8,0))
	var flight: Dictionary = controller.prepare_route_batch(flying,8)
	check(baseline.valid and baseline.reachable and flight.routes.size() == 8,"winged keeps a route through the cost pipeline")
	var flight_paths := {}
	for route: Dictionary in flight.routes:
		check(route.cells.size()-1 == shortest_length,"winged only flies the true shortest distance")
		flight_paths[str(route.cells)] = true
	var effect := {"tags":[&"flying"],"excluded_tags":[],"cells":{Vector2i(1,0):true},"multiplier":0.001}
	check(controller.plan_for(flying,0,[effect]).route_probabilities == baseline.route_probabilities,"flying ignores all ground traffic effects")
	for member: Dictionary in actual.pending:
		if member.profile == flying: check(member.points[0].y > scene.get_node("TileMap").global_position.y+1.0,"flight altitude frozen in actual waypoints")
		if member.profile == flying:
			var junctions := preload("res://scripts/enemies/spawning/route_waypoints.gd").junctions(controller.route_history.current)
			var inner := 0
			for cell: Vector2 in member.route.cells.slice(1,-1): if junctions.has(Vector2i(cell)): inner += 1
			check(member.points.size() == 2+inner and member.points.size() < member.route.cells.size(),"flyers keep only junctions between their ends")
	scene.queue_free()
	await get_tree().process_frame
