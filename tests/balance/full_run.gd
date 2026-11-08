extends Node
const Driver = preload("res://tests/balance/laboratory.gd")
const Policy = preload("res://tests/balance/policy.gd")
var output := "res://.godot/phase5/pilot"
var seed_value := 11
var policies := ["generalist","damage","route","swarm","heavy","barracks","core"]
var config := "candidate1"
var results: Array = []
var failures: Array = []
var price_factor := 1.0
var reward_factor := 1.0
var speed_factor := 1.0
var hp_factor := 1.0
var interval_factor := 1.0
var healing_factor := 1.0
var disable_factor := 1.0
var growth_factor := 1.0
var price_mode := "individual"
var map_variant := "frontier"
var rendered := false
var choice_clicks := 0
var restart_verified := false
var late_interval_factor := 1.0
var level_path := "res://assets/data/levels/frontier.tres"
var reroll_first := false
func _ready() -> void: run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--config="): config = arg.trim_prefix("--config=")
		if arg.begins_with("--policy="): policies = [arg.trim_prefix("--policy=")]
		if arg.begins_with("--price="): price_factor = float(arg.trim_prefix("--price="))
		if arg.begins_with("--reward="): reward_factor = float(arg.trim_prefix("--reward="))
		if arg.begins_with("--speed="): speed_factor = float(arg.trim_prefix("--speed="))
		if arg.begins_with("--hp="): hp_factor = float(arg.trim_prefix("--hp="))
		if arg.begins_with("--interval="): interval_factor = float(arg.trim_prefix("--interval="))
		if arg.begins_with("--healing="): healing_factor = float(arg.trim_prefix("--healing="))
		if arg.begins_with("--disable="): disable_factor = float(arg.trim_prefix("--disable="))
		if arg.begins_with("--growth="): growth_factor = float(arg.trim_prefix("--growth="))
		if arg.begins_with("--price-mode="): price_mode = arg.trim_prefix("--price-mode=")
		if arg.begins_with("--map="): map_variant = arg.trim_prefix("--map=")
		if arg == "--rendered": rendered = true
		if arg.begins_with("--late-interval="): late_interval_factor = float(arg.trim_prefix("--late-interval="))
		if arg.begins_with("--level-resource="): level_path = arg.trim_prefix("--level-resource=")
		if arg == "--reroll-first": reroll_first = true
	if rendered:
		policies = ["generalist"]
		if DisplayServer.get_name() == "headless": failures.append("Rendered evidence requires a real renderer")
	if config == "candidate3" and level_path == "res://assets/data/levels/frontier.tres": level_path = "res://tests/balance/config/candidate2_frontier.tres"
	for kind: String in policies: await play(kind)
	if results.size() != policies.size(): failures.append("Incomplete policy matrix")
	FileAccess.open(output+"/summary.json",FileAccess.WRITE).store_string(JSON.stringify({"results":results,"failures":failures},"\t"))
	print("FULL_RUN_LAB ",JSON.stringify({"results":results,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
func play(kind: String) -> void:
	var id := "%s_%d" % [kind,seed_value]
	BalanceTrace.begin(output+"/"+id+".jsonl",{"run_id":id,"config":config,"seed":seed_value,"kind":"full_run","policy":kind,"price_factor":price_factor,"reward_factor":reward_factor,"speed_factor":speed_factor,"hp_factor":hp_factor,"interval_factor":interval_factor,"late_interval_factor":late_interval_factor,"healing_factor":healing_factor,"disable_factor":disable_factor,"growth_factor":growth_factor,"price_mode":price_mode,"map":map_variant,"rng":{"shop":seed_value+1000,"spawn":seed_value+2000,"relics":seed_value+3000}})
	var scene: Node3D = load("res://scenes/level.tscn").instantiate()
	scene.level = load(level_path).duplicate(true)
	if map_variant == "holdout":
		preload("res://tests/balance/holdout.gd").apply(scene.level)
	var wave_index := 0
	for act in scene.level.acts:
		for recipe in act.waves:
			recipe.reward = roundi(recipe.reward*reward_factor)
			recipe.move_speed *= speed_factor
			for group in recipe.groups: group.interval_ticks = roundi(group.interval_ticks*interval_factor*(late_interval_factor if wave_index >= 9 else 1.0))
			wave_index += 1
	var shop: Node = scene.get_node("CardPlacement/Shop")
	# Shop definitions remain shared with relic identities; restore after each run.
	var prices := {}
	var growths := {}
	for definition: TowerDefinition in shop.catalog:
		prices[definition] = definition.card_price
		var original := {"sentry":3,"ballista":11,"broadside":12,"crossfire":13,"mortar":14,"barracks":15}
		var value: int = 9 if price_mode == "flat9" else (original[definition.name_key.split(".")[1]] if price_mode == "original" else definition.card_price)
		definition.card_price = roundi(value*price_factor)
		if not growths.has(definition.growth):
			growths[definition.growth] = [definition.growth.damage,definition.growth.friendly_damage]
			definition.growth.damage = 1.0+(definition.growth.damage-1.0)*growth_factor
			definition.growth.friendly_damage = 1.0+(definition.growth.friendly_damage-1.0)*growth_factor
	var healths := {}
	for troop: Troop in TroopCatalog.all():
		var heal: HealAbility = troop.find_ability(HealAbility)
		var sabotage: SabotageAbility = troop.find_ability(SabotageAbility)
		healths[troop] = [troop.max_health,heal.amount if heal else 0.0,sabotage.duration if sabotage else 0.0]
		troop.max_health *= hp_factor
		if heal: heal.amount *= healing_factor
		if sabotage: sabotage.duration *= disable_factor
	shop.random_seed = seed_value+1000
	scene.get_node("EnemyWave").spawn_seed = seed_value+2000
	get_tree().root.add_child(scene)
	for frame in 3: await get_tree().process_frame
	if rendered:
		get_tree().current_scene = scene
		scene.set_process(false)
		scene.get_node("EnemyWave").set_process(false)
		scene.get_node("EnemyWave").enemy_spawned.connect(func(enemy): enemy.set_process(false))
		var combat: Node = scene.get_node("TowerMap").combat
		combat.set_process(false)
		combat.enemy_abilities.set_process(false)
		combat.barracks.set_process(false)
	else: scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("TowerMap").relics._rng.seed = seed_value+3000
	var agent := Policy.new()
	agent.kind = kind
	agent.session = scene
	var wave: Node = scene.get_node("EnemyWave")
	var elapsed := 0.0
	var total_damage := 0.0
	var steps := 0
	var per_wave: Array = []
	while not scene.finished and elapsed < 2400:
		BalanceTrace.wave = scene.current_wave+1
		await prepare(scene,agent)
		var index: int = scene.current_wave
		var beginning := elapsed
		var peak := 0
		if rendered:
			await get_tree().create_timer(0.45).timeout
			if index in [0,6,12]: await snapshot("preparation_"+str(index+1))
			await click(scene.get_node("LevelHUD").start_callouts[0])
			if not scene._wave_starting: failures.append("Real start click failed at wave "+str(index+1))
			scene.set_process(false)
		else: scene._on_start_requested()
		while not scene.finished and scene.current_wave == index and elapsed-beginning < 180:
			scene._process(Driver.STEP)
			Driver.step(scene,Driver.STEP)
			elapsed += Driver.STEP
			steps += 1
			peak = maxi(peak,wave.alive)
			if steps%(12 if rendered else 120) == 0: await get_tree().process_frame
			if rendered:
				scene.set_process(false)
				if index == 14 and not scene.has_meta("boss_capture") and scene.run_status.boss != null:
					scene.set_meta("boss_capture",true)
					await snapshot("boss")
		total_damage += wave.damage_received
		per_wave.append({"wave":index+1,"kills":wave.killed,"leaks":wave.completed,"spawned":wave.spawned,"gold":shop.coins,"life":scene.base_health,"peak_alive":peak,"seconds":elapsed-beginning,"towers":scene.get_node("TowerMap").towers.size()})
		if scene.current_wave == index and not scene.finished:
			failures.append(id+": wave timeout "+str(index+1))
			break
		if scene.choosing_relic:
			var chosen: RelicDefinition = agent.relic(scene.relic_choice.offers)
			if rendered:
				await get_tree().process_frame
				await snapshot("relic_"+str(scene.current_wave))
				await click(scene.relic_choice.row.get_child(scene.relic_choice.offers.find(chosen)))
				choice_clicks += 1
			else: scene.relic_choice.choose(chosen)
			await get_tree().create_timer(0.3).timeout
	var levels := {}
	for tower: DefenseTower in scene.get_node("TowerMap").towers.values(): levels[BalanceTrace.tower_id(tower)] = tower.level
	var result := {"id":id,"policy":kind,"seed":seed_value,"gold":shop.coins,"outcome":"victory" if scene.victory else "defeat","completed_waves":scene.current_wave,"total_killed":scene.total_kills,"total_leaks":scene.total_leaks,"base_health":scene.base_health,"damage_received":total_damage,"seconds":elapsed,"levels":levels,"relics":scene.get_node("TowerMap").relics.held.duplicate(),"waves":per_wave,"unplaced_cards":scene.get_node("CardPlacement").cards.size()}
	results.append(result)
	BalanceTrace.end(result)
	if rendered:
		await snapshot("result")
		if choice_clicks != 4 or not scene.victory: failures.append("Rendered run did not win with exactly four choices")
		await click(scene.run_status.get_node("Result/Center/Panel/Margin/Column/Restart"))
		for frame in 8: await get_tree().process_frame
		var restarted: Node = get_tree().current_scene
		restart_verified = restarted != scene and restarted.current_wave == 0 and not restarted.finished and restarted.base_health == restarted.level.base_health and Engine.time_scale == 1.0 and not get_tree().paused and restarted.get_node("CardPlacement/Shop").coins == restarted.level.starting_gold and restarted.get_node("CardPlacement").cards.size() == 3 and restarted.get_node("TowerMap").towers.is_empty() and restarted.get_node("TowerMap").relics.held.is_empty()
		if not restart_verified: failures.append("Real result restart failed to reset state")
		await snapshot("restarted")
		get_tree().current_scene = self
		restarted.queue_free()
		FileAccess.open(output+"/rendered.json",FileAccess.WRITE).store_string(JSON.stringify({"choice_clicks":choice_clicks,"restart_verified":restart_verified,"renderer":RenderingServer.get_current_rendering_method(),"failures":failures},"\t"))
	else: scene.queue_free()
	await get_tree().process_frame
	for definition: TowerDefinition in prices: definition.card_price = prices[definition]
	for growth: TowerGrowth in growths:
		growth.damage = growths[growth][0]
		growth.friendly_damage = growths[growth][1]
	for troop: Troop in healths:
		troop.max_health = healths[troop][0]
		var heal: HealAbility = troop.find_ability(HealAbility)
		var sabotage: SabotageAbility = troop.find_ability(SabotageAbility)
		if heal: heal.amount = healths[troop][1]
		if sabotage: sabotage.duration = healths[troop][2]
	print("POLICY_DONE ",id," ",result.outcome," wave=",result.completed_waves," leaks=",result.total_leaks)
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(event,true)
	await get_tree().process_frame
func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+label+".png")
func prepare(scene: Node, agent: RefCounted) -> void:
	var cards: Node = scene.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	await place_inventory(scene,agent)
	var rerolls := 0
	if reroll_first and shop.available and shop.coins >= maxi(0,shop.reroll_price):
		shop.open_shop()
		if shop.reroll(): rerolls += 1
		shop.close_shop()
		await get_tree().process_frame
	for attempt in 8:
		if not shop.available: break
		shop.open_shop()
		agent.refresh()
		var ranked: Array[int] = []
		for i in shop.offers.size():
			if shop.offers[i] != null and shop.sold[i] == 0 and shop.prices[i] <= shop.coins: ranked.append(i)
		ranked.sort_custom(func(a,b): return agent.preference(shop.offers[a]) > agent.preference(shop.offers[b]))
		var bought := false
		for i in ranked:
			if agent.preference(shop.offers[i]) < 0: continue
			# Placement authority is locked while shop is open; inspect after closing.
			shop.close_shop()
			var spot: Dictionary = agent.best(shop.offers[i])
			shop.open_shop()
			if spot.is_empty(): continue
			if shop.buy(i):
				bought = true
				break
		shop.close_shop()
		if bought:
			await place_inventory(scene,agent)
		elif rerolls < 1 and shop.coins >= 10:
			shop.open_shop()
			if shop.reroll(): rerolls += 1
			shop.close_shop()
			await get_tree().process_frame
		else: break
	shop.close_shop()
func place_inventory(scene: Node, agent: RefCounted) -> void:
	var cards: Node = scene.get_node("CardPlacement")
	for pass_index in 3:
		var placed := false
		for i in range(cards.cards.size()-1,-1,-1):
			agent.refresh()
			var spot: Dictionary = agent.best(cards.cards[i])
			if spot.is_empty(): continue
			cards.select_card(i,false)
			cards.turns = spot.turns
			if cards.place_selected(spot.at) != null:
				placed = true
				for frame in 2: await get_tree().process_frame
		if not placed: break
