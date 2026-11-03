extends Node
const Fixture = preload("res://tests/construction/fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Surface = preload("res://scripts/map/tile/appearance/road_surface.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _ready() -> void: run.call_deferred()
func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

static func card(body: Array[Vector2i], roads: Array[Vector2i], key := "sentry", explicit := false) -> BuildCard:
	var preset := TilePreset.new(); preset.preset_id = "refinement_fixture"
	preset.tower_footprint = body; preset.road_offsets = roads
	if explicit:
		preset.manual_ports = true
		for cell in roads: preset.explicit_road_ports[cell] = 15
	return BuildCard.from_parts(load("res://assets/data/towers/"+key+".tres"),preset)

func run() -> void:
	structural_oracle()
	var dynamic := Fixture.session(0); add_child(dynamic); await frames()
	var visual: Node = dynamic.get_node("TileVisuals")
	var dynamic_portal: Node = dynamic.get_node("PortalMap")
	var dynamic_revision: int = dynamic_portal.revision
	var placement: Node = dynamic.get_node("TilePlacement")
	var branch: Array[Vector3i] = [Vector3i(8,0,1),Vector3i(8,0,2),Vector3i(9,0,2)]
	placement.add_cells(branch)
	await frames()
	check(dynamic_portal.revision == dynamic_revision and not visual.surface.active.has(Vector2i(8,1)),"Skipped dead-end navigation rebuild still refreshes gray display")
	branch = [Vector3i(9,0,1)]
	placement.add_cells(branch)
	await frames()
	check(visual.surface.active.has(Vector2i(8,1)) and visual.surface.active.has(Vector2i(9,2)),"Second attachment restores every legal detour tile to beige")
	dynamic.free(); await frames(1)
	for size in [1,4]:
		for explicit in [false,true]:
			var session := Fixture.session(0); add_child(session); await frames()
			var towers: Node = session.get_node("TowerMap")
			var map: GridMap = session.get_node("TileMap")
			var portal: Node = session.get_node("PortalMap")
			var body: Array[Vector2i] = [Vector2i.ZERO]
			if size == 4: body.append_array([Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE])
			var old: DefenseTower = towers.place_card(card(body,[],"mortar"),Vector3i(5,0,2))
			check(old != null,"Existing single/multicell obstacle placed")
			await frames()
			var incoming := card([Vector2i.ZERO],[Vector2i(-1,0),Vector2i(-2,0),Vector2i(-3,0),Vector2i(-2,1),Vector2i(-3,1)],"sentry",explicit)
			var anchor := Vector3i(8,0,2)
			var entries := [{"card":incoming,"anchor":anchor,"turns":0}]
			var plan: Dictionary = towers.construction_plan(entries)
			check(plan.ok,"Road overlap is clipped before legality: "+plan.error)
			var old_items := {}; var old_ports := {}
			for cell in old.occupied_cells:
				old_items[cell] = map.get_cell_item(Vector3i(cell.x,0,cell.y))
				old_ports[cell] = session.get_node("TilePlacement").port_overrides.get(cell,-1)
				check(not plan.ground.has(cell) and not plan.ports.has(cell),"Clipped cells carry no new ground or port requests")
			var preview: Node = session.get_node("CardPlacement/Preview")
			preview.show_at(map,incoming,anchor,0,true)
			check(preview.displayed_ground == towers.card_ground(incoming,Vector2i(8,2),0),"Preview uses exact clipping authority")
			for cell in old.occupied_cells: check(not cell in preview.displayed_ground,"Preview omits hidden road")
			var before_count: int = towers.towers.size()
			var built: DefenseTower = towers.place_card(incoming,anchor)
			check(built != null and towers.towers.size() == before_count+1,"One successful card creates exactly one tower")
			await frames()
			check(old.health == old.max_health and towers.occupied[Vector2i(5,2)] == old,"Original tower unchanged")
			for cell in old.occupied_cells:
				check(map.get_cell_item(Vector3i(cell.x,0,cell.y)) == old_items[cell],"Clipped road does not rewrite old foundation")
				check(session.get_node("TilePlacement").port_overrides.get(cell,-1) == old_ports[cell],"Clipped road leaves no stored requested ports")
			check(Snapshot.connects_terminals(Snapshot.capture(map,towers.occupied),portal.terminal_cells()),"Committed network remains connected")
			var schedule := WaveSpawnSchedule.build(session.get_node("EnemyWave").definition,portal,71,false)
			check(not schedule.is_empty() and schedule.pending.size() == session.get_node("EnemyWave").definition.total_count(),"Soldier, Scout and Winged Beast schedule remains legal")
			var surf: RefCounted = session.get_node("TileVisuals").surface
			check(not surf.connects(Vector2i(7,2),3) if size == 4 else true,"No visual exit points into a tower")
			var revision: int = portal.revision
			var snapshot := Snapshot.capture(map)
			check(towers.place_card(incoming,anchor) == built and built.level == 2,"Upgrade reuses same tower")
			check(portal.revision == revision and Snapshot.capture(map) == snapshot,"Upgrade never rebuilds roads")
			var collision := card([Vector2i.ZERO,Vector2i.LEFT],[],"sentry")
			check(not towers.validate_card(collision,Vector3i(9,0,2)).is_empty(),"New body overlap rejected beyond anchor")
			var blocked := card([Vector2i.ZERO],[Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2)],"sentry",explicit)
			# Place another obstacle on the only proposed bypass. Without clipping
			# it would appear to reconnect the cut main line through this body.
			var obstacle: DefenseTower = towers.place_card(card([Vector2i.ZERO],[],"mortar"),Vector3i(11,0,1))
			check(obstacle != null,"Bypass obstacle placed")
			await frames()
			var cards: Node = session.get_node("CardPlacement")
			cards.add_card(blocked); cards.select_card(cards.cards.size()-1)
			var hand_size: int = cards.cards.size()
			var gold: int = cards.get_node("Shop").coins
			var before := Snapshot.capture(map); revision = portal.revision
			check(not cards.place_selected(Vector3i(11,0,0)),"Clipped only bypass rejects card through real hand path")
			check(cards.cards.size() == hand_size and cards.get_node("Shop").coins == gold,"Failure retains card and Gold")
			check(before == Snapshot.capture(map) and portal.revision == revision,"Failure is atomic")
			session.free(); await frames(1)
	var report := {"checks":checks,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}
	var file := FileAccess.open(Artifacts.path("road_refinement/rules.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t"))
	print("ROAD_REFINEMENT_RULES: ",JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)

func structural_oracle() -> void:
	var guard: RefCounted = ClassDB.instantiate("RoadEditGuard")
	# Enumerate all 3x3 occupancy maps and independently enumerate simple paths.
	# Includes disconnected terminals, dangling cycles and alternate legal lanes.
	for bits in 512:
		var cells := PackedInt32Array(); var ports := PackedByteArray(); var masks := {}
		for i in 9:
			if bits & (1<<i):
				var cell := Vector2i(i%3,i/3); cells.append_array(PackedInt32Array([cell.x,cell.y])); ports.append(15); masks[cell] = 15
		var ends := PackedVector2Array([Vector2(2,2),Vector2(0,0),Vector2(2,0)])
		var result: Dictionary = guard.prepare(cells,ports,ends)
		var actual := {}
		var packed: PackedInt32Array = result.get("route_cells",PackedInt32Array())
		for i in range(0,packed.size(),2): actual[Vector2i(packed[i],packed[i+1])] = true
		var expected := {}
		# Missing terminals make this an invalid level, with no classified roads.
		if masks.has(Vector2i(2,2)) and masks.has(Vector2i.ZERO) and masks.has(Vector2i(2,0)):
			for start in [Vector2i.ZERO,Vector2i(2,0)]: oracle_paths(start,Vector2i(2,2),masks,{},expected)
		check(actual == expected,"Native full-route membership vs exhaustive oracle map "+str(bits))
	var rng := RandomNumberGenerator.new(); rng.seed = 528
	for trial in 128:
		var cells := PackedInt32Array(); var ports := PackedByteArray(); var masks := {}
		for i in 9:
			var cell := Vector2i(i%3,i/3); var mask := rng.randi_range(0,15)
			cells.append_array(PackedInt32Array([cell.x,cell.y])); ports.append(mask); masks[cell] = mask
		var result: Dictionary = guard.prepare(cells,ports,PackedVector2Array([Vector2(2,2),Vector2.ZERO,Vector2(2,0)]))
		var actual := {}; var expected := {}
		var packed: PackedInt32Array = result.get("route_cells",PackedInt32Array())
		for i in range(0,packed.size(),2): actual[Vector2i(packed[i],packed[i+1])] = true
		for start in [Vector2i.ZERO,Vector2i(2,0)]: oracle_paths(start,Vector2i(2,2),masks,{},expected)
		check(actual == expected,"Reciprocal-port oracle "+str(trial))
	# A disconnected two-row pair must not be painted as a plaza.
	var surface := Surface.new(); surface.masks = {Vector2i.ZERO:10,Vector2i(1,0):10,Vector2i(0,1):10,Vector2i(1,1):10}
	check(surface.shape(Vector2i.ZERO).y == 0,"Parallel closed interfaces do not fill shared corner")
	surface.masks = {Vector2i.ZERO:15,Vector2i(1,0):15,Vector2i(0,1):15,Vector2i(1,1):15}
	check(surface.shape(Vector2i.ZERO).y == 2,"Reciprocal square fills internal corner")

func oracle_paths(at: Vector2i, goal: Vector2i, masks: Dictionary, seen: Dictionary, union: Dictionary) -> void:
	if not masks.has(at) or seen.has(at): return
	seen[at] = true
	if at == goal: union.merge(seen)
	else:
		for d in 4:
			var direction: Vector3i = TileConstants.DIRECTIONS[d]
			var next := at+Vector2i(direction.x,direction.z)
			if int(masks[at]) & (1<<d) and int(masks.get(next,0)) & (1<<((d+2)%4)): oracle_paths(next,goal,masks,seen,union)
	seen.erase(at)
