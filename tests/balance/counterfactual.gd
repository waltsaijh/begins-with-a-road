extends Node
const Fixture = preload("res://tests/synergy/fixture.gd")
const Driver = preload("res://tests/balance/laboratory.gd")
var output := "res://.godot/phase5/counterfactual"
var seed_value := 11
var results: Array = []
var failures: Array = []
func _ready() -> void: run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	for mechanic in ["guardian","healing","disable","swarm","scout","flying","boss"]:
		for enabled in [false,true]:
			for traffic in [false,true]: await encounter(mechanic,enabled,traffic)
	if results.size() != 28: failures.append("Incomplete factorial")
	FileAccess.open(output+"/summary.json",FileAccess.WRITE).store_string(JSON.stringify({"results":results,"failures":failures},"\t"))
	print("COUNTERFACTUAL ",results.size()," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func encounter(mechanic: String, enabled: bool, traffic: bool) -> void:
	var id := "%s_%d_%d_%d" % [mechanic,int(enabled),int(traffic),seed_value]
	BalanceTrace.begin(output+"/"+id+".jsonl",{"run_id":id,"config":"counterfactual","seed":seed_value,"kind":"counterfactual","mechanic":mechanic,"enabled":enabled,"traffic":traffic,"budget":50,"forced_loadout":true})
	var level := Fixture.definition(0)
	preload("res://tests/fixtures/level_fixture.gd").single_start(level)
	var recipe := WaveDefinition.new()
	recipe.move_speed = 1.4
	recipe.reward = 0
	var types := [["rook",4],["rats",30]]
	match mechanic:
		"healing": types = [["rook",3],["bloodmage",3],["heavy",4]]
		"disable": types = [["bomber",4],["rats",30]]
		"swarm": types = [["rats",40]]
		"scout": types = [["scout",20],["soldier",6]]
		"flying": types = [["winged",20],["heavy",3]]
		"boss": types = [["ravager",1],["rook",2],["rats",15]]
	for entry: Array in types:
		var profile: Troop = TroopCatalog.find(entry[0]).duplicate(true)
		if not enabled:
			match mechanic:
				"guardian": profile.taunt_radius = 0
				"healing": profile.heal_amount = 0
				"disable", "boss": profile.sabotage_radius = 0
				"swarm": profile.cohort_size = 1
				"scout", "flying":
					profile.tile_cost_reduce = Troop.TileCostReduce.ADD
					profile.path_base_cost = 1.0
					profile.road_age_weight = 0.0
					profile.score_threshold = INF
		var group := WaveSpawnGroup.new()
		group.troop = profile
		group.enemy_count = entry[1]
		group.interval_ticks = 6 if entry[0] == "rats" else 12
		if entry[0] == "bloodmage": group.start_tick = 2
		recipe.groups.append(group)
	level.acts[0].waves.assign([recipe])
	level.base_health = 0
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	scene.level = level
	scene.get_node("CardPlacement").initial_card_count = 0
	scene.get_node("CardPlacement/Shop").initial_coins = 50
	scene.get_node("EnemyWave").spawn_seed = seed_value+2000
	add_child(scene)
	for frame in 3: await get_tree().process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var tm: Node = scene.get_node("TowerMap")
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var keys := ["crossfire","mortar","sentry","ballista"]
	var spots := [Vector3i(8,0,1),Vector3i(11,0,1),Vector3i(8,0,7),Vector3i(14,0,7)]
	for i in keys.size():
		var definition: TowerDefinition = load("res://assets/data/towers/"+keys[i]+".tres")
		var preset := TilePreset.new()
		var placed: DefenseTower = tm.place_card(BuildCard.from_parts(definition,preset),spots[i],0)
		# Add the isolated support cell via the actual card's ground union.
		if placed == null:
			failures.append(id+": illegal forced tower "+keys[i])
		else:
			shop.coins -= definition.card_price
			BalanceTrace.event("gold","shop",{"delta":-definition.card_price,"balance":shop.coins,"reason":"diagnostic_card"})
	if mechanic == "scout": Fixture.new_roads(scene)
	if traffic:
		for spec in [["narrow_passage",Vector2i(7,0)],["barricade",Vector2i(7,6)]]:
			var definition: TrafficStructureDefinition = load("res://assets/data/traffic/"+spec[0]+".tres")
			if tm.traffic.place(definition,spec[1],0) == null: failures.append(id+": illegal traffic")
			else:
				shop.coins -= definition.card_price
				BalanceTrace.event("gold","shop",{"delta":-definition.card_price,"balance":shop.coins,"reason":"diagnostic_traffic"})
	for frame in 3: await get_tree().process_frame
	var wave: Node = scene.get_node("EnemyWave")
	BalanceTrace.wave = 1
	if not wave.start_wave(): failures.append(id+": cannot start")
	var elapsed := 0.0
	while (wave.active or scene._settling_wave) and elapsed < 180:
		Driver.step(scene,Driver.STEP)
		scene._process(Driver.STEP)
		elapsed += Driver.STEP
		if int(elapsed/Driver.STEP)%120 == 0: await get_tree().process_frame
	var result := {"id":id,"mechanic":mechanic,"enabled":enabled,"traffic":traffic,"seed":seed_value,"spawned":wave.spawned,"killed":wave.killed,"leaked":wave.completed,"gold":shop.coins,"damage_received":wave.damage_received,"seconds":elapsed,"timeout":wave.active}
	results.append(result)
	BalanceTrace.end(result)
	scene.queue_free()
	await get_tree().process_frame
