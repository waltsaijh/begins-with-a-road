extends Node
const Fixture = preload("res://tests/synergy/fixture.gd")
var failures: Array[String] = []
var checks := 0
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
func _ready() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func session(count: int, boss := false) -> Node:
	var level := Fixture.definition(0)
	level.level_id = "merge_defeat_boss" if boss else ("merge_victory" if count == 15 else "merge_defeat")
	preload("res://tests/fixtures/level_fixture.gd").single_start(level)
	level.base_health = 20 if boss else 1
	level.starting_gold = 9
	level.opening_shop = true
	# Exercise both five-wave event boundaries with a deterministic, non-targeted choice.
	level.special_event_catalog = SpecialEventCatalog.new()
	level.special_event_catalog.entries.assign([preload("res://assets/data/events/event_05.tres")])
	level.acts.clear()
	for a in ceili(count/3.0):
		var act := ActDefinition.new()
		act.add_start_after_completion = false
		for w in mini(3,count-a*3):
			var recipe := WaveDefinition.new()
			recipe.reward = 0 if a*3+w == count-1 else 2
			var group := WaveSpawnGroup.new()
			group.troop = TroopCatalog.find("ravager" if boss else "soldier")
			group.enemy_count = 1
			recipe.groups = [group]
			if count == 3 and a == 0 and w == 0:
				var later := group.duplicate(true) as WaveSpawnGroup
				later.start_tick = 100
				recipe.groups.append(later)
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
	var old_path: String = LevelProgress.save_path
	var old_completed: Dictionary = LevelProgress.snapshot()
	LevelProgress.save_path = Artifacts.path("balance/merge_completion.cfg")
	LevelProgress._completed = {}
	var level: LevelDefinition = load("res://assets/data/levels/frontier.tres")
	check(level.acts.size() == 5 and level.wave_count() == 15,"Frontier is five ACTs / fifteen waves")
	check(level.acts.all(func(act): return not act.add_start_after_completion) and not level.reward_final_act,"No automatic entrances or fifth relic")
	var names := {}
	for act in level.acts:
		for wave in act.waves:
			for group in wave.groups: names[group.troop.troop_name] = true
	check(names.size() == 10 and names.has("ravager"),"Nine ordinary troops and one boss are authored")
	var scene: Node = await session(15)
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var priced := {}
	for card: BuildCard in shop.roll_cards(shop.catalog.size()):
		check(card.price == card.tower.card_price, "Dealt card uses the price of " + card.tower.resource_path)
		priced[card.tower] = true
	check(priced.size() == shop.catalog.size(), "Every tower in the shop catalog has a priced offer")
	shop.open_shop()
	var offer: BuildCard = shop.offers[0]
	var shown: Label = shop.view.price_view(1).get_node("Number")
	check(offer.price == offer.tower.card_price and shown.text == str(offer.price), "Displayed offer reads the authored tower price")
	shop.grant_gold(offer.price, "test")
	var before: int = shop.coins
	check(shop.buy(0) and shop.coins == before - offer.price and shop.sold[0] == 1, "Buying charges the displayed amount once")
	shop.close_shop()
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
		if i+1 in [5,10]:
			check(scene.choosing_event and scene.special_events.choose(1), "Resolve the five-wave event before starting the next wave")
	check(scene.finished and scene.victory and choices == 4,"Fifteenth completion wins with exactly four rewards")
	check(not scene.get_node("EnemyWave").start_allowed and not shop.available,"Terminal state locks start and shop")
	check(LevelProgress.snapshot().has("merge_victory"),"Victory records the completed Level ID")
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
		check(not LevelProgress.snapshot().has(scene.level.progress_id()),"Defeat never records completion")
		check(shop.coins == 9 and not wave.active and wave._pending.is_empty(),"Defeat cancels pending spawns and awards no completion Gold")
		await get_tree().process_frame
		check(wave.living_enemies().is_empty() and wave.alive == 0,"Defeat cleans enemy membership")
		scene.queue_free()
		await get_tree().process_frame
	LevelProgress.save_path = old_path
	LevelProgress._completed = old_completed
	print("PHASE5_RULES ",JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
