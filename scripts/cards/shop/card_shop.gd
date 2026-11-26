extends Node
const Picker = preload("res://scripts/levels/presentation/unit_pick.gd")
signal balance_changed(coins: int)
signal gold_granted(amount: int, reason: String, world_position: Variant)
signal purchased(card: BuildCard)
signal rerolled
## Optional scenario policies; ordinary levels leave these empty.
var deal_filter: Callable
var purchase_rule: Callable
var reroll_rule: Callable
## Wave-bound shop state and transactions. The view owns only layout/animation.
@export var catalog: Array[TowerDefinition] = []
@export var traffic_catalog: Array[TrafficStructureDefinition] = []
@export var wave_reward := ShopConstants.WAVE_REWARD
@export var reroll_price := ShopConstants.REROLL_PRICE
@export var initial_coins := ShopConstants.INITIAL_COINS
@export var random_seed := ShopConstants.SEED
@onready var view: CanvasLayer = $View
var coins := 0
var offers: Array[BuildCard] = []
var prices := PackedInt32Array()
var sold := PackedByteArray()
var available := false
var deals := 0
## Successful paid rerolls since acquiring/last consuming the loyalty reward.
var loyalty_period := 0
var loyalty_paid_rerolls := 0
var _reroll_in_progress := false
var _placement: Node3D
var _wave: Node
var _rng := RandomNumberGenerator.new()
var _round := 0
var _rewarded_round := 0
## Optional per-session geometry pools. Keys are the original TowerDefinition
## objects; these never replace the combat definitions or alter shared assets.
var tile_preset_overrides: Dictionary = {}

func _preset_picker(definition: TowerDefinition) -> TowerDefinition:
	if not tile_preset_overrides.has(definition): return definition
	# Reuse the established file/weight validation and stable weighted draw.
	# This temporary picker is never assigned to a card or a combat instance.
	var picker := TowerDefinition.new()
	picker.tile_preset_candidates.assign(tile_preset_overrides[definition])
	return picker

func setup(placement: Node3D, wave: Node) -> void:
	_placement = placement
	_wave = wave
	coins = maxi(0, initial_coins)
	if BalanceTrace.enabled: BalanceTrace.event("gold","shop",{"delta":coins,"balance":coins,"reason":"initial"},"shop")
	_rng.seed = random_seed
	view.open_requested.connect(open_shop)
	view.close_requested.connect(close_shop)
	view.purchase_requested.connect(buy)
	view.reroll_requested.connect(reroll)
	view.get_node("Root/BaseUpgrade").pressed.connect(open_base_page)
	view.get_node("BasePage/Center/Panel/Rows/Back").pressed.connect(close_shop)
	_placement.towers.towers_changed.connect(_refresh_upgrades)
	_refresh_upgrades()
	if _wave != null:
		_wave.wave_started.connect(_on_wave_started)
		_wave.wave_finished.connect(_on_wave_finished)
		if _wave.active: _on_wave_started()
	_refresh()

func _on_wave_started() -> void:
	if not is_inside_tree() or not view.is_inside_tree(): return
	_round += 1
	hide_for_wave_start()

func prepare_opening_shop() -> void:
	available = _deal()
	_refresh()
	view.set_available(available)
	if is_instance_valid(_wave.controls): _wave.controls.set_shop_present(available)

func hide_for_wave_start() -> void:
	available = false
	close_shop()
	view.set_available(false)
	if is_instance_valid(_wave.controls): _wave.controls.set_shop_present(false)

func restore_after_failed_start(was_available: bool) -> void:
	# Restore the same offers and prices, without rewards, a new deal or RNG use.
	available = was_available
	_refresh()
	view.set_available(available)
	if is_instance_valid(_wave.controls): _wave.controls.set_shop_present(available)

func _on_wave_finished() -> void:
	if not is_inside_tree() or not view.is_inside_tree() or _round <= _rewarded_round or _wave.active:
		return
	_rewarded_round = _round
	grant_gold(maxi(0, wave_reward),"wave_reward")
	available = _deal()
	_refresh()
	view.set_available(available)
	if is_instance_valid(_wave.controls): _wave.controls.set_shop_present(available)

func roll_cards(count: int) -> Array[BuildCard]:
	var result: Array[BuildCard] = []
	var valid: Array[TowerDefinition] = []
	var pickers := {}
	for tower in catalog:
		if tower == null: continue
		var picker := _preset_picker(tower)
		var preset := picker.first_tile_preset()
		if preset != null and BuildCard.from_parts(tower, preset).configuration_error().is_empty():
			valid.append(tower)
			pickers[tower] = picker
	if valid.is_empty(): return result
	var bag: Array[TowerDefinition] = []
	for i in maxi(0, count):
		if bag.is_empty():
			bag = valid.duplicate()
			for j in range(bag.size()-1, 0, -1):
				var index := _rng.randi_range(0, j)
				var swap := bag[j]
				bag[j] = bag[index]
				bag[index] = swap
		var tower: TowerDefinition = bag.pop_back()
		var preset: TilePreset = pickers[tower].roll_tile_preset(_rng)
		result.append(BuildCard.from_parts(tower, preset))
	return result

func roll_traffic_cards(count: int) -> Array[BuildCard]:
	var valid: Array[TrafficStructureDefinition] = []
	for definition in traffic_catalog:
		if definition != null and definition.configuration_error().is_empty(): valid.append(definition)
	var result: Array[BuildCard] = []
	var bag: Array[TrafficStructureDefinition] = []
	if valid.is_empty(): return result
	for i in count:
		if bag.is_empty():
			bag.assign(valid)
			for j in range(bag.size()-1,0,-1):
				var index := _rng.randi_range(0,j)
				var swap := bag[j]
				bag[j] = bag[index]
				bag[index] = swap
		result.append(BuildCard.from_traffic(bag.pop_back()))
	return result

func roll_offers() -> Array[BuildCard]:
	# Support resources/tools remain available, but never enter the normal shop.
	return roll_cards(ShopConstants.OFFER_COUNT)

func _deal() -> bool:
	var next := roll_offers()
	if next.is_empty(): return false
	_accept_deal(next)
	return true

func _accept_deal(next: Array[BuildCard]) -> void:
	if deal_filter.is_valid(): next = deal_filter.call(next)
	offers.assign(next)
	prices.clear()
	sold.clear()
	for card in offers:
		prices.append(card.price if card != null else 0)
		sold.append(0)
	if BalanceTrace.enabled:
		var entries: Array = []
		for card in offers: entries.append({"card":card.visual_definition().resource_path,"price":card.price} if card != null else {})
		BalanceTrace.event("shop_deal","shop",{"offers":entries},"shop")
	deals += 1

func open_shop() -> void:
	if not can_open(): return
	_refresh_upgrades()
	_placement.set_shop_open(true)
	view.set_open(true)
	if is_instance_valid(_wave.controls): _wave.controls.visible = false

func open_base_page() -> void:
	if not can_open() or not _placement.commander_enabled or purchase_rule.is_valid(): return
	open_shop()
	view.get_node("BasePage").show()
	view.get_node("Root").hide()

func can_open() -> bool:
	return available and not _placement.pause_locked and not _placement.entry_selection_active and not _placement._wave_start_pending and not get_tree().paused and not ScreenTransition.active and not (_wave != null and _wave.active)

func upgrade_base(id: String) -> bool:
	if not view.get_node("BasePage").visible: return false
	if not _placement.accept_upgrade(id): return false
	_refresh_upgrades()
	return true

func try_open_from_world(camera: Camera3D, point: Vector2) -> bool:
	if not can_open() or _placement.selected >= 0 or _placement.hand.is_dragging(): return false
	var goal := _placement.get_node_or_null("../Goal") as Node3D
	if goal == null: return false
	var distance := Picker.hit_distance(camera.project_ray_origin(point),camera.project_ray_normal(point),Picker.mesh_parts(goal))
	if not is_finite(distance): return false
	# Units retain inspection priority when projected over the base.
	if _wave != null and Picker.pick(camera,point,_placement.towers,_wave.visuals) != null: return false
	if _placement.commander_enabled and not purchase_rule.is_valid(): open_base_page()
	else: open_shop()
	return view.opened

func close_shop() -> void:
	_placement.set_shop_open(false)
	view.set_open(false)
	if is_instance_valid(_wave.controls): _wave.controls.visible = true

func buy(index: int) -> bool:
	if _placement.pause_locked or _placement.entry_selection_active or get_tree().paused or not available or not view.opened or view.get_node("BasePage").visible or _wave.active or index < 0 or index >= offers.size() or sold[index] != 0 or offers[index] == null:
		return false
	if purchase_rule.is_valid() and not purchase_rule.call(offers[index]): return false
	if coins < prices[index]:
		return false
	coins -= prices[index]
	sold[index] = 1
	# Reserve the offer before inventory notifications; reentrant clicks cannot
	# buy it twice. Roll back if the recipe became invalid after it was dealt.
	if not _placement.add_card(offers[index]):
		coins += prices[index]
		sold[index] = 0
		_refresh()
		return false
	if BalanceTrace.enabled: BalanceTrace.event("gold","shop",{"delta":-prices[index],"balance":coins,"reason":"purchase","card":offers[index].visual_definition().resource_path},"shop")
	_refresh()
	purchased.emit(offers[index])
	return true

func configure_loyalty(period: int) -> void:
	period = maxi(0,period)
	if loyalty_period == period: return
	loyalty_period = period
	loyalty_paid_rerolls = 0

func loyalty_free_ready() -> bool:
	return loyalty_period > 0 and loyalty_paid_rerolls >= loyalty_period

func current_reroll_price() -> int:
	return 0 if loyalty_free_ready() else maxi(0,reroll_price)

func reroll() -> bool:
	if _reroll_in_progress or _placement.pause_locked or _placement.entry_selection_active or get_tree().paused or not available or not view.opened or view.get_node("BasePage").visible or _wave.active or view.rerolling:
		return false
	if reroll_rule.is_valid() and not reroll_rule.call(): return false
	var cost := current_reroll_price()
	if coins < cost: return false
	_reroll_in_progress = true
	var next := roll_offers()
	if next.is_empty():
		_reroll_in_progress = false
		return false
	var was_free := loyalty_free_ready()
	coins -= cost
	if loyalty_period > 0:
		if was_free: loyalty_paid_rerolls = 0
		elif cost > 0: loyalty_paid_rerolls += 1
	if BalanceTrace.enabled: BalanceTrace.event("gold","shop",{"delta":-cost,"balance":coins,"reason":"reroll"},"shop")
	_accept_deal(next)
	_refresh(true)
	view.animate_reroll()
	rerolled.emit()
	_reroll_in_progress = false
	return true

func _refresh_upgrades() -> void:
	var upgrade: Button = view.get_node("Root/BaseUpgrade")
	upgrade.visible = _placement.commander_enabled and not purchase_rule.is_valid()
	var notice: Label = view.get_node("Entry/UpgradeNotice")
	notice.visible = false
	if not upgrade.visible: return
	var level: int = _placement.base_level
	const Catalog = preload("res://scripts/cards/definitions/base_upgrades.gd")
	var counts := Catalog.counts(_placement.towers)
	var count := int(counts.values().reduce(func(a,b): return a+b, 0))
	var ready_to_upgrade: bool = _placement.milestone_counts.has(level)
	notice.visible = ready_to_upgrade
	var rows := view.get_node("BasePage/Center/Panel/Rows")
	rows.get_node("Progress").text = tr("spell.base_max") if level == 4 else tr("spell.base_upgrade").format({"level":level, "count":count, "need":level*5})
	rows.get_node("Rule").visible = level < 4
	rows.get_node("Rule").text = tr("spell.base_locked") if ready_to_upgrade else tr("spell.base_threshold").format({"need":level*5})
	var options := rows.get_node("Options")
	for old in options.get_children():
		options.remove_child(old)
		old.queue_free()
	if not ready_to_upgrade: return
	for id: String in Catalog.TIERS[level-1]:
		if not Catalog.eligible(id, _placement.milestone_counts[level]): continue
		var choice := Button.new()
		choice.name = id
		choice.text = tr("upgrade."+id)+"  ·  "+tr("upgrade."+id+".detail")
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.pressed.connect(upgrade_base.bind(id))
		options.add_child(choice)

func _refresh(insert_offers := false) -> void:
	view.show_offers(offers, prices, sold, coins, current_reroll_price(), insert_offers)
	balance_changed.emit(coins)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(_placement) and is_node_ready(): _refresh_upgrades()

func _refresh_balance() -> void:
	view.update_balance(coins, current_reroll_price())
	balance_changed.emit(coins)

func grant_gold(amount: int, reason: String, world_position: Variant = null) -> void:
	coins += maxi(0,amount)
	if BalanceTrace.enabled: BalanceTrace.event("gold","shop",{"delta":maxi(0,amount),"balance":coins,"reason":reason},"shop")
	_refresh_balance()
	if amount > 0: gold_granted.emit(amount, reason, world_position)

func _exit_tree() -> void:
	if is_instance_valid(_wave):
		if _wave.wave_started.is_connected(_on_wave_started): _wave.wave_started.disconnect(_on_wave_started)
		if _wave.wave_finished.is_connected(_on_wave_finished): _wave.wave_finished.disconnect(_on_wave_finished)

func spend_gold(amount: int,reason: String) -> bool:
	if amount < 0 or coins < amount: return false
	coins -= amount
	if BalanceTrace.enabled: BalanceTrace.event("gold","shop",{"delta":-amount,"balance":coins,"reason":reason},"shop")
	_refresh_balance()
	return true
