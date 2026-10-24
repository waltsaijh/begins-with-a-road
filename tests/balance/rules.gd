extends Node
const Fixture = preload("res://tests/synergy/fixture.gd")
const Driver = preload("res://tests/balance/laboratory.gd")
var failures: Array[String] = []
var checks := 0
func _ready() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func session(count: int, boss := false) -> Node:
	var level := Fixture.definition(0)
	level.starts = [Vector2i(0,0)]
	level.base_health = 20 if boss else 1
	level.starting_gold = 9
	level.opening_shop = true
	level.acts.clear()
	for a in ceili(count/3.0):
		var act := ActDefinition.new()
		for w in mini(3,count-a*3):
			var recipe := WaveDefinition.new()
			recipe.reward = 0 if a*3+w == count-1 else 2
			var group := WaveSpawnGroup.new()
			group.troop = TroopCatalog.find("siege_behemoth" if boss else "soldier")
			group.enemy_count = 1
			recipe.groups = [group]
			act.waves.append(recipe)
		level.acts.append(act)
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	scene.level = level
	add_child(scene)
	for frame in 4: await get_tree().process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	return scene
func start(scene: Node) -> void:
	scene._on_start_requested()
	scene._advance_wave_start(1.5)
	scene.get_node("EnemyWave")._process(0.0)
func verify() -> void:
	var level: LevelDefinition = load("res://assets/data/levels/frontier.tres")
	check(level.acts.size() == 5 and level.wave_count() == 15,"Frontier is five ACTs / fifteen waves")
	check(not level.expand_starts_after_act and not level.reward_final_act,"No automatic entrances or fifth relic")
	var names := {}
	for act in level.acts:
		for wave in act.waves:
			for group in wave.groups: names[group.troop.troop_name] = true
	check(names.size() == 10 and names.has("siege_behemoth"),"Nine ordinary troops and one boss are authored")
	var prices := {"sentry":9,"ballista":8,"broadside":8,"crossfire":10,"mortar":9,"barracks":8}
	for name in prices:
		check(load("res://assets/data/towers/"+name+".tres").card_price == prices[name],"Loaded price, not serialized text: "+name)
	var scene: Node = await session(15)
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var choices := 0
	for i in 15:
		check(scene.current_wave == i and not scene.finished,"Correct preparation index")
		start(scene)
		var wave: Node = scene.get_node("EnemyWave")
		check(wave.active and not shop.available,"Start locks shop")
		for enemy in wave.living_enemies(): enemy.take_damage(100000)
		await get_tree().process_frame
		if scene.choosing_relic:
			choices += 1
			check(i+1 in [3,6,9,12],"Relic boundary is one of four authorized waves")
			var relic: RelicDefinition = scene.relic_choice.offers[0]
			check(scene.relic_choice.choose(relic),"Choice commits once")
			check(not scene.relic_choice.choose(relic),"Repeated click cannot duplicate reward")
			await get_tree().create_timer(0.3).timeout
	check(scene.finished and scene.victory and choices == 4,"Fifteenth completion wins with exactly four rewards")
	check(not scene.get_node("EnemyWave").start_allowed and not shop.available,"Terminal state locks start and shop")
	var balance: int = shop.coins
	scene._on_wave_finished()
	shop._on_wave_finished()
	check(scene.current_wave == 15 and shop.coins == balance,"Late completion cannot duplicate progression or income")
	scene.queue_free()
	await get_tree().process_frame
	for boss in [false,true]:
		scene = await session(3,boss)
		shop = scene.get_node("CardPlacement/Shop")
		var wave: Node = scene.get_node("EnemyWave")
		# A pending later group must be cancelled, not paid as a completed wave.
		var later: WaveSpawnGroup = wave.definition.groups[0].duplicate(true)
		later.start_tick = 100
		wave.definition.groups.append(later)
		start(scene)
		check(wave._pending.size() == 1,"Future batch remains pending")
		var enemy: Node3D = wave.living_enemies()[0]
		if boss:
			var route: PackedVector3Array = enemy.waypoints.duplicate()
			enemy.apply_slow(0.5,2.0)
			check(enemy._speed_factor(0) == 0.5 and enemy.waypoints == route,"Boss slow preserves immutable path")
			enemy.apply_frost(0.18,2,0.6)
			check(enemy._speed_factor(0) < 0.5,"Boss frost is effective")
		enemy._process(10000)
		check(scene.finished and not scene.victory and scene.current_wave == 0,"Leak produces immediate defeat without advancement")
		check(shop.coins == 9 and not wave.active and wave._pending.is_empty(),"Defeat cancels pending spawns and awards no completion Gold")
		await get_tree().process_frame
		check(wave.living_enemies().is_empty() and wave.alive == 0,"Defeat cleans enemy membership")
		scene.queue_free()
		await get_tree().process_frame
	print("PHASE5_RULES ",JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
