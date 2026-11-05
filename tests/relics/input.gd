extends "res://tests/relics/playground.gd"
var failures: Array[String] = []
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void: verify.call_deferred()
func motion(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = mask
	render_viewport.push_input(event,true)
func left(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	render_viewport.push_input(event,true)
func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame
func click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	motion(point)
	left(point,true)
	left(point,false)
	await frames()
func select_manual_relic(index: int) -> void:
	await click_control(picker)
	check(relic_list.visible and relic_list.item_count == 21, "Real picker click expands all 21 relics")
	var cursor := relic_list.get_global_rect().get_center()
	motion(cursor)
	# Exercise wheel scrolling as well as a row click, without programmatic select.
	var scroll := relic_list.get_v_scroll_bar()
	var direction := MOUSE_BUTTON_WHEEL_DOWN if index > selected_relic_index else MOUSE_BUTTON_WHEEL_UP
	for step in 30:
		var event := InputEventMouseButton.new()
		event.position = cursor
		event.button_index = direction
		event.pressed = true
		render_viewport.push_input(event,true)
		await frames(1)
		var item_rect := relic_list.get_item_rect(index)
		if item_rect.position.y >= scroll.value and item_rect.end.y <= scroll.value+relic_list.size.y-8: break
	var local := relic_list.get_item_rect(index).get_center()-Vector2(0,scroll.value)
	check(relic_list.get_item_at_position(local,true) == index, "Scrolled row maps to requested relic")
	var point := relic_list.global_position+local
	motion(point)
	left(point,true)
	left(point,false)
	await frames()
	check(selected_relic_index == index and not relic_list.visible, "Real row click selects relic and closes list")
func verify() -> void:
	render_viewport = TestViewport.new()
	render_viewport.size = Vector2i(1280,800)
	render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(render_viewport)
	await setup()
	await frames(8)
	render_viewport.mouse_entered.emit()
	var cards: Node = session.get_node("CardPlacement")
	var map: GridMap = session.get_node("TileMap")
	var camera: Camera3D = session.get_node("Camera3D")
	var tower: DefenseTower = session.get_node("TowerMap").upgrade_target(ANCHORS[0])
	var point := camera.unproject_position(map.to_global(map.map_to_local(ANCHORS[0])))
	cards.hand.finish_animation()
	var button: Button = cards.hand.views[0]
	var start := button.get_global_transform_with_canvas()*(button.size*0.5)
	var count: int = cards.cards.size()
	var coins: int = cards.get_node("Shop").coins
	var used := map.get_used_cells()
	motion(start)
	left(start,true)
	motion(point,MOUSE_BUTTON_MASK_LEFT)
	await frames()
	check(cards.hand.is_dragging() and cards.preview.upgrade_mode and cards.preview.ground.mesh == null, "Real hand drag enters upgrade hologram without roads")
	check(cards.preview.upgrade_label.text == "Lv.1 → Lv.2", "Hover shows next level")
	await snapshot("upgrade")
	left(point,false)
	await frames()
	check(tower.level == 2 and cards.cards.size() == count-1 and cards.get_node("Shop").coins == coins and map.get_used_cells() == used, "Real drop upgrades once, consumes one card and preserves roads/gold")
	# Six cards can still lack one tower type when another type is duplicated.
	var retained: BuildCard = cards.cards[0]
	cards.add_card(BuildCard.from_parts(retained.tower,retained.tile_preset))
	var existing_cards: Array = cards.cards.duplicate()
	var refill_count: int = cards.cards.size()
	var refill_key := InputEventKey.new()
	refill_key.physical_keycode = KEY_B
	refill_key.pressed = true
	get_viewport().push_input(refill_key,true)
	await frames()
	check(cards.cards.size() == refill_count+1 and is_instance_valid(session), "B fills only the missing tower type even when hand already has six cards")
	for card in existing_cards: check(cards.cards.has(card), "Refill preserves existing card instances and duplicates")
	refill_key.echo = true
	get_viewport().push_input(refill_key,true)
	await frames()
	check(cards.cards.size() == refill_count+1, "Holding refill key does not repeat grants")
	refill_key.echo = false
	refill_key.pressed = false
	get_viewport().push_input(refill_key,true)
	await click_control(refill_button)
	check(cards.cards.size() == refill_count+1 and relic_feedback.text == "手牌已齊全，無需補牌", "Refill button leaves a complete hand unchanged")
	for index in cards.cards.size():
		if cards.cards[index].tower == tower.definition:
			cards.select_card(index)
			break
	check(cards.place_selected(ANCHORS[0]) == tower, "Consume replenished mortar card through a real upgrade")
	await click_control(refill_button)
	check(cards.cards.size() == refill_count+1 and relic_feedback.text == "已補入 1 張缺少的塔牌", "Refill button replenishes exactly the consumed tower type")
	# The manual tool uses the real acquisition path, with no reward or currency cost.
	var manager: RunRelics = session.get_node("TowerMap").relics
	await select_manual_relic(manager.catalog.entries.find(manager.catalog.find(&"protagonist")))
	await click_control(grant_button)
	check(manager.held.has(&"protagonist") and grant_button.disabled and not grant_selected_relic(), "Manual grant click applies unique relic once and disables duplicates")
	check(relic_feedback.text.contains("成為主角") and picker.text.contains("1/1"), "Manual grant displays owned count and result")
	await click_control(remove_button)
	var sentry: DefenseTower = session.get_node("TowerMap").upgrade_target(ANCHORS[5])
	check(not manager.held.has(&"protagonist") and not sentry.unlimited_levels and remove_button.disabled and not remove_selected_relic(), "Manual remove click retracts unique effect and prevents empty removal")
	await click_control(grant_button)
	check(sentry.unlimited_levels, "Removed exclusive can be acquired again")
	await select_manual_relic(20)
	check(picker.text.contains("熟客優惠"), "Last relic is reachable through real scrolling")
	await select_manual_relic(0)
	check(picker.text.contains("冰霜射線"), "First relic remains reachable after scrolling back")
	await select_manual_relic(manager.catalog.entries.find(manager.catalog.find(&"gold")))
	await click_control(grant_button)
	await click_control(grant_button)
	check(int(manager.held.get(&"gold",0)) == 2 and cards.get_node("Shop").coins == coins+40, "Manual tool grants repeatable generic twice with immediate effect")
	await click_control(remove_button)
	check(int(manager.held.get(&"gold",0)) == 1 and cards.get_node("Shop").coins == coins+40, "Manual generic removal removes one stack without reclaiming spent gold")
	render_viewport.size = Vector2i(800,600)
	await frames()
	check(grant_button.get_global_rect().end.x <= 800 and grant_button.get_global_rect().position.x >= 0, "Manual relic tool remains visible at 800px viewport width")
	await click_control(picker)
	check(relic_list.visible and remove_button.get_global_rect().end.y <= 600, "Expanded list and removal button fit 800x600 viewport")
	await snapshot("manual_relic_tool")
	await click_control(picker)
	render_viewport.size = Vector2i(1280,800)
	await frames()
	# Inspect the actual baked airship at close range, including its firing markers.
	var ship: DefenseTower = session.get_node("TowerMap").upgrade_target(ANCHORS[3])
	var base: Node3D = ship._visual.get_node("FixedBase")
	var base_transform := base.global_transform
	var flight: Node3D = ship.patrol_visual()
	var docked := flight.position
	manager.acquire(manager.catalog.find(&"departure"))
	preload("res://scripts/combat/relic_combat.gd").advance(session.get_node("TowerMap").combat,ship,1)
	check(flight.position.x > docked.x and base.global_transform == base_transform, "Rendered cruise moves airship but leaves base fixed")
	for muzzle in ship._visual.muzzles(): check(flight.is_ancestor_of(muzzle), "Rendered firing markers are attached to airship")
	var camera_focus: Vector3 = camera.focus
	var camera_size := camera.size
	camera.focus = ship.global_position+Vector3.UP*0.65
	camera.size = 3.0
	camera.update_pose()
	relic_panel.hide()
	await frames()
	await snapshot("airship_patrol")
	manager.remove(manager.catalog.find(&"departure"))
	check(flight.position == docked and base.global_transform == base_transform, "Removing cruise returns airship without moving base")
	await frames()
	await snapshot("airship_docked")
	camera.focus = camera_focus
	camera.size = camera_size
	camera.update_pose()
	relic_panel.show()
	await frames()
	# ACT completion must wait for a real card click and preserve the lock on pause.
	session._on_start_requested()
	session._advance_wave_start(1.5)
	var combat: Node = session.get_node("TowerMap").combat
	session.get_node("EnemyWave")._process(0)
	var foe: Node3D = session.get_node("EnemyWave").living_enemies()[0]
	tower.prepare_shot(foe)
	tower.attack.fire(combat,tower,foe)
	finish_wave()
	check(session._settling_wave and not session.choosing_relic and cards.input_suspended, "Last enemy death waits for outstanding shell before rewarding")
	await get_tree().create_timer(2.0).timeout
	await frames()
	check(session.choosing_relic and cards.input_suspended and not session.get_node("EnemyWave").start_allowed, "ACT completion enters mandatory reward phase")
	var choice: CanvasLayer = session.relic_choice
	var hud: CanvasLayer = session.get_node("LevelHUD")
	var backdrop: ColorRect = choice.get_node("Modal/Backdrop")
	check(backdrop.get_global_rect().is_equal_approx(Rect2(Vector2.ZERO,Vector2(render_viewport.size))), "Reward dimmer covers the entire viewport, including the header")
	var before_roll: Dictionary = manager.held.duplicate()
	var before_roll_coins: int = cards.get_node("Shop").coins
	var old_card: WeakRef = weakref(choice.row.get_child(0))
	check(choice.debug_reroll_button.is_visible_in_tree(), "Debug reward reroll button is visible")
	await click_control(choice.debug_reroll_button)
	check(old_card.get_ref() == null and choice.row.get_child_count() == 3, "Real debug button click rebuilds the three reward cards")
	check(manager.held == before_roll and cards.get_node("Shop").coins == before_roll_coins and session.choosing_relic and cards.input_suspended, "Debug reroll preserves inventory, coins and reward phase locks")
	await click_control(hud.pause_button)
	check(get_tree().paused, "Full-screen reward dimmer keeps the header pause button reachable")
	check(not choice.choose(choice.offers[0]), "Paused reward cannot acquire")
	var paused_cards: int = cards.cards.size()
	check(not refill() and cards.cards.size() == paused_cards, "Paused test tool cannot refill cards")
	check(not grant_selected_relic() and not remove_selected_relic() and int(manager.held.get(&"gold",0)) == 1, "Paused manual tool cannot acquire or remove")
	await snapshot("paused_reward")
	hud.set_paused(false)
	await get_tree().create_timer(0.4).timeout
	check(cards.input_suspended and session.choosing_relic, "Resume preserves reward lock")
	await snapshot("exclusive_reward")
	var option: Button = choice.row.get_child(1)
	var selected: RelicDefinition = choice.offers[1]
	var option_point := option.get_global_rect().get_center()
	motion(option_point)
	left(option_point,true)
	left(option_point,false)
	await get_tree().create_timer(0.4).timeout
	check(session.get_node("TowerMap").relics.held.has(selected.id) and not session.choosing_relic and not cards.input_suspended, "Real reward card click acquires and resumes preparation")
	var inventory: Control = choice.inventory
	await frames()
	check(choice.get_node_or_null("InventoryButton") == null and choice.get_node_or_null("Collection") == null,"Old collection interface was not removed")
	var icons: HBoxContainer = inventory.get_node("Icons")
	var owned := 0
	for amount in manager.held.values(): owned += int(amount)
	check(inventory.visible and icons.get_child_count() == owned,"Each acquired relic copy should have an icon")
	check(icons.get_child(owned-1).get_meta("relic_id") == selected.id,"Newest acquired relic was not appended to the right")
	check(icons.get_child(owned-1).tooltip_text.contains(tr(selected.name_key)),"Relic icon lost its name/description tooltip")
	check(not cards.hand.is_ancestor_of(inventory),"Relic row is still parented to the hand")
	check(absf(inventory.position.x-inventory.screen_margin.x)<1 and absf(inventory.get_rect().end.y+inventory.screen_margin.y-render_viewport.get_visible_rect().size.y)<1,"Relics did not keep their independent screen margin")
	for i in icons.get_child_count()-1:
		check(icons.get_child(i).get_global_rect().end.x < icons.get_child(i+1).get_global_rect().position.x and is_equal_approx(icons.get_child(i).position.y,icons.get_child(i+1).position.y),"Relic icons are not arranged left to right")
	await snapshot("hand_relic_icons")
	var fixed_position := inventory.global_position
	var hand_root: Control = cards.hand.get_node("Cards")
	var original_hand_position := hand_root.position
	hand_root.position.y += 80
	await frames()
	check(inventory.global_position.is_equal_approx(fixed_position),"Moving the hand root moved the independent relic row")
	hand_root.position = original_hand_position
	cards.hand.set_stowed(true)
	cards.hand.finish_animation()
	await frames()
	check(inventory.visible and inventory.get_global_rect().end.y < render_viewport.size.y,"Combat stowing hid relics or moved them below the screen")
	check(inventory.global_position.is_equal_approx(fixed_position),"Stowing the hand moved the relic row")
	cards.hand.set_stowed(false)
	cards.hand.finish_animation()
	await frames()
	var weak: WeakRef = weakref(session.get_node("TowerMap").relics)
	session.queue_free()
	await frames()
	check(weak.get_ref() == null, "Unload releases run manager")
	var fresh: Node3D = load("res://scenes/level.tscn").instantiate()
	render_viewport.add_child(fresh)
	await frames()
	check(fresh.get_node("TowerMap").relics.held.is_empty() and fresh.current_wave == 0, "New session has no held relics")
	fresh.queue_free()
	await frames()
	var output := {"failures":failures,"rendered":DisplayServer.get_name() != "headless","real_drag_and_reward_click":true}
	FileAccess.open(Artifacts.path("relics/input.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("RELIC_INPUT:",JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)
