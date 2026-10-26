extends SceneTree
const Signatures = preload("res://scripts/enemies/rendering/enemy_render_signatures.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0

func _initialize() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func verify() -> void:
	var service := root.get_node("DisplayWarmup")
	var profiles := TroopCatalog.all()
	var soldier := TroopCatalog.find("soldier")
	var quick := TroopCatalog.find("quickfeet")
	var heavy := TroopCatalog.find("heavy")
	check(Signatures.profile_keys(quick) == Signatures.profile_keys(heavy), "Equal rigid materials did not share a render signature")
	check(Signatures.profile_keys(soldier) == Signatures.profile_keys(quick), "Shared GPU gait did not share its render signature")
	# Different material/shader features must survive deduplication.
	var copy := quick.duplicate() as Troop
	var model := quick.model.instantiate()
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var changed := StandardMaterial3D.new()
	changed.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = changed
	copy.model = PackedScene.new()
	copy.model.pack(model)
	model.free()
	check(Signatures.profile_keys(copy) != Signatures.profile_keys(quick), "A new transparency combination was dropped")
	seed(811)
	var expected := randi()
	seed(811)
	change_scene_to_file("res://scenes/menus/boot.tscn")
	await scene_changed
	var boot := current_scene
	var selected: Array[Troop] = service.representatives(profiles, boot.renderer)
	check(selected.has(soldier) and not selected.has(quick) and not selected.has(heavy), "Startup did not select one shared GPU representative")
	for profile in profiles:
		if profile not in [soldier, quick, heavy]:
			check(selected.has(profile), "Startup dropped a distinct scripted model")
	var samples := {}
	var finished := 0
	var total := 0
	var same_viewport := true
	var captured := false
	var transition: CanvasLayer = root.get_node("ScreenTransition")
	var menu_loading_frames := 0
	if DisplayServer.get_name() != "headless":
		transition.covered.connect(func():
			var image := root.get_texture().get_image()
			image.save_png(Artifacts.path("menus/loading_labels/native_menu_loading.png")), CONNECT_ONE_SHOT)
	while current_scene == boot:
		if is_instance_valid(boot):
			finished = boot.completed
			total = boot.total
			check(boot.get_node_or_null("EnemyWave") == null and boot.get_node_or_null("PortalMap") == null, "Startup initialized gameplay")
			check(boot.display.is_visible_in_tree() or transition.loading.is_visible_in_tree(), "Startup labels disappeared during handoff")
			for enemy in boot.renderer.units:
				samples[enemy.troop.troop_name] = true
				same_viewport = same_viewport and enemy.get_viewport() == root
			if not captured and not boot.renderer.units.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(Artifacts.path("menus/startup_loading.png"))
				captured = true
		if transition.active:
			check(transition.loading.is_visible_in_tree() and transition.loading_stage.text == "ui.loading.menu", "Startup transition lost its stage label")
			menu_loading_frames += 1
		await process_frame
	if current_scene == null: await scene_changed
	check(current_scene.scene_file_path.ends_with("main_menu.tscn"), "Startup did not open menu")
	while transition.active:
		check(transition.loading.is_visible_in_tree() and transition.loading_stage.text == "ui.loading.menu", "Menu first draw was hidden by an unlabeled cover")
		check(not transition.loading_bar.visible and not transition.loading_count.visible, "Unknown menu preparation showed a stale completed count")
		menu_loading_frames += 1
		await process_frame
	check(menu_loading_frames > 0, "Labeled startup handoff was not observed")
	check(not transition.loading.visible, "Startup label leaked into the interactive menu")
	check(total == selected.size()+1 and finished == total, "Startup work count did not complete")
	check(service._retained_resources.size() == 1,"World palette representative was not retained")
	check(randi() == expected, "Startup preparation consumed gameplay RNG")
	check(same_viewport, "Startup drew into a separate viewport")
	if DisplayServer.get_name() != "headless":
		check(samples.has("soldier") and not samples.has("quickfeet") and not samples.has("heavy"), "Startup drew duplicate/missing model representatives")
		for profile in selected: check(samples.has(profile.troop_name), "Startup did not draw a distinct representative")
	check(service._retained.size() == selected.size(), "Prepared resources were not retained")
	change_scene_to_file("res://scenes/level.tscn")
	await scene_changed
	var level := current_scene
	var renderer: MultiMeshInstance3D = level.get_node("EnemyWave").visuals
	check(service.representatives(profiles, renderer).is_empty(), "Level did not reuse startup context/materials")
	var work := []
	var error: int = await level.prepare_for_play(func(done, count, _stage): work.append([done,count]))
	var plans := {}
	for group: WaveSpawnGroup in level._waves[0].groups:
		plans[[group.troop, group.start_index]] = true
	var expected_work := 1+plans.size()
	check(error == OK and work.back() == [expected_work,expected_work], "Level repeated shared display preparation")
	check(service._retained.size() == selected.size() and renderer.units.is_empty(), "Preparation leaked visual representatives")
	var previous := root.msaa_3d
	root.msaa_3d = Viewport.MSAA_DISABLED if previous != Viewport.MSAA_DISABLED else Viewport.MSAA_2X
	check(service.representatives(profiles, renderer).size() == selected.size(), "A changed render context bypassed preparation")
	root.msaa_3d = previous
	var result := {"failures":failures,"representatives":samples.keys(),"startup_work":total,"level_work":work.back(),"same_viewport":same_viewport,"menu_loading_frames":menu_loading_frames}
	var file := FileAccess.open(Artifacts.path("menus/startup_loading.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("STARTUP_LOADING_CHECK:"+JSON.stringify(result))
	quit(int(failures > 0))
