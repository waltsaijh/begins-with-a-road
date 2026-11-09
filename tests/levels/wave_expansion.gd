extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	verify.call_deferred()
func wait_map(scene: Node) -> void:
	for i in 600:
		if not scene.get_node("PortalMap").computing: return
		await get_tree().process_frame
	check(false,"Map rebuild timed out")
func verify() -> void:
	var authored: LevelDefinition = load("res://assets/data/levels/frontier.tres")
	for completed in range(16):
		check(authored.expands_after(completed) == (completed in [5,10]),"Wrong Frontier expansion at %d" % completed)
	var level: LevelDefinition = authored.duplicate(true)
	# Keep the real 5 ACT / 15 wave structure and terrain; shorten combat only.
	for act in level.acts:
		for wave in act.waves:
			var group := WaveSpawnGroup.new()
			group.troop = TroopCatalog.find("soldier")
			group.enemy_count = 6
			group.interval_ticks = 0
			wave.groups = [group]
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	scene.level = level
	add_child(scene)
	await wait_map(scene)
	var wave: Node = scene.get_node("EnemyWave")
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node): enemy.set_process(false))
	scene.get_node("TowerMap").combat.enabled = false
	var timeline: WaveTimeline = scene.timeline
	check(timeline.expansion_indices() == PackedInt32Array([4,9]),"Missing entrance milestones")
	check(timeline.reward_indices() == PackedInt32Array([2,5,8,11]),"Relic cadence changed")
	check(timeline.get_node("Track/Markers").get_child_count() == 6,"Window does not reuse bounded markers")
	for i in 15:
		if i in timeline.reward_indices():
			check(timeline.reward_fraction(i) > timeline.node_fraction(i) and timeline.reward_fraction(i) < timeline.node_fraction(i+1),"Relic overlaps a wave")
		if i in timeline.expansion_indices():
			check(timeline.expansion_fraction(i) > timeline.node_fraction(i) and timeline.expansion_fraction(i) < timeline.node_fraction(i+1),"Entrance overlaps a wave")
	var overlap: LevelDefinition = level.duplicate(true)
	overlap.expansion_wave_interval = 3
	overlap.reward_final_act = true
	timeline.configure(overlap)
	check(timeline.node_fraction(2) < timeline.reward_fraction(2) and timeline.reward_fraction(2) < timeline.expansion_fraction(2) and timeline.expansion_fraction(2) < timeline.node_fraction(3),"Simultaneous events overlap or have wrong order")
	check(is_equal_approx(timeline.reward_fraction(14),1.0),"Final relic is not the last milestone")
	timeline.configure(level)
	TranslationServer.set_locale("en")
	timeline._set_cursor(float(timeline.event_index("wave",3)))
	check(timeline._get_tooltip(timeline.event_position("entrance",4)).contains("After wave 5"),"Entrance tooltip does not identify the wave")
	TranslationServer.set_locale("zh_TW")
	timeline._set_cursor(0.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("levels/wave_expansion_timeline.png"))
	for index in 15:
		scene._on_start_requested()
		scene.set_process(false)
		scene._advance_wave_start(1.5)
		check(wave.active,"Wave failed to start")
		wave._process(1000.0)
		var origins := {}
		for enemy in wave.living_enemies(): origins[Vector2i(enemy.route.cells[0])] = true
		check(origins.size() == scene.get_node("PortalMap").start_nodes.size(),"New entrances not used by later waves")
		for enemy in wave.living_enemies(): enemy.take_damage(1000000)
		if scene.choosing_relic:
			check(not scene.choosing_start,"Reward and expansion opened simultaneously")
			scene.relic_choice.choose(scene.relic_choice.offers[0])
			await get_tree().create_timer(0.3).timeout
		check(scene.choosing_start == (index in [4,9]),"Wrong runtime expansion timing")
		if scene.choosing_start:
			check(not wave.start_allowed and scene.get_node("CardPlacement").input_suspended,"Expansion did not lock construction/start")
			var expansion: Node = scene.expansion
			expansion.choose_direction(0)
			var cell: Vector2i = expansion.choices[0].paths.keys()[0]
			check(expansion.commit(Vector3i(cell.x,0,cell.y)),"Entrance commit failed")
			await wait_map(scene)
			check(not scene.choosing_start and wave.start_allowed,"Entrance completion did not restore preparation")
		scene.set_process(false)
		await get_tree().process_frame
	check(scene.finished and scene.victory and scene.get_node("PortalMap").start_nodes.size() == 3,"Final wave did not win with exactly two added entrances")
	check(authored.endpoint_layout().starts.size() == 1,"Runtime modified authored terrain")
	scene.queue_free()
	await get_tree().process_frame
	print("WAVE_EXPANSION_CHECK: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
