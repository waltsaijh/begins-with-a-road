extends Node
const Fixture = preload("res://tests/fixtures/level_fixture.gd")
const PortalFixture = preload("res://tests/fixtures/portal_fixture.gd")
const Planner = preload("res://scripts/levels/expansion/spawn_expansion_planner.gd")
const Search = preload("res://scripts/map/tile/road_construction_search.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Layout = preload("res://scripts/map/tile/construction_layout.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []
var checks := 0
var scene: Node3D

func _ready() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame
func wait_map(host: Node) -> void:
	for i in 180:
		await frames(1)
		if not host.get_node("PortalMap").computing and not host.expansion.active: return
	check(false,"Placement commit or graph did not settle")

func place_entrance() -> void:
	var expansion: Node = scene.expansion
	var controller: Node = scene.get_node("PortalMap")
	var previous: String = expansion.last_region
	var count: int = controller.start_paths.size()
	await frames(5)
	check(expansion.active and not expansion.committing and controller.start_paths.size() == count,"Entrance waits for player placement without auto-committing")
	check(scene.choosing_start and not scene.get_node("EnemyWave").start_allowed and scene.get_node("CardPlacement").input_suspended,"Placement keeps building and wave start locked")
	check(expansion.get_node_or_null("Interface/Root/Panel/Margin/Content/Directions") == null,"No direction selection buttons")
	if not previous.is_empty():
		check(expansion.choices.all(func(region): return region.direction != previous),"All candidates in the previous region are excluded")
		for region in Planner.generate(controller,8,3):
			if region.direction != previous: continue
			var forbidden: Vector2i = region.paths.keys()[0]
			check(not expansion.commit(Vector3i(forbidden.x,0,forbidden.y)),"Excluded region cannot be committed directly")
			break
	var region: Dictionary = expansion.choices[0]
	for possible in expansion.choices:
		if possible.direction == ("south" if previous.is_empty() else "north"): region = possible
	var at: Vector2i = region.paths.keys()[0]
	for possible: Vector2i in region.proposals:
		if region.proposals[possible].independent:
			at = possible
			break
	var cell := Vector3i(at.x,0,at.y)
	check(not expansion.commit(Vector3i.ZERO) and expansion.last_region == previous,"Invalid placement neither commits nor changes region history")
	var hud: Node = scene.get_node("LevelHUD")
	hud.set_paused(true)
	await frames()
	check(not expansion.commit(cell) and not expansion.get_node("World").visible,"Pause hides candidates and rejects placement")
	hud.set_paused(false)
	await get_tree().create_timer(0.4).timeout
	var camera: Camera3D = scene.get_node("Camera3D")
	var world: Vector3 = controller.map.to_global(controller.map.map_to_local(cell))
	camera.focus = world
	camera.update_pose()
	var point := camera.unproject_position(world)
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	get_viewport().push_input(press,true)
	var drag := InputEventMouseMotion.new()
	drag.position = point+Vector2(40,0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(drag,true)
	var release := press.duplicate() as InputEventMouseButton
	release.position = drag.position
	release.pressed = false
	get_viewport().push_input(release,true)
	await frames(3)
	check(controller.start_paths.size() == count and expansion.last_region == previous,"Dragging the camera over candidates does not place an entrance")
	camera.focus = world
	camera.update_pose()
	point = camera.unproject_position(world)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	await frames(3)
	check(expansion.hovered_cell == cell and expansion.get_node("World/EntrancePreview").visible,"Direct hover previews the chosen entrance without choosing a direction")
	check(expansion.get_node("World/PathPreview").multimesh.instance_count == region.paths[at].size(),"Hover previews the real independent road")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("levels/entrance_place_"+region.direction+".png"))
	# A subsequent ordinary click must still place the exact hovered tile.
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		get_viewport().push_input(click,true)
	await frames(2)
	check(controller.start_paths.size() == count+1 and expansion.last_region == region.direction,"Real world click commits the exact player-chosen location and region")
	check(not expansion.commit(cell),"Repeated click cannot create another entrance")
	await wait_map(scene)
func recipe() -> WaveDefinition:
	var group := WaveSpawnGroup.new()
	group.troop = TroopCatalog.find("soldier")
	group.enemy_count = 8
	group.batch_size = 2
	group.interval_ticks = 3
	var wave := WaveDefinition.new()
	wave.groups = [group]
	return wave
func level() -> LevelDefinition:
	var result := Fixture.level("")
	var map := result.terrain.instantiate() as GridMap
	for x in range(8,17): map.set_cell_item(Vector3i(x,0,0),3)
	map.get_node("Goal").position = map.map_to_local(Vector3i(16,0,0))+Vector3.UP*0.125
	map.get_node("Start").position.y = 0.125
	map.get_node("Start").height_offset = 0.125
	result.terrain = PackedScene.new()
	result.terrain.pack(map)
	map.free()
	result.acts.clear()
	for index in 4:
		var act := ActDefinition.new()
		act.add_start_after_completion = index != 1
		act.waves = [recipe()]
		if index == 0: act.waves.append(recipe())
		result.acts.append(act)
	return result
func finish_wave() -> void:
	scene._begin_wave_start()
	scene.set_process(false)
	scene._advance_wave_start(1.5)
	var wave: Node = scene.get_node("EnemyWave")
	check(wave.active,"Real wave starts")
	wave.set_process(false)
	wave._process(1000)
	var origins := {}
	for enemy in wave.living_enemies(): origins[Vector2i(enemy.route.cells[0])] = true
	check(origins.size() == scene.get_node("PortalMap").start_nodes.size(),"Actual enemies spawn at every active entrance")
	for enemy in wave.living_enemies(): enemy.take_damage(1000000)
	if scene.choosing_relic:
		check(not scene.choosing_start,"Relic precedes player entrance placement")
		scene.relic_choice.choose(scene.relic_choice.offers[0])
		await get_tree().create_timer(0.3).timeout
	if scene.choosing_start: await place_entrance()
	await wait_map(scene)
func verify() -> void:
	scene = load("res://scenes/level.tscn").instantiate()
	scene.level = level()
	add_child(scene)
	await wait_map(scene)
	var controller: Node = scene.get_node("PortalMap")
	var map: GridMap = controller.map
	var expansion: Node = scene.expansion
	var wave: Node = scene.get_node("EnemyWave")
	wave.enemy_spawned.connect(func(enemy): enemy.set_process(false))
	scene.get_node("TowerMap").combat.enabled = false
	check(expansion.get_node_or_null("World/Candidates") != null,"World candidate placement is available")
	var foundation: Array[Vector3i] = [Vector3i(6,0,2)]
	scene.get_node("TilePlacement").add_cells(foundation)
	var tower: DefenseTower = scene.get_node("TowerMap").place_tower(Vector3i(6,0,2))
	check(tower != null,"Obstacle fixture tower")
	await wait_map(scene)
	var choices: Array[Dictionary] = Planner.generate(controller,8,3)
	# The 3x3 castle around the goal closes the cells behind it, so the region directly
	# behind the base (east here) has no legal road; the other three remain.
	check(choices.size() == 3 and not choices.any(func(region): return region.direction == "east"),"All legal cardinal sectors are considered")
	var context := Search.capture(controller)
	check(load("res://assets/data/levels/frontier.tres").expansion_blocked_goal_sides == 2,"Second level stores its east-of-base restriction")
	check(scene.level.expansion_blocked_goal_sides == 0,"Other level fixtures retain all four regions")
	var restricted := Planner.generate(controller,8,3,2)
	check(not restricted.is_empty() and restricted.all(func(region): return region.direction != "east" and region.paths.keys().all(func(at): return at.x <= context.goal.x)),"Base-east restriction removes the full half-plane, including north/south corners")
	var east_choices := Planner.generate(controller,16,3).filter(func(region): return region.direction == "east")
	if not east_choices.is_empty():
		var eastern_cell: Vector2i = east_choices[0].paths.keys()[0]
		check(not Planner.valid(controller,eastern_cell,east_choices[0].paths[eastern_cell],2),"Final validation also rejects an eastern endpoint")
	for region in choices:
		for at: Vector2i in region.paths:
			check(Search.distance(at,context.goal) >= 8 and Search.distance(at,context.terminals[1]) >= 6,"Candidate preserves goal/start spacing")
			check(not Vector2i(6,2) in region.paths[at],"Candidate road avoids tower footprint")
		var at: Vector2i = region.paths.keys()[0]
		check(Planner.valid(controller,at,region.paths[at]),"Candidate path passes real reciprocal-port validation")
	var synthetic: Array[Dictionary] = []
	for key in ["north","west"]:
		synthetic.append({"direction":key,"proposals":{Vector2i.ZERO:{"independent":true,"fresh":4,"separated":3,"path":[Vector2i.ZERO,Vector2i.ONE]}}})
	var west := Planner.allowed(synthetic,"north")
	var north := Planner.allowed(synthetic,west[0].direction)
	check(west.size() == 1 and west[0].direction == "west" and north.size() == 1 and north[0].direction == "north","Only previous region is excluded; older regions become available")
	check(Planner.allowed([synthetic[0]],"north")[0].direction == "north","No alternative sector permits same-region fallback")
	check(Planner.allowed(synthetic,"").size() == 2,"All legal regions are simultaneously available on the first placement")
	var completed := [0]
	expansion.completed.connect(func(_index): completed[0] += 1)
	await finish_wave()
	check(completed[0] == 0 and not scene.choosing_start,"Non-boundary wave does not expand")
	var original := {}
	for cell in map.get_used_cells(): original[cell] = true
	await finish_wave()
	check(completed[0] == 1 and controller.start_nodes.size() == 2 and not scene.choosing_start,"Checked ACT creates exactly one player-placed entrance")
	var first_region: String = expansion.last_region
	check(first_region == "south","Player can freely choose the south region on the first placement")
	var selected: Dictionary = expansion.selected
	check(selected.proposal.independent and selected.proposal.separated >= 2,"New road is independent until the base merge zone")
	check(selected.proposal.path.size()-1 <= ceili(Search.distance(selected.cell,context.goal)*1.75)+6,"Independent route has a reasonable length bound")
	for cell in original: check(map.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM,"Original map cells remain intact")
	check(controller.blocked_cells.has(tower.grid_cell),"Expansion preserves tower occupancy")
	var marker: Node3D = controller.get_node(controller.start_paths[-1])
	var cell: Vector3i = map.local_to_map(map.to_local(marker.global_position))
	check(is_equal_approx(map.to_local(marker.global_position).y-map.map_to_local(Vector3i(cell.x,0,cell.z)).y,0.125),"New marker preserves terrain endpoint height")
	check(not scene.get_node("CardPlacement").input_suspended and wave.start_allowed,"Committed entrance restores preparation")
	var schedule := WaveSpawnSchedule.build(wave.definition,controller,0,false,wave.additional_start_indices)
	var hist := [0,0]
	for entry: Dictionary in schedule.pending:
		hist[entry.start_index] += 1
		check(entry.spawn_tick == floori(float(entry.slot)/2)*3,"Quarter-second batch timing preserved")
	check(hist == [4,4],"Existing scheduler splits normal count across two entrances")
	var forecast: Array[Dictionary] = wave.routes_for_display()
	check(forecast.size() == 8,"Native route preview includes expanded entrances")
	var starts_before: int = controller.start_paths.size()
	await finish_wave()
	check(controller.start_paths.size() == starts_before,"Unchecked ACT retains its expansion setting")
	await finish_wave()
	check(completed[0] == 2 and controller.start_nodes.size() == 3 and expansion.last_region != first_region,"Next expansion excludes the previous sector")
	await finish_wave()
	check(scene.finished and scene.victory and completed[0] == 2,"Final wave wins without another entrance")
	check(scene.level.endpoint_layout().starts.size() == 1,"Runtime never edits authored terrain")
	scene.queue_free()
	await frames(2)
	await verify_early_merge()
	await verify_generated_road_join()
	await verify_generated_parallel()
	print("ACT_SPAWN_EXPANSION_CHECK:"+JSON.stringify({"checks":checks,"failures":failures,"player_placement":true,"previous_region_only":true,"native_spawns":true}))
	# Like enemy_status, Web reports JSON and lets the browser runner close it.
	if not OS.has_feature("web"): get_tree().quit(0 if failures.is_empty() else 1)

func verify_generated_road_join() -> void:
	var cells: Array[Vector2i] = []
	for x in 17: cells.append(Vector2i(x,0))
	var host := PortalFixture.scene_for(cells,Vector2i.ZERO,Vector2i(16,0))
	host.get_node("EnemyWave").auto_start = false
	add_child(host)
	var controller: Node = host.get_node("PortalMap")
	for i in 120:
		await frames(1)
		if not controller.computing: break
	var route: Array[Vector2i] = []
	for x in range(8,17): route.append(Vector2i(x,-4))
	for y in range(-3,1): route.append(Vector2i(16,y))
	var proposed := Search.proposal(Search.capture(controller),route)
	check(Search.commit(controller,proposed).ok,"Fixture generates an independent entrance road")
	for i in 120:
		await frames(1)
		if not controller.computing: break
	var road := BuildCard.new()
	road.special = load("res://assets/data/events/cards/road.tres")
	var towers: Node = host.get_node("TowerMap")
	var plan: Dictionary = towers._special_plan(road,Vector3i(8,0,-3),0)
	check(plan.ok,"Road card previews a legal connection to the generated road")
	if plan.ok:
		var ground := {}
		var ports := {}
		for at in road.ground_cells(Vector2i(8,-3)):
			ground[at] = true
			ports[at] = 15
		var old_layout := Layout.build(controller.map,ground,ports,host.get_node("TilePlacement").port_overrides,controller.blocked_cells)
		print("ROAD_JOIN_REPRO:"+JSON.stringify({"closed_distance":PortalFixture.road_distance(old_layout.snapshot,Vector2i(8,-4),Vector2i(8,0)),"fixed_distance":PortalFixture.road_distance(plan.layout.snapshot,Vector2i(8,-4),Vector2i(8,0))}))
		check(PortalFixture.road_distance(plan.layout.snapshot,Vector2i(8,-4),Vector2i(8,0)) == 4,"Road preview actually joins generated and original roads")
	check(towers.place_card(road,Vector3i(8,0,-3)) != null,"Road card commits the connecting tiles")
	check(PortalFixture.road_distance(Snapshot.capture(controller.map),Vector2i(8,-4),Vector2i(8,0)) == 4,"Placed bridge has reciprocal ports into both roads")
	var preset := TilePreset.new()
	preset.tower_offset = Vector2i(-1,2)
	preset.road_offsets = [Vector2i.ZERO,Vector2i.DOWN,Vector2i(0,2),Vector2i(0,3)]
	var tower_card := BuildCard.from_parts(load("res://assets/data/towers/sentry.tres"),preset)
	var tower_plan: Dictionary = towers.construction_plan([{"card":tower_card,"anchor":Vector3i(10,0,-3),"turns":0}])
	check(tower_plan.ok and PortalFixture.road_distance(tower_plan.snapshot,Vector2i(10,-4),Vector2i(10,0)) == 4,"Normal tower-card preview joins both roads")
	check(towers.place_card(tower_card,Vector3i(10,0,-3)) != null,"Normal tower card can construct the connection")
	check(PortalFixture.road_distance(Snapshot.capture(controller.map),Vector2i(10,-4),Vector2i(10,0)) == 4,"Tower-card preview and committed connection agree")
	var bridge_cells: Array[Vector3i] = [Vector3i(12,0,-3),Vector3i(12,0,-2),Vector3i(12,0,-1)]
	host.get_node("TilePlacement").add_cells(bridge_cells)
	check(PortalFixture.road_distance(Snapshot.capture(controller.map),Vector2i(12,-4),Vector2i(12,0)) == 4,"Existing plain ground construction also joins generated roads")
	var closed_preset: TilePreset = preset.duplicate(true)
	closed_preset.preset_id = "closed_join_test"
	closed_preset.manual_ports = true
	for offset in closed_preset.road_offsets: closed_preset.explicit_road_ports[offset] = 5
	closed_preset.explicit_road_ports[Vector2i.ZERO] = 4
	var closed := BuildCard.from_parts(load("res://assets/data/towers/sentry.tres"),closed_preset)
	var closed_plan: Dictionary = towers.construction_plan([{"card":closed,"anchor":Vector3i(14,0,-3),"turns":0}])
	check(closed_plan.ok and PortalFixture.road_distance(closed_plan.snapshot,Vector2i(14,-4),Vector2i(14,0)) > 4,"Authored card with a closed outward port remains closed: "+str(closed_plan.get("error","")))
	host.queue_free()
	await frames(2)

func verify_generated_parallel() -> void:
	var cells: Array[Vector2i] = []
	for x in 17: cells.append(Vector2i(x,0))
	var host := PortalFixture.scene_for(cells,Vector2i.ZERO,Vector2i(16,0))
	host.get_node("EnemyWave").auto_start = false
	add_child(host)
	var controller: Node = host.get_node("PortalMap")
	for i in 120:
		await frames(1)
		if not controller.computing: break
	var path: Array[Vector2i] = []
	for x in range(8,17): path.append(Vector2i(x,-1))
	path.append(Vector2i(16,0))
	check(Search.commit(controller,Search.proposal(Search.capture(controller),path)).ok,"Parallel edge fixture commits with an explicit merge at the base")
	var before := Snapshot.capture(controller.map)
	check(PortalFixture.road_distance(before,Vector2i(8,-1),Vector2i(8,0)) > 1,"Generated adjacent roads do not auto-merge before player construction")
	var road := BuildCard.new()
	road.special = load("res://assets/data/events/cards/road.tres")
	var towers: Node = host.get_node("TowerMap")
	var plan: Dictionary = towers._special_plan(road,Vector3i(8,0,0),0)
	check(plan.ok and PortalFixture.road_distance(plan.layout.snapshot,Vector2i(8,-1),Vector2i(8,0)) == 1,"Explicit player touch opens a junction even when roads already exist")
	check(PortalFixture.road_distance(Snapshot.capture(controller.map),Vector2i(8,-1),Vector2i(8,0)) > 1,"Hover preview does not alter the real port contract")
	check(towers.place_card(road,Vector3i(8,0,0)) != null,"Player connection commits")
	var after := Snapshot.capture(controller.map)
	check(PortalFixture.road_distance(after,Vector2i(8,-1),Vector2i(8,0)) == 1,"Committed player junction opens reciprocally")
	check(PortalFixture.road_distance(after,Vector2i(9,-1),Vector2i(9,0)) > 1,"Untouched parallel neighbor remains separate")
	host.queue_free()
	await frames(2)
func verify_early_merge() -> void:
	var cells: Array[Vector2i] = []
	for x in 17: cells.append(Vector2i(x,0))
	var host := PortalFixture.scene_for(cells,Vector2i.ZERO,Vector2i(16,0))
	host.get_node("EnemyWave").auto_start = false
	add_child(host)
	var controller: Node = host.get_node("PortalMap")
	for i in 120:
		await frames(1)
		if not controller.computing: break
	var map: GridMap = controller.map
	for y in range(-3,4):
		for x in range(13,20):
			if (x in [13,19] or y in [-3,3]) and Vector2i(x,y) != Vector2i(13,0): map.set_cell_item(Vector3i(x,0,y),0)
	controller.rebuild()
	for i in 120:
		await frames(1)
		if not controller.computing: break
	var choices := Planner.generate(controller,8,3)
	check(not choices.is_empty(),"Early merge fallback finds a legal entrance outside a blocked base perimeter")
	var region: Dictionary = Planner.allowed(choices,"")[0]
	var cell: Vector2i = region.proposals.keys()[0]
	var chosen := {"cell":cell,"proposal":region.proposals[cell]}
	check(not chosen.is_empty() and not chosen.proposal.independent,"Fallback is used only when independent paths are impossible")
	check(Planner.valid(controller,chosen.cell,chosen.proposal.path),"Early merge still reaches the base without crossing stone")
	host.queue_free()
	await frames(2)
