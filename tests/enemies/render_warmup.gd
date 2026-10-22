extends Node
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	verify.call_deferred()

func verify() -> void:
	var world := Fixture.scene_for(Fixture.annotated(), Vector2i(-3, 0), Vector2i(11, 0))
	var wave: Node = world.get_node("EnemyWave")
	wave.auto_start = false
	wave.show_button = false
	add_child(world)
	var events := [0, 0, 0]
	wave.enemy_spawned.connect(func(_enemy): events[0] += 1)
	wave.wave_started.connect(func(): events[1] += 1)
	wave.wave_finished.connect(func(): events[2] += 1)
	var rendered := DisplayServer.get_name() != "headless"
	if rendered: check(not wave.start_wave(), "Start accepted before presentation was ready")
	seed(811)
	var expected_random := randi()
	seed(811)
	var saw_lock := false
	var saw_sample := false
	var captured_cover := false
	while not wave.presentation_ready:
		await get_tree().process_frame
		saw_lock = saw_lock or world.process_mode == Node.PROCESS_MODE_DISABLED
		saw_sample = saw_sample or not wave.visuals.units.is_empty()
		if rendered and saw_sample and not captured_cover:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(Artifacts.path("enemies/render_warmup_loading.png"))
			captured_cover = true
		check(wave.living_enemies().is_empty() and not wave.active, "Warmup entered combat")
	check(randi() == expected_random, "Warmup consumed gameplay RNG")
	check(not rendered or (saw_lock and saw_sample), "Actual render warmup was skipped")
	check(world.process_mode == Node.PROCESS_MODE_INHERIT, "Gameplay processing was not restored")
	check(wave.visuals.units.is_empty() and wave.visuals._slots.is_empty(), "Warmup leaked visual slots")
	check(wave.visuals.multimesh.visible_instance_count == 0, "Warmup mesh remained visible")
	check(wave.visuals.status_overlay.batch.count == 0, "Warmup status remained visible")
	check(events == [0, 0, 0] and wave._next_enemy_id == 0 and wave._pending.is_empty(), "Warmup changed wave state")
	while world.get_node("PortalMap").computing: await get_tree().process_frame
	var definition := WaveDefinition.new()
	for profile in TroopCatalog.all():
		var group := WaveSpawnGroup.new()
		group.troop = profile
		group.enemy_count = 1
		group.interval_ticks = 0
		definition.groups.append(group)
	wave.apply_definition(definition)
	check(wave.start_wave(), "Wave rejected after warmup")
	wave.set_process(false)
	wave._process(0.0)
	check(wave.spawned == definition.total_count() and events[0] == definition.total_count(), "Spawn count changed after warmup")
	for enemy in wave.living_enemies(): enemy.set_process(false)
	await get_tree().process_frame
	if rendered:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("enemies/render_warmup.png"))
	world.queue_free()
	await get_tree().process_frame
	# The formal entry must stay in preparation, and permit the normal transition
	# only after the shared loading phase has finished.
	var level: Node3D = load("res://scenes/level.tscn").instantiate()
	add_child(level)
	var formal_wave: Node = level.get_node("EnemyWave")
	if rendered:
		level._begin_wave_start()
		check(not level._wave_starting, "Formal start bypassed loading")
	while not formal_wave.presentation_ready: await get_tree().process_frame
	check(not formal_wave.active and formal_wave.spawned == 0, "Formal loading started combat")
	level._begin_wave_start()
	check(level._wave_starting, "Formal start remained locked after loading")
	level.queue_free()
	await get_tree().process_frame
	# Cancellation while awaiting a draw must release the cover with its world.
	if rendered:
		var cancelled: Node3D = load("res://scenes/level.tscn").instantiate()
		add_child(cancelled)
		await get_tree().process_frame
		cancelled.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("RENDER_WARMUP_CHECK:"+JSON.stringify({"failures": failures, "rendered": rendered, "locked": saw_lock, "sampled": saw_sample}))
	get_tree().quit(int(failures > 0))
