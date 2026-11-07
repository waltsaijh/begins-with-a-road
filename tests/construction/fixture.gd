extends RefCounted
## Independent test support: free cards and 60 Gold are explicit subsidies.
## The scene still uses the complete existing shop, wave, combat and relic flow.
const Endpoints = preload("res://tests/fixtures/level_fixture.gd")
const LEGACY = preload("res://tests/fixtures/card_fixture.gd")
const PRESET_ROOT := "res://assets/data/construction/presets/"
const TOWER_KEYS := ["ballista", "crossfire", "sentry", "mortar", "ballista", "crossfire"]
const SHAPE_KEYS := ["corner", "corner", "straight", "tee", "pocket", "cross"]
const MODE_NAMES := ["A 舊版即時", "B 複合即時", "C 複合批次"]

static func card(shape: String, tower_key := "ballista", legacy := false) -> BuildCard:
	var tower: TowerDefinition = load("res://assets/data/towers/"+tower_key+".tres")
	var preset: TilePreset = LEGACY.card(shape).tile_preset if legacy else load(PRESET_ROOT+shape+".tres")
	return BuildCard.from_parts(tower, preset)

static func starting_cards(mode := 2) -> Array[BuildCard]:
	var result: Array[BuildCard] = []
	for index in TOWER_KEYS.size():
		var shape: String = ["corner", "bridge", "flank"][index % 3] if mode == 0 else SHAPE_KEYS[index]
		result.append(card(shape, TOWER_KEYS[index], mode == 0))
	return result

static func definition(mode := 2) -> LevelDefinition:
	var result := LevelDefinition.new()
	result.set_meta("display_title", "Construction Playground — "+MODE_NAMES[clampi(mode, 0, 2)]+"（測試補助：6 張免費卡＋60 Gold）")
	result.starting_gold = 60
	result.opening_shop = true
	result.base_health = 0
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-8.5, 0, -0.5)
	# End masks are harmless outside the map; topology uses reciprocal ports.
	for x in 17: terrain.set_cell_item(Vector3i(x, 0, 0), 6)
	Endpoints.endpoint(terrain, Endpoints.Start, Vector2i.ZERO, "Start")
	Endpoints.endpoint(terrain, Endpoints.Goal, Vector2i(16,0), "Goal")
	result.terrain = PackedScene.new()
	result.terrain.pack(terrain)
	terrain.free()
	var act := ActDefinition.new()
	act.add_start_after_completion = false
	act.title = "建造試驗"
	for index in 6:
		var wave := WaveDefinition.new()
		wave.move_speed = 0.8
		wave.reward = 18
		for id in ["soldier", "scout", "winged"]:
			var group := WaveSpawnGroup.new()
			group.troop = TroopCatalog.find(id)
			group.enemy_count = 4+index
			group.interval_ticks = 6
			group.start_tick = 0 if id == "soldier" else (8 if id == "scout" else 16)
			group.start_index = 0
			wave.groups.append(group)
		act.waves.append(wave)
	result.acts = [act]
	return result

static func session(mode := 2) -> Node3D:
	var result: Node3D = load("res://scenes/level.tscn").instantiate()
	result.level = definition(mode)
	result.set_meta("construction_mode", mode)
	result.set_meta("construction_test_subsidy", "6 free cards + 60 Gold; base health disabled")
	result.get_node("CardPlacement").initial_card_count = 0
	result.get_node("CardPlacement").cards = starting_cards(mode)
	if mode > 0:
		var pool: Array[TilePresetCandidate] = []
		for key in ["straight","corner","tee","cross","pocket"]:
			var option := TilePresetCandidate.new()
			option.preset_path = PRESET_ROOT+key+".tres"
			option.weight = 1.0
			pool.append(option)
		var shop: Node = result.get_node("CardPlacement/Shop")
		for tower in shop.catalog:
			# Barracks retains its existing road + garrison placement recipe.
			if tower.deployment == null: shop.tile_preset_overrides[tower] = pool
	return result

static func batch_pair() -> Array:
	# The first tower cuts the original line; the second L completes a 4-cell-deep bypass.
	return [
		{"card":card("corner", "ballista"), "anchor":Vector3i(6, 0, 0), "turns":0},
		{"card":card("corner", "crossfire"), "anchor":Vector3i(9, 0, -2), "turns":1}]
