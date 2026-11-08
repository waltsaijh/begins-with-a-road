extends SceneTree
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0

func _initialize() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in count: await process_frame

func click(button: Control) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
	await frames()

func complete(level: Node) -> void:
	level.current_wave = level.level.wave_count()
	level._end_run(true)
	await frames()
	check(level.finished and not level.choosing_relic and not level.tutorial.overlay.visible,"Tutorial victory must bypass relics and hide the teaching overlay")
	check(level.run_status._next_map_id == "frontier", "Tutorial continuation must select the second battlefield")
	var panel: Control = level.run_status.get_node("Result/Center/Panel")
	var actions: Control = level.run_status.get_node("Result/Center/Panel/Margin/Column/TutorialActions")
	check(panel.get_global_rect().encloses(actions.get_global_rect()),"Tutorial actions must sit inside the victory panel")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5,true,false,true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("tutorial/09_victory_actions.png"))

func verify() -> void:
	root.size = Vector2i(1280,800)
	var progress: Node = root.get_node("LevelProgress")
	progress.load_progress(Artifacts.path("tutorial/completion_flow.cfg"))
	progress._completed.clear()
	LevelLaunch.select(load("res://assets/data/levels/tutorial.tres"))
	change_scene_to_file("res://scenes/level.tscn")
	await frames(15)
	var level := current_scene
	await complete(level)
	var old: WeakRef = weakref(level)
	await click(level.run_status.get_node("Result/Center/Panel/Margin/Column/TutorialActions/Restart"))
	await frames(15)
	level = null
	check(old.get_ref() == null and current_scene.level.progress_id() == "tutorial", "Restart must replace the old scene with the same tutorial")
	check(current_scene.current_wave == 0 and current_scene.tutorial.stage == current_scene.tutorial.Stage.CAMERA and current_scene.get_node("CardPlacement").cards.is_empty(), "Restart must return to camera practice without cards")
	await complete(current_scene)
	await create_timer(4.1,true,false,true).timeout
	var audio: Node = root.get_node("GameAudio")
	check(not audio._victory_pending and not audio._victory.playing and audio._active >= 0 and audio._voices[audio._active].stream == audio.DEFAULT,"The real victory clip must finish once and hand back to BGM naturally")
	await click(current_scene.run_status.get_node("Result/Center/Panel/Margin/Column/TutorialActions/Continue"))
	if root.get_node("ScreenTransition").active: await root.get_node("ScreenTransition").finished
	await frames(12)
	check(current_scene.scene_file_path == "res://scenes/menus/main_menu.tscn" and current_scene._selecting and not current_scene.home.visible, "Continue must open the battlefield selection page directly")
	var selection: Control = current_scene.map_selection
	check(selection.visible and selection.current_step == selection.Step.MAP and selection.maps[selection.selected].id == "frontier" and selection.maps[selection.selected].unlocked, "Continue must preselect the unlocked second battlefield without starting combat")
	check(LevelLaunch.take_menu_map().is_empty(), "Menu selection handoff must be consumed only once")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.9,true,false,true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("tutorial/08_continue_frontier.png"))
	current_scene.queue_free()
	await frames()
	root.get_node("GameAudio").queue_free()
	await create_timer(0.15,true,false,true).timeout
	print("TUTORIAL_COMPLETION_FLOW: failures=",failures)
	quit(0 if failures == 0 else 1)
