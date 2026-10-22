extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const RESTART_STATE := &"pause_menu_restart_check"
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	for i in count:
		await tree.process_frame
		if not is_inside_tree(): return

func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	get_viewport().push_input(event, true)
	await frames(1)

func click(button: Button) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	await move_mouse(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await frames(1)

func click_setting(_page: Control, button: Control) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await frames(2)

func verify_text_canvas(hud: CanvasLayer, page: Control) -> void:
	# Compare the page title against the same Label drawn directly under the HUD.
	# This catches an accidental return to offscreen rendering/compositing.
	var title: Label = page.get_node("Panel/Margin/Layout/Header/Title")
	var reference := Label.new()
	reference.text = title.text
	reference.add_theme_font_override("font", title.get_theme_font("font"))
	reference.add_theme_font_size_override("font_size", title.get_theme_font_size("font_size"))
	reference.add_theme_color_override("font_color", title.get_theme_color("font_color"))
	reference.position = title.get_global_transform_with_canvas().origin
	reference.size = title.size
	reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference.hide()
	hud.add_child(reference)
	# A solid backing makes the pixel comparison independent of moving clouds.
	var backing := ColorRect.new()
	backing.color = Color.WHITE
	backing.position = reference.position
	backing.size = title.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(backing)
	hud.move_child(backing, page.get_index())
	await frames(2)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var pixels_per_unit := Vector2(image.get_size())/get_viewport().get_visible_rect().size
	var area := Rect2i(Vector2i((reference.position*pixels_per_unit).floor()), Vector2i((reference.size*pixels_per_unit).floor()))
	var actual := image.get_region(area)
	title.modulate.a = 0.0
	reference.show()
	await frames(2)
	await RenderingServer.frame_post_draw
	var expected := get_viewport().get_texture().get_image().get_region(area)
	check(actual.get_data() == expected.get_data(), "Settings text pixels differ from an equivalent Label on the main HUD canvas")
	actual.save_png(Artifacts.path("settings/title_canvas.png"))
	title.modulate.a = 1.0
	backing.queue_free()
	reference.queue_free()
	await frames(2)

func verify() -> void:
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	add_child(scene)
	await frames(12)
	for i in 120:
		if not scene.get_node("PortalMap").computing: break
		await frames(1)
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	var wave: Node = scene.get_node("EnemyWave")
	var cards: Node = scene.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	if get_tree().has_meta(RESTART_STATE):
		var previous: Dictionary = get_tree().get_meta(RESTART_STATE)
		get_tree().remove_meta(RESTART_STATE)
		failures = previous.failures
		check(scene.get_instance_id() != previous.scene_id and scene.current_wave == 0 and not wave.active and wave.living_enemies().is_empty(), "Restart did not create a fresh level without old enemies")
		check(shop.coins == shop.initial_coins and cards.cards.size() == cards.initial_card_count and cards.selected == -1, "Restart retained the old economy or hand selection")
		check(not get_tree().paused and Engine.time_scale == 1.0 and hud.speed_index == 0 and not hud.pause_menu.visible and not cards.pause_locked, "Restart retained pause or speed state")
		print("PAUSE_MENU_CHECK:"+JSON.stringify({"failures": failures, "hover_shift_scale": true, "stable_hit_area": true, "no_underline": true, "settings_page": true, "restart_live_level": true, "translations": true}))
		get_tree().quit(1 if failures else 0)
		return
	hud.set_paused(true)
	check(get_tree().paused and Engine.time_scale == 0.0, "Pause did not immediately freeze simulation")
	await frames(2)
	check(hud._menu_buttons.size() == 4, "Pause menu does not have four actions")
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")
	check(hud.restart_button.text == "重新開始" and hud.settings_button.text == "設定", "New menu items lack Chinese translations")
	TranslationServer.set_locale("en")
	check(hud.restart_button.text == "Restart" and hud.settings_button.text == "Settings", "New menu items lack English translations")
	TranslationServer.set_locale(locale)
	for button: Button in hud._menu_buttons:
		check(button.can_process() and button.get_theme_stylebox("hover") is StyleBoxEmpty and button.get_theme_stylebox("focus") is StyleBoxEmpty and button.get_theme_stylebox("disabled") is StyleBoxEmpty, "Menu item stopped processing or retained a filled background/underline")
	var button: Button = hud.resume_button
	# Hover at the right edge that the animated text moves away from.
	var rest_point := button.get_global_transform_with_canvas()*Vector2(button.size.x-2.0, button.size.y*0.5)
	await move_mouse(rest_point)
	await frames(2)
	check(button.scale.x > 1.0 and button.scale.x < button.hover_scale, "Hover movement snapped instead of transitioning")
	await get_tree().create_timer(0.25, true, false, true).timeout
	check(button.is_hovered() and is_equal_approx(button.position.x, -button.hover_shift) and is_equal_approx(button.scale.x, button.hover_scale), "Paused hover did not slide left and enlarge while retaining its hit area")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("levels/pause_menu_hover.png"))
	await move_mouse(Vector2(10, 100))
	await get_tree().create_timer(0.25, true, false, true).timeout
	# Let newly registered tweens finish their frame step before inspecting them.
	await frames(2)
	check(is_zero_approx(button.position.x) and button.scale.is_equal_approx(Vector2.ONE), "Leaving hover did not slide right and restore size")
	var progress: float = scene.timeline.progress
	var coins: int = shop.coins
	await click(hud.settings_button)
	await frames(3)
	check(hud.settings_page.visible and hud.pause_requested and get_tree().paused and not scene._wave_starting and scene.timeline.progress == progress and shop.coins == coins, "Settings did not open while preserving paused gameplay")
	var page: Control = hud.settings_page
	check(page.get_viewport() == hud.resume_button.get_viewport() and page.get_canvas() == hud.resume_button.get_canvas(), "Settings must draw directly on the pause menu's viewport and canvas")
	check(page.get_node("Panel").get_theme_stylebox("panel") is StyleBoxEmpty, "Settings background is not transparent")
	await get_tree().create_timer(0.25, true, false, true).timeout
	check(is_equal_approx(hud.get_node("PauseBlocker/WhiteVeil").color.a, maxf(hud._pause_veil_alpha, hud.settings_veil_alpha)), "Settings did not strengthen the pause veil")
	check(page.rows.get_child(0).get_node("Value").get_child_count() == 2, "Language must use text radio choices")
	var category: Button = page.categories.get_child(0)
	check(category.get_theme_stylebox("hover") is StyleBoxEmpty and category.get_theme_stylebox("focus") is StyleBoxEmpty and category.underline > 0.99, "Category must use animated underline without a box")
	await click_setting(page, page.categories.get_child(1))
	await frames(2)
	var radios: Node = page.rows.get_child(0).get_node("Value")
	check(radios.get_child_count() == 3 and radios.get_child(0).button_group != null, "Missing radio group")
	await click_setting(page, radios.get_child(2))
	check(get_viewport().msaa_3d == Viewport.MSAA_4X and not radios.get_child(1).button_pressed, "Radio choice was not exclusive or applied")
	check(not radios.get_child(2) is CheckBox and radios.get_child(2).underline > 0.0 and radios.get_child(2).underline < 1.0, "Radio underline must animate without circle icons")
	await get_tree().create_timer(0.25, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("settings/radio.png"))
	await click_setting(page, page.categories.get_child(2))
	await frames(2)
	var checkbox: Button = page.rows.get_child(0).get_node("Value").get_child(0)
	await click_setting(page, checkbox)
	check(AudioServer.is_bus_mute(0), "Checkbox did not apply mute")
	check(checkbox.checkbox and checkbox.icon == null, "Boolean option should be text-only")
	await get_tree().create_timer(0.25, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("settings/checkbox.png"))
	check(checkbox.underline > 0.99, "Enabled boolean option must retain its underline")
	var toggle_width := checkbox.size.x
	check(checkbox.get_theme_font("font") == load("res://assets/fonts/NotoSansTC-Light.ttf") and checkbox.scale.is_equal_approx(Vector2.ONE*1.1) and checkbox.get_theme_color("font_hover_color") == Color.BLACK, "Hover must retain Light and smoothly enlarge to 110% in black")
	await click_setting(page, checkbox)
	check(not AudioServer.is_bus_mute(0) and checkbox.has_focus(), "Clicking again must disable the value while retaining focus")
	await get_tree().create_timer(0.25, true, false, true).timeout
	check(checkbox.underline < 0.01, "Unchecked toggle underline must collapse despite keyboard focus")
	var accept := InputEventKey.new()
	accept.keycode = KEY_SPACE
	for expected_value in [true, false]:
		accept.pressed = true
		get_viewport().push_input(accept, true)
		accept.pressed = false
		get_viewport().push_input(accept, true)
		await frames(2)
		check(AudioServer.is_bus_mute(0) == expected_value, "Settings keyboard activation stopped working on the shared canvas")
	var leave := InputEventMouseMotion.new()
	leave.position = Vector2(20, 20)
	get_viewport().push_input(leave, true)
	await frames(2)
	await get_tree().create_timer(0.25, true, false, true).timeout
	await frames(2)
	check(checkbox.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(checkbox.size.x, toggle_width), "Leaving hover must restore 100% without changing layout")
	page.categories.get_child(0).pressed.emit()
	await frames(2)
	var language_buttons: Node = page.rows.get_child(0).get_node("Value")
	var english: Button = language_buttons.get_child(1)
	var chinese: Button = language_buttons.get_child(0)
	await click_setting(page, english)
	var advancing: float = english.underline
	await frames(3)
	check(TranslationServer.get_locale().begins_with("en") and tr(page.categories.get_child(0).text) == "General", "Language change did not refresh the page")
	check(is_instance_valid(english) and english == page.rows.get_child(0).get_node("Value").get_child(1) and english.has_focus() and english.underline >= advancing, "Language change rebuilt buttons or reset the underline/focus")
	await click_setting(page, chinese)
	await frames(3)
	await get_tree().create_timer(0.25, true, false, true).timeout
	check(chinese.underline > 0.99 and english.underline < 0.01, "Rapid locale reversal did not finish with the correct underline")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("settings/page.png"))
	await verify_text_canvas(hud, page)
	var definitions: Array[Dictionary] = [{"label": "Long list", "options": []}]
	for i in 24: definitions[0].options.append({"key": StringName("test_%d" % i), "label": "Option %d" % i, "kind": "checkbox", "default": false})
	page.configure(definitions, {})
	await frames(3)
	page.scroll.scroll_vertical = 400
	await frames(2)
	check(page.scroll.scroll_vertical > 0 and page.scroll.get_v_scroll_bar().visible, "Long settings list cannot scroll")
	var camera: Camera3D = scene.get_node("Camera3D")
	var camera_size := camera.size
	var wheel := InputEventMouseButton.new()
	wheel.position = page.scroll.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	get_viewport().push_input(wheel, true)
	await frames(2)
	check(page.scroll.scroll_vertical > 400 and camera.size == camera_size, "Wheel did not scroll settings independently of camera")
	# A modal Control must isolate the whole viewport, including its empty margin.
	var camera_pose := camera.global_transform
	var camera_focus: Vector3 = camera.focus
	var pressed_background := [false]
	var background := Button.new()
	background.position = Vector2.ZERO
	background.size = Vector2(42, 42)
	background.pressed.connect(func(): pressed_background[0] = true)
	hud.add_child(background)
	hud.move_child(background, page.get_index())
	await click_setting(page, background)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	for i in 32:
		tab.shift_pressed = i >= 16
		tab.pressed = true
		get_viewport().push_input(tab, true)
		tab.pressed = false
		get_viewport().push_input(tab, true)
		check(page.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Keyboard focus escaped behind the modal page")
	for mouse_button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
		var press := InputEventMouseButton.new()
		press.position = Vector2(10, 10)
		press.button_index = mouse_button
		press.pressed = true
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if mouse_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
		get_viewport().push_input(press, true)
		var drag := InputEventMouseMotion.new()
		drag.position = Vector2(130, 120)
		drag.relative = Vector2(120, 110)
		drag.button_mask = press.button_mask
		get_viewport().push_input(drag, true)
		press.position = drag.position
		press.pressed = false
		press.button_mask = 0
		get_viewport().push_input(press, true)
	wheel.position = Vector2(10, 10)
	get_viewport().push_input(wheel, true)
	await frames(3)
	check(camera.global_transform.is_equal_approx(camera_pose) and camera.focus.is_equal_approx(camera_focus) and camera.size == camera_size and camera._orbit_press == null, "Settings leaked orbit, pan, zoom or a pending click to the background")
	check(not pressed_background[0] and shop.coins == coins and scene.timeline.progress == progress, "Settings leaked clicks or changed paused gameplay")
	background.queue_free()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	await frames(2)
	check(not page.visible and hud.pause_requested and get_tree().paused, "Esc should return to pause without resuming")
	check(not camera._navigation_locked, "Returning to pause must release the camera lock")
	await get_tree().create_timer(0.25, true, false, true).timeout
	check(is_equal_approx(hud.get_node("PauseBlocker/WhiteVeil").color.a, hud._pause_veil_alpha), "Closing settings did not restore the scene's original veil alpha")
	# Opening a modal while a camera gesture is pending must discard its tail.
	camera._orbit_velocity = 1.0
	hud.open_settings()
	await frames(2)
	check(camera._navigation_locked and is_zero_approx(camera._orbit_velocity), "Opening settings did not clear the previous camera gesture")
	check(page.visible and page.sections.size() == 3, "Reopening did not restore real settings")
	await click_setting(page, page.get_node("Panel/Margin/Layout/Header/Back"))
	check(not page.visible and get_tree().paused, "Back resumed the game")
	var old_size := camera.size
	wheel.position = Vector2(10, 10)
	get_viewport().push_input(wheel, true)
	await frames(2)
	check(camera.size != old_size, "Camera navigation did not resume in the pause menu")
	TranslationServer.set_locale(locale)
	# Restart a live wave at 4x with altered instance state, rather than an empty level.
	hud.set_paused(false)
	scene._on_start_requested()
	scene._process(1.5)
	wave._process(0.0)
	shop.coins = 750
	hud.cycle_speed()
	hud.cycle_speed()
	check(wave.active and not wave.living_enemies().is_empty(), "Restart fixture did not start a live wave")
	hud.set_paused(true)
	check(get_tree().paused and Engine.time_scale == 0.0, "Live 4x wave did not pause immediately")
	get_tree().set_meta(RESTART_STATE, {"failures": failures, "scene_id": scene.get_instance_id()})
	await click(hud.restart_button)
	if not is_inside_tree(): return
	await frames(30)
	check(false, "Restart action did not reload the current scene")
	get_tree().quit(1)
