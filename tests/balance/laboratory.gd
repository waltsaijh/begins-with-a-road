extends Node
## Fixed-step driver of production systems, not a second combat simulation.
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const KEYS := ["sentry","ballista","broadside","crossfire","mortar","barracks"]
const STEP := 1.0/60.0
var output := "res://.godot/phase5/baseline"
var seed_value := 11
var config := "baseline"
var scale_damage := 1.0
var level_value := 1
var original_stats := false
var results: Array = []
var failures: Array = []
func _ready() -> void: run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--config="): config = arg.trim_prefix("--config=")
		if arg.begins_with("--damage="): scale_damage = float(arg.trim_prefix("--damage="))
		if arg.begins_with("--level="): level_value = int(arg.trim_prefix("--level="))
		if arg == "--stats=baseline": original_stats = true
	for key in KEYS:
		for geometry in ["parallel","approach","away"]:
			for troop in ["soldier","rats","heavy","winged"]:
				await arena(key,geometry,troop)
	if results.size() != 72: failures.append("Incomplete matrix: %d/72" % results.size())
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output+"/summary.json",FileAccess.WRITE).store_string(JSON.stringify({"results":results,"failures":failures},"\t"))
	print("BALANCE_LAB ",JSON.stringify({"cases":results.size(),"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
func arena(key: String, geometry: String, troop_key: String) -> void:
	var id := "%s_%s_%s_%d" % [key,geometry,troop_key,seed_value]
	BalanceTrace.begin(output+"/"+id+".jsonl",{"run_id":id,"config":config,"seed":seed_value,"kind":"reference","tower":key,"geometry":geometry,"troop":troop_key,"level":level_value,"damage_factor":scale_damage,"rng":{"spawn":seed_value if original_stats else 91573,"global":seed_value,"mode":"legacy_global" if original_stats else "dedicated"}})
	var cells: Array[Vector2i] = []
	var anchor := Vector2i(10,1)
	var start := Vector2i(0,0)
	var goal := Vector2i(20,0)
	if geometry == "parallel":
		for x in 21: cells.append(Vector2i(x,0))
	else:
		anchor = Vector2i(0,1)
		start = Vector2i(0,-18)
		goal = Vector2i(2,0)
		for y in range(-18,1): cells.append(Vector2i(0,y))
		cells.append(Vector2i(1,0))
		cells.append(goal)
	cells.append(anchor)
	var scene := Fixture.scene_for(cells,start,goal)
	scene.get_node("EnemyWave").auto_start = false
	scene.get_node("CardPlacement").initial_card_count = 0
	scene.get_node("CardPlacement").cards.clear()
	add_child(scene)
	for frame in 3: await get_tree().process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var tm: Node = scene.get_node("TowerMap")
	var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres").duplicate(true)
	if original_stats:
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/balance/phase5_baseline_parameters.json"))
		var prefix := "res://assets/data/towers/"+key+".tres."
		for parameter in baseline.parameters:
			if parameter.id == prefix+"default_damage": definition.default_damage = parameter.original_value
			if parameter.id == prefix+"card_price": definition.card_price = parameter.original_value
			if parameter.id == prefix+"deployment.damage" and definition.deployment != null: definition.deployment.damage = parameter.original_value
	definition.default_damage *= scale_damage
	if definition.deployment != null: definition.deployment.damage *= scale_damage
	var turns := 2 if geometry == "away" else 0
	if key == "broadside": turns = 0 if geometry == "away" else 1
	if key == "barracks": turns = 0 # Garrison requires the adjacent authored road.
	var tower: DefenseTower = tm.place_card(BuildCard.from_parts(definition,TilePreset.new()),Vector3i(anchor.x,0,anchor.y),turns)
	if tower == null:
		failures.append(id+": "+tm.last_error)
	else:
		for upgrade in range(1,level_value):
			if not tower.upgrade(): failures.append(id+": illegal diagnostic upgrade")
		var wave: Node = scene.get_node("EnemyWave")
		# Historical reference baselines preceded the dedicated spawn stream.
		if original_stats: wave.spawn_rng = null
		var recipe := WaveDefinition.new()
		recipe.move_speed = 2.5
		var group := WaveSpawnGroup.new()
		group.troop = TroopCatalog.find(troop_key)
		group.enemy_count = 20 if troop_key == "rats" else 8
		group.interval_ticks = 6
		recipe.groups = [group]
		wave.apply_definition(recipe)
		for frame in 3: await get_tree().process_frame
		seed(seed_value)
		BalanceTrace.wave = 1
		if not wave.start_wave(): failures.append(id+": cannot start")
		var elapsed := 0.0
		var peak := 0
		while (wave.active or not tm.combat.projectiles.is_empty()) and elapsed < 180:
			step(scene,STEP)
			elapsed += STEP
			peak = maxi(peak,wave.alive)
			if int(elapsed/STEP)%60 == 0: await get_tree().process_frame
		var result := {"id":id,"config":config,"tower":key,"geometry":geometry,"troop":troop_key,"seed":seed_value,"spawned":wave.spawned,"killed":wave.killed,"leaked":wave.completed,"seconds":elapsed,"peak_alive":peak,"shots":tm.combat.shots_fired,"price":definition.card_price,"gold":scene.get_node("CardPlacement/Shop").coins,"timeout":wave.active}
		results.append(result)
		BalanceTrace.end(result)
	scene.queue_free()
	await get_tree().process_frame
static func step(scene: Node, seconds: float) -> void:
	BalanceTrace.time += seconds
	var wave: Node = scene.get_node("EnemyWave")
	var combat: Node = scene.get_node("TowerMap").combat
	wave._process(seconds)
	for enemy in wave.living_enemies(): enemy._process(seconds)
	combat.enemy_abilities._process(seconds)
	combat.barracks._process(seconds)
	combat._process(seconds)
	# Age visual pools too; disabling drawing must not allow unbounded effects.
	if DisplayServer.get_name() == "headless":
		combat.visuals.beams.clear()
		combat.visuals.restored_bursts.clear()
		combat.visuals.get_node("ImpactEffects").advance(seconds)
	else:
		combat.visuals._process(seconds)
		combat.visuals.restored_bursts._process(seconds)
