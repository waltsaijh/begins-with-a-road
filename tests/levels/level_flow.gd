extends Node
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func recipe(profile: Troop, count: int, reward: int) -> WaveDefinition:
	var result := WaveDefinition.new()
	var group := WaveSpawnGroup.new()
	group.troop = profile
	group.enemy_count = count
	group.interval_ticks = 0
	result.groups = [group]
	result.reward = reward
	return result

func wait_map(scene: Node) -> void:
	for i in 120:
		var map: Node = scene.get_node("PortalMap")
		if not map.computing and map.plan.get("reachable", false): return
		await get_tree().process_frame
	check(false, "Level navigation failed to become ready")

func verify() -> void:
	var authored: LevelDefinition = load("res://assets/data/levels/frontier.tres")
	check(authored.configuration_error().is_empty() and authored.wave_count() == 9, "Authored level did not load its ACTs/waves")
	var level := LevelDefinition.new()
	# Fixed-map progression is covered here; ACT expansion has its own integration test.
	level.expand_starts_after_act = false
	# A fixed bridge fixture keeps level flow independent of the designer's map edits.
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-12, 0, -0.5)
	for x in 24: terrain.set_cell_item(Vector3i(x, 0, 0), 3)
	level.terrain = PackedScene.new()
	level.terrain.pack(terrain)
	terrain.free()
	var act1 := ActDefinition.new()
	act1.title = "ACT I"
	act1.waves = [recipe((TroopCatalog.find("soldier").duplicate() as Troop), 3, 3), recipe((TroopCatalog.find("quickfeet").duplicate() as Troop), 2, 7)]
	var act2 := ActDefinition.new()
	act2.title = "ACT II"
	act2.waves = [recipe((TroopCatalog.find("heavy").duplicate() as Troop), 2, 11)]
	level.acts = [act1, act2]
	var scene: Node3D = load("res://scenes/level.tscn").instantiate()
	scene.level = level
	scene.get_node("TileMap").clear()
	get_tree().root.add_child(scene)
	await wait_map(scene)
	var wave: Node = scene.get_node("EnemyWave")
	var cards: Node = scene.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	var placement: Node = scene.get_node("TilePlacement")
	wave.set_process(false)
	scene.get_node("TowerMap").combat.enabled = false
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	var completed := [0]
	scene.level_finished.connect(func(): completed[0] += 1)
	check(scene.get_node("TileMap").get_used_cells().size() == 24, "Level did not restore its authored terrain")
	check(not wave.active and wave.enemy_count == 3 and scene.current_wave == 0, "Level did not prepare the first wave without auto-starting")
	check(scene.timeline.mouse_filter == Control.MOUSE_FILTER_IGNORE and scene.timeline.wave_index == 0, "Timeline blocks input or starts at the wrong position")
	var viewport_width := get_viewport().get_visible_rect().size.x
	check(is_equal_approx(scene.timeline.size.x, viewport_width*0.5) and is_equal_approx(scene.timeline.position.x+scene.timeline.size.x*0.5, viewport_width*0.5), "Timeline is not half-width and horizontally centered")
	check(scene.find_children("*", "OptionButton", true, false).is_empty(), "Removed troop/distribution dropdowns remain")
	check(wave.controls.spawn_button.get_parent() == scene.get_node("LevelHUD/WorldActions") and shop.view.get_node_or_null("Root/Balance") == null, "Start button did not move to its world anchor or wallet remained in shop")
	check(is_equal_approx(scene.timeline.node_fraction(0), 1.0/3.0) and is_equal_approx(scene.timeline.node_fraction(2), 1.0), "Wave markers include an extra interval before the level end")
	check(not scene.timeline.is_act_end(0) and scene.timeline.is_act_end(1) and scene.timeline.is_act_end(2), "ACT-ending waves did not replace circle markers with dividers")
	var expected_rewards := [3, 10, 21]
	for index in 3:
		await wait_map(scene)
		scene.set_process(false)
		cards.select_card(1)
		cards.hand._set_hover(1)
		cards.preview.visible = true
		var coins_before: int = shop.coins
		var waiting_position: float = scene.timeline.position_fraction()
		scene._process(3600.0)
		check(not wave.active and not scene._wave_starting and not scene.is_processing(), "Waiting started a wave without player confirmation")
		check(is_zero_approx(scene.timeline.progress) and is_equal_approx(scene.timeline.position_fraction(), waiting_position), "Waiting advanced the timeline")
		check(wave.controls.spawn_button.get_node_or_null("Shape/Countdown") == null and shop.coins == coins_before, "Countdown border or waiting reward remains")
		if index > 0:
			shop.open_shop()
			check(shop.view.opened and scene.get_node("LevelHUD")._callout_available, "Open shop disabled the start callout")
		wave.controls.spawn_button.pressed.emit()
		scene.set_process(false)
		check(shop.coins == coins_before, "Manual start granted a removed early-start reward")
		check(not scene.get_node("LevelHUD")._callout_available and wave.controls.spawn_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Retracting callout still accepts input")
		check(not wave.active and wave._pending.is_empty() and wave.controls.spawn_button.disabled, "Manual start bypassed the opening transition")
		check(cards.selected == -1 and cards.input_suspended and cards.hand.stowed and not cards.preview.visible, "Manual start did not immediately cancel placement and stow the hand")
		check(not shop.available and not shop.view.available and not shop.view.opened, "Manual start left the shop available")
		shop.open_shop()
		cards.set_shop_open(false)
		cards.select_card(0)
		check(not shop.view.opened and cards.selected == -1 and cards.hand.stowed, "Pending start allowed the shop or hand to reopen")
		cards.hand.finish_animation()
		shop.view.finish_animation()
		for view: Control in cards.hand.views:
			check((view.get_global_transform()*Vector2.ZERO).y >= get_viewport().get_visible_rect().size.y, "Hand did not retract during the opening transition")
		check(is_zero_approx(scene.timeline.progress), "Manual start jumped the timeline")
		wave._update_button()
		check(wave.controls.spawn_button.disabled, "Navigation refresh re-enabled a pending start")
		for expected: float in [0.125, 0.5, 0.875, 1.0]:
			wave.controls.spawn_button.pressed.emit()
			scene._process(0.25)
			check(not wave.active and wave._pending.is_empty() and is_equal_approx(scene.timeline.progress, expected), "Opening timeline did not follow one-second ease-in-out")
		var held_cutoff: float = scene.timeline.fill_cutoff()
		wave.controls.spawn_button.pressed.emit()
		scene._process(0.375)
		check(not wave.active and is_equal_approx(scene.timeline.fill_cutoff(), held_cutoff), "Wave attacked or moved the timeline during the half-second hold")
		check(cards.hand.stowed and cards.input_suspended and wave.controls.spawn_button.disabled and shop.coins == coins_before, "Repeated start released input or granted coins")
		scene._process(0.125)
		check(wave.active and not shop.view.opened, "Manual start did not begin the scheduled wave")
		var node_position: float = scene.timeline.node_fraction(index)
		check(is_equal_approx(scene.timeline.position_fraction(), node_position), "Wave start did not snap the timeline onto its node")
		check(scene.timeline.fill_cutoff() > scene.timeline.size.x*node_position, "Wave start left its marker partially unfilled")
		check(cards.selected == -1 and cards.input_suspended and cards.hand.stowed and cards.hand._hovered == -1, "Starting wave did not cancel selection/hover and stow hand")
		check(not cards.preview.visible and not placement.is_processing_unhandled_input() and not scene.get_node("TowerMap").input_enabled, "Placement hover/tools remained active during wave")
		cards.set_shop_open(false)
		check(cards.input_suspended, "Closing shop accidentally unlocked construction during combat")
		cards.select_card(0)
		check(cards.selected == -1, "A hidden card could be selected during wave")
		cards.hand.finish_animation()
		for view: Control in cards.hand.views:
			check((view.get_global_transform()*Vector2.ZERO).y >= get_viewport().get_visible_rect().size.y and view.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Stowed hand remains visible/clickable")
		while not wave._pending.is_empty(): wave._process(0)
		var enemies: Array[Node3D] = wave.living_enemies()
		var held_fill: float = scene.timeline.fill_cutoff()
		enemies[0].take_damage(100000)
		scene._process(120.0)
		check(is_equal_approx(scene.timeline.position_fraction(), node_position) and scene.current_wave == index, "Timeline moved before the active wave finished")
		for i in range(1, enemies.size()): enemies[i]._process(10000)
		if scene.choosing_relic:
			check(cards.input_suspended and not wave.start_allowed, "Relic choice must lock preparation")
			var choice: RelicDefinition = scene.relic_choice.offers.filter(func(r): return r.id != &"gold")[0]
			scene.relic_choice.choose(choice)
			await get_tree().create_timer(0.3).timeout
		check(not wave.active and not cards.hand.stowed and not cards.input_suspended, "Wave end did not restore the hand/build phase")
		check(shop.coins == expected_rewards[index], "Wave completion reward used the wrong value or was duplicated")
		check(scene.get_node("LevelHUD/Header/Balance/Amount").text == str(shop.coins), "Top wallet did not update after a wave reward")
		check(scene.current_wave == index+1 and scene.timeline.wave_index == index+1, "Timeline did not advance across the ACT boundary")
		if index < 2:
			check(is_zero_approx(scene.timeline.progress) and is_equal_approx(scene.timeline.position_fraction(), node_position), "New preparation moved away from the finished node")
			check(is_equal_approx(scene.timeline.fill_cutoff(), held_fill), "New preparation moved the fill away from its completed marker")
		await get_tree().process_frame
	check(scene.finished and completed[0] == 1 and wave.controls.spawn_button.disabled and not wave.start_wave(), "Completed level allowed extra waves or repeated completion")
	for control: Control in scene.find_children("*", "Control", true, false):
		check(control.tooltip_text.is_empty(), "Gameplay UI still has a hover tooltip")
	shop.open_shop()
	shop.view.finish_animation()
	check(shop.buy(0), "Wallet purchase check failed")
	check(scene.get_node("LevelHUD/Header/Balance/Amount").text == str(shop.coins), "Top wallet did not update after purchase")
	shop.view.finish_animation()
	check(shop.reroll(), "Wallet reroll check failed")
	check(scene.get_node("LevelHUD/Header/Balance/Amount").text == str(shop.coins), "Top wallet did not update after reroll")
	scene.queue_free()
	await get_tree().process_frame
	# Multiple authored starts must be retained in the shared portal graph.
	level.starts = [Vector2i.ZERO, Vector2i(5, 0)]
	level.use_terrain_endpoints = false
	act1.waves = [recipe((TroopCatalog.find("soldier").duplicate() as Troop), 1, 1)]
	act1.waves[0].groups[0].start_index = 1
	level.acts = [act1]
	scene = load("res://scenes/level.tscn").instantiate()
	scene.level = level
	get_tree().root.add_child(scene)
	await wait_map(scene)
	wave = scene.get_node("EnemyWave")
	wave.set_process(false)
	check(scene.get_node("PortalMap").start_nodes.size() == 2, "Level did not retain its second start")
	scene.set_process(false)
	# Even very long preparation requires a click; slow opening frames still preserve the hold.
	scene._process(100000.0)
	check(not scene._wave_starting and not wave.active, "Long preparation triggered an automatic attack")
	scene._on_start_requested()
	scene.set_process(false)
	scene._process(1.25)
	check(scene._wave_starting and is_equal_approx(scene._wave_start_elapsed, 1.25) and not wave.active, "Slow opening frame skipped the remaining hold")
	scene._process(0.25)
	check(wave.active, "Manual start did not finish after its remaining delay")
	check(wave._pending[0].route.cells[0] == Vector2(5, 0), "Wave did not use its authored start")
	scene.queue_free()
	await get_tree().process_frame
	print("LEVEL_FLOW_CHECK:"+JSON.stringify({"failures": failures, "authored_terrain": true, "acts": true, "timeline": true, "every_wave_start_delay_1_5_seconds": true, "manual_start_ease_in_out_1_second_hold_0_5_seconds": true, "indefinite_preparation": true, "no_start_bonus": true, "stowed_hand": true, "cancelled_hover": true, "rewards": true, "finite_waves": true, "multiple_starts": true}))
	get_tree().quit(1 if failures else 0)
