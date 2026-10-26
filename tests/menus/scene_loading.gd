extends SceneTree
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
var transition: CanvasLayer

func _initialize() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await process_frame

func click(button: Control, settle := true) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await frames(1)
	event.pressed = false
	root.push_input(event, true)
	await frames(1)
	if settle and transition.active:
		await transition.finished
		await frames(2)

func verify() -> void:
	transition = root.get_node("ScreenTransition")
	TranslationServer.set_locale("zh_TW")
	change_scene_to_file("res://scenes/menus/main_menu.tscn")
	await scene_changed
	await create_timer(0.9).timeout
	await frames(3)
	var menu := current_scene
	await click(menu.start_button)
	await click(menu.map_selection.start_button)
	await click(menu.map_selection.start_button, false)
	if not transition.active:
		check(false,"Launch click did not begin a transition")
		quit(1)
		return
	var last_value := 0.0
	var total := 0.0
	var samples := {}
	var saw_loading := false
	var saw_unknown := false
	var captured := false
	var rng_set := false
	var expected_rng := 0
	var requested := false
	var start_checked := false
	while transition.active:
		if transition.loading.visible:
			saw_loading = true
			saw_unknown = saw_unknown or not transition.loading_bar.visible
			if transition.loading_bar.visible:
				check(transition.loading_bar.value >= last_value, "Progress moved backwards")
				last_value = transition.loading_bar.value
				if total == 0: total = transition.loading_bar.max_value
				check(transition.loading_bar.max_value == total, "Known work count changed")
			if not requested:
				check(not transition.change_scene("res://scenes/menus/main_menu.tscn"), "Duplicate transition accepted")
				var escape := InputEventKey.new()
				escape.keycode = KEY_ESCAPE
				escape.pressed = true
				root.push_input(escape, true)
				requested = true
			if current_scene != null and current_scene.scene_file_path.ends_with("level.tscn"):
				var wave: Node = current_scene.get_node("EnemyWave")
				check(wave._living.is_empty() and not wave.active and wave._next_enemy_id == 0, "Loading changed combat state")
				if current_scene._loading and not start_checked:
					check(not wave.start_wave(), "Internal wave start bypassed loading lock")
					current_scene._begin_wave_start()
					check(not current_scene._wave_starting, "Session start bypassed loading lock")
					start_checked = true
				if transition.loading_stage.text == "ui.loading.visuals":
					if not rng_set:
						seed(811)
						expected_rng = randi()
						seed(811)
						rng_set = true
					for enemy in wave.visuals.units: samples[enemy.troop.troop_name] = true
					if not captured and not wave.visuals.units.is_empty() and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(Artifacts.path("menus/loading_visuals.png"))
						captured = true
		await process_frame
	check(saw_loading and saw_unknown and total > 0 and last_value == total, "Loading stages/counts were not presented")
	if DisplayServer.get_name() != "headless":
		check(samples.has("soldier") and not samples.has("quickfeet") and not samples.has("heavy"), "Fallback did not select unique material/render representatives")
	if rng_set: check(randi() == expected_rng, "Visual preparation consumed gameplay RNG")
	var level := current_scene
	var wave: Node = level.get_node("EnemyWave")
	check(level._presentation_prepared and not level._loading and wave.start_allowed, "Preparation did not complete")
	check(level.process_mode == Node.PROCESS_MODE_PAUSABLE and not paused, "Gameplay process mode was not restored")
	check(not transition.loading.visible and not transition.veil.visible, "Loading cover leaked")
	check(wave.visuals.units.is_empty() and wave.visuals.multimesh.visible_instance_count == 0 and wave.visuals.status_overlay.batch.count == 0, "Warmup visuals leaked")
	check(level.current_wave == 0 and not wave.active and wave.spawned == 0, "Loading started the first wave")
	check(await level.prepare_for_play(Callable()) == ERR_INVALID_PARAMETER, "Invalid progress callback accepted")
	var repeated := [0]
	check(await level.prepare_for_play(func(_done, _total, _stage): repeated[0] += 1) == OK and repeated[0] == 0, "Completed preparation ran twice")
	level._begin_wave_start()
	level._process(1.5)
	check(wave.active, "Normal opening remained locked")
	transition.change_scene("res://scenes/menus/main_menu.tscn")
	await transition.finished
	for method in [&"fail_loading", &"cancel_loading"]:
		transition.change_scene("res://tests/fixtures/loading_target.tscn", method)
		var error: int = await transition.finished
		check(error != OK and not transition.active and current_scene.scene_file_path.ends_with("main_menu.tscn"), "Failed/cancelled preparation did not restore menu")
		check(not transition.loading.visible and not transition.veil.visible, "Failed loading leaked an input cover")
	print("SCENE_LOADING_CHECK:"+JSON.stringify({"failures":failures,"loading":saw_loading,"unknown_stage":saw_unknown,"work_units":total,"models":samples.keys(),"cancel_recovery":true}))
	quit(int(failures > 0))
