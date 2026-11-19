extends Node
const Fixture = preload("res://tests/fixtures/level_fixture.gd")
const Road = preload("res://scripts/events/event_road_builder.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
var failures: Array[String] = []
var checks := 0
var host: Node3D
var manager: SpecialEventManager
var towers: Node3D
var cards: Node3D
var shop: Node

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	run.call_deferred()

static func definition() -> LevelDefinition:
	var result := Fixture.level("")
	result.base_health = 100
	result.starting_gold = 200
	result.opening_shop = true
	var map := result.terrain.instantiate() as GridMap
	for x in range(8,17): map.set_cell_item(Vector3i(x,0,0),3)
	map.get_node("Goal").position = map.map_to_local(Vector3i(16,0,0))+Vector3.UP*0.0305
	Fixture.endpoint(map,Fixture.Start,Vector2i(2,0),"Start2")
	result.terrain = PackedScene.new()
	result.terrain.pack(map)
	map.free()
	result.acts.clear()
	for act_index in 5:
		var act := ActDefinition.new()
		act.title = "ACT %d" % (act_index+1)
		act.add_start_after_completion = false
		for i in 3:
			var wave := WaveDefinition.new()
			var group := WaveSpawnGroup.new()
			group.troop = TroopCatalog.find("soldier")
			group.enemy_count = 1
			wave.groups = [group]
			act.waves.append(wave)
		result.acts.append(act)
	return result

func wait_graph() -> void:
	for i in 120:
		await get_tree().process_frame
		if not host.get_node("PortalMap").computing: return
	check(false,"Road graph settles")

func begin(index: int) -> bool:
	host.choosing_event = true
	host._wave.start_allowed = false
	cards.set_entry_selection(true)
	return manager.begin(manager.catalog[index-1])

func resolve(index: int,option: int,target: DefenseTower = null) -> void:
	check(begin(index),"Event %d can open" % index)
	check(manager.choose(option),"Event %d option %d executes" % [index,option])
	if target != null: check(manager.select_target(target),"Target completes event")
	check(manager.active == null and not host.choosing_event and not cards.entry_selection_active,"Event unlocks normal preparation")
	check(not manager.choose(option),"Resolved event cannot execute twice")

func special_index(id: String) -> int:
	for i in cards.cards.size():
		if cards.cards[i].special != null and cards.cards[i].special.id == StringName(id): return i
	return -1

func place(id: String,at: Vector3i,turns := 0) -> Node3D:
	var index := special_index(id)
	check(index >= 0,"Special card is present: "+id)
	cards.select_card(index,false)
	cards.turns = turns
	return cards.place_selected(at)

func build(at: Vector3i) -> DefenseTower:
	var definition: TowerDefinition = load("res://assets/data/towers/sentry.tres")
	var preset := TilePreset.new()
	preset.road_offsets = [Vector2i.ZERO]
	var card := BuildCard.from_parts(definition,preset)
	return towers.place_card(card,at) as DefenseTower

func run() -> void:
	host = load("res://scenes/level.tscn").instantiate()
	host.level = definition()
	add_child(host)
	await wait_graph()
	manager = host.special_events
	towers = host.get_node("TowerMap")
	cards = host.get_node("CardPlacement")
	shop = cards.get_node("Shop")
	check(manager.catalog.size() == 9,"Nine event resources")
	for language in ["zh_TW","en"]:
		TranslationServer.set_locale(language)
		for event in manager.catalog:
			for suffix in ["title","description","a.name","a.effect","b.name","b.effect"]:
				var value := event.text(suffix)
				check(not value.begins_with("event.") and not "{" in value,"Bilingual formatted text: "+str(event.id)+suffix)
	TranslationServer.set_locale("zh_TW")
	check(SpecialEventManager.due(5,15) and SpecialEventManager.due(10,15) and not SpecialEventManager.due(15,15) and SpecialEventManager.due(20,25),"Every fifth non-final wave")
	check(host.timeline.special_indices() == PackedInt32Array([4,9]),"Timeline has two special icons")
	var a := build(Vector3i(5,0,3))
	var b := build(Vector3i(9,0,3))
	var c := build(Vector3i(13,0,3))
	check(a != null and b != null and c != null,"Three real towers built")
	await wait_graph()
	resolve(2,0)
	check(a.level == 2 and b.level == 2 and c.level == 2,"Supply upgrades distinct eligible towers")
	var before: int = shop.coins
	resolve(7,1)
	check(shop.coins == before+20 and a.level+b.level+c.level == 5,"Strike rejection downgrades exactly one tower")
	before = shop.coins
	resolve(7,0)
	check(shop.coins == before-80 and a.level+b.level+c.level == 7,"Salary upgrades two towers and charges once")
	shop.coins = 0
	check(not manager.option_error(manager.catalog[2],0).is_empty() and not manager.option_error(manager.catalog[4],0).is_empty(),"Insufficient funds disable paid options")
	check(begin(3) and manager.choice.buttons[0].disabled and not manager.choice.buttons[1].disabled,"UI disables only the unaffordable option")
	check(not manager.choose(0) and manager.choose(1),"Unaffordable merchant still forces a valid choice")
	check(host._wave.definition.total_count() == 13,"Cheese adds editable 12 rats")
	shop.grant_gold(300,"test")
	resolve(3,0)
	a.level = 3; a.refresh_stats()
	var count: int = cards.cards.size()
	check(place("potion",Vector3i(a.grid_cell.x,0,a.grid_cell.y)) == a and a.level == 4 and cards.cards.size() == count-1,"Potion consumes card and breaks cap exactly once")
	check(not a.upgrade() and not a.unlimited_levels,"Potion preserves normal upgrade limit")
	resolve(4,0,b)
	check(b.event_ceasefire and b.is_disabled(),"Chosen tower truly ceases fire")
	manager._on_wave_finished()
	check(not b.event_ceasefire and not b.is_disabled(),"Ceasefire recovers after next wave")
	check(begin(4),"Target UI opens")
	manager.choice.buttons[0].pressed.emit()
	check(host.unit_inspection._blocked() and not manager.choice.markers.is_empty(),"Target selection blocks inspection and highlights eligible towers")
	var camera: Camera3D = host.get_node("Camera3D")
	camera.focus = a.global_position
	camera.update_pose()
	var click := InputEventMouseButton.new()
	click.position = camera.unproject_position(a.global_position+Vector3.UP*0.5)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	manager.choice._unhandled_input(click)
	check(manager.active == null and a.event_ceasefire,"World target click resolves the chosen tower")
	manager._on_wave_finished()
	resolve(4,1)
	resolve(1,1)
	var recipe: WaveDefinition = host._wave.definition
	var original_count: int = host._waves[0].total_count()
	check(recipe.total_count() == original_count+12+10+20,"Per-entrance reinforcements append full quantities")
	host._wave.additional_start_indices = PackedInt32Array([1])
	var actual_origins := WaveSpawnSchedule._assigned_origins(recipe,host._wave.additional_start_indices)
	var original_origins := WaveSpawnSchedule._assigned_origins(host._waves[0],host._wave.additional_start_indices)
	check(actual_origins[0] == original_origins[0],"Fixed reinforcements preserve original groups' entrance allocation")
	await wait_graph()
	var schedule := WaveSpawnSchedule.build(recipe,host.get_node("PortalMap"),0,false,host._wave.additional_start_indices)
	var per_start := {}
	for entry: Dictionary in schedule.get("pending",[]):
		if entry.profile == TroopCatalog.find("scout"): per_start[entry.start_index] = int(per_start.get(entry.start_index,0))+1
	check(per_start.get(0,0) == 10 and per_start.get(1,0) == 10,"Native route schedule contains 10 scouts at EACH entrance")
	check(host._waves[0].total_count() == original_count,"Original resource is never polluted")
	manager._on_wave_started()
	check(manager.effective_wave(host._waves[0]).total_count() == original_count,"Reinforcements expire after successful start")
	resolve(1,0)
	await wait_graph()
	var controller: Node = host.get_node("PortalMap")
	check(Snapshot.connects_terminals(Snapshot.capture(towers.map,towers.blocked_occupancy()),controller.terminal_cells()),"Generated road preserves all terminal connections")
	var batch: Dictionary = controller.prepare_route_batch(TroopCatalog.find("soldier"),40,0)
	check(not batch.is_empty(),"Enemies can use committed native road graph")
	var distinct := {}
	for route: Dictionary in batch.get("routes",[]): distinct[route.cells] = true
	check(distinct.size() > 1,"Generated road is a genuine alternative in native distribution")
	check(Road.propose(towers,8,1).is_empty(),"Bounded unavailable road has no side effects")
	resolve(5,0)
	var used: int = towers.map.get_used_cells().size()
	check(place("road",Vector3i(6,0,-5),1) != null and towers.map.get_used_cells().size() >= used+4,"Rotated 1x4 road places using hand")
	resolve(5,1)
	var baseline: float = a.damage
	manager._on_wave_started()
	check(is_equal_approx(a.damage,baseline*0.9),"Unplaced rubble imposes next-wave penalty")
	check(place("rubble",Vector3i(3,0,6)) != null,"First rubble freely places")
	check(is_equal_approx(a.damage,baseline*0.9),"Partial placement retains penalty")
	check(place("rubble",Vector3i(4,0,6)) != null,"Second rubble places")
	manager._on_wave_started()
	check(is_equal_approx(a.damage,baseline),"Completed rubble removes later-wave penalty")
	resolve(9,0)
	check(is_equal_approx(a.damage,baseline),"Gem does not grant bonus in hand")
	check(place("large_gem",Vector3i(7,0,7),1) != null and towers.special_occupied.size() == 6,"Rotated 2x2 gem occupies four real cells")
	check(is_equal_approx(a.damage,baseline*1.1),"Placed large gem refreshes actual damage")
	manager.refresh_towers(); towers.relics.refresh_towers()
	check(is_equal_approx(a.damage,baseline*1.1),"Repeated stat refresh never compounds event multiplier")
	resolve(9,1)
	for i in 3:
		check(place("small_gem",Vector3i(12+i,0,7)) != null,"Small gem places")
		check(manager.wave_gold_bonus == (5 if i == 2 else 0),"Small gems activate only at full completion")
	check(shop.wave_reward == host._waves[0].reward+5,"Gem reward uses normal wave reward path")
	var health: int = host.base_health
	var held: int = towers.relics.held.size()
	resolve(6,0)
	check(host.base_health == health-5 and towers.relics.held.size() == held+1,"Blood pays real health and grants real relic")
	host.base_health = 5
	check(not manager.option_error(manager.catalog[5],0).is_empty(),"Altar cannot kill base")
	host.base_health = health
	resolve(6,1)
	check(host._wave.definition.total_count() == original_count+6,"Altar appends six winged beasts")
	resolve(8,0)
	check(host._wave.definition.total_count() == original_count+6+5,"Payroll appends five heavy infantry")
	count = cards.cards.size()
	resolve(8,1)
	check(cards.cards.size() == count+1 and cards.cards[-1].tower != null,"Random normal tower recipe enters hand")
	var ground: int = towers.map.get_cell_item(Vector3i(c.grid_cell.x,0,c.grid_cell.y))
	var at := c.grid_cell
	resolve(2,1,c)
	check(not towers.occupied.has(at) and towers.map.get_cell_item(Vector3i(at.x,0,at.y)) == ground,"Removal frees occupancy while keeping ground")
	await wait_graph()
	# Exercise UI button bindings, double click guard, card previews and overlap authority.
	check(begin(8),"UI choice opens")
	before = shop.coins
	manager.choice.buttons[0].pressed.emit()
	manager.choice.buttons[0].pressed.emit()
	check(shop.coins == before+60 and manager.active == null,"UI click pays exactly once, including duplicate input")
	for id in ["road","rubble","large_gem","small_gem","potion"]:
		manager._give_cards(id,1)
		var index := special_index(id)
		var card: BuildCard = cards.cards[index]
		cards.preview.show_at(towers.map,card,Vector3i(20,0,10),1,true)
		check(cards.preview.visible,"Special card world preview: "+id)
		if id != "potion":
			check(not towers.validate_card(card,Vector3i(3,0,6)).is_empty(),"Special card cannot overlap rubble: "+id)
	var same: BuildCard = BuildCard.from_parts(a.definition,a.definition.first_tile_preset())
	check(not towers.validate_card(same,Vector3i(3,0,6)).is_empty(),"Normal tower cannot overwrite permanent event tiles")
	# Prefer unused eligible events before allowing a new cycle.
	manager.seen.clear()
	var drawn := {}
	for i in 9:
		check(manager.begin(),"Random event pool remains executable")
		check(not drawn.has(manager.active.id),"Random draw avoids repeats")
		drawn[manager.active.id] = true
		manager.active = null
		manager.choice.dismiss()
	check(drawn.size() == 9 and manager.begin(),"All nine events precede a repeat cycle")
	manager.active = null; manager.choice.dismiss()
	# Drive the real completion transition at both event milestones and final wave.
	for completed in [5,10]:
		host.current_wave = completed-1
		host._finish_wave_transition()
		check(host.choosing_event and manager.active != null and not host._wave.start_allowed,"Real completion %d blocks for event" % completed)
		host._begin_wave_start()
		check(not host._wave_starting,"Event cannot be bypassed by internal wave-start API")
		var option := 0 if manager.option_error(manager.active,0).is_empty() else 1
		manager.choose(option)
		if manager._target_option >= 0: manager.select_target(a)
		check(not host.choosing_event and host._wave.start_allowed,"Event resumes correct next wave")
	# ACT, expansion and event at the same boundary serialize in that order.
	host.level.expansion_wave_interval = 5
	host.level.acts[0].waves.append(host.level.acts[1].waves.pop_back())
	host.level.acts[0].waves.append(host.level.acts[1].waves.pop_back())
	host.current_wave = 4; host._event_completed_at = -1
	host._finish_wave_transition()
	check(host.choosing_relic and not host.choosing_event and not host.choosing_start,"Relic opens before entrance and special event")
	host.relic_choice.choose(host.relic_choice.offers[0])
	await get_tree().create_timer(0.3).timeout
	await wait_graph()
	check(host.choosing_start and not host.choosing_event,"Player entrance placement waits before the event")
	var region: Dictionary = host.expansion.choices[0]
	var entrance: Vector2i = region.paths.keys()[0]
	check(host.expansion.commit(Vector3i(entrance.x,0,entrance.y)),"Entrance commits directly without a direction selector")
	await wait_graph()
	check(host.get_node("PortalMap").start_paths.size() == 3,"Player entrance commits before event")
	check(host.choosing_event and not host.choosing_relic and not host.choosing_start,"Special event follows entrance resolution")
	var option := 0 if manager.option_error(manager.active,0).is_empty() else 1
	manager.choose(option)
	if manager._target_option >= 0: manager.select_target(a)
	check(host._wave.start_allowed and not cards.input_suspended,"Serialized choices cannot permanently lock preparation")
	host.level.expansion_wave_interval = 0
	await wait_graph()
	host.current_wave = 1
	host._prepare_wave()
	before = shop.coins
	var reward: int = shop.wave_reward
	var kills: int = host.total_kills
	host._begin_wave_start()
	host._advance_wave_start(1.5)
	check(host._wave.active and manager.pending_reinforcements.is_empty(),"Real successful wave start consumes next-wave effects")
	host._wave.set_process(false)
	host._wave._process(1000)
	var population: int = host._wave.spawned
	check(population == host._wave.definition.total_count(),"All appended enemies actually spawn")
	for enemy in host._wave.living_enemies(): enemy.take_damage(10000000)
	check(host.total_kills == kills+population,"Reinforcements participate in real kill statistics")
	check(shop.coins == before+population+reward,"Normal wave reward includes small gem bonus once")
	before = shop.coins
	shop._on_wave_finished()
	check(shop.coins == before,"Duplicate completion cannot pay gem reward twice")
	host.current_wave = 14
	host._finish_wave_transition()
	check(host.finished and host.victory and not host.choosing_event,"Final fifteenth wave wins without event")
	print("SPECIAL_EVENTS_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	host.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
