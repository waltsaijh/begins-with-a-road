extends SceneTree
## Every result offers the main menu; only a win offers the next playable level.
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	verify.call_deferred()

func play(id: String) -> Node:
	LevelLaunch.select(load("res://assets/data/levels/%s.tres" % id))
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	return scene

func leave(scene: Node) -> void:
	scene.free()
	await process_frame

func verify() -> void:
	var progress: Node = root.get_node("LevelProgress")
	var path := Artifacts.path("result_actions/progress.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	progress.load_progress(path)

	var scene := await play("tutorial")
	scene._end_run(false)
	var column: Control = scene.run_status.column
	check(not column.get_node("NextLevel").visible and column.get_node("Home").visible, "Defeat must offer the main menu but no next level")
	check(not progress.snapshot().has("tutorial"), "Defeat recorded a completion")
	await leave(scene)

	scene = await play("tutorial")
	scene._end_run(true)
	column = scene.run_status.column
	check(column.get_node("NextLevel").visible and column.get_node("Home").visible, "A win must offer the next level and the main menu")
	check(scene.run_status.next_map != null and scene.run_status.next_map.id == "frontier", "The tutorial's win unlocks frontier")
	await leave(scene)

	scene = await play("frontier")
	scene._end_run(true)
	check(scene.run_status.next_map != null and scene.run_status.next_map.id == "bridge", "Frontier's win leads to bridge")
	scene.run_status.next_level()
	var transition: Node = root.get_node("ScreenTransition")
	for frame in 600:
		await process_frame
		if not transition.active: break
	check(current_scene != scene and current_scene.level.progress_id() == "bridge" and not current_scene.finished, "Next level did not open bridge")
	check(not paused and Engine.time_scale == 1.0, "Next level left the game paused or sped up")

	current_scene._end_run(true)
	column = current_scene.run_status.column
	check(not column.get_node("NextLevel").visible and column.get_node("Home").visible, "The last level only offers the main menu")
	current_scene.run_status.return_home()
	for frame in 600:
		await process_frame
		if not transition.active: break
	check(current_scene.scene_file_path == "res://scenes/menus/main_menu.tscn", "Home did not open the main menu")
	print("RESULT_ACTIONS_CHECK:", JSON.stringify({"failures": failures}))
	quit(1 if not failures.is_empty() else 0)
