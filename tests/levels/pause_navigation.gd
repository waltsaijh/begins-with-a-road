extends Node
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited

var failures := 0
var _viewport: SubViewport
var timings: Array[float] = []

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	_viewport.push_input(event, true)

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_viewport.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_viewport.push_input(click, true)
	click.pressed = false
	_viewport.push_input(click, true)

func finish_pause(hud: CanvasLayer) -> void:
	if hud._pause_motion != null and hud._pause_motion.is_running(): await hud._pause_motion.finished
	await frames(1)

func health_sample(camera: Camera3D, head: Vector3, bar_size: Vector2) -> Vector2i:
	var origin := (camera.unproject_position(head)-bar_size*Vector2(0.5, 1.0)).round()
	return Vector2i(origin+Vector2(8, bar_size.y*0.5))

func is_health_pixel(image: Image, point: Vector2i, color: Color) -> bool:
	if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point): return false
	return image.get_pixelv(point).is_equal_approx(color)

func verify() -> void:
	_viewport = TestViewport.new()
	_viewport.size = Vector2i(1152, 648)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.level = scene.level.duplicate(true)
	scene.level.auto_start = false
	_viewport.add_child(scene)
	await frames(15)
	while scene.get_node("PortalMap").computing: await frames(1)
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	var cards: Node3D = scene.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	var camera: Camera3D = scene.get_node("Camera3D")
	var wave: Node = scene.get_node("EnemyWave")
	cards.select_card(0)
	var selected: int = cards.selected
	var original_hand_color: Color = cards.hand.get_node("Cards").modulate
	for speed: float in [1.0, 2.0, 4.0]:
		while hud.SPEEDS[hud.speed_index] != speed: hud.cycle_speed()
		var remaining: float = scene.preparation_remaining
		var started := Time.get_ticks_usec()
		hud.set_paused(true)
		check(hud.pause_requested and cards.pause_locked and not cards.towers.input_enabled and not get_tree().paused, "Pause did not lock input before starting the ramp")
		key(KEY_R)
		key(KEY_2)
		check(cards.selected == selected and cards.turns == 0, "Gameplay keys changed selection during deceleration")
		check(cards.place_selected(Vector3i(5, 0, 2)) == null, "Placement was allowed during deceleration")
		var last := speed
		var intermediate := false
		while not get_tree().paused and Time.get_ticks_usec()-started < 1000000:
			await frames(1)
			check(Engine.time_scale <= last+0.00001, "Pause ramp increased simulation speed")
			intermediate = intermediate or (Engine.time_scale > 0 and Engine.time_scale < speed)
			last = Engine.time_scale
		var milliseconds := float(Time.get_ticks_usec()-started)/1000.0
		timings.append(milliseconds)
		check(intermediate and milliseconds >= 210.0 and milliseconds < 450.0, "Pause did not decelerate over 0.25 real seconds independently of speed")
		check(get_tree().paused and Engine.time_scale == 0.0 and scene.preparation_remaining < remaining, "Pause did not allow the slow-down then freeze at zero delta")
		check(is_equal_approx(hud.pause_menu.modulate.a, 1.0), "Pause menu did not fade in while simulation slowed to zero")
		var frozen: float = scene.preparation_remaining
		var size_before := camera.size
		var wheel := InputEventMouseButton.new()
		wheel.position = Vector2(500, 300)
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		_viewport.push_input(wheel, true)
		check(is_equal_approx(camera.size, size_before/pow(1.12, wheel.factor)), "Paused camera could not zoom or handled one wheel event twice")
		var focus_before: Vector3 = camera.focus
		var drag := InputEventMouseMotion.new()
		drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
		drag.position = Vector2(560, 320)
		drag.relative = Vector2(60, 20)
		_viewport.push_input(drag, true)
		check(not camera.focus.is_equal_approx(focus_before), "Paused camera could not pan")
		click_at(cards.hand.views[1].get_global_transform_with_canvas()*(cards.hand.views[1].size*0.5))
		wave.controls.spawn_requested.emit()
		await frames(3)
		check(scene.preparation_remaining == frozen and cards.selected == selected and not scene._wave_starting, "Camera/input during pause changed gameplay")
		hud.set_paused(false)
		check(not get_tree().paused and Engine.time_scale == speed and not cards.pause_locked and cards.selected == selected, "Resume did not restore speed and the previous card selection")
		check(cards.hand.get_node("Cards").modulate == original_hand_color, "Resume did not restore card opacity")
		check(hud.pause_menu.visible and hud.resume_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Resume did not start a non-interactive menu fade-out")
		await frames(3)
		check(hud.pause_menu.modulate.a > 0.0 and hud.pause_menu.modulate.a < 1.0, "Menu fade-out snapped or used scaled game time")
		if hud._pause_menu_motion.is_running(): await hud._pause_menu_motion.finished
		check(not hud.pause_menu.visible and is_zero_approx(hud.pause_menu.modulate.a), "Pause menu did not hide at the end of its fade-out")
	# Build an affordable shop state so transaction rejection exercises the pause lock.
	shop.available = shop._deal()
	shop.coins = 1000
	shop._refresh()
	shop.view.set_available(true)
	shop.open_shop()
	shop.view.finish_animation()
	var coins: int = shop.coins
	var deals: int = shop.deals
	hud.set_paused(true)
	check(not shop.buy(0) and not shop.reroll() and shop.coins == coins and shop.deals == deals, "Shop changed during the pause ramp")
	await finish_pause(hud)
	check(not shop.buy(0) and not shop.reroll() and shop.view.opened, "Paused shop allowed transactions or lost its open state")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_viewport.get_texture().get_image().save_png("res://reports/levels/pause_navigation.png")
	var chosen: int = hud.speed_index
	hud.cycle_speed()
	check(Engine.time_scale == 0.0 and get_tree().paused and hud.speed_index != chosen, "Changing selected speed restarted paused simulation")
	key(KEY_ESCAPE)
	check(not hud.pause_requested and not get_tree().paused and Engine.time_scale == hud.SPEEDS[hud.speed_index], "Escape failed to resume from zero delta")
	shop.close_shop()
	# Resuming mid-ramp must cancel the pending freeze, even after its old deadline.
	hud.set_paused(true)
	await frames(1)
	hud.set_paused(false)
	await get_tree().create_timer(0.35, true, false, true).timeout
	check(not get_tree().paused and not hud.pause_requested and Engine.time_scale == hud.SPEEDS[hud.speed_index], "Cancelled pause tween froze a resumed game")
	# Freeze real enemies, then inspect rendered health pixels after actual navigation.
	scene.get_node("TowerMap").combat.enabled = false
	scene._begin_wave_start(false)
	scene._process(2.0)
	wave._process(0.0)
	check(wave.active and not wave.living_enemies().is_empty(), "Could not prepare enemies for paused health projection")
	hud.set_paused(true)
	await finish_pause(hud)
	var unit: Node3D = wave.living_enemies()[0]
	var frozen_position := unit.global_position
	var slot: int = wave.visuals._slots[unit]
	var head: Vector3 = wave.visuals.head_positions[slot]
	camera.focus = head
	camera.size = 8.0
	camera.update_pose()
	var overlay: Control = wave.visuals.status_overlay
	check(overlay.can_process(), "Health overlay stopped projecting while gameplay was paused")
	var bar_size: Vector2 = overlay.appearance.size
	var health_color: Color = overlay.appearance.get_node("Health").color
	await frames(3)
	var old_pixel := health_sample(camera, head, bar_size)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(is_health_pixel(_viewport.get_texture().get_image(), old_pixel, health_color), "Health bar did not appear above the frozen enemy")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	motion.position = Vector2(620, 340)
	motion.relative = Vector2(120, 40)
	_viewport.push_input(motion, true)
	await frames(3)
	var moved_pixel := health_sample(camera, head, bar_size)
	check(moved_pixel.distance_to(old_pixel) > 50, "Camera pan did not move the health projection")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		check(is_health_pixel(image, moved_pixel, health_color) and not is_health_pixel(image, old_pixel, health_color), "Paused health bar stayed at its old screen position after panning")
	var zoom := InputEventMouseButton.new()
	zoom.position = motion.position
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	_viewport.push_input(zoom, true)
	await frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		check(is_health_pixel(image, health_sample(camera, head, bar_size), health_color), "Paused health bar did not follow zoom")
		image.save_png("res://reports/levels/paused_enemy_navigation.png")
	check(unit.global_position == frozen_position and get_tree().paused and Engine.time_scale == 0, "Reprojecting health bars advanced gameplay")
	hud.set_paused(false)
	print("PAUSE_NAVIGATION_CHECK:"+JSON.stringify({"failures": failures, "ramp_ms_at_1x_2x_4x": timings, "immediate_input_lock": true, "paused_zoom_and_pan": true, "paused_health_projection": true, "menu_fades": true, "shop_locked": true, "resume_selection": true, "rapid_toggle": true}))
	get_tree().quit(1 if failures else 0)
