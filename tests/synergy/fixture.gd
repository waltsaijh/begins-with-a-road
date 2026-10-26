extends RefCounted
const Endpoints = preload("res://tests/fixtures/level_fixture.gd")
const KEYS = ["ballista","crossfire","mortar","broadside","barracks","sentry"]
const ANCHORS = [Vector3i(7,0,2),Vector3i(10,0,1),Vector3i(12,0,4),Vector3i(9,0,7),Vector3i(5,0,7),Vector3i(14,0,8)]
const TITLES = ["A 盾衛兵＋鼠群", "B 盾衛兵＋血法師＋重裝兵", "C 鼠群＋爆破手", "D 飛翼獸＋偵查兵"]
static func definition(scenario: int) -> LevelDefinition:
	var level := LevelDefinition.new()
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-9.5,0,-3.5)
	for x in 17:
		for y in [0,6]: terrain.set_cell_item(Vector3i(x,0,y),6)
	for x in [2,16]:
		for y in 7: terrain.set_cell_item(Vector3i(x,0,y),6)
	for x in range(16,19): terrain.set_cell_item(Vector3i(x,0,3),6)
	# A single attached base supplies the barracks' legal road garrison.
	terrain.set_cell_item(Vector3i(5,0,7),6)
	Endpoints.endpoint(terrain, Endpoints.Start, Vector2i(0,0), "Start")
	Endpoints.endpoint(terrain, Endpoints.Start, Vector2i(0,6), "Start2")
	Endpoints.endpoint(terrain, Endpoints.Goal, Vector2i(18,3), "Goal")
	level.terrain = PackedScene.new()
	level.terrain.pack(terrain)
	terrain.free()
	var types: Array = [
		[["shield_guardian",4,0],["rat_swarm",30,1]],
		[["shield_guardian",4,0],["blood_mage",5,1],["heavy",6,0]],
		[["saboteur",6,0],["rat_swarm",30,1]],
		[["winged_beast",12,0],["scout",12,0]]][scenario]
	var act := ActDefinition.new()
	act.add_start_after_completion = false
	act.title = TITLES[scenario]
	for repeat in 3:
		var wave := WaveDefinition.new()
		wave.move_speed = 0.9
		wave.reward = 25
		for origin in 2:
			for type: Array in types:
				var group := WaveSpawnGroup.new()
				group.troop = TroopCatalog.find(type[0])
				group.enemy_count = type[1]
				group.start_tick = type[2]
				group.start_index = origin
				group.interval_ticks = 6
				wave.groups.append(group)
		act.waves.append(wave)
	level.acts = [act]
	return level

static func session(scenario: int) -> Node3D:
	var result: Node3D = load("res://scenes/level.tscn").instantiate()
	result.level = definition(scenario)
	result.get_node("CardPlacement").initial_card_count = 0
	return result

static func towers(session: Node3D) -> void:
	for i in KEYS.size():
		var definition: TowerDefinition = load("res://assets/data/towers/"+KEYS[i]+".tres")
		var card := BuildCard.from_parts(definition,TilePreset.new())
		var placed: DefenseTower = session.get_node("TowerMap").place_card(card,ANCHORS[i],1 if KEYS[i] == "broadside" else 0)
		assert(placed != null,"Synergy fixture tower "+KEYS[i])

static func new_roads(session: Node3D) -> void:
	var cells: Array[Vector3i] = []
	for y in [-3,9]:
		for x in range(2,17): cells.append(Vector3i(x,0,y))
	for x in [2,16]:
		for y in range(-3,10): cells.append(Vector3i(x,0,y))
	session.get_node("TilePlacement").add_cells(cells)
