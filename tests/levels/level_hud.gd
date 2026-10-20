extends Node
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func finish_pause(hud: CanvasLayer) -> void:
	check(hud.pause_requested and hud.pause_menu.visible, "Pause request did not immediately open its menu")
	if hud._pause_motion != null and hud._pause_motion.is_running(): await hud._pause_motion.finished
	await frames(1)
	check(get_tree().paused and is_zero_approx(Engine.time_scale), "Pause ramp did not finish at zero simulation delta")

func finish_menu_fade(hud: CanvasLayer) -> void:
	if hud._pause_menu_motion != null and hud._pause_menu_motion.is_running(): await hud._pause_menu_motion.finished
	await frames(1)

func click(button: Button) -> void:
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
		await frames(1)
	else:
		await click_at(button.get_global_transform_with_canvas()*(button.size*0.5))

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await frames(1)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)
	await frames(1)

func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func verify() -> void:
	var scene: Node3D = load("res://scenes/level.tscn").instantiate()
	add_child(scene)
	for i in 120:
		if not scene.get_node("PortalMap").computing: break
		await frames(1)
	await frames()
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	if hud._callout_motion != null and hud._callout_motion.is_running(): await hud._callout_motion.finished
	await frames(1)
	var wave: Node = scene.get_node("EnemyWave")
	var cards: Node = scene.get_node("CardPlacement")
	scene.get_node("TowerMap").combat.enabled = false
	check(hud.process_mode == Node.PROCESS_MODE_ALWAYS and not get_tree().paused and Engine.time_scale == 1, "HUD did not start unpaused at 1x")
	var buttons: Array[Button] = [hud.speed_button, hud.pause_button]
	check(hud.early_start == wave.controls.spawn_button and not hud.pause_menu.visible, "HUD did not retain the start action or hide the pause menu")
	check(hud.early_start.get_parent() == hud.get_node("WorldActions") and hud.early_start.is_visible_in_tree(), "Early start is not displayed at the first entrance")
	var camera: Camera3D = scene.get_node("Camera3D")
	var anchor: Vector2 = camera.unproject_position(scene.get_node("Start").global_position+Vector3.UP*hud.start_anchor_height)
	check(is_equal_approx(hud.early_start.get_global_rect().get_center().x, anchor.x) and is_equal_approx(hud.early_start.get_global_rect().end.y, anchor.y-hud.start_anchor_gap), "Callout pointer does not align with the initial start")
	var old_focus: Vector3 = camera.focus
	var old_position: Vector2 = hud.early_start.position
	camera.focus += Vector3(1, 0, 0)
	camera.update_pose()
	hud._process(0)
	check(not hud.early_start.position.is_equal_approx(old_position), "Callout did not follow camera movement")
	camera.focus = old_focus
	camera.update_pose()
	hud._process(0)
	var rect: Rect2 = hud.early_start.get_global_rect()
	camera.pan(Vector2.ZERO, Vector2(-rect.position.x-4.0, 0))
	hud._process(0)
	check(hud.early_start.get_global_rect().position.x < 0 and hud.early_start.visible, "A partially clipped callout disappeared while panning")
	camera.pan(Vector2.ZERO, Vector2(-hud.early_start.size.x-40.0, 0))
	hud._process(0)
	check(not hud.early_start.visible, "Completely offscreen callout remained visible")
	camera.focus = old_focus
	camera.update_pose()
	hud._process(0)
	check(hud.early_start.get_node_or_null("Reward") == null, "Callout still shows a bonus preview")
	await screenshot("res://reports/levels/wave_start_callout.png")
	if DisplayServer.get_name() != "headless":
		var hover := InputEventMouseMotion.new()
		hover.position = hud.early_start.get_global_rect().get_center()
		Input.parse_input_event(hover)
		await frames(12)
		check(hud.early_start.hover_amount > 0.8 and hud.early_start.scale.x > 1.0, "Hover did not tint/lift/enlarge the callout")
		await screenshot("res://reports/levels/wave_start_callout_hover.png")
		hover.position = Vector2(1, 1)
		Input.parse_input_event(hover)
		await frames(12)
	for i in buttons.size()-1:
		check(buttons[i].get_global_rect().end.x < buttons[i+1].get_global_rect().position.x and is_equal_approx(buttons[i].get_global_rect().get_center().y, buttons[i+1].get_global_rect().get_center().y), "Header actions do not form one horizontal row")
	for speed in [2, 4, 1]:
		await click(hud.speed_button)
		check(Engine.time_scale == speed and hud.speed_button.text.is_empty() and hud.speed_button.icon == hud.SPEED_ICONS[hud.speed_index], "Speed button did not cycle 1x/2x/4x icons")
	await click(hud.pause_button)
	await finish_pause(hud)
	check(get_tree().paused and hud.pause_menu.visible and hud.early_start.disabled, "Pause button did not freeze gameplay and open the menu")
	var remaining: float = scene.preparation_remaining
	var before_progress: float = scene.timeline.progress
	await frames(8)
	check(scene.preparation_remaining == remaining and scene.timeline.progress == before_progress, "Preparation/timeline kept advancing while paused")
	check(hud.resume_button.can_process() and hud.exit_button.can_process(), "Pause menu cannot receive input while paused")
	var menu: Control = hud.pause_menu.get_node("Menu")
	var viewport := get_viewport().get_visible_rect().size
	check(menu.get_global_rect().position.x > viewport.x*0.5 and menu.get_global_rect().position.y > viewport.y*0.5 and menu.get_global_rect().end.x <= viewport.x and menu.get_global_rect().end.y <= viewport.y, "Pause menu is not inside the bottom-right corner")
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_TW")
	await frames(1)
	check(hud.resume_button.text == "繼續遊戲" and hud.exit_button.text == "離開", "Pause menu Chinese labels are missing")
	check(hud.early_start.get_node("Title").text == "提早開始?", "Chinese callout label is wrong")
	TranslationServer.set_locale("en")
	await frames(1)
	check(hud.resume_button.text == "Resume game" and hud.exit_button.text == "Exit", "Pause menu English labels are missing")
	check(hud.early_start.get_node("Title").text == "Start Now?", "English callout label is wrong")
	TranslationServer.set_locale(locale)
	if DisplayServer.get_name() != "headless":
		var selected: int = cards.selected
		await click_at(cards.hand.views[0].get_global_transform_with_canvas()*(cards.hand.views[0].size*0.5))
		check(cards.selected == selected and get_tree().paused, "Pause menu allowed a card underneath to be selected")
	await screenshot("res://reports/levels/level_paused.png")
	check(hud.speed_button.disabled and hud.pause_button.disabled, "Pause did not disable both header actions")
	await click(hud.speed_button)
	if DisplayServer.get_name() != "headless":
		check(not hud.speed_button.is_hovered(), "Disabled speed button still reacts to hover")
		await click(hud.pause_button)
		check(not hud.pause_button.is_hovered(), "Disabled pause button still reacts to hover")
	check(hud.SPEEDS[hud.speed_index] == 1 and Engine.time_scale == 0 and get_tree().paused, "Disabled header actions changed speed or resumed the game")
	await click(hud.resume_button)
	await finish_menu_fade(hud)
	check(not get_tree().paused and not hud.pause_menu.visible and Engine.time_scale == 1 and not hud.early_start.disabled, "Resume lost speed or failed to restore the start action")
	check(not hud.speed_button.disabled and not hud.pause_button.disabled, "Resume did not restore the header actions")
	await frames()
	check(scene.preparation_remaining < remaining, "Preparation did not resume")
	# Freeze and resume the existing early-start transition without resetting it.
	var shop: Node = cards.get_node("Shop")
	var coins_before: int = shop.coins
	await click(hud.early_start)
	check(scene._wave_starting and hud.early_start.disabled and not hud._callout_available, "World start action did not start the transition/retract its callout")
	check(shop.coins > coins_before and shop.coins <= coins_before+scene.level.early_start_max_bonus, "Clicking the callout did not credit the shown bonus")
	var bonus_balance: int = shop.coins
	await click(hud.pause_button)
	await finish_pause(hud)
	var elapsed: float = scene._wave_start_elapsed
	var reveal: float = hud._callout_reveal
	await frames(8)
	check(scene._wave_start_elapsed == elapsed and not wave.active, "Early-start transition advanced while paused")
	check(hud._callout_reveal == reveal, "Callout retraction kept moving while paused")
	wave.controls.spawn_requested.emit()
	check(scene._wave_start_elapsed == elapsed, "Paused start action reset the transition")
	check(shop.coins == bonus_balance, "Repeated/paused start action granted extra coins")
	await click(hud.resume_button)
	check(hud.early_start.disabled and scene._wave_starting, "Resume re-enabled an already pending start")
	if hud._callout_motion != null and hud._callout_motion.is_running(): await hud._callout_motion.finished
	check(is_zero_approx(hud._callout_reveal) and not hud.early_start.visible, "Callout did not finish shrinking into the tower")
	scene._process(2.0)
	await frames()
	check(wave.active and not wave.living_enemies().is_empty(), "Wave did not start after resuming the transition")
	await click(hud.pause_button)
	await finish_pause(hud)
	var spawned: int = wave.spawned
	var units: Array[Node3D] = wave.living_enemies()
	var position: Vector3 = units[0].global_position
	var walk_phase: float = wave.visuals._poses[0].walk_phase
	await frames(8)
	check(wave.spawned == spawned and units[0].global_position == position and wave.visuals._poses[0].walk_phase == walk_phase, "Pause did not freeze spawning, enemies and animation")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	Input.parse_input_event(event)
	await frames()
	await finish_menu_fade(hud)
	check(not get_tree().paused and not hud.pause_menu.visible and hud.early_start.disabled, "Escape did not resume combat or incorrectly enabled start")
	# Finish this real wave and confirm that its next preparation restores the bubble.
	wave.set_process(false)
	while not wave._pending.is_empty(): wave._process(1000.0)
	for unit: Node3D in wave.living_enemies(): unit.take_damage(100000)
	scene.set_process(false)
	check(not wave.active and scene.current_wave == 1 and hud._callout_available, "Wave completion did not start the callout return")
	await frames(1)
	check(hud._callout_reveal > 0.0 and hud._callout_reveal < 1.0, "Callout return snapped instead of easing out")
	if hud._callout_motion != null and hud._callout_motion.is_running(): await hud._callout_motion.finished
	check(is_equal_approx(hud._callout_reveal, 1.0) and hud.early_start.visible, "Callout did not return above the tower")
	await screenshot("res://reports/levels/wave_start_callout_return.png")
	# The Exit action closes the test only after reporting its verification.
	await click(hud.pause_button)
	await finish_pause(hud)
	hud.cycle_speed()
	var exited := [false]
	hud.exit_requested.connect(func(): exited[0] = true)
	hud.exit_button.pressed.emit()
	check(exited[0] and not get_tree().paused and Engine.time_scale == 1, "Exit did not request closing and reset pause/speed")
	print("LEVEL_HUD_CHECK:"+JSON.stringify({"failures": failures, "speed_cycle": true, "button_row": true, "pause_menu": true, "pause_freezes_simulation": true, "input_blocked": true, "resume_preserves_speed": true, "early_start_pause": true, "exit": true}))
	get_tree().quit(1 if failures else 0)
