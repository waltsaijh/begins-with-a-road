extends Node
const Fixture = preload("res://tests/tower_tile_editor/fixture.gd")
const LevelFixture = preload("res://tests/construction/fixture.gd")
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var checks := 0
var failures: Array[String] = []
func _ready() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func frames(n := 4) -> void:
	for i in n: await get_tree().process_frame
func cells(snapshot: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in snapshot.ports.size(): result.append(Vector2i(snapshot.cells[2*i],snapshot.cells[2*i+1]))
	return result
func run() -> void:
	var shapes: Array[Array] = [[Vector2i.ZERO],[Vector2i.ZERO,Vector2i.RIGHT,Vector2i(2,0)],[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1)],[Vector2i.ZERO,Vector2i.DOWN,Vector2i(1,1)],[Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN],[Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]]
	for shape in shapes:
		var preset := Fixture.compact(); preset.road_offsets.clear(); preset.tower_footprint.assign(shape)
		var card := BuildCard.from_parts(Catalog.tower("sentry"),preset)
		check(card.configuration_error().is_empty(),"Connected arbitrary footprint accepted")
		for turn in 4:
			var actual := card.tower_cells(Vector2i(5,6),turn)
			check(actual.size() == shape.size(),"Rotation preserves all cells")
			for cell: Vector2i in shape: check(Vector2i(5,6)+BuildCard.rotate_cell(cell,turn) in actual,"Rotation around placement origin")
	var invalid := Fixture.compact(); invalid.tower_footprint.append(Vector2i(4,4))
	check(not invalid.configuration_error().is_empty(),"Disconnected footprint rejected")
	invalid = Fixture.compact(); invalid.tower_offset = Vector2i(4,4)
	check(not invalid.configuration_error().is_empty(),"Anchor outside body rejected")
	invalid = Fixture.compact(); invalid.road_offsets.append(Vector2i.ZERO)
	check(not invalid.configuration_error().is_empty(),"Body-road overlap rejected")
	invalid = Fixture.compact(); invalid.allowed_rotations = [1,3]
	check(not invalid.configuration_error().is_empty(),"Disallowed default rotation rejected")
	var preset := Fixture.long_hull()
	preset.manual_ports = true
	for pos in preset.road_offsets: preset.explicit_road_ports[pos] = 15
	var directory := Artifacts.path("tower_tile_editor/catalog_"+str(Time.get_ticks_usec()))
	var catalog := Catalog.new(directory)
	check(catalog.save("broadside",preset,3.5,true),"Save native preset and registry: "+catalog.error)
	var reloaded := Catalog.new(directory)
	var rows: Array[Dictionary] = reloaded.rows("broadside")
	var row: Dictionary = rows.back()
	check(row.id == preset.preset_id and row.weight == 3.5 and row.default and row.preset.tower_footprint == preset.tower_footprint and row.preset.road_offsets == preset.road_offsets,"Reload preserves ID, owner, geometry, weight and default")
	check(row.preset.explicit_road_ports == preset.explicit_road_ports and row.preset.facing_steps == preset.facing_steps,"Reload preserves orientation and all outward interface bits")
	var held := BuildCard.from_parts(Catalog.tower("broadside"),row.preset)
	preset.display_name = "重新命名"; preset.tower_footprint.append(Vector2i(0,1))
	check(catalog.save("broadside",preset,2,false),"Overwrite existing preset atomically")
	check(held.tile_preset.tower_footprint.size() == 3,"Existing hand cards retain saved geometry")
	check(Catalog.new(directory).rows("broadside").back().preset.display_name == "重新命名","Rename persists")
	var clone: TilePreset = preset.duplicate(true); clone.preset_id = Catalog.fresh_id()
	check(catalog.save("broadside",clone,0,true),"Independent duplicate can be disabled by zero weight")
	check(not catalog.save("mortar",preset,1,false),"Cannot silently reassign an existing ID to another tower")
	var shop_session := LevelFixture.session(0); add_child(shop_session); await frames()
	var actual_shop: Node = shop_session.get_node("CardPlacement/Shop")
	catalog.apply(actual_shop)
	var rolled: Array[BuildCard] = actual_shop.roll_cards(300)
	check(rolled.any(func(card): return card.tile_preset.preset_id == preset.preset_id),"Real shop draws saved native user preset by registered weight")
	check(rolled.all(func(card): return card.tile_preset.preset_id != clone.preset_id),"Zero-weight configuration never enters actual shop draw")
	check(rolled.all(func(card): return card.tower in actual_shop.catalog and card.price == card.tower.card_price),"Saved geometry preserves original tower identity and price in actual shop")
	check(catalog.archive(preset.preset_id),"User configuration can be removed from candidates")
	catalog.apply(actual_shop)
	check(actual_shop.roll_cards(60).all(func(card): return card.tile_preset.preset_id != preset.preset_id),"Archived preset immediately leaves real shop candidates")
	shop_session.queue_free(); await frames()
	check(FileAccess.file_exists(directory+"/"+preset.preset_id+".tres") and Catalog.new(directory).rows("broadside").all(func(r): return r.id != preset.preset_id),"Archive preserves external references but removes candidate")
	check(not catalog.archive("builtin"),"Built-in deletion protected")
	for turn in 4:
		var session := LevelFixture.session(0); add_child(session); await frames()
		var towers: Node = session.get_node("TowerMap")
		var card := BuildCard.from_parts(Catalog.tower("crossfire"),Fixture.cross_body())
		card.tile_preset.tower_offset = Vector2i.RIGHT
		card.tile_preset.facing_steps = 1
		var tower: DefenseTower = towers.place_card(card,Vector3i(8,0,7),turn)
		check(tower != null,"Offset cross-body placement at rotation "+str(turn))
		if tower != null:
			check(towers.towers.size() == 1 and tower.occupied_cells.size() == 5,"Five cells create exactly one tower")
			check(tower.rotation_steps == (turn+1)%4 and tower.grid_cell == Vector2i(8,7)+BuildCard.rotate_cell(Vector2i.RIGHT,turn),"Logical firing origin and facing use declared anchor")
			for cell in tower.occupied_cells:
				check(towers.occupied.get(cell) == tower and towers.upgrade_target(Vector3i(cell.x,0,cell.y)) == tower,"All occupied cells resolve one instance")
			check(tower.attack_offsets() == tower.definition.effective_attack_cells(Vector2i.ZERO,tower.rotation_steps,1,false,tower.attack_radius,tower.body_cells()),"Attack area uses actual body and facing")
			var revision: int = session.get_node("PortalMap").revision
			var target: Vector2i = tower.occupied_cells.back()
			check(towers.place_card(card,Vector3i(target.x,0,target.y),0) == tower and tower.level == 2 and session.get_node("PortalMap").revision == revision,"Upgrade at outer footprint consumes one tower upgrade, no roads")
			card.tile_preset.tower_footprint.clear()
			check(tower.occupied_cells.size() == 5 and tower.placement_preset.tower_footprint.size() == 5,"Placed body is a stable snapshot")
			tower.take_damage(100000)
			await frames()
			check(towers.occupied.is_empty(),"Death removes every occupied cell")
		session.queue_free(); await frames()
	await bypass()
	await functional_anchors()
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open(Artifacts.path("tower_tile_editor/rules.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t"))
	print("TOWER_TILE_RULES:"+JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)

func bypass() -> void:
	var session := LevelFixture.session(0); add_child(session); await frames()
	var towers: Node = session.get_node("TowerMap")
	var portal: Node = session.get_node("PortalMap")
	var map: GridMap = session.get_node("TileMap")
	var card := BuildCard.from_parts(Catalog.tower("broadside"),Fixture.long_hull())
	var history: int = portal.route_history.revision
	var shop: Node = session.get_node("CardPlacement/Shop")
	var wave: Node = session.get_node("EnemyWave")
	var rng: int = shop._rng.state
	var plan: Dictionary = towers.construction_plan([{"card":card,"anchor":Vector3i(8,0,0),"turns":0}])
	check(plan.ok,"Long hull single-card bypass is legal: "+plan.error)
	check(history == portal.route_history.revision and rng == shop._rng.state,"Candidate preview leaves route history and shop RNG unchanged")
	var tower: DefenseTower = towers.place_card(card,Vector3i(8,0,0),0)
	check(tower != null and tower.occupied_cells.size() == 3,"Long hull has three actual obstacles")
	var snapshot := Snapshot.capture(map,towers.occupied)
	check(Snapshot.connects_terminals(snapshot,portal.terminal_cells()),"Actual road detours around complete hull")
	for cell in [Vector2i(7,0),Vector2i(8,0),Vector2i(9,0)]: check(not cell in cells(snapshot),"Each hull cell excluded from native graph")
	check(cells(snapshot).size() == 19,"One-side bypass adds exactly authored roads, no automatic ring")
	var compact := BuildCard.from_parts(card.tower,Fixture.compact())
	var second: DefenseTower = towers.place_card(compact,Vector3i(12,0,3),1)
	check(second != null and second.definition == tower.definition and second.occupied_cells.size() == 1,"Same TowerDefinition supports multiple independent body shapes")
	var before := snapshot.duplicate(true)
	var bad := BuildCard.from_parts(Catalog.tower("mortar"),Fixture.compact())
	check(towers.place_card(bad,Vector3i(4,0,0)) == null,"Two-sided mortar cannot cut the only route")
	check(Snapshot.connects_terminals(Snapshot.capture(map,towers.occupied),portal.terminal_cells()),"Failed placement preserves route")
	var mortar: DefenseTower = towers.place_card(bad,Vector3i(4,0,3))
	check(mortar != null and bad.ground_cells(Vector2i.ZERO).size() == 3,"Mortar has exactly one body and two road tiles")
	# Same authoritative planner used by actual Soldier / Scout / Winged waves.
	await frames()
	var schedule: Dictionary = WaveSpawnSchedule.build(wave.definition,portal,1,false)
	check(not schedule.is_empty(),"Mixed-wave schedule is available after multi-cell construction")
	for member: Dictionary in schedule.get("pending",[]):
		for pos: Vector2 in member.route.cells: check(not towers.occupied.has(Vector2i(pos)),"Actual Soldier / Scout / Winged route avoids every footprint cell")
		if member.profile == TroopCatalog.find("scout"): check(member.route.birth_wave == 1,"Scout uses committed new bypass history")
		if member.profile == TroopCatalog.find("winged"): check(member.route.cells.size()-1 == portal.route_history.candidates(0,true).distance,"Winged path is genuinely shortest")
	session.queue_free(); await frames()

func functional_anchors() -> void:
	for key in Catalog.KEYS:
		var session := LevelFixture.session(0); add_child(session); await frames()
		var towers: Node = session.get_node("TowerMap")
		var preset := Fixture.long_hull()
		var turn := 1
		var origin := Vector3i(8,0,7)
		if key == "barracks":
			preset.custom_home = true; preset.home_offset = Vector2i(-2,0); turn = 0; origin = Vector3i(8,0,0)
		else:
			preset.tower_offset = Vector2i(1,0)
			preset.model_offset = Vector3(0.2,0.1,0.15)
		var card := BuildCard.from_parts(Catalog.tower(key),preset)
		var tower: DefenseTower = towers.place_card(card,origin,turn)
		check(tower != null,key+" accepts a custom multi-cell preset")
		await frames()
		if tower != null:
			var anchor := card.tower_anchor(Vector2i(origin.x,origin.z),turn)
			var map: GridMap = session.get_node("TileMap")
			var world := map.to_global(map.map_to_local(Vector3i(anchor.x,0,anchor.y))+Vector3.UP*TowerConstants.GROUND_OFFSET)
			var body_center := TowerBodyGeometry.origin(card.tower,tower.body_cells())
			var expected := world+tower.global_basis*Vector3(body_center.x,0,body_center.y)
			check(tower.combat_origin().is_equal_approx(expected),key+" uses body firing center independent of visual offset")
			check(is_equal_approx(tower.damage,card.tower.default_damage) and is_equal_approx(tower.attack_interval,card.tower.attack_interval),key+" preserves authored combat numbers")
			check(is_equal_approx(tower._visual.position.x,preset.model_offset.x) and is_equal_approx(tower._visual.position.z,preset.model_offset.z),key+" applies visual offset without moving logical anchor")
			if key == "broadside":
				check(tower.covers_cell(anchor+BuildCard.rotate_cell(Vector2i.RIGHT,tower.rotation_steps)) and tower.covers_cell(anchor+BuildCard.rotate_cell(Vector2i.LEFT,tower.rotation_steps)),"Broadside retains both authored side lanes")
				check(not tower.covers_cell(anchor+BuildCard.rotate_cell(Vector2i.UP,tower.rotation_steps)),"Broadside cannot fire down its forward axis")
			if key == "barracks":
				check(tower.garrison_cell() == Vector2i(6,0) and not towers.occupied.has(tower.garrison_cell()),"Barracks custom home is outside full body")
				var manager: Node = towers.combat.barracks
				check(manager.units.size() == 2 and manager.units.all(func(unit): return unit.home == tower.garrison_cell()),"Both real friendlies spawn at configured legal home")
				var blocker := BuildCard.from_parts(Catalog.tower("sentry"),Fixture.compact())
				check(not towers.validate_card(blocker,Vector3i(6,0,0)).is_empty(),"Future towers cannot cover custom garrison home")
		session.queue_free(); await frames()
	var session := LevelFixture.session(0); add_child(session); await frames()
	var preset := Fixture.long_hull(); preset.custom_home = true; preset.home_offset = Vector2i.ZERO
	var card := BuildCard.from_parts(Catalog.tower("barracks"),preset)
	check(not session.get_node("TowerMap").validate_card(card,Vector3i(8,0,0)).is_empty(),"Barracks rejects home inside its own footprint")
	card.tile_preset.home_offset = Vector2i(0,3); card.tile_preset.road_offsets.append(Vector2i(0,3))
	check(not session.get_node("TowerMap").validate_card(card,Vector3i(8,0,0)).is_empty(),"Barracks rejects isolated non-traversable home island")
	check(session.get_node("TowerMap").construction_plan([{"card":card,"anchor":Vector3i(8,0,0),"turns":0}],false).ok,"Legacy batch draft may temporarily disconnect a home until final validation")
	session.queue_free(); await frames()
