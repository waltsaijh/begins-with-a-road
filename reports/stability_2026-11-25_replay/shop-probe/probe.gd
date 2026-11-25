extends Node

const BASE := 9
const TOTAL := 32
const FIXED_SEED := 17391
var balance_signals := 0
var grant_signals := 0
var failed := false

func _ready() -> void:
	investigate.call_deferred()

func fail_probe(note: String) -> void:
	failed = true
	print("SHOP_PROBE STOP ", note)
	get_tree().quit(2)

func check_shop(shop: Node, ids: Array) -> bool:
	if shop.view.opened or shop.available or shop.view.available or shop.view.get_node("Root").visible or shop.offers.size() != 4 or shop.view.slots.size() != 5:
		fail_probe("shop state or number of offers changed")
		return false
	for i in 4:
		var item: Resource = shop.offers[i]
		if item == null or item.get_instance_id() != ids[i] or shop.sold[i] != 0 or shop.view.slots[i+1].get_node("Face/Card").card != item:
			fail_probe("presented offer changed")
			return false
	return true

func sample(shop: Node, ids: Array, count: int, round_id: int) -> void:
	shop.coins = BASE
	shop._refresh()
	if not check_shop(shop, ids) or shop.coins != BASE: return
	balance_signals = 0
	grant_signals = 0
	var amount := 1 if count == 32 else TOTAL
	var started := Time.get_ticks_usec()
	for i in count:
		shop.grant_gold(amount, "enemy_kill")
	var elapsed := Time.get_ticks_usec()-started
	if not check_shop(shop, ids): return
	if shop.coins != BASE+TOTAL or balance_signals != count or grant_signals != count:
		fail_probe("balance or signal count mismatched")
		return
	print("SHOP_PROBE round=",round_id," grants=",count," elapsed_us=",elapsed," coins=",shop.coins," balance_signals=",balance_signals," gold_signals=",grant_signals," opened=",shop.view.opened," available=",shop.available)

func investigate() -> void:
	if DisplayServer.get_name() != "headless":
		fail_probe("headless only")
		return
	seed(FIXED_SEED)
	Engine.time_scale = 1.0
	var scene: Node = preload("res://scenes/level.tscn").instantiate()
	scene.level = preload("res://assets/data/levels/frontier.tres")
	var shop: Node = scene.get_node("CardPlacement/Shop")
	shop.random_seed = FIXED_SEED
	add_child(scene)
	for i in 5: await get_tree().process_frame
	if shop.offers.size() != 4 or shop.coins != BASE:
		fail_probe("authored starting shop not ready")
		return
	shop.hide_for_wave_start()
	var ids := []
	var offers := []
	for card: BuildCard in shop.offers:
		if card == null:
			fail_probe("empty opening offer")
			return
		ids.append(card.get_instance_id())
		offers.append([card.visual_definition().resource_path,card.tile_preset.resource_path,card.price])
	if not check_shop(shop, ids): return
	print("SHOP_PROBE frontier seed=",FIXED_SEED," cards=",offers," baseline=",BASE," speed=",Engine.time_scale," hand=",scene.get_node("CardPlacement").cards.size()," ticks=usec")
	shop.balance_changed.connect(func(_value): balance_signals += 1)
	shop.gold_granted.connect(func(_value,_reason,_world): grant_signals += 1)
	for round_id in 4:
		var order := [1,32] if round_id % 2 == 0 else [32,1]
		for count: int in order:
			sample(shop, ids, count, round_id)
			if failed: return
	print("SHOP_PROBE DONE round=0 warmup; rounds=1..3 measured")
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
