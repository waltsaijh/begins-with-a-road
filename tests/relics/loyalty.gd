extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void: verify.call_deferred()
func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame
func settle(shop: Node) -> void:
	shop.view._stop_reroll_animation()
	shop.view.finish_animation()
func paid(shop: Node) -> void:
	var wallet: int = shop.coins
	var expected: int = shop.current_reroll_price()
	check(expected > 0 and shop.reroll(),"Paid reroll failed")
	check(shop.coins == wallet-expected,"Paid reroll charged an incorrect amount")
	settle(shop)
func verify() -> void:
	var pools := RunRelics.new()
	add_child(pools)
	for i in 500:
		var offers := pools.options()
		check(offers.size() == 3 and offers[0].tower == null and offers[1].tower != null and offers[2].tower != null,"Generic entered an exclusive slot")
		check(offers[0] != offers[1] and offers[1] != offers[2] and offers[0] != offers[2],"Reward options duplicate")
	var first_exclusive: RelicDefinition
	for relic in pools.catalog.entries:
		if relic.tower != null:
			pools.held[relic.id] = relic.max_stacks
			first_exclusive = relic
	check(pools.options().size() == 1 and pools.options()[0].tower == null,"Exhausted exclusive slots were filled with generic relics")
	pools.held.erase(first_exclusive.id)
	var short := pools.options()
	check(short.size() == 2 and short[1] == first_exclusive,"One remaining exclusive was duplicated or replaced by a generic")
	pools.held.clear()
	for relic in pools.catalog.entries:
		if relic.tower == null: pools.held[relic.id] = relic.max_stacks
	var no_generic := pools.options()
	check(no_generic.size() == 3 and no_generic.all(func(relic): return relic.tower != null),"Generic exhaustion did not fall back to unique exclusives")
	pools.queue_free()
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	add_child(scene)
	for i in 180:
		if not scene.get_node("PortalMap").computing: break
		await frames(1)
	var shop: Node = scene.get_node("CardPlacement/Shop")
	shop.reroll_price = 2
	shop.prepare_opening_shop()
	shop.grant_gold(100,"test")
	shop.open_shop()
	settle(shop)
	await paid(shop)
	await paid(shop)
	var relics: RunRelics = scene.get_node("TowerMap").relics
	var loyalty := relics.catalog.find(&"reroll_discount")
	check(relics.acquire(loyalty) and not relics.can_acquire(loyalty),"Loyalty was not acquired once per run")
	check(shop.loyalty_period == 3 and shop.loyalty_paid_rerolls == 0 and shop.reroll_price == 2,"Acquisition changed base price or counted old rerolls")
	for cycle in 2:
		for i in 3:
			await paid(shop)
			check(shop.loyalty_paid_rerolls == i+1,"Paid progress was not retained")
		check(shop.current_reroll_price() == 0 and shop.view.price_view(0).get_node("Number").text == "0","Fourth-reroll price is not shown as zero")
		shop.coins = 0
		shop._refresh()
		settle(shop)
		check(not shop.view.slots[0].get_node("Face/Back").disabled,"Free refresh is disabled at zero gold")
		var deals: int = shop.deals
		check(shop.reroll() and shop.coins == 0 and shop.deals == deals+1,"Free refresh did not replace offers without gold")
		check(shop.loyalty_paid_rerolls == 0 and shop.current_reroll_price() == 2,"Free refresh did not reset the cycle")
		check(not shop.reroll(),"Repeated click consumed another reroll during animation")
		settle(shop)
		shop.grant_gold(100,"test")
	await paid(shop)
	shop.hide_for_wave_start()
	shop.prepare_opening_shop()
	shop.open_shop()
	settle(shop)
	relics.refresh_towers()
	check(shop.loyalty_paid_rerolls == 1,"Wave preparation or relic refresh reset progress")
	var progress: int = shop.loyalty_paid_rerolls
	shop.coins = 0
	check(not shop.reroll() and shop.loyalty_paid_rerolls == progress,"Unfunded reroll advanced progress")
	shop.grant_gold(100,"test")
	get_tree().paused = true
	check(not shop.reroll() and shop.loyalty_paid_rerolls == progress,"Paused reroll advanced progress")
	get_tree().paused = false
	await paid(shop)
	await paid(shop)
	check(shop.loyalty_free_ready(),"Failed to prepare the next free reroll")
	shop.reroll_rule = func(): return false
	check(not shop.reroll() and shop.loyalty_free_ready(),"Rejected tutorial/policy reroll consumed free progress")
	shop.reroll_rule = Callable()
	var catalog: Array[TowerDefinition] = shop.catalog.duplicate()
	shop.catalog.clear()
	var old_offers: Array = shop.offers.duplicate()
	check(not shop.reroll() and shop.loyalty_free_ready() and shop.offers == old_offers,"Empty pool consumed a free reroll")
	shop.catalog.assign(catalog)
	var reentry := [0]
	shop.balance_changed.connect(func(_coins):
		reentry[0] += 1
		check(not shop.reroll(),"Reentrant callback charged another refresh"),CONNECT_ONE_SHOT)
	var deals_before: int = shop.deals
	var wallet: int = shop.coins
	check(shop.reroll() and reentry[0] == 1 and shop.deals == deals_before+1 and shop.coins == wallet,"Free reroll was not one atomic transaction")
	settle(shop)
	await paid(shop)
	check(relics.remove(loyalty) and shop.loyalty_period == 0 and shop.current_reroll_price() == 2,"Removing the relic did not disable its cycle")
	check(relics.acquire(loyalty) and shop.loyalty_paid_rerolls == 0,"Reacquisition retained stale progress")
	var fresh: Node = load("res://scenes/cards/card_shop.tscn").instantiate()
	add_child(fresh)
	check(fresh.loyalty_period == 0 and fresh.loyalty_paid_rerolls == 0,"Fresh shop inherited previous run's progress")
	fresh.queue_free()
	scene.queue_free()
	await frames()
	print("LOYALTY_POOL_CHECK: checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
