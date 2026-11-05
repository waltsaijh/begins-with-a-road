extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
const TestLevel = preload("res://tests/levels/road_flow_fixture.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited

var failures := 0
var _viewport: SubViewport

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func motion(point: Vector2, relative := Vector2.ZERO, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	event.button_mask = mask
	_viewport.push_input(event, true)

func left(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_viewport.push_input(event, true)

func right(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	_viewport.push_input(event, true)

func click(button: Button) -> void:
	var point := button.get_global_transform_with_canvas()*(button.size*0.5)
	motion(point)
	left(point, true)
	left(point, false)

func verify() -> void:
	_viewport = TestViewport.new()
	_viewport.size = Vector2i(1152, 648)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.level = TestLevel.level()
	scene.get_node("CardPlacement").cards = TestCards.starting_hand()
	_viewport.add_child(scene)
	await frames(12)
	while scene.get_node("PortalMap").computing: await frames(1)
	var camera: Camera3D = scene.get_node("Camera3D")
	camera.maximum_orbit_speed = 180.0
	camera.orbit_smoothing_seconds = 0.15
	var map: GridMap = scene.get_node("TileMap")
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	var cells := map.get_used_cells()
	var map_transform := map.global_transform
	var pivot: Vector3 = camera.focus
	var size_before := camera.size
	var elevation: float = camera.elevation
	var distance_before: float = camera.global_position.distance_to(pivot)
	var angle_before: float = camera.azimuth
	var center := camera.unproject_position(pivot)
	var start := center+Vector2(180, 0)
	motion(start)
	right(start, true)
	check(camera._orbit_press != null and not camera._orbiting, "Press did not wait to distinguish click from drag")
	motion(start+Vector2(1, 1), Vector2(1, 1), MOUSE_BUTTON_MASK_RIGHT)
	check(is_equal_approx(camera.azimuth, angle_before), "Tiny click jitter rotated the map")
	# A fast pointer input targets the cap, while actual speed eases toward it.
	motion(center+Vector2(0, 180), Vector2(-180, 180), MOUSE_BUTTON_MASK_RIGHT)
	check(is_equal_approx(camera.azimuth, angle_before), "Mouse events bypassed the maximum rotation speed")
	camera._advance_orbit(0.1)
	check(camera._orbit_target_velocity == deg_to_rad(180.0) and camera._orbit_velocity > 0.0 and camera._orbit_velocity < deg_to_rad(180.0), "Current speed did not smoothly approach the capped target")
	check(wrapf(camera.azimuth-angle_before, -PI, PI) > 0.0 and wrapf(camera.azimuth-angle_before, -PI, PI) < deg_to_rad(18.0), "Acceleration bypassed the speed cap")
	var release_angle: float = camera.azimuth
	right(center+Vector2(0, 180), false)
	check(is_zero_approx(camera._orbit_input_angle), "Releasing retained queued circles")
	var release_speed: float = camera._orbit_velocity
	var previous_speed := absf(release_speed)
	for i in 3:
		camera._advance_orbit(0.05)
		check(absf(camera._orbit_velocity) < previous_speed, "Release speed did not smoothly decrease")
		previous_speed = absf(camera._orbit_velocity)
	check(absf(camera._orbit_velocity) <= absf(release_speed)*0.01001 and camera._orbit_target_velocity == 0.0, "Release did not use the same velocity response toward zero")
	camera._advance_orbit(1.0)
	var stop_angle: float = camera.azimuth
	check(stop_angle > release_angle and is_zero_approx(camera._orbit_velocity), "Velocity did not settle completely")
	check(absf(stop_angle-release_angle-release_speed*0.15/log(100.0)) < 0.00001, "Release travel did not match the velocity transition")
	camera._advance_orbit(3.0)
	check(is_equal_approx(camera.azimuth, stop_angle), "Release continued rotating after settling")
	camera._stop_orbit()
	motion(start)
	right(start, true)
	var speed_point := start
	for i in 6:
		var point := center+Vector2.from_angle((i+1)*PI/60.0)*180.0
		motion(point, point-speed_point, MOUSE_BUTTON_MASK_RIGHT)
		var speed_before: float = camera._orbit_velocity
		camera._advance_orbit(1.0/60.0)
		check(camera._orbit_velocity > speed_before and camera._orbit_velocity < deg_to_rad(180.0), "Continuous input did not accelerate smoothly")
		speed_point = point
	var backwards := center+Vector2.from_angle(5.0*PI/60.0)*180.0
	motion(backwards, backwards-speed_point, MOUSE_BUTTON_MASK_RIGHT)
	var forward_speed: float = camera._orbit_velocity
	camera._advance_orbit(1.0/60.0)
	check(camera._orbit_target_velocity < 0.0 and camera._orbit_velocity < forward_speed and camera._orbit_velocity > camera._orbit_target_velocity, "Reversal snapped to the opposite target speed")
	var held_speed: float = absf(camera._orbit_velocity)
	camera._advance_orbit(0.1)
	check(camera._orbit_target_velocity == 0.0 and absf(camera._orbit_velocity) < held_speed, "Stopping the pointer while held retained a nonzero target or backlog")
	camera._stop_orbit()
	camera.azimuth = angle_before
	camera.update_pose()
	motion(start)
	right(start, true)
	var total_angle := 0.0
	var previous := start
	for step in range(1, 49):
		var point := center+Vector2.from_angle(TAU*step/48.0)*180.0
		var before: float = camera.azimuth
		motion(point, point-previous, MOUSE_BUTTON_MASK_RIGHT)
		camera._advance_orbit(1.0/24.0)
		total_angle += wrapf(camera.azimuth-before, -PI, PI)
		previous = point
	var settle_before: float = camera.azimuth
	camera._advance_orbit(1.0)
	total_angle += wrapf(camera.azimuth-settle_before, -PI, PI)
	right(previous, false)
	camera._stop_orbit()
	check(is_equal_approx(total_angle, TAU), "Clockwise circle did not rotate exactly one full turn")
	check(camera.focus.is_equal_approx(pivot) and is_equal_approx(camera.elevation, elevation) and is_equal_approx(camera.size, size_before), "Orbit changed its pivot, pitch or zoom")
	check(is_equal_approx(camera.global_position.distance_to(pivot), distance_before), "Orbit changed the camera distance")
	# Reverse rotation with a changing radius must retain the same angle ratio.
	motion(start)
	right(start, true)
	total_angle = 0.0
	previous = start
	for step in range(1, 49):
		var point := center+Vector2.from_angle(-TAU*step/48.0)*(180.0+sin(step*0.4)*35.0)
		var before: float = camera.azimuth
		motion(point, point-previous, MOUSE_BUTTON_MASK_RIGHT)
		camera._advance_orbit(1.0/24.0)
		total_angle += wrapf(camera.azimuth-before, -PI, PI)
		previous = point
	var reverse_settle: float = camera.azimuth
	camera._advance_orbit(1.0)
	total_angle += wrapf(camera.azimuth-reverse_settle, -PI, PI)
	right(previous, false)
	camera._stop_orbit()
	check(is_equal_approx(total_angle, -TAU), "Reverse/variable-radius circle lost its angular ratio")
	# Multiple fast circles produce one capped velocity sample, not a backlog.
	motion(start)
	right(start, true)
	var fast_angle: float = camera.azimuth
	for step in range(1, 97):
		motion(center+Vector2.from_angle(TAU*step/48.0)*180.0, Vector2.ZERO, MOUSE_BUTTON_MASK_RIGHT)
	check(is_equal_approx(camera._orbit_input_angle, TAU*2.0) and is_equal_approx(camera.azimuth, fast_angle), "Rapid two-turn input was lost or applied without a speed limit")
	camera._advance_orbit(0.25)
	check(wrapf(camera.azimuth-fast_angle, -PI, PI) < PI/4 and is_zero_approx(camera._orbit_input_angle) and camera._orbit_velocity <= deg_to_rad(180.0), "Fast input exceeded the speed cap or retained old circles")
	var fast_release: float = camera.azimuth
	right(start, false)
	camera._advance_orbit(4.0)
	check(is_zero_approx(camera._orbit_input_angle) and is_zero_approx(camera._orbit_velocity) and absf(wrapf(camera.azimuth-fast_release, -PI, PI)) <= deg_to_rad(180.0)*0.15/3.0+0.00001, "Queued circles prolonged the short release tail")
	# Terrain is now a valid starting surface, including while holding a card.
	var ground := camera.unproject_position(map.to_global(map.map_to_local(cells[cells.size()/2])))
	motion(ground)
	right(ground, true)
	motion(ground+Vector2(60, 60), Vector2(60, 60), MOUSE_BUTTON_MASK_RIGHT)
	check(camera._orbiting, "Ground dragging did not start an orbit")
	# Crossing a UI button must retain the drag and consume its release.
	var ui_point: Vector2 = hud.speed_button.get_global_rect().get_center()
	motion(ui_point, Vector2(30, 0), MOUSE_BUTTON_MASK_RIGHT)
	right(ui_point, false)
	await frames()
	check(not camera._orbiting and hud.speed_index == 0, "Releasing an orbit over UI activated a button or retained capture")
	camera._advance_orbit(10.0)
	var released: float = camera.azimuth
	motion(start, Vector2(40, 0), MOUSE_BUTTON_MASK_RIGHT)
	check(is_equal_approx(camera.azimuth, released), "A released drag kept rotating")
	click(hud.speed_button)
	await frames()
	check(hud.speed_index == 1 and is_equal_approx(camera.azimuth, released), "A normal UI click was intercepted by orbit")
	while hud.speed_index != 0: hud.cycle_speed()
	# Dragging from a non-card button rotates without activating it.
	motion(ui_point)
	right(ui_point, true)
	motion(ui_point+Vector2(-70, 50), Vector2(-70, 50), MOUSE_BUTTON_MASK_RIGHT)
	camera._advance_orbit(0.1)
	right(ui_point+Vector2(-70, 50), false)
	await frames()
	check(hud.speed_index == 0 and not is_equal_approx(camera.azimuth, released), "A non-card UI drag activated the control or could not rotate")
	motion(center)
	right(center, true)
	var center_angle: float = camera.azimuth
	motion(center+Vector2(8, 0), Vector2(8, 0), MOUSE_BUTTON_MASK_RIGHT)
	motion(center+Vector2(-8, 0), Vector2(-16, 0), MOUSE_BUTTON_MASK_RIGHT)
	right(center+Vector2(-8, 0), false)
	check(is_equal_approx(camera.azimuth, center_angle), "Crossing the center dead zone flipped the camera")
	camera._advance_orbit(10.0)
	check(map.get_used_cells() == cells and map.global_transform == map_transform, "Orbit moved or rebuilt the logical terrain")
	hud.set_paused(true)
	await frames(2)
	var progress: float = scene.timeline.progress
	motion(start)
	right(start, true)
	var paused_angle: float = camera.azimuth
	motion(center+Vector2(0, 180), Vector2(-180, 180), MOUSE_BUTTON_MASK_RIGHT)
	await get_tree().create_timer(0.1, true, false, true).timeout
	right(center+Vector2(0, 180), false)
	check(not is_equal_approx(camera.azimuth, paused_angle) and get_tree().paused and Engine.time_scale == 0.0, "Paused orbit stopped working or resumed gameplay")
	check(scene.timeline.progress == progress and not scene._wave_starting, "Paused orbit changed gameplay")
	var menu_angle: float = camera.azimuth
	click(hud.settings_button)
	await frames()
	check(hud.pause_requested and not camera._orbiting and is_equal_approx(camera.azimuth, menu_angle), "A pause-menu click started an orbit")
	check(hud.settings_page.visible and camera._navigation_locked, "Settings did not acquire the camera lock")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_viewport.push_input(escape, true)
	await frames()
	check(not hud.settings_page.visible and hud.pause_requested and not camera._navigation_locked, "Esc did not return from settings to normal paused navigation")
	click(hud.resume_button)
	await frames()
	check(not get_tree().paused and not hud.pause_requested, "Orbit routing blocked the resume button")
	motion(start)
	right(start, true)
	_viewport.mouse_exited.emit()
	check(not camera._orbiting and camera._orbit_press == null, "Leaving the viewport did not cancel orbit")
	_viewport.mouse_entered.emit()
	camera._stop_orbit()
	# Exercise real card clicks in the same viewport after orbiting.
	camera.azimuth = deg_to_rad(30.0)
	camera.update_pose()
	var cards: Node = scene.get_node("CardPlacement")
	click(cards.hand.views[0])
	await frames()
	check(cards.selected == 0 and not camera._orbiting, "Orbit intercepted a hand-card click")
	var before_turns: int = cards.turns
	var before_click_focus: Vector3 = camera.focus
	motion(start)
	right(start, true)
	motion(start+Vector2.ONE, Vector2.ONE, MOUSE_BUTTON_MASK_RIGHT)
	check(cards.turns == before_turns and camera.focus.is_equal_approx(before_click_focus), "Right press or tiny jitter rotated a card or panned")
	right(start+Vector2.ONE, false)
	await frames()
	check(cards.turns == posmod(before_turns+1,4) and camera.focus.is_equal_approx(before_click_focus), "A right click did not rotate the selected card exactly once")
	cards.rotate_card(-1)
	var before_right_angle: float = camera.azimuth
	right(start,true)
	motion(start+Vector2(60,20),Vector2(60,20),MOUSE_BUTTON_MASK_RIGHT)
	camera._advance_orbit(0.1)
	right(start+Vector2(60,20),false)
	await frames()
	check(camera.focus.is_equal_approx(before_click_focus) and not is_equal_approx(camera.azimuth,before_right_angle) and cards.turns == before_turns and cards.selected == 0, "Right orbit changed the focus or rotated/cancelled the selected card")
	camera._stop_navigation()
	camera.azimuth = before_right_angle
	camera.focus = before_click_focus
	camera.update_pose()
	var placement_point := Vector2(-1, -1)
	for cell in map.get_used_cells():
		var point := camera.unproject_position(map.to_global(map.map_to_local(cell)))
		if not Rect2(Vector2(20, 100), Vector2(1050, 300)).has_point(point): continue
		if cards.towers.validate_card(cards.cards[0], cell, 0).is_empty():
			motion(point)
			await frames(2)
			if _viewport.gui_get_hovered_control() != null: continue
			placement_point = point
			break
	check(placement_point.x >= 0, "Could not find a valid card-placement fixture")
	if placement_point.x >= 0:
		motion(placement_point)
		await frames(3)
		check(cards.preview.visible, "Card preview disappeared after orbiting")
		var count: int = cards.cards.size()
		left(placement_point, true)
		motion(placement_point+Vector2(50, 40), Vector2(50, 40), MOUSE_BUTTON_MASK_LEFT)
		left(placement_point+Vector2(50, 40), false)
		await frames()
		check(cards.cards.size() == count and cards.selected == 0, "Dragging while holding a card placed it")
		camera._stop_orbit()
		camera.focus = before_click_focus
		camera.azimuth = deg_to_rad(30.0)
		camera.update_pose()
		motion(placement_point)
		left(placement_point, true)
		left(placement_point, false)
		await frames()
		check(cards.cards.size() == count-1 and not camera._orbiting, "Orbit intercepted card placement")
	# Card fronts and deck/reroll backs retain their input, even when disabled.
	var card: Button = cards.hand.views[0]
	var card_point := card.get_global_transform_with_canvas()*(card.size*0.5)
	card.disabled = true
	motion(card_point)
	left(card_point, true)
	motion(card_point+Vector2(70, -40), Vector2(70, -40), MOUSE_BUTTON_MASK_LEFT)
	check(camera._pan_press == null and camera._orbit_press == null, "A disabled card started camera dragging")
	left(card_point+Vector2(70, -40), false)
	card.disabled = false
	var shop: Node = cards.get_node("Shop")
	shop._on_wave_started()
	shop._on_wave_finished()
	shop.view.finish_animation()
	var back: Button = shop.view.slots.back().get_node("Face/Back")
	var back_point := back.get_global_transform_with_canvas()*(back.size*0.5)
	check(back.is_visible_in_tree() and camera._over_card(back_point), "Shop deck back is not excluded from left panning")
	click(back)
	await frames(2)
	shop.view.finish_animation()
	check(shop.view.opened, "Card exclusion blocked opening the shop")
	var reroll: Button = shop.view.slots[0].get_node("Face/Back")
	var reroll_point := reroll.get_global_transform_with_canvas()*(reroll.size*0.5)
	var coins: int = shop.coins
	var middle_press := InputEventMouseButton.new()
	middle_press.button_index = MOUSE_BUTTON_MIDDLE
	middle_press.pressed = true
	middle_press.position = center
	_viewport.push_input(middle_press,true)
	var before_middle: Vector3 = camera.focus
	motion(center+Vector2(50,20),Vector2(50,20),MOUSE_BUTTON_MASK_MIDDLE)
	middle_press.pressed = false
	_viewport.push_input(middle_press,true)
	check(camera.focus.is_equal_approx(before_middle), "Middle dragging still pans the camera")
	# Pan through actual GUI cards: both the first crossing and motion within
	# the shop must reach camera input before the GUI can swallow them.
	camera.focus = camera._initial_focus
	camera.update_pose()
	var pan_start := Vector2(360,230)
	motion(pan_start)
	left(pan_start, true)
	var before_pan: Vector3 = camera.focus
	motion(reroll_point, Vector2(0, 120), MOUSE_BUTTON_MASK_LEFT)
	check(not camera.focus.is_equal_approx(before_pan), "Left drag stopped when entering the shop cards")
	var inside_pan: Vector3 = camera.focus
	motion(reroll_point+Vector2(20, 0), Vector2(20, 0), MOUSE_BUTTON_MASK_LEFT)
	check(not camera.focus.is_equal_approx(inside_pan), "Left drag stopped while moving across a shop card")
	left(reroll_point+Vector2(20, 0), false)
	var released_pan: Vector3 = camera.focus
	motion(reroll_point+Vector2(40, 0), Vector2(20, 0))
	check(camera.focus.is_equal_approx(released_pan) and shop.coins == coins and shop.view.opened, "Left release kept panning or activated a shop card")
	# Right orbit starts even over a card, without activating its left action.
	var card_orbit_angle: float = camera.azimuth
	right(reroll_point, true)
	motion(reroll_point+Vector2(0, -40), Vector2(0, -40), MOUSE_BUTTON_MASK_RIGHT)
	camera._advance_orbit(0.1)
	right(reroll_point+Vector2(0, -40), false)
	check(camera.focus.is_equal_approx(released_pan) and not is_equal_approx(camera.azimuth,card_orbit_angle) and shop.coins == coins and shop.view.opened, "Right dragging a shop card did not orbit safely")
	camera._stop_navigation()
	# Losing focus or leaving the viewport must discard the held pan gesture.
	for lose_focus in [false,true]:
		left(pan_start,true)
		if lose_focus: camera.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		else: _viewport.mouse_exited.emit()
		var stopped_focus: Vector3 = camera.focus
		motion(pan_start+Vector2(20,20),Vector2(20,20),MOUSE_BUTTON_MASK_LEFT)
		left(pan_start+Vector2(20,20),false)
		check(camera._pan_press == null and camera.focus.is_equal_approx(stopped_focus), "Cancelled left dragging restarted without a new press")
		_viewport.mouse_entered.emit()
	camera.focus = camera._initial_focus
	camera.update_pose()
	motion(reroll_point)
	left(reroll_point, true)
	motion(reroll_point+Vector2(180, -100), Vector2(180, -100), MOUSE_BUTTON_MASK_LEFT)
	check(camera._pan_press == null and camera._orbit_press == null, "Reroll-card dragging moved the camera")
	left(reroll_point+Vector2(180, -100), false)
	await frames()
	check(shop.coins == coins and shop.view.opened, "Dragging off the reroll card spent coins or closed the shop")
	motion(center)
	left(center, true)
	motion(center+Vector2(50, 50), Vector2(50, 50), MOUSE_BUTTON_MASK_LEFT)
	left(center+Vector2(50, 50), false)
	await frames()
	check(shop.view.opened, "Panning with the shop open closed it")
	motion(center)
	left(center, true)
	left(center, false)
	await frames(2)
	check(not shop.view.opened, "An ordinary outside click no longer closes the shop")
	shop.view.finish_animation()
	await frames(3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_viewport.get_texture().get_image().save_png(Artifacts.path("levels/camera_orbit.png"))
	var report := {"failures": failures, "maximum_speed": true, "left_pan_over_shop": true, "right_orbit_over_cards": true, "velocity_smoothing": true, "smooth_bounded_stop": true, "full_circle": true, "reverse_circle": true, "non_card_drag": true, "center_dead_zone": true, "fixed_pivot": true, "yaw_only": true, "ui_priority": true, "click_vs_drag": true, "card_exclusion": true, "capture_and_release": true, "paused": true, "terrain_unchanged": true}
	FileAccess.open(Artifacts.path("levels/camera_orbit.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CAMERA_ORBIT_CHECK:"+JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
