extends Node
const Fixture = preload("res://tests/fixtures/level_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Progress = preload("res://scripts/levels/level_progress.gd")
var failures := 0
var progress: Node
var old_path := ""
var old_completed := {}
var fixture_translations: Array[Translation] = []
var root: Window:
	get: return get_tree().root
var current_scene: Node:
	get: return get_tree().current_scene
	set(value): get_tree().current_scene = value

func _ready(): verify.call_deferred()
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func frames(count := 3):
	for i in count: await get_tree().process_frame
func click(button: Control):
	var point:=button.get_global_transform_with_canvas()*(button.size*0.5)
	var move:=InputEventMouseMotion.new()
	move.position=point
	root.push_input(move,true)
	var event:=InputEventMouseButton.new()
	event.position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	root.push_input(event,true)
	await frames(1)
	event.pressed=false
	root.push_input(event,true)
	await frames(3)
	if root.get_node("ScreenTransition").active:
		await root.get_node("ScreenTransition").finished
		await frames()
func capture(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Artifacts.path("menus/level_selection/"+name+".png"))
func verify():
	check(LevelCatalog.discover().any(func(level): return level.progress_id()=="frontier"),"Exported catalog did not discover formal Level resources")
	if OS.has_feature("web"):
		var stored:=Progress.new()
		var persistent_path:="user://level_selection_reload_test.cfg"
		check(stored.load_progress(persistent_path)==OK,"Web completion file could not load")
		var verifying:bool=JavaScriptBridge.eval("new URLSearchParams(location.search).has('verify_reload')")
		if verifying:
			check(stored.snapshot().has("web_reload"),"Web completion did not survive page reload")
			DirAccess.remove_absolute(persistent_path)
		else:
			check(stored.mark_completed("web_reload")==OK,"Web completion did not save")
		stored.free()
	progress=root.get_node("LevelProgress")
	old_path=progress.save_path
	old_completed=progress.snapshot()
	var save:=Artifacts.path("menus/level_selection/completed.cfg")
	if FileAccess.file_exists(save): DirAccess.remove_absolute(save)
	progress.load_progress(save)
	root.size=Vector2i(1280,800)
	TranslationServer.set_locale("zh_TW")
	# Save two *new* Level files. Nothing is registered in the menu scene.
	var directory:=Artifacts.path("menus/level_selection/resources")
	DirAccess.make_dir_recursive_absolute(directory)
	var first:=Fixture.level("selection_first")
	# Child sorts before the parent by both ID and filename, but must display second.
	var second:=Fixture.level("selection_child",PackedStringArray(["selection_first"]),true)
	for locale in ["en","zh_TW"]:
		var translation:=Translation.new()
		translation.locale=locale
		translation.add_message(first.title_key(),"First map" if locale=="en" else "前置關卡")
		translation.add_message(second.title_key(),"Child map" if locale=="en" else "後續關卡")
		translation.add_message(first.description_key(),"A test map." if locale=="en" else "測試地圖。")
		translation.add_message(second.description_key(),"Requires the first map." if locale=="en" else "通關前置關卡後解鎖。")
		TranslationServer.add_translation(translation)
		fixture_translations.append(translation)
	check(ResourceSaver.save(first,directory.path_join("z_parent.tres"))==OK,"Could not create first Level fixture")
	check(ResourceSaver.save(second,directory.path_join("a_child.tres"))==OK,"Could not create second Level fixture")
	first=load(directory.path_join("z_parent.tres"))
	second=load(directory.path_join("a_child.tres"))
	var menu:Node3D=load("res://scenes/menus/main_menu.tscn").instantiate()
	menu.levels_directory=directory
	root.add_child(menu)
	current_scene=menu
	await frames(4)
	var preview:Node3D=menu.map_previews.get_child(0)
	check(menu.map_selection.maps.size()==2 and preview.terrain==null,"Catalog missed a new Level or instantiated previews before selection")
	await click(menu.start_button)
	var selection:Control=menu.map_selection
	check(menu.map_previews.get_child_count()==1 and preview.terrain.get_used_cells().size()==8,"Preview is not one shared, read-only terrain host")
	var old_terrain:WeakRef=weakref(preview.terrain)
	check(selection.maps[0].level==first and not selection.start_button.disabled,"New root map was not selectable")
	check(selection.get_node("Footer/Column/Details/Info/Index").text=="01 / 02","Parent map did not display index 01 / 02")
	check(tr(selection.get_node("Footer/Column/MapRow/Name").text)=="前置關卡","Derived title key did not translate")
	await capture("unlocked_zh")
	await click(selection.next_button)
	check(old_terrain.get_ref()==null and preview.terrain.get_used_cells().back().z==7,"Switching maps retained old terrain or showed wrong map")
	check(selection.start_button.disabled and selection.current_step==0,"Locked map allowed next step")
	check(selection.get_node("Footer/Column/Details/Info/Index").text.begins_with("02 / 02"),"Child map did not display index 02 / 02")
	check(tr(selection.start_button.text)=="未解鎖" and selection.get_node("Footer/Column/Details/Info/Description").text.contains(tr(first.title_key())),"Locked status/prerequisite title missing")
	check(preview.terrain.get_script()==null and preview.terrain.process_mode==Node.PROCESS_MODE_DISABLED and menu.get_node_or_null("EnemyWave")==null,"Preview initialized gameplay")
	selection.advance()
	menu._launch_map(selection.maps[1],{})
	check(current_scene==menu and not menu._starting,"Direct launch bypassed a locked map")
	await capture("locked_zh")
	TranslationServer.set_locale("en")
	await frames()
	check(tr(selection.start_button.text)=="Locked","Locked text did not translate")
	check(tr(selection.get_node("Footer/Column/MapRow/Name").text)=="Child map","Derived title key did not update with the language")
	await capture("locked_en")
	# Complete the first fixture through the real LevelSession wave lifecycle.
	var completed_level:Node=load("res://scenes/level.tscn").instantiate()
	completed_level.level=first
	root.add_child(completed_level)
	await frames(6)
	completed_level.set_process(false)
	var wave:Node=completed_level.get_node("EnemyWave")
	wave.set_process(false)
	completed_level._begin_wave_start()
	completed_level.set_process(false)
	completed_level._process(1.5)
	wave._process(0.01)
	for enemy in wave.living_enemies(): enemy.take_damage(1000000)
	await frames(5)
	check(completed_level.finished and progress.snapshot().has("selection_first"),"Finishing the final wave did not record completion")
	completed_level.queue_free()
	await frames()
	preview.activate()
	check(not selection.start_button.disabled and selection.maps[1].unlocked,"Completion did not unlock the dependent map in the live menu")
	check(progress.load_progress(save)==OK and selection.maps[1].unlocked,"Reloading completion lost the unlock")
	await capture("unlocked_after_completion")
	await click(selection.start_button)
	await click(selection.start_button)
	var level:=current_scene
	check(level!=menu and level.get("level")==second,"Shared scene ignored the selected Level resource")
	if level==menu:
		finish(directory)
		return
	var map:GridMap=level.get_node("TileMap")
	check(map.get_used_cells().back().z==7 and map.local_to_map(map.to_local(level.get_node("Goal").global_position))==Vector3i(0,0,7),"Playable terrain/endpoints do not match preview")
	check(level.get_node("EnemyWave").enemy_count==1 and not level.get_node("EnemyWave").active,"Wrong waves or automatic first wave")
	# Restart must retain the selected resource, despite sharing level.tscn.
	level._begin_wave_start()
	level.set_process(false)
	level._process(1.5)
	level.get_node("EnemyWave")._process(0.01)
	check(not progress.snapshot().has(second.progress_id()),"Entering combat prematurely marked completion")
	var previous:WeakRef=weakref(level)
	check(level.restart_level()==OK,"Selected level restart failed")
	await get_tree().scene_changed
	await frames(6)
	check(previous.get_ref()==null and current_scene.level==second,"Restart fell back to Frontier")
	check(not progress.snapshot().has(second.progress_id()),"Restart during combat incorrectly recorded completion")
	finish(directory)
func finish(directory: String):
	progress.save_path=old_path
	progress._completed=old_completed
	LevelLaunch.clear()
	for translation in fixture_translations: TranslationServer.remove_translation(translation)
	for file in ["z_parent.tres","a_child.tres"]: DirAccess.remove_absolute(directory.path_join(file))
	var result:={"failures":failures,"automatic_level_files":true,"lazy_preview":true,"locked_launch_guard":true,"completion_unlock_reload":true,"selected_level_restart":true}
	FileAccess.open(Artifacts.path("menus/level_selection/result.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	print("LEVEL_SELECTION_CHECK:",JSON.stringify(result))
	# Keep Web alive for the browser runner's reload/persistence check. An
	# immediate engine shutdown can race GridMap's outstanding worker groups.
	if not OS.has_feature("web"): get_tree().quit(int(failures>0))
