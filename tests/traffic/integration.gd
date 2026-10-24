extends Node
const Fixture = preload("res://tests/traffic/fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []
var checks := 0
var level: Node3D
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void: run.call_deferred()
func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame
func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("traffic/"+name+".png"))
func run() -> void:
	level = Fixture.session()
	add_child(level)
	await frames(12)
	var controller: Node = level.get_node("PortalMap")
	var cards: Node = level.get_node("CardPlacement")
	var towers: Node = level.get_node("TowerMap")
	var traffic: TrafficStructures = towers.traffic
	var flow: Node = level.get_node("WaveFlowPreview")
	var wave: Node = level.get_node("EnemyWave")
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	var map: GridMap = controller.map
	var original_cells := map.get_used_cells()
	var original_items := {}
	for cell in original_cells: original_items[cell] = [map.get_cell_item(cell),map.get_cell_item_orientation(cell)]
	var flag: BuildCard = cards.cards[0]
	var barricade: BuildCard = cards.cards[1]
	var narrow: BuildCard = cards.cards[2]
	check(flag.configuration_error().is_empty() and barricade.configuration_error().is_empty() and narrow.configuration_error().is_empty(),"all card definitions valid")
	check(not towers.validate_card(flag,Vector3i(1,0,0)).is_empty(),"flag rejects road")
	check(not towers.validate_card(barricade,Vector3i(1,0,1)).is_empty(),"overlay rejects empty")
	check(not towers.validate_card(narrow,Vector3i(0,0,0)).is_empty(),"overlay rejects endpoint")
	check(towers.validate_card(flag,Vector3i(2,0,1)).is_empty(),"flag near road")
	var prior_rng := 8723
	seed(prior_rng)
	var expected := randi()
	seed(prior_rng)
	var baseline: RoadFlowForecast = flow.forecast
	var preview_effect := barricade.traffic.effect_at(Vector2i(2,0),0)
	cards.preview_traffic_at(barricade,Vector3i(2,0,0),0,true)
	await frames()
	var predicted: RoadFlowForecast = flow.forecast
	check(randi() == expected,"preview preserves formal RNG")
	check(predicted.counts_by_origin == baseline.counts_by_origin,"preview preserves each origin/troop count")
	check(predicted.all != baseline.all,"candidate changes actual quota flow")
	check(not flow.delta_overlay.markers.is_empty(),"actual changed junctions have markers")
	check(traffic.instances.is_empty() and controller.traffic_effects.is_empty(),"preview does not commit any state")
	check(flow.arrows.phase_data == predicted.animation().lookup_texture(),"candidate renderer uses candidate complete-trip clocks")
	var rebuilds: int = flow.candidate_rebuild_count
	for i in 10: cards.preview_traffic_at(barricade,Vector3i(2,0,0),0,true)
	await frames()
	check(flow.candidate_rebuild_count == rebuilds,"unchanged candidate cached")
	await screenshot("candidate")
	var profile: Troop = wave.definition.groups[0].troop
	flow.panel.selected = profile
	flow._filter(profile,0)
	check(flow.arrows.phase_data == predicted.animation(profile,0).lookup_texture(),"candidate clocks follow troop and entrance filtering")
	cards.set_traffic_candidate({})
	check(flow.forecast.all == baseline.all and flow.delta_overlay.markers.is_empty(),"cancel restores baseline immediately")
	check(flow.arrows.phase_data == baseline.animation(profile,0).lookup_texture(),"cancel restores filtered baseline clocks immediately")
	flow.panel.selected = null
	flow._filter(null,0)
	check(flow.arrows.phase_data == baseline.animation().lookup_texture(),"leaving filter restores all baseline clocks")
	check(flow.candidate_rebuild_count == rebuilds,"clock filtering does not rebuild the candidate schedule")
	var saved_threshold: float = profile.score_threshold
	profile.score_threshold = 1.0
	await frames()
	var base_plan: Dictionary = controller.plan_for(profile,0,[])
	var flag_effect := flag.traffic.effect_at(Vector2i(2,1),0)
	var weighted_plan: Dictionary = controller.plan_for(profile,0,[flag_effect])
	check(base_plan.routes == weighted_plan.routes and base_plan.score == weighted_plan.score,"strict threshold and raw score unchanged by modifiers")
	profile.score_threshold = saved_threshold
	await frames()
	var zero_effect := {"tags":[],"cells":{Vector2i(10,2):true},"multiplier":0.0}
	cards.set_traffic_candidate(zero_effect)
	await frames()
	check(flow.forecast.all == flow.baseline.all and flow.delta_overlay.markers.is_empty() and flow._candidate_unavailable,"invalid zero-mass preview does not invent missing enemies")
	cards.set_traffic_candidate({})
	await frames()
	var placed: TrafficStructure = towers.place_card(barricade,Vector3i(2,0,0))
	check(placed != null and placed.remaining_waves == 3,"placement does not spend lifetime")
	await frames()
	check(flow.forecast.all == predicted.all,"committed forecast equals candidate forecast")
	check(not towers.validate_card(narrow,Vector3i(2,0,0)).is_empty(),"exclusive overlap denied")
	var flag_instance: TrafficStructure = towers.place_card(flag,Vector3i(2,0,1),1)
	var narrow_instance: TrafficStructure = towers.place_card(narrow,Vector3i(6,0,4),2)
	check(flag_instance != null and narrow_instance != null,"all structure kinds place")
	var flag_ground := flag_instance.get_node("Visual/Ground")
	var top := flag_ground.get_node("Tile/Top") as MeshInstance3D
	check(top.mesh.get_aabb().size.x == 1.0 and top.mesh.get_aabb().size.z == 1.0,"flag ground occupies exactly one tile")
	check(not level.get_node("TilePlacement").place_cell(Vector3i(2,0,1)),"direct road edit cannot overwrite flag")
	check(not preload("res://scripts/levels/expansion/spawn_expansion_planner.gd").valid(controller,Vector2i(2,1),[Vector2i(2,1)]),"ACT extension cannot overwrite flag")
	# Existing tower API must protect both overlay and flag cells.
	var tower_definition: TowerDefinition = load("res://assets/data/towers/sentry.tres")
	var tower_card := BuildCard.from_parts(tower_definition,tower_definition.first_tile_preset())
	check(not towers.validate_card(tower_card,Vector3i(2,0,0)).is_empty(),"tower cannot overwrite overlay")
	check(not towers.validate_card(tower_card,Vector3i(2,0,1)).is_empty(),"tower cannot overwrite flag")
	var barracks: TowerDefinition = load("res://assets/data/towers/barracks.tres")
	check(not towers._validate_deployment(barracks,Vector2i(2,1),0).is_empty(),"barracks cannot deploy onto overlay")
	# An already existing barracks reservation prevents overlays.
	var dummy := DefenseTower.new()
	dummy.definition = barracks
	dummy.grid_cell = Vector2i(3,1)
	towers.towers[Vector2i(3,1)] = dummy
	check(not towers.validate_card(barricade,Vector3i(3,0,0)).is_empty(),"overlay cannot occupy existing soldier home")
	towers.towers.erase(Vector2i(3,1))
	dummy.free()
	await frames()
	var schedule := WaveSpawnSchedule.build(wave.definition,controller,wave._next_enemy_id,false,wave.additional_start_indices)
	var forecast := RoadFlowForecast.from_pending(schedule.pending)
	check(forecast.all == flow.forecast.all,"preview uses actual schedule")
	var quick: Troop = wave.definition.groups[1].troop
	flow.panel.selected = quick
	flow._filter(quick,0)
	check(flow.selected_origin == 0,"troop hover origin maintained")
	flow.panel.selected = null
	flow._filter(null,0)
	# Snapshot routes first, then remove a structure during combat.
	check(wave.start_wave(),"wave starts with weighted schedule")
	var frozen: Array = wave._pending.duplicate(true)
	check(RoadFlowForecast.from_pending(frozen).all == forecast.all,"formal shuffled quotas equal preview")
	traffic.remove(flag_instance)
	check(wave._pending == frozen,"removal never rewrites committed wave")
	await frames()
	check(not is_instance_valid(flag_ground),"flag removal also removes its supporting ground")
	check(towers.place_card(flag,Vector3i(5,0,1)) == null,"combat placement denied")
	check(placed.remaining_waves == 3,"no lifetime loss during combat")
	for round_index in 3:
		if round_index > 0: check(wave.start_wave(),"next weighted wave starts")
		wave._process(10000.0)
		for enemy: Node3D in wave.living_enemies(): enemy._process(10000.0)
		if level.choosing_relic:
			level.relic_choice.choose(level.relic_choice.offers[0])
			await get_tree().create_timer(0.3).timeout
		await frames(6)
		if round_index < 2: check(is_instance_valid(placed) and placed.remaining_waves == 2-round_index,"one decrement per complete wave")
	check(not is_instance_valid(placed) and not is_instance_valid(narrow_instance),"expires after exactly third wave")
	check(traffic.instances.is_empty() and traffic.occupied.is_empty() and controller.traffic_effects.is_empty(),"expiry clears indexes and modifiers")
	check(flow.forecast.all == baseline.all,"expiry refreshes next wave flow across ACT")
	check(map.get_used_cells().size() == original_cells.size(),"no road creation/removal")
	for cell in original_cells: check(original_items[cell] == [map.get_cell_item(cell),map.get_cell_item_orientation(cell)],"road tile and orientation unchanged")
	# Early external deletion also unregisters the effect.
	var early: TrafficStructure = towers.place_card(flag,Vector3i(2,0,1))
	early.queue_free()
	await frames()
	check(traffic.instances.is_empty() and controller.traffic_effects.is_empty(),"external deletion unregisters")
	# Two independent pools, purchases and shared card-back reroll.
	var shop: Node = cards.get_node("Shop")
	shop.coins = 100
	shop.available = shop._deal()
	shop._refresh()
	shop.view.set_available(true)
	shop.open_shop()
	shop.view.finish_animation()
	check(shop.offers.size() == 6 and shop.view.slots.size() == 7,"four plus two plus original reroll card")
	for i in 6: check((shop.offers[i].tower != null) == (i < 4),"pool separation")
	check(shop.view.slots[1].position.y < shop.view.slots[5].position.y,"two distinct rows")
	check(shop.view.slots[0].position.x > shop.view.slots[6].position.x,"reroll at bottom right")
	var before_cards: Array = shop.offers.duplicate()
	var coins: int = shop.coins
	var reroll_price: int = shop.reroll_price
	check(shop.reroll(),"shared reroll succeeds")
	check(shop.coins == coins-reroll_price,"single reroll fee")
	for i in 6: check(shop.offers[i] != before_cards[i],"both pools re-dealt")
	check(shop.view.rerolling and not shop.reroll(),"original animation blocks duplicate reroll")
	shop.view._stop_reroll_animation()
	shop.view.finish_animation()
	await screenshot("shop")
	var purchased: BuildCard = shop.offers[4]
	coins = shop.coins
	check(shop.buy(4) and not shop.buy(4),"support purchase exactly once")
	check(cards.cards[-1] == purchased and shop.coins == coins-purchased.price,"support price snapshot and shared inventory")
	var saved_towers: Array = shop.catalog.duplicate()
	var saved_support: Array = shop.traffic_catalog.duplicate()
	shop.catalog.clear()
	shop.traffic_catalog.clear()
	shop.view.finish_animation()
	coins = shop.coins
	check(not shop.reroll() and shop.coins == coins,"all-invalid pools do not charge")
	shop.catalog.assign(saved_towers)
	shop.traffic_catalog.assign(saved_support)
	shop.close_shop()
	# Delta filtering counts real integer edge visits, never raw probability.
	var edge := Vector4i(4,0,5,0)
	check(TrafficFlowDelta.compare({edge:5},{edge:5},{Vector2i(4,0):true}).is_empty(),"no fake unchanged marker")
	check(TrafficFlowDelta.compare({edge:5},{edge:6},{Vector2i(4,0):true},2).is_empty(),"minimum quota delta")
	check(TrafficFlowDelta.compare({edge:5},{edge:9},{}).is_empty(),"no marker on ordinary road")
	# Last wave and unload safely clean up structures without touching roads.
	var last_structure: TrafficStructure = towers.place_card(narrow,Vector3i(6,0,4))
	check(last_structure != null,"structure can participate in final wave")
	check(wave.start_wave(),"last wave starts")
	wave._process(10000.0)
	for enemy: Node3D in wave.living_enemies(): enemy._process(10000.0)
	await frames()
	if level.choosing_relic:
		level.relic_choice.choose(level.relic_choice.offers[0])
		await get_tree().create_timer(0.3).timeout
	check(level.finished and not flow.arrows.visible,"last wave stops preview")
	check(last_structure.remaining_waves == 2,"final wave decrements even without a following wave")
	level.queue_free()
	await frames()
	var result := {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name() != "headless"}
	FileAccess.open(Artifacts.path("traffic/integration.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PHASE2_INTEGRATION:",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
