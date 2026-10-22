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
		check(scene.get_node("TowerMap").relics.held.is_empty(), "Restart retained acquired relics")
		check(not get_tree().paused and Engine.time_scale == 1.0 and hud.speed_index == 0 and not hud.pause_menu.visible and not cards.pause_locked, "Restart retained pause or speed state")
		print("PAUSE_MENU_CHECK:"+JSON.stringify({"failures": failures, "hover_shift_scale": true, "stable_hit_area": true, "no_underline": true, "settings_placeholder": true, "restart_live_level": true, "translations": true}))
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
		check(button.can_process() and button.get_theme_stylebox("hover") is StyleBoxEmpty and button.get_theme_stylebox("focus") is StyleBoxEmpty, "Menu item stopped processing or retained an underline")
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
	check(is_zero_approx(button.position.x) and button.scale.is_equal_approx(Vector2.ONE), "Leaving hover did not slide right and restore size")
	var progress: float = scene.timeline.progress
	var coins: int = shop.coins
	await click(hud.settings_button)
	await frames(3)
	check(hud.pause_requested and get_tree().paused and hud.pause_menu.visible and not scene._wave_starting and scene.timeline.progress == progress and shop.coins == coins, "Settings placeholder changed gameplay or left the pause menu")
	# Restart a live wave at 4x with altered instance state, rather than an empty level.
	hud.set_paused(false)
	scene._on_start_requested()
	scene._process(1.5)
	wave._process(0.0)
	shop.coins = 750
	var relics: RunRelics = scene.get_node("TowerMap").relics
	check(relics.acquire(relics.catalog.find(&"protagonist")), "Restart fixture did not acquire a relic")
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
