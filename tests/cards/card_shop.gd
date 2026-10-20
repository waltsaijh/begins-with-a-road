extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func top_edge_gap(items: Array) -> float:
	var gap := 0.0
	for i in items.size()-1:
		var a: Control = items[i]
		var b: Control = items[i+1]
		var a0 := a.get_global_transform()*Vector2.ZERO
		var a1 := a.get_global_transform()*Vector2(a.size.x, 0)
		var b0 := b.get_global_transform()*Vector2.ZERO
		var b1 := b.get_global_transform()*Vector2(b.size.x, 0)
		var left := maxf(a0.x, b0.x)
		var right := minf(a1.x, b1.x)
		if left > right: continue
		for x in [left, right]:
			var ay := lerpf(a0.y, a1.y, (x-a0.x)/(a1.x-a0.x))
			var by := lerpf(b0.y, b1.y, (x-b0.x)/(b1.x-b0.x))
			gap = maxf(gap, absf(ay-by))
	return gap

func check_compact(view: CanvasLayer) -> void:
	var active: PackedInt32Array = view.active_indices()
	var previous := -INF
	for index in active:
		var slot: Control = view.slots[index]
		var centre: Vector2 = slot.get_global_transform()*Vector2(slot.size.x*0.5, 0)
		if is_finite(previous):
			var gap := centre.x-previous
			check(gap > slot.size.x*slot.scale.x*0.8 and gap < slot.size.x*slot.scale.x, "Shop retained a hole between remaining cards")
		previous = centre.x
	var last: Control = view.slots[active[-1]]
	check(absf((last.get_global_transform()*Vector2(last.size.x, 0)).x-(get_viewport().get_visible_rect().size.x-ShopConstants.MARGIN)) < 1.0, "Shop no longer hugs the right edge")

func ready_map(scene: Node) -> void:
	for i in 120:
		if not scene.get_node("PortalMap").computing and scene.get_node("PortalMap").plan.get("reachable", false): return
		await get_tree().process_frame
	check(false, "Shop fixture did not prepare")

func click_at(point: Vector2) -> void:
	await hover_at(point)

	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)
	await get_tree().process_frame

func hover_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame

func click_button(button: Button) -> void:
	# The headless dummy renderer does not hit-test GUI canvases. GPU/Web runs
	# below exercise real input propagation; headless runs test transactions.
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
		await get_tree().process_frame
	else:
		await click_at(button.get_global_transform()*(button.size*0.5))

func settle(cards: Node, shop: Node) -> void:
	shop.view.finish_animation()
	cards.hand.finish_animation()

func screenshot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)

func verify() -> void:
	var cells: Array[Vector2i] = []
	for x in range(-3, 4): cells.append(Vector2i(x, 0))
	var scene := Fixture.scene_for(cells, Vector2i(-3, 0), Vector2i(3, 0))
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	wave.enemy_count = 1
	wave.batch_size = 1
	add_child(scene)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	scene.get_node("TowerMap").combat.enabled = false
	await ready_map(scene)
	var cards: Node = scene.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	var view: CanvasLayer = shop.view
	var original_coin: Texture2D = view.coin_texture
	var original_back: Texture2D = view.card_back_texture
	var custom_art := ImageTexture.create_from_image(Image.create_empty(32, 32, false, Image.FORMAT_RGBA8))
	view.coin_texture = custom_art
	view.card_back_texture = custom_art
	for i in view.slots.size():
		check(view.price_view(i).get_node("Gold").texture == custom_art and view.slots[i].get_node("Face/Back/Artwork").texture == custom_art, "Custom artwork did not update every shop slot")
	view.coin_texture = original_coin
	view.card_back_texture = original_back
	var map: GridMap = scene.get_node("TileMap")
	check(view.get_node_or_null("Root/Hint") == null, "Shop still has a separate hint label")
	check(cards.hand._canvas.get_child_count() == cards.hand.views.size(), "Hand still has a separate status panel")
	check(not scene.get_node("PortalOverlay")._panel.visible and wave.controls.spawn_button.text.is_empty(), "Non-card HUD text remains visible by default")
	check(not shop.available and not view.get_node("Root").visible and cards.cards.size() == 3, "Shop appeared before a wave ended")
	check(view.get_node_or_null("Root/Dimmer") == null and view.get_node_or_null("Root/Header") == null, "Shop still has a modal overlay/header")
	check(cards.hand.views[0].position.y < cards.hand.views[1].position.y and cards.hand.views[1].position.y < cards.hand.views[2].position.y, "Hand does not curve down from the outside left")
	check(cards.hand.views[1].position.x-cards.hand.views[0].position.x < ShopConstants.CARD_SIZE.x, "Hand cards do not overlap")
	check(cards.hand.views[0].scale.x < 1.0, "Hand cards did not shrink")
	check(top_edge_gap(cards.hand.views) < 1.0, "Hand top edges form visible steps")
	var hand_positions := PackedVector2Array()
	for card: Control in cards.hand.views: hand_positions.append(card.position)
	var bottom_point: Vector2 = cards.hand.views[1].get_global_transform()*Vector2(cards.hand.views[1].size.x*0.5, cards.hand.views[1].size.y-2)
	var hand_point: Vector2 = cards.hand.views[1].get_global_transform()*(cards.hand.views[1].size*0.5)
	await hover_at(hand_point)
	cards.hand.finish_animation()
	check(cards.hand._hovered == 1 and cards.hand.views[1].position.y < hand_positions[1].y, "Hand hover did not lift the card")
	check(cards.hand.views[1].z_index == 1 and cards.hand.views[1].scale.is_equal_approx(cards.hand.views[0].scale), "Hand hover changed scale or draw order")
	check(CardFanLayout.pick(cards.hand.views, hand_point, 0, 1) == 1, "Hovered hand card lost its activation point")
	await screenshot("res://reports/cards/hand_hover.png")
	if DisplayServer.get_name() != "headless":
		await click_at(hand_point)
		check(cards.selected == 1, "Hover reflow changed the clicked hand card")
		cards.select_card(-1)
	await hover_at(bottom_point)
	cards.hand.finish_animation()
	check(cards.hand._hovered == 1, "Lifting lost hover at the original bottom edge")
	if DisplayServer.get_name() != "headless":
		await click_at(bottom_point)
		check(cards.selected == 1, "Lifted card's original bottom edge stopped receiving clicks")
		cards.select_card(-1)
	await hover_at(Vector2(400, 200))
	cards.hand.finish_animation()
	for i in cards.hand.views.size(): check(cards.hand.views[i].position.distance_to(hand_positions[i]) < 0.01, "Hand did not return after hover")
	check(not shop.buy(0) and not shop.reroll(), "Hidden shop accepted a transaction")
	check(wave.start_wave(), "Initial shop wave failed to start")
	wave._process(0)
	wave.living_enemies()[0]._process(10000)
	var below: float = view.slots[0].position.y
	check(below > get_viewport().get_visible_rect().size.y, "Shop deck did not start below the screen")
	view._motion.custom_step(0.13)
	check(view.slots[0].position.y < below, "Shop deck did not rise during its entry animation")
	await get_tree().process_frame
	settle(cards, shop)
	check(shop.available and not view.opened and view.slots.size() == 5 and shop.coins == ShopConstants.WAVE_REWARD, "Wave completion failed to raise the five-card deck/reward")
	for i in view.slots.size():
		var slot: Control = view.slots[i]
		check(slot.get_node("Face/Back").visible and not slot.get_node("Face/Card").visible and not view.price_view(i).is_visible_in_tree(), "Collapsed shop exposed card fronts or prices")
	check(view.slots[0].z_index > view.slots[4].z_index, "Shop icon is not on the top card")
	await screenshot("res://reports/cards/shop_closed.png")
	await click_button(view.slots[0].get_node("Face/Back"))
	settle(cards, shop)
	check(view.opened and cards.hand.collapsed and cards.input_suspended, "Deck click did not open the shop and fold the hand")
	check(not cards.placement.is_processing_unhandled_input() and not cards.towers.input_enabled and not wave.controls.visible, "Open shop leaked construction/spawn input")
	for i in view.slots.size():
		check(view.price_view(i).is_visible_in_tree(), "Shop slot missing its price")
		if i > 0:
			check(view.slots[i].get_node("Face/Card").visible and not view.slots[i].get_node("Face/Back").visible, "Offer did not flip face up")
	check(view.slots[0].get_node("Face/Back/Icon").texture.resource_path.ends_with("reroll_icon.png"), "Leftmost card is not reroll")
	var reroll_back: Button = view.slots[0].get_node("Face/Back")
	var reroll_price: HBoxContainer = view.price_view(0)
	check(reroll_price.position.y >= 0.0 and reroll_price.position.y+reroll_price.size.y <= reroll_back.get_node("Icon").position.y and reroll_price.alignment == BoxContainer.ALIGNMENT_CENTER, "Reroll price is not centered inside the top of its card")
	check(reroll_price.get_node("Number").get_theme_color("font_color") == Color.WHITE, "Reroll price is not white")
	check(view.slots[0].position.y > view.slots[2].position.y and view.slots[2].position.y > view.slots[4].position.y, "Shop does not curve up towards the outside right")
	check(view.slots[1].position.x-view.slots[0].position.x < ShopConstants.CARD_SIZE.x, "Shop cards do not overlap")
	check(view.slots[0].scale.x < 1.0, "Shop cards did not shrink")
	check(top_edge_gap(view.slots) < 1.0, "Shop top edges form visible steps")
	var original_positions := PackedVector2Array()
	for slot: Control in view.slots: original_positions.append(slot.position)
	var focus_point: Vector2 = view.slots[2].get_global_transform()*(view.slots[2].size*0.5)
	await hover_at(focus_point)
	view.finish_animation()
	check(view._hovered == 2, "Shop card did not enter hover")
	for i in view.slots.size():
		if i != 2: check(view.slots[i].position.distance_to(original_positions[i]) < 0.01, "Hover moved a neighbouring card")
		check(view.slots[i].z_index == i+1 and view.slots[i].scale.is_equal_approx(view.slots[0].scale), "Shop hover changed scale or draw order")
	var relative_lift: Vector2 = (view.slots[2].position-original_positions[2]).rotated(-view.slots[2].rotation)
	check(absf(relative_lift.x) < 0.01 and relative_lift.y < -5.0, "Hover did not move along the card's own up direction")
	for i in 12: await get_tree().process_frame
	check(view._hovered == 2 and CardFanLayout.pick(view.slots, focus_point, 0, 2) == 2, "Stationary hover oscillated or moved away from its activation point")
	# Reach overlapping cards through their exposed outside edge, including both ends.
	for index in [0, 4, 1, 3, 2]:
		var slot: Control = view.slots[index]
		var x := CardFanLayout.OVERLAP+12 if index == view._hovered+1 else 8.0
		await hover_at(slot.get_global_transform()*Vector2(x, slot.size.y*0.5))
		view.finish_animation()
		check(view._hovered == index, "Overlapping card cannot be reached through its visible edge")
	await hover_at(Vector2(400, 200))
	view.finish_animation()
	for i in view.slots.size(): check(view.slots[i].position.distance_to(original_positions[i]) < 0.01, "Shop card did not return after hover")
	for i in view.slots.size():
		check(absf(view.slots[i].rotation_degrees) < 5, "Shop fan exceeds five degrees")
		check(view.price_view(i).get_node("Gold").texture != null, "Price is missing its gold icon")
	check(view.get_node_or_null("Root/Balance") == null, "Shop still has a duplicate balance")
	var wallet: int = shop.coins
	shop.coins = 0
	shop._refresh()
	view.finish_animation()
	check(reroll_back.disabled and reroll_back.modulate == view.slots[1].get_node("Face/Card").modulate, "Unaffordable reroll does not fade like other cards")
	check(not view.rerolling, "Unaffordable reroll started an animation")
	if DisplayServer.get_name() != "headless":
		var price_control: Control = view.price_view(1)
		await click_at(price_control.get_global_transform()*(price_control.size*0.5))
		check(view.opened and cards.cards.size() == 3, "Clicking an unaffordable price changed the shop or hand")
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(400, 200)
		Input.parse_input_event(motion)
		await get_tree().process_frame
		check(get_viewport().gui_get_hovered_control() == null, "Shop intercepts the uncovered game area")
	var deals: int = shop.deals
	check(not shop.buy(0) and not shop.reroll() and shop.deals == deals and cards.cards.size() == 3, "Insufficient currency changed stock or hand")
	shop.coins = wallet
	shop._refresh()
	view.finish_animation()
	check(not reroll_back.disabled and reroll_back.modulate == Color.WHITE, "Restored money did not restore reroll appearance")
	var price: int = shop.prices[0]
	var old_hand: Array = cards.hand.views.duplicate()
	var arrival_checks: Array[bool] = []
	cards.cards_changed.connect(func():
		if cards.hand._entering.has(cards.hand.views[-1]):
			arrival_checks.append(cards.hand.views[-1].position.y > get_viewport().get_visible_rect().size.y)
			cards.hand._motion.pause())
	var buy_button: Button = view.slots[1].get_node("Face/Card")
	var buy_point := buy_button.get_global_transform()*Vector2(buy_button.size.x*0.5, buy_button.size.y-2)
	await hover_at(buy_point)
	view.finish_animation()
	check(view._hovered == 1, "Shop lift lost its original lower hit area")
	if DisplayServer.get_name() == "headless": await click_button(buy_button)
	else: await click_at(buy_point)
	check(arrival_checks == [true] and cards.hand._entering.size() == 1, "Purchased card did not start below the viewport")
	var arriving: Button = cards.hand.views[-1]
	var arrival_y: float = arriving.position.y
	cards.hand._motion.custom_step(0.10)
	check(arriving.position.y < arrival_y, "Purchased card did not move up into the hand")
	for i in old_hand.size(): check(cards.hand.views[i] == old_hand[i], "Purchase rebuilt an existing hand card")
	await screenshot("res://reports/cards/hand_purchase.png")
	var interrupted_at: Vector2 = arriving.position
	shop.close_shop()
	shop.open_shop()
	check(arriving.position.distance_to(interrupted_at) < 0.01 and cards.hand._entering.has(arriving), "Closing during purchase restarted or lost the insertion")
	settle(cards, shop)
	check(cards.cards.size() == 4 and shop.coins == wallet-price and shop.sold[0] == 1, "Offer click did not charge once and add a hand card")
	check(not shop.buy(0) and cards.hand.collapsed and cards.hand.views.size() == 4, "Sold offer was purchased twice or unfolded the hand")
	check(not view.slots[1].visible and not view.price_view(1).is_visible_in_tree() and view.slots[1].get_node_or_null("Face/Sold") == null, "Purchased card/price/badge remains visible")
	check_compact(view)
	# Buy a nonadjacent offer as well: stable offer IDs must survive compaction.
	wallet = shop.coins
	price = shop.prices[2]
	if DisplayServer.get_name() == "headless": await click_button(view.slots[3].get_node("Face/Card"))
	else:
		var price_control: Control = view.price_view(3)
		await click_at(price_control.get_global_transform()*(price_control.size*0.5))
	settle(cards, shop)
	check(cards.cards.size() == 5 and shop.coins == wallet-price and shop.sold[2] == 1, "Compaction mapped a click to the wrong offer")
	check(arrival_checks == [true, true], "Second purchase did not insert from below")
	check(view.active_indices() == PackedInt32Array([0, 2, 4]), "Sold slots remain in compact layout")
	check_compact(view)
	await screenshot("res://reports/cards/shop_sold.png")
	# Let both flips actually finish: snapping the layout or immediately
	# reversing never reveals the sold card backs restored by the closed deck.
	shop.close_shop()
	await get_tree().create_timer(0.4).timeout
	shop.open_shop()
	await get_tree().create_timer(0.4).timeout
	check(not view._animating, "Reopened shop animation did not complete")
	for i in view.slots.size():
		var stocked: bool = i == 0 or shop.sold[i-1] == 0
		check(view.slots[i].visible == stocked, "Reopening restored a sold card back")
		check(view.price_view(i).is_visible_in_tree() == stocked, "Reopening restored a sold price")
		if i > 0 and stocked:
			check(view.slots[i].get_node("Face/Card").visible and not view.slots[i].get_node("Face/Back").visible, "Reopened offer shows its back")
	check_compact(view)
	await screenshot("res://reports/cards/shop_reopened.png")
	wallet = shop.coins
	if DisplayServer.get_name() == "headless": await click_button(reroll_back)
	else: await click_at(reroll_price.get_global_transform()*(reroll_price.size*0.5))
	check(shop.deals == deals+1 and shop.coins == wallet-shop.reroll_price and shop.sold == PackedByteArray([0, 0, 0, 0]), "Reroll click did not replace all four offers and charge once")
	check(view.rerolling and reroll_back.disabled, "Successful reroll did not spin or block repeated clicks")
	check(not shop.reroll() and shop.deals == deals+1, "Reroll charged again while its icon was spinning")
	var spin: Tween = view._reroll_motion
	spin.pause()
	spin.custom_step(maxf(0.0, 0.125-spin.get_total_elapsed_time()))
	var reroll_icon: Control = reroll_back.get_node("Icon")
	check(absf(reroll_icon.rotation-TAU*0.125) < 0.02, "Reroll did not ease in during the first quarter of its animation")
	check(view._entering.size() == 4 and view._animating, "Reroll did not insert four new shop cards")
	view._motion.pause()
	var reroll_y: float = view.slots[4].position.y
	view._motion.custom_step(0.08)
	check(view.slots[4].position.y < reroll_y, "Rerolled cards did not rise from below")
	await screenshot("res://reports/cards/shop_reroll.png")
	spin.custom_step(0.125)
	check(absf(reroll_icon.rotation-PI) < 0.02, "Reroll did not reach half a turn halfway through 0.5 seconds")
	spin.custom_step(0.125)
	check(absf(reroll_icon.rotation-TAU*0.875) < 0.02, "Reroll did not ease out during its final quarter")
	spin.custom_step(0.125)
	check(not view.rerolling and is_zero_approx(reroll_icon.rotation), "Reroll did not finish one full turn and reset after 0.5 seconds")
	shop.close_shop()
	shop.open_shop()
	settle(cards, shop)
	check(view.active_indices().size() == 5 and view.slots[4].get_node("Face/Card").visible, "Closing during reroll lost the new stock")
	check_compact(view)
	var tiles := map.get_used_cells().size()
	if DisplayServer.get_name() == "headless":
		var outside := InputEventMouseButton.new()
		outside.pressed = true
		outside.button_index = MOUSE_BUTTON_LEFT
		outside.position = Vector2(400, 200)
		view._unhandled_input(outside)
	else:
		await click_at(Vector2(400, 200))
	settle(cards, shop)
	check(not view.opened and not cards.hand.collapsed and not cards.input_suspended and wave.controls.visible, "Outside click did not restore the hand/tools")
	check(map.get_used_cells().size() == tiles, "Closing click also placed a world tile")
	# Reversing an in-flight transition must produce the final requested state.
	shop.open_shop()
	shop.close_shop()
	shop.open_shop()
	settle(cards, shop)
	check(view.opened and view.slots[4].get_node("Face/Card").visible, "Interrupted animation left the wrong card face")
	shop.close_shop()
	settle(cards, shop)
	# A failed construction retains inventory; a successful one consumes exactly one.
	cards.select_card(1)
	check(cards.place_selected(Vector3i(-3, 0, 0)) == null and cards.cards.size() == 5 and cards.selected == 1, "Failed placement consumed the card")
	check(cards.place_selected(Vector3i.ZERO) != null and cards.cards.size() == 4 and cards.selected == -1 and cards.hand.views.size() == 4, "Successful placement did not consume exactly one hand card")
	check(cards.hand.views[1] == old_hand[2] and cards.hand.views[1].key_number == 2, "Consuming a card rebuilt or misnumbered its neighbour")
	cards.hand.views[1].pressed.emit()
	check(cards.selected == 1, "Persistent hand button retained its old index")
	cards.select_card(-1)
	await ready_map(scene)
	shop.open_shop()
	settle(cards, shop)
	wallet = shop.coins
	check(wave.start_wave(), "Second shop wave failed to start")
	settle(cards, shop)
	check(not shop.available and not view.opened and not view.get_node("Root").visible and not cards.hand.collapsed and wave.controls.visible, "Wave start did not retract shop/unfold hand")
	check(not shop.buy(0) and not shop.reroll() and shop.coins == wallet, "Active wave accepted a shop transaction")
	wave._process(0)
	wave.living_enemies()[0].take_damage(10000)
	await get_tree().process_frame
	check(shop.coins == wallet+shop.wave_reward and shop.available, "All-killed wave did not reopen/reward the shop")
	wallet = shop.coins
	deals = shop.deals
	wave.wave_finished.emit()
	check(shop.coins == wallet and shop.deals == deals, "Duplicate completion paid/dealt twice")
	shop.open_shop()
	settle(cards, shop)
	# Keep the viewport resize path valid without starting more animation.
	view._layout(false, false)
	# The lowered row may extend slightly past the bottom edge.
	var shop_bounds := get_viewport().get_visible_rect().grow_individual(0.0, 0.0, 0.0, maxf(0.0, view.vertical_offset))
	for slot: Control in view.slots:
		for corner in [Vector2.ZERO, Vector2(slot.size.x, 0), slot.size, Vector2(0, slot.size.y)]:
			check(shop_bounds.has_point(slot.get_global_transform()*corner), "Open shop card corner falls outside the lowered row bounds")
	scene.get_node("TileVisuals").finish()
	scene.get_node("CloudLayer").set_process(false)
	await screenshot("res://reports/cards/shop_open.png")
	await hover_at(view.slots[2].get_global_transform()*(view.slots[2].size*0.5))
	view.finish_animation()
	await screenshot("res://reports/cards/shop_hover.png")
	for control: Control in scene.find_children("*", "Control", true, false):
		check(control.tooltip_text.is_empty(), "Gameplay UI still has a hover tooltip")
	var report := {"failures": failures, "five_back_cards": true, "four_offers_and_reroll": true, "prices": true, "purchase_and_reroll": true, "outside_click_no_world_edit": true, "hand_fold_restore": true, "successful_placement_consumes": true, "wave_start_hides": true, "arrival_and_kill_rewards": true, "duplicate_reward_guard": true, "animation_reversal": true, "no_modal_overlay": true, "shallow_overlapping_fan": true, "gold_icons": true, "sold_card_hidden": true, "smaller_cards": true, "mirrored_outer_arc": true, "hover_focus": true, "stable_hover": true, "hover_keeps_neighbours": true, "hover_lift_only": true, "continuous_top_edge": true, "hand_insert_from_below": true, "persistent_hand_views": true, "compact_shop": true, "reroll_insert_from_below": true, "minimal_hud": true}
	print("CARD_SHOP_CHECK:"+JSON.stringify(report))
	if not OS.has_feature("web"):
		FileAccess.open("res://reports/cards/shop_windows.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ")+"\n")
		get_tree().quit(1 if failures else 0)
