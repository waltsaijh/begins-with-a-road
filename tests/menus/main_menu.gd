extends SceneTree
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
var white_frames := 0
var transition: CanvasLayer

func _initialize() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await process_frame

func layout_rect(control: Control) -> Rect2:
	# Compare each control's position and size within its layout container.
	return Rect2(control.position, control.size)

func click(button: Control, settle_transition := true) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await frames(1)
	event.pressed = false
	root.push_input(event, true)
	await frames(2)
	if settle_transition and transition.active:
		await transition.finished
		await frames(2)

func verify() -> void:
	transition = root.get_node("ScreenTransition")
	transition.covered.connect(func():
		var image := root.get_texture().get_image()
		for point in [Vector2i(1, 1), image.get_size()/2, image.get_size()-Vector2i(2, 2)]:
			check(image.get_pixelv(point).is_equal_approx(Color.WHITE), "Scene switch was not hidden behind a fully white frame")
		white_frames += 1
		if white_frames == 1: image.save_png(Artifacts.path("menus/white_transition.png")))
	TranslationServer.set_locale("zh_TW")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/menus/main_menu.tscn", "F5 does not enter the start menu")
	var menu := load("res://scenes/menus/main_menu.tscn").instantiate() as Node3D
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.0).timeout
	await frames(2)
	check(not paused and Engine.time_scale == 1.0 and menu.home.visible, "Menu inherited gameplay pause state")
	check(not menu.map_previews.visible and menu.get_node_or_null("PortalMap") == null and menu.get_node_or_null("EnemyWave") == null, "Menu booted gameplay systems or exposed the map preview")
	var bridge := menu.get_node("Stage/Bridge")
	var roads := 0
	for child in bridge.get_children():
		if child.name.begins_with("Road"): roads += 1
	check(roads == 58 and bridge.get_child(0).scene_file_path.begins_with("res://assets/models/tiles/"), "Scenic bridge is not made from explicit local scene instances")
	check(menu.start_button.get_parent().get_child_count() == 3, "Start menu lacks its three explicit actions")
	var hover := InputEventMouseMotion.new()
	hover.position = menu.start_button.get_global_transform_with_canvas()*(menu.start_button.size*0.5)
	root.push_input(hover, true)
	await create_timer(0.25).timeout
	await frames(2)
	check(menu.start_button.scale.is_equal_approx(Vector2.ONE) and menu.start_button.get_theme_font("font") == load("res://assets/fonts/NotoSansTC-Light.ttf") and menu.start_button.get_theme_color("font_hover_color") == Color.BLACK and menu.start_button.get_theme_color("font_focus_color") == Color.BLACK, "Start menu hover must turn black without changing scale or font weight")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Artifacts.path("menus/main_menu.png"))
	for extent in [Vector2i(1000, 750), Vector2i(1600, 900)]:
		root.size = extent
		await frames(3)
		var available := root.get_visible_rect()
		for button in [menu.start_button, menu.settings_button, menu.exit_button]:
			check(available.encloses(button.get_global_rect()), "Menu action is clipped at %s" % extent)
		var camera: Camera3D = menu.get_node("Stage/Camera3D")
		var entrance: Node3D = bridge.get_node("Entrance")
		check(not camera.is_position_behind(entrance.global_position) and available.has_point(camera.unproject_position(entrance.global_position)), "Menu's bridge entrance is outside the camera")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("menus/menu_%dx%d.png" % [extent.x, extent.y]))
	root.size = Vector2i(1280, 800)
	await frames(3)
	await click(menu.start_button, false)
	check(transition.active and menu.home.visible and not menu.map_selection.visible, "Page transition switched before the white cover")
	menu.open_settings()
	menu.start_game()
	check(not menu.settings_page.visible, "Transition accepted a second UI action")
	await transition.finished
	await frames(2)
	var selection: Control = menu.map_selection
	var preview: Node3D = menu.map_previews.get_child(0)
	var definition: MenuMapDefinition = preview.definition
	check(current_scene == menu and selection.visible and menu._selecting and not menu.home.visible and not bridge.visible, "Start should open selection without starting gameplay")
	check(root.get_camera_3d() == preview.camera and preview.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Selection did not switch to the orthographic map preview")
	check(preview.terrain.scene_file_path == definition.level.terrain.resource_path, "Preview does not reference the playable terrain")
	check(selection.maps.size() == 1 and selection.previous_button.disabled and selection.next_button.disabled, "Unavailable maps must not appear playable")
	check(selection.previous_button.get_theme_stylebox("disabled") is StyleBoxEmpty, "Disabled map navigation should retain the transparent text style")
	check(selection.get_node("Footer/Column/Details/Info/Summary").text == tr("ui.maps.summary") % [definition.level.acts.size(), definition.level.wave_count()], "Map summary did not follow actual level data")
	var cells: Array[Vector3i] = preview.terrain.get_used_cells()
	var original_cells := cells.duplicate()
	selection.select_map(1)
	check(selection.selected == 0, "Single-map selection changed to an unavailable option")
	await create_timer(0.4).timeout
	for extent in [Vector2i(1280, 800), Vector2i(1000, 750), Vector2i(1600, 900)]:
		root.size = extent
		await frames(4)
		var available := root.get_visible_rect()
		for button in [selection.start_button, selection.back_button]:
			check(available.encloses(button.get_global_rect()), "Selection action is clipped at %s" % extent)
		var map_area := Rect2(20, 135, available.size.x-40, available.size.y-355)
		for cell in cells:
			var point: Vector3 = preview.terrain.to_global(preview.terrain.map_to_local(cell))
			check(not preview.camera.is_position_behind(point) and map_area.has_point(preview.camera.unproject_position(point)), "A preview tile is clipped behind selection UI at %s" % extent)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("menus/map_selection_%dx%d.png" % [extent.x, extent.y]))
	check(preview.terrain.get_used_cells() == original_cells, "Browsing maps mutated terrain")
	var selection_id := selection.get_instance_id()
	var preview_id := preview.get_instance_id()
	var fixed_paths := ["Heading", "Heading/Title", "Footer", "Footer/Column/MapRow", "Footer/Column/MapRow/Name", "Footer/Column/MapRow/Previous", "Footer/Column/MapRow/Next", "Footer/Column/Details", "Footer/Column/Actions", "Footer/Column/Actions/Back", "Footer/Column/Actions/Start"]
	var fixed_rects := {}
	for path in fixed_paths: fixed_rects[path] = layout_rect(selection.get_node(path))
	var camera_transform: Transform3D = preview.camera.global_transform
	var camera_size: float = preview.camera.size
	var camera_offset: float = preview.camera.v_offset
	var heading_text: String = selection.get_node("Heading/Title").text
	await click(selection.start_button)
	check(current_scene == menu and selection.current_step == 1 and selection.get_instance_id() == selection_id and preview.get_instance_id() == preview_id and selection.get_viewport() == root, "Run setup must advance inside the existing selection scene and viewport")
	check(not transition.active and selection.previous_button.visible and selection.previous_button.disabled and selection.get_node("Footer/Column/Details/RunOptions").visible, "Next should replace only the description region and keep map arrows in place")
	for path in fixed_paths:
		check(layout_rect(selection.get_node(path)).is_equal_approx(fixed_rects[path]), "Next moved fixed UI: %s (%s -> %s)" % [path, fixed_rects[path], layout_rect(selection.get_node(path))])
	check(preview.camera.global_transform.is_equal_approx(camera_transform) and is_equal_approx(preview.camera.size, camera_size) and is_equal_approx(preview.camera.v_offset, camera_offset), "Next reframed or resized the map preview")
	check(selection.get_node("Heading/Title").text == heading_text, "Next replaced the page heading")
	var options: Node = selection.get_node("Footer/Column/Details/RunOptions")
	await click(options.get_node("LeftColumn/Group/Difficulty/Choices/Challenge"))
	await click(options.get_node("RightColumn/Group/StartingHand/Choices/Fixed"))
	await click(options.get_node("LeftColumn/Group/ExtraEvents/Enabled"))
	var selected_options := {"difficulty": "challenge", "starting_hand": "fixed", "extra_events": true}
	check(selection.get_run_options() == selected_options, "Prototype radio and toggle choices did not update: %s" % selection.get_run_options())
	for extent in [Vector2i(1280, 800), Vector2i(1000, 750), Vector2i(1600, 900)]:
		root.size = extent
		await frames(4)
		await click(selection.back_button)
		fixed_rects.clear()
		for path in fixed_paths: fixed_rects[path] = layout_rect(selection.get_node(path))
		camera_transform = preview.camera.global_transform
		camera_size = preview.camera.size
		camera_offset = preview.camera.v_offset
		await click(selection.start_button)
		for path in fixed_paths:
			check(layout_rect(selection.get_node(path)).is_equal_approx(fixed_rects[path]), "Step change moved %s at %s (%s -> %s)" % [path, extent, fixed_rects[path], layout_rect(selection.get_node(path))])
		check(preview.camera.global_transform.is_equal_approx(camera_transform) and is_equal_approx(preview.camera.size, camera_size) and is_equal_approx(preview.camera.v_offset, camera_offset), "Step change moved the camera at %s" % extent)
		for control in [options, selection.start_button, selection.back_button]:
			check(root.get_visible_rect().encloses(control.get_global_rect()), "Run settings are clipped at %s" % extent)
		for row in options.get_children():
			check(options.get_global_rect().encloses(row.get_global_rect()), "Compact option row overflowed the original description region at %s" % extent)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("menus/run_setup_%dx%d.png" % [extent.x, extent.y]))
	TranslationServer.set_locale("en")
	await frames(2)
	check(tr(options.get_node("LeftColumn/Group/Difficulty/Key").text) == "Difficulty" and selection.get_run_options() == selected_options, "Run settings translation lost local choices")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Artifacts.path("menus/run_setup_en.png"))
	TranslationServer.set_locale("zh_TW")
	await frames(2)
	options.get_node("LeftColumn/Group/Difficulty/Choices/Challenge").grab_focus()
	var step_back := InputEventKey.new()
	step_back.keycode = KEY_ESCAPE
	step_back.pressed = true
	root.push_input(step_back, true)
	await frames(2)
	check(selection.current_step == 0 and selection.visible and current_scene == menu and not transition.active, "Esc from run settings should return one step without leaving selection")
	check(selection.start_button.has_focus(), "Esc left keyboard focus on a hidden option")
	await click(selection.start_button)
	check(selection.get_run_options() == selected_options and selection.current_step == 1, "Back and Next lost run settings")
	await click(selection.back_button)
	check(selection.current_step == 0 and selection.get_instance_id() == selection_id, "Back from run settings replaced the scene")
	check(selection.back_button.has_focus() and not selection.start_button.has_focus(), "Back stole focus for Next and reversed the underline animation")
	var returning_underline: float = selection.back_button.underline
	await create_timer(0.08).timeout
	check(selection.back_button.underline > returning_underline, "Back underline reversed while the same button remained focused")
	await create_timer(0.2).timeout
	check(selection.back_button.underline > 0.99 and selection.start_button.underline < 0.01, "Back did not finish with the focused underline on the clicked action")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Artifacts.path("menus/back_focus_underline.png"))
	var go_back := InputEventKey.new()
	go_back.keycode = KEY_ESCAPE
	go_back.pressed = true
	root.push_input(go_back, true)
	if transition.active: await transition.finished
	await frames(2)
	check(menu.home.visible and not selection.visible and not menu.map_previews.visible and root.get_camera_3d() == menu.get_node("Stage/Camera3D"), "Esc did not return to the scenic home menu")
	root.size = Vector2i(1280, 800)
	await frames(3)
	await click(menu.settings_button)
	check(menu.settings_page.visible and not menu.home.visible and menu.settings_page.get_canvas() == menu.home.get_canvas(), "Menu settings did not use the shared canvas/modal page")
	await create_timer(0.25).timeout
	check(is_equal_approx(menu.veil.color.a, menu.settings_veil_alpha), "Menu settings veil did not strengthen")
	var values: Node = menu.settings_page.rows.get_child(0).get_node("Value")
	await click(values.get_child(1))
	check(TranslationServer.get_locale().begins_with("en"), "Menu language setting did not apply")
	await click(menu.settings_page.categories.get_child(1))
	await click(menu.settings_page.rows.get_child(0).get_node("Value").get_child(2))
	check(root.msaa_3d == Viewport.MSAA_4X, "Menu display setting did not apply")
	# Covered background actions remain unusable while settings are open.
	menu.start_game()
	check(current_scene == menu and not menu._starting, "Settings allowed a background start")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await frames(2)
	check(not menu.settings_page.visible and menu.home.visible and menu.settings_button.has_focus(), "Esc did not return to the menu with focus restored")
	check(tr(menu.start_button.text) == "Start game", "Menu labels did not refresh to English")
	await create_timer(0.25).timeout
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Artifacts.path("menus/main_menu_en.png"))
	var previous: WeakRef = weakref(menu)
	await click(menu.start_button)
	check(current_scene == menu and selection.visible, "Starting bypassed battlefield selection")
	await create_timer(0.4).timeout
	check(tr(selection.get_node("Footer/Column/MapRow/Name").text) == "Frontier Outpost", "Selected map did not translate to English")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Artifacts.path("menus/map_selection_en.png"))
	await click(selection.back_button)
	check(menu.home.visible and not selection.visible, "Selection Back did not return home")
	await click(menu.start_button)
	await click(selection.start_button)
	check(current_scene == menu and selection.current_step == 1, "Next skipped run settings and launched immediately")
	var launch_payload: Array = []
	selection.launch_requested.connect(func(map: MenuMapDefinition, values: Dictionary): launch_payload.append({"map": map, "values": values}))
	await click(selection.start_button)
	for i in 120:
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/level.tscn": break
		await frames(1)
	check(current_scene.scene_file_path == "res://scenes/level.tscn" and previous.get_ref() == null, "Start did not replace the menu with the formal level")
	var level := current_scene
	check(level.level == definition.level, "Launched level differs from the selected map definition")
	check(launch_payload.size() == 1 and launch_payload[0].map == definition and launch_payload[0].values == selected_options, "Begin did not emit the chosen map and run settings once")
	for i in 120:
		if not level.get_node("PortalMap").computing: break
		await frames(1)
	var hud: CanvasLayer = level.get_node("LevelHUD")
	check(level.current_wave == 0 and not level.get_node("EnemyWave").active and not paused and Engine.time_scale == 1.0, "Start did not enter manual first-wave preparation at 1x")
	check(root.msaa_3d == Viewport.MSAA_4X and TranslationServer.get_locale().begins_with("en"), "Menu settings were lost entering gameplay")
	hud.set_paused(true)
	hud.open_settings()
	check(hud.settings_page.visible and level.get_node("Camera3D")._navigation_locked, "In-game settings no longer work after entering from the menu")
	hud.settings_page.close()
	hud.set_paused(false)
	# Return from a real paused 4x battle, keeping simulation frozen until covered.
	level._on_start_requested()
	level._process(1.5)
	var wave: Node = level.get_node("EnemyWave")
	wave._process(0.0)
	hud.cycle_speed()
	hud.cycle_speed()
	check(wave.active and hud.speed_index == 2, "Return-home fixture is not an active 4x battle")
	hud.set_paused(true)
	check(hud.home_button.text == "Back to main menu", "Pause action was not renamed")
	await create_timer(0.4, true, false, true).timeout
	await frames(2)
	# A white backing isolates button fill from the animated 3D background.
	hud.get_node("PauseBlocker/WhiteVeil").color = Color.WHITE
	await frames(2)
	var previous_level: WeakRef = weakref(level)
	await click(hud.home_button, false)
	check(transition.active and paused and Engine.time_scale == 0.0, "Return transition resumed the old game")
	var return_image := root.get_texture().get_image()
	var pixels_per_unit := Vector2(return_image.get_size())/root.get_visible_rect().size
	for button: Button in hud._menu_buttons:
		var point := button.get_global_transform_with_canvas()*Vector2(5, button.size.y*0.5)
		var pixel := return_image.get_pixelv(Vector2i((point*pixels_per_unit).floor()))
		check(pixel.r > 0.95 and pixel.g > 0.95 and pixel.b > 0.95, "Return transition filled a text button with a gray disabled background: "+str(button.get_parent().name))
	return_image.save_png(Artifacts.path("menus/pause_return_transition.png"))
	root.push_input(escape, true)
	hud.request_return_home()
	await frames(2)
	check(paused, "Esc bypassed the return transition input lock")
	if transition.active: await transition.finished
	await frames(2)
	check(current_scene.scene_file_path == "res://scenes/menus/main_menu.tscn" and previous_level.get_ref() == null, "Pause menu did not return to the main scene and release the old level")
	check(not paused and Engine.time_scale == 1.0 and current_scene.home.visible and not transition.veil.visible, "Return left the menu paused or covered")
	check(root.msaa_3d == Viewport.MSAA_4X and TranslationServer.get_locale().begins_with("en"), "Returning home discarded user settings")
	var fresh_menu: Node3D = current_scene
	await click(fresh_menu.start_button)
	await click(fresh_menu.map_selection.start_button)
	check(fresh_menu.map_selection.get_run_options() == {"difficulty": "standard", "starting_hand": "random", "extra_events": false}, "New menu retained the previous run's prototype choices")
	await click(fresh_menu.map_selection.start_button)
	var fresh_level := current_scene
	var shop: Node = fresh_level.get_node("CardPlacement/Shop")
	check(fresh_level.current_wave == 0 and not fresh_level.get_node("EnemyWave").active and shop.coins == shop.initial_coins and fresh_level.get_node("LevelHUD").speed_index == 0, "Returning and starting again retained the old run")
	check(white_frames >= 8, "Some page/scene changes bypassed the white transition")
	print("MAIN_MENU_CHECK:"+JSON.stringify({"failures": failures, "explicit_stage": true, "responsive": true, "shared_settings": true, "map_selection": true, "inline_run_setup": true, "run_options": true, "read_only_preview": true, "white_transitions": white_frames, "return_home": true, "fresh_run": true, "manual_first_wave": true}))
	quit(1 if failures else 0)
