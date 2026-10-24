extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited

const Planner = preload("res://scripts/levels/expansion/spawn_expansion_planner.gd")
var failures := 0
var _viewport: SubViewport

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func wait_map(scene: Node) -> void:
	for i in 120:
		if not scene.get_node("PortalMap").computing: return
		await frames(1)
	check(false, "Map rebuild never completed")

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_viewport.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_viewport.push_input(event, true)
	event.pressed = false
	_viewport.push_input(event, true)

func save_frame(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(path)

func finish_wave(scene: Node) -> void:
	scene.set_process(false)
	scene._begin_wave_start()
	scene.set_process(false)
	scene._advance_wave_start(1.5)
	var wave: Node = scene.get_node("EnemyWave")
	check(wave.active, "Wave could not start")
	wave._process(100)
	var origins := {}
	for enemy in wave.living_enemies(): origins[Vector2i(enemy.route.cells[0])] = true
	check(origins.size() == scene.get_node("PortalMap").start_nodes.size(), "Enemies did not actually spawn at every active entrance")
	for enemy in wave.living_enemies(): enemy.take_damage(1000000)
	scene.set_process(false)

func recipe(profile: Troop) -> WaveDefinition:
	var definition := WaveDefinition.new()
	var group := WaveSpawnGroup.new()
	group.troop = profile
	group.enemy_count = 8
	group.batch_size = 2
	group.interval_ticks = 3
	definition.groups = [group]
	return definition

func verify() -> void:
	TranslationServer.set_locale("zh_TW")
	_viewport = TestViewport.new()
	_viewport.size = Vector2i(1152, 648)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var level := LevelDefinition.new()
	var authored := load("res://scenes/maps/tile_map.tscn").instantiate() as GridMap
	var first := authored.get_node("Endpoints/Start") as TerrainEndpoint
	first.height_offset = 0.125
	level.terrain = PackedScene.new()
	level.terrain.pack(authored)
	authored.free()
	var profile := TroopCatalog.find("soldier").duplicate() as Troop
	for i in 4:
		var act := ActDefinition.new()
		act.title = "ACT %d" % (i+1)
		act.add_start_after_completion = i != 1
		act.waves = [recipe(profile)]
		if i == 0: act.waves.append(recipe(profile))
		level.acts.append(act)
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.level = level
	_viewport.add_child(scene)
	await wait_map(scene)
	scene.set_process(false)
	var wave: Node = scene.get_node("EnemyWave")
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node): enemy.set_process(false))
	scene.get_node("TowerMap").combat.enabled = false
	var cards: Node = scene.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	var controller: Node = scene.get_node("PortalMap")
	var expansion: Node = scene.get_node("SpawnExpansion")
	var hud: Node = scene.get_node("LevelHUD")
	var map: GridMap = scene.get_node("TileMap")
	# Occupied branch tiles must never become endpoints or connecting road cells.
	var branch: Array[Vector3i] = [Vector3i(4, 0, 1)]
	scene.get_node("TilePlacement").add_cells(branch)
	await wait_map(scene)
	check(scene.get_node("TowerMap").place_tower(Vector3i(4, 0, 1)) != null, "Obstacle fixture tower failed to place")
	await wait_map(scene)
	scene.set_process(false)
	var completions := [0]
	expansion.completed.connect(func(_index: int):
		completions[0] += 1
		scene.set_process(false))
	finish_wave(scene)
	check(not scene.choosing_start and not expansion.active and controller.start_paths.size() == 1, "A non-final wave triggered an ACT expansion")
	finish_wave(scene)
	check(scene.current_wave == 2 and scene.choosing_start and expansion.active and expansion.choices.size() == 3, "ACT end did not offer three directions")
	check(cards.entry_selection_active and cards.input_suspended and cards.hand.stowed and cards.selected == -1 and not cards.preview.visible, "ACT choice did not stow/cancel the hand")
	check(not scene.get_node("TowerMap").input_enabled and not shop.view.visible and not wave.start_allowed and not hud._callout_available, "ACT choice left construction/shop/early start available")
	var progress: float = scene.timeline.progress
	var coins: int = shop.coins
	scene._process(120)
	scene._on_start_requested()
	wave.controls.spawn_button.pressed.emit()
	check(is_equal_approx(scene.timeline.progress, progress) and not wave.active and not scene._wave_starting and shop.coins == coins and not wave.start_wave(), "ACT choice advanced the timeline or allowed attack/rewards")
	shop.open_shop()
	shop.close_shop()
	cards.select_card(0)
	check(cards.selected == -1 and cards.input_suspended and cards.hand.stowed and not shop.view.opened and cards.place_selected(Vector3i(5, 0, 1)) == null, "Closing the shop released the ACT placement lock")
	check(not expansion.commit(Vector3i(0, 0, -6)), "Position chosen before selecting a direction")
	await frames(5)
	await save_frame(Artifacts.path("levels/act_expansion_directions.png"))
	var ui_button: Button = expansion.buttons.get_child(1)
	click(ui_button.get_global_rect().get_center())
	await frames(2)
	check(expansion.selected_direction == 1, "Direction button did not enter placement mode")
	check(expansion.back.visible and not expansion.buttons.visible, "Placement mode did not expose the change-direction action")
	var original_focus: Vector3 = scene.get_node("Camera3D")._initial_focus
	expansion.back_to_directions()
	check(expansion.selected_direction == -1 and not expansion.back.visible and scene.get_node("Camera3D").focus.is_equal_approx(original_focus), "Change direction did not restore the overview")
	click(ui_button.get_global_rect().get_center())
	await frames(2)
	var paths: Dictionary = expansion.choices[1].paths
	var picked: Vector2i = paths.keys()[paths.size()/2]
	var cell := Vector3i(picked.x, 0, picked.y)
	for choice in expansion.choices:
		check(not choice.paths.is_empty(), "Empty direction offered")
		for candidate: Vector2i in choice.paths:
			check(Planner.valid(controller, candidate, choice.paths[candidate]), "A displayed candidate is disconnected")
			check(not Vector2i(4, 1) in choice.paths[candidate], "Candidate road crossed a defense tower")
			for origin: Vector2i in controller.terminal_cells().slice(1):
				check(absi(candidate.x-origin.x)+absi(candidate.y-origin.y) >= 6, "Candidate overlaps a protected entrance")
			check(candidate != controller.terminal_cells()[0], "Candidate overlaps the goal")
	check(not expansion.commit(Vector3i(0, 0, 0)) and not expansion.commit(Vector3i(picked.x, 1, picked.y)), "Invalid endpoint changed terrain")
	# Pause and resume cannot release the separate ACT lock.
	hud.set_paused(true)
	check(not expansion.commit(cell), "Pause still allowed an entrance commit")
	hud.set_paused(false)
	check(cards.input_suspended and cards.entry_selection_active and cards.hand.stowed and not scene.get_node("TowerMap").input_enabled, "Resume released the ACT lock")
	await frames(3)
	expansion.set_process(false)
	expansion.show_hover(cell)
	check(expansion.hovered_cell == cell and expansion.get_node("World/EntrancePreview").visible and expansion.get_node("World/PathPreview").multimesh.instance_count == paths[picked].size(), "Hover did not preview the road and entrance")
	check(is_equal_approx(expansion.get_node("World/EntrancePreview").position.y-map.map_to_local(cell).y,0.125), "Entrance preview did not inherit the terrain endpoint height")
	await frames(2)
	await save_frame(Artifacts.path("levels/act_expansion_position.png"))
	TranslationServer.set_locale("en")
	check(expansion.heading.text == "Choose a highlighted tile", "Expansion UI did not switch to English")
	TranslationServer.set_locale("zh_TW")
	var old_count := map.get_used_cells().size()
	var camera: Camera3D = scene.get_node("Camera3D")
	var point := camera.unproject_position(map.to_global(map.map_to_local(cell)))
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(press, true)
	var drag := InputEventMouseMotion.new()
	drag.position = point+Vector2(50, 40)
	drag.relative = Vector2(50, 40)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	_viewport.push_input(drag, true)
	press.position = drag.position
	press.pressed = false
	press.button_mask = 0
	_viewport.push_input(press, true)
	await frames(2)
	check(expansion.active and not expansion.committing and controller.start_paths.size() == 1, "Dragging a candidate committed an entrance")
	point = camera.unproject_position(map.to_global(map.map_to_local(cell)))
	# Observe the commit lock at the rebuild signal: clicks are now dispatched
	# after release to distinguish them from camera drags.
	var commit_observed := [false]
	controller.graph_changed.connect(func():
		commit_observed[0] = true
		check(expansion.committing and scene.choosing_start and not wave.start_allowed and cards.input_suspended, "Commit unlocked gameplay before graph rebuild")
		check(not expansion.commit(cell), "A repeated click committed a second entrance"), CONNECT_ONE_SHOT)
	click(point)
	await frames(2)
	check(commit_observed[0], "Candidate click did not commit an entrance")
	await wait_map(scene)
	check(completions[0] == 1 and not scene.choosing_start and not expansion.active and controller.start_paths.size() == 2 and controller.start_nodes.size() == 2, "New protected entrance was not added exactly once")
	check(map.get_used_cells().size() == old_count+paths[picked].size(), "Extension did not preserve old terrain/add its exact road")
	check(not cards.input_suspended and not cards.hand.stowed and shop.view.visible and shop.available and wave.start_allowed, "Build phase did not resume with manual start and shop reward")
	var marker: Node3D = controller.get_node(controller.start_paths[1])
	check(map.local_to_map(map.to_local(marker.global_position)) == cell, "Entrance animation changed the logical graph marker")
	check(is_equal_approx(map.to_local(marker.global_position).y-map.map_to_local(cell).y,0.125), "New ACT entrance did not inherit the terrain endpoint height")
	var schedule := WaveSpawnSchedule.build(wave.definition, controller, 0, false, wave.additional_start_indices)
	var hist := [0, 0]
	var assignments := {}
	for entry: Dictionary in schedule.pending:
		hist[entry.start_index] += 1
		assignments[entry.wave_index] = [entry.start_index, entry.route.route_index]
		var origin: Vector3i = map.local_to_map(map.to_local(controller.get_node(controller.start_paths[entry.start_index]).global_position))
		check(entry.route.cells[0] == Vector2(origin.x, origin.z), "Route does not start at its assigned entrance")
		check(entry.spawn_tick == floori(float(entry.slot)/2)*3, "Entrance allocation changed quarter-second group timing")
	check(hist == [4, 4] and schedule.pending.size() == 8, "Next ACT did not split the original count across both entrances")
	var preview_starts := {}
	for route: Dictionary in wave.routes_for_display(): preview_starts[Vector2i(route.cells[0])] = true
	check(preview_starts.size() == 2, "F1 route preview ignored the new entrance")
	var repeat := WaveSpawnSchedule.build(wave.definition, controller, 99999, false, wave.additional_start_indices)
	for entry: Dictionary in repeat.pending:
		check(assignments[entry.wave_index] == [entry.start_index, entry.route.route_index], "Global enemy ID changed entrance/route quotas")
	scene._process(15)
	check(not scene._wave_starting and not wave.active and is_zero_approx(scene.timeline.progress), "Preparation did not wait for a manual start after committing")
	finish_wave(scene)
	check(not scene.choosing_start and not expansion.active and controller.start_nodes.size()==2 and scene.current_wave==3 and not wave.active,"Unchecked second ACT did not skip expansion and wait for manual start")
	finish_wave(scene)
	check(scene.choosing_start and expansion.active and expansion.choices.size() == 3, "Checked third ACT did not offer another expansion after an unchecked ACT")
	expansion.choose_direction(2)
	var second_cell: Vector2i = expansion.choices[2].paths.keys()[0]
	check(expansion.commit(Vector3i(second_cell.x, 0, second_cell.y)), "Second ACT entrance failed to commit")
	await wait_map(scene)
	check(controller.start_nodes.size() == 3 and wave.additional_start_indices == PackedInt32Array([1, 2]), "Second expansion replaced an existing entrance")
	schedule = WaveSpawnSchedule.build(wave.definition, controller, 0, false, wave.additional_start_indices)
	var starts := {}
	for entry: Dictionary in schedule.pending: starts[entry.start_index] = true
	check(starts.size() == 3 and schedule.pending.size() == 8, "Fourth ACT did not use all three entrances")
	finish_wave(scene)
	check(scene.finished and not scene.choosing_start and not expansion.active and completions[0] == 2 and controller.start_paths.size() == 3, "Final ACT incorrectly requested another expansion")
	check(level.endpoint_layout().starts.size() == 1 and not level.acts[1].add_start_after_completion and level.acts[1].waves[0].groups[0].enemy_count == 8, "Runtime expansion modified authored level data")
	scene.queue_free()
	await frames(2)
	print("ACT_SPAWN_EXPANSION_CHECK:"+JSON.stringify({"failures": failures, "two_stage_ui": true, "manual_start_only": true, "placement_lock": true, "pause_lock": true, "road_preview": true, "actual_new_spawns": true, "deterministic_quotas": true, "integer_quarter_ticks": true, "two_act_expansions": true, "final_act": true}))
	get_tree().quit(1 if failures else 0)
