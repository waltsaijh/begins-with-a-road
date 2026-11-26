extends Node

const Fixture = preload("res://tests/fixtures/level_fixture.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	run.call_deferred()

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
	for i in 3: await get_tree().process_frame

func run() -> void:
	TranslationServer.set_locale("zh_TW")
	check(tr("spell.shot.name") == "射擊", "Localized spell card name")
	check(tr("spell.area_damage").contains("{damage}"), "Localized card effect")
	var level := Fixture.level("")
	level.opening_shop = true
	level.starting_gold = 40
	var recipe := level.acts[0].waves[0]
	recipe.groups[0].enemy_count = 3
	recipe.groups[0].troop = TroopCatalog.find("heavy")
	recipe.move_speed = 0.1
	level.acts[0].waves.append(recipe)
	var mixed: WaveDefinition = recipe.duplicate(true)
	var flying := WaveSpawnGroup.new()
	flying.troop = TroopCatalog.find("winged")
	flying.enemy_count = 1
	mixed.groups.append(flying)
	level.acts[0].waves.append(mixed)
	var session := preload("res://scenes/level.tscn").instantiate()
	session.level = level
	add_child(session)
	var cards: Node = session.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	var wave: Node = session.get_node("EnemyWave")
	var map: GridMap = session.get_node("TileMap")
	for i in 40: await get_tree().process_frame
	get_tree().root.propagate_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)
	get_viewport().mouse_entered.emit()
	var starting_count: int = cards.cards.size()
	check(wave.start_wave(), "Start first wave")
	for i in 3: await get_tree().process_frame
	check(cards.cards.size() == starting_count + 1 and not cards.hand.stowed, "One shot in the shared hand")
	cards.hand._idle_since = Time.get_ticks_msec()-2000
	cards.hand._process(0.0)
	check(cards.hand.folded and not cards.hand.stowed, "Idle combat hand folds into an accessible pile")
	cards.deal_commander_spells(0)
	check(cards.cards.size() == starting_count + 1, "Repeated start notification cannot deal again")
	cards.select_card(0)
	check(cards.selected == -1 and cards.hand.views[0].disabled, "Construction stays locked during combat")
	for enemy in wave.living_enemies(): enemy.take_damage(1000)
	for i in 4: await get_tree().process_frame
	cards.select_card(starting_count)
	check(cards.selected == -1, "Saved spell cannot be cast during preparation")
	shop.open_base_page()
	var coins: int = shop.coins
	var towers: Node = cards.towers
	for i in 5:
		check(not shop.upgrade_base("marksman"), "Below five towers")
		var where := Vector3i(15+i,0,5)
		var support: Array[Vector3i] = [where]
		cards.placement.add_cells(support)
		check(towers.place_tower(where) != null, "Deploy tower for upgrade")
	check(not shop.upgrade_base("wizard"), "Tower composition checked")
	check(not shop.view.has_node("BasePage/Center/Panel/Rows/Options/wizard"), "Ineligible upgrades are hidden")
	shop.view.finish_animation()
	check(shop.view.get_node("BasePage").visible and not shop.view.get_node("Root").visible, "Independent base page")
	check(towers.remove_tower(Vector3i(19,0,5)), "Remove fifth tower")
	check(not shop.view.get_node("BasePage/Center/Panel/Rows/Options/marksman").disabled, "Recorded options survive tower loss")
	shop.view.get_node("BasePage/Center/Panel/Rows/Options/marksman").pressed.emit()
	check(towers.place_tower(Vector3i(19,0,5)) != null, "Restore fifth tower")
	check(cards.base_level == 2 and shop.coins == coins and not shop.upgrade_base("marksman"), "Select exactly one upgrade without gold")
	for i in 90:
		if not session.get_node("PortalMap").computing: break
		await get_tree().process_frame
	shop.close_shop()
	check(wave.start_wave(), "Start second wave")
	for i in 3: await get_tree().process_frame
	check(cards.cards.size() == starting_count + 2 and cards.cards.back().quantity == 2, "Two upgraded shots stack apart from the carried base shot")
	check(cards.hand.views.back().get_node("Visuals/Content/Layout/Header/StackCount").text == "×2", "Face shows the stack count")
	check(cards.cards.back().spell.damage == 90, "New marksman shots deal 90")
	cards.hand.finish_animation()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(preload("res://tests/fixtures/test_artifacts.gd").path("cards/commander_hand.png"))
	await click(cards.hand.views[starting_count].get_global_rect().get_center())
	check(cards.selected == starting_count, "Click the spell in the shared hand")
	check(cards.place_selected(TileConstants.INVALID_CELL) == null and cards.selected == starting_count, "Invalid shot retains selection")
	var hud: Node = session.get_node("LevelHUD")
	hud.set_paused(true)
	check(cards.place_selected(Vector3i.ZERO) == null, "Pause blocks casting")
	hud.set_paused(false)
	check(cards.hand._interaction_enabled, "Resume restores spell input")
	var enemies: Array[Node3D] = wave.living_enemies()
	if enemies.size() == 3:
		var center := map.to_global(map.map_to_local(Vector3i.ZERO))
		enemies[0].global_position = center
		enemies[1].global_position = center + Vector3(1, 2, 0)
		enemies[2].global_position = center + Vector3(1.01, 0, 0)
		check(cards.place_selected(Vector3i.ZERO) != null, "Cast on road")
		check(enemies[0].shield == 80 and enemies[1].shield == 80 and enemies[2].shield == 150, "Saved shot deals 70 within radius")
		check(cards.selected == -1 and cards.cards.size() == starting_count + 1 and cards.cards.back().quantity == 2, "Consuming the single basic shot preserves the upgraded stack")
		cards.hand.finish_animation()
		await click(cards.hand.views[starting_count].get_global_rect().get_center())
		var camera: Camera3D = session.get_node("Camera3D")
		await click(camera.unproject_position(map.to_global(map.map_to_local(Vector3i(3, 0, 0)))))
		check(cards.selected == -1 and cards.cards.size() == starting_count + 1 and cards.cards.back().quantity == 1, "World click consumes one charge through camera input")
		cards.hand.finish_animation()
		var from: Vector2 = cards.hand.views[starting_count].get_global_rect().get_center()
		var to := camera.unproject_position(map.to_global(map.map_to_local(Vector3i(4, 0, 0))))
		var press := InputEventMouseButton.new()
		press.position = from
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(press, true)
		var drag := InputEventMouseMotion.new()
		drag.position = to
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(drag, true)
		await get_tree().process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = to
		get_viewport().push_input(release, true)
		check(cards.cards.size() == starting_count and cards.hand.stowed, "Dragging consumes the last spell and stows the hand")
	else: check(false, "Expected three enemies")
	for enemy in wave.living_enemies(): enemy.take_damage(1000)
	for i in 4: await get_tree().process_frame
	shop.open_base_page()
	for i in range(5,15):
		var where := Vector3i(15+i,0,5)
		var support: Array[Vector3i] = [where]
		cards.placement.add_cells(support)
		check(towers.place_tower(where) != null, "Deploy additional tower")
		if i == 9: check(shop.upgrade_base("response"), "Rapid Response unlocks at ten towers")
	check(shop.upgrade_base("last") and cards.base_level == 4, "Fifteen towers grant one final spell")
	check(cards.cards.back().spell.kind == &"last" and not shop.upgrade_base("last"), "Only one final reward")
	shop.close_shop()
	for i in 90:
		if not session.get_node("PortalMap").computing: break
		await get_tree().process_frame
	check(wave.start_wave(), "Start final wave")
	for i in 3: await get_tree().process_frame
	var rally := Vector3i(2,0,0)
	check(cards.cards.back().spell.kind == &"reinforce", "Response deals Reinforcements")
	cards.select_card(cards.cards.size()-1)
	cards.place_selected(rally)
	var combat: Node = towers.combat
	check(combat.barracks.units.size() == 2, "Summon two soldiers without a barracks")
	var air := 0
	var ground := 0
	for enemy in wave.living_enemies():
		enemy.global_position = map.to_global(map.map_to_local(rally))
		enemy.shield = 200
		if enemy.troop.has_tag(&"flying"): air += 1
		else: ground += 1
	preload("res://assets/data/spells/volley.tres").resolve(combat,rally)
	check(air == 1 and ground == 3 and wave.living_enemies().all(func(e): return e.shield == 60), "Volley hits air and ground for 140")
	preload("res://assets/data/spells/lightning.tres").resolve(combat,rally)
	check(wave.living_enemies().all(func(e): return e.stun_remaining == 1), "Lightning stuns all surviving targets")
	preload("res://assets/data/spells/delayed.tres").resolve(combat,rally)
	check(combat.projectiles.size() > 0, "Delayed spell creates a live flight")
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	check(not wave.active and combat.barracks.units.is_empty(), "Reinforcements leave at wave end")
	print("Commander spells failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
