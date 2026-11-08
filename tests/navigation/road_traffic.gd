extends SceneTree
## Followers plan after everyone else and take the road most of them use.
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	verify.call_deferred()

func group(profile: Troop, count: int) -> WaveSpawnGroup:
	var result := WaveSpawnGroup.new()
	result.troop = profile
	result.enemy_count = count
	return result

func verify() -> void:
	# A ring: two equal roads from the corner (0,0) to (4,4).
	var cells: Array[Vector2i] = []
	for x in 5:
		for y in 5:
			if x == 0 or y == 0 or x == 4 or y == 4: cells.append(Vector2i(x,y))
	var scene: Node = Fixture.scene_for(cells,Vector2i(0,0),Vector2i(4,4))
	scene.get_node("EnemyWave").auto_start = false
	root.add_child(scene)
	var map: Node = scene.get_node("PortalMap")
	for i in 120:
		await process_frame
		if not map.computing: break
	# The crowd avoids a threatened top road, so it mostly takes the left one.
	map.tile_parameters.get_tile(Vector2i(2,0)).threat = 5.0
	await process_frame
	var crowd := Troop.new()
	crowd.troop_name = "crowd"
	crowd.route_selection = Troop.RouteSelection.SOFTMAX
	crowd.route_temperature = 0.5
	crowd.threat_weight = 1.0
	var follower := Troop.new()
	follower.troop_name = "follower"
	follower.route_selection = Troop.RouteSelection.UNIFORM
	follower.tile_cost_reduce = Troop.TileCostReduce.MAX
	follower.path_base_cost = 0.0
	follower.road_traffic_weight = -1.0
	var wave := WaveDefinition.new()
	wave.groups.append(group(follower,8))
	wave.groups.append(group(crowd,16))
	var schedule: Dictionary = WaveSpawnSchedule.build(wave,map,0,false)
	check(not schedule.is_empty(),"schedule with followers is available")
	var crowd_left := 0
	var follower_left := 0
	var followers := 0
	for member: Dictionary in schedule.get("pending",[]):
		var left: bool = Vector2(0,2) in member.route.cells
		if member.profile == crowd and left: crowd_left += 1
		if member.profile == follower:
			followers += 1
			if left: follower_left += 1
	check(crowd_left > 8,"fixture crowd prefers the left road (%d of 16)" % crowd_left)
	check(followers == 8 and follower_left == 8,"every follower takes the crowded road (%d of %d)" % [follower_left,followers])
	var shares: float = map.tile_parameters.get_tile(Vector2i(0,2)).road_traffic
	check(is_equal_approx(shares,crowd_left/16.0),"shares count the first pass only")
	# The same wave again reuses the same shares and the same routes.
	var again: Dictionary = WaveSpawnSchedule.build(wave,map,0,false)
	check(again.pending.size() == schedule.pending.size(),"repeated schedule is stable")
	print("ROAD_TRAFFIC_CHECK:", JSON.stringify({"failures":failures,"crowd_left":crowd_left,"follower_left":follower_left}))
	scene.free()
	quit(1 if not failures.is_empty() else 0)
