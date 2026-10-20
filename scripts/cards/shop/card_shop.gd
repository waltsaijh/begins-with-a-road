extends Node
signal balance_changed(coins: int)
## Wave-bound shop state and transactions. The view owns only layout/animation.
@export var catalog: Array[TowerDefinition] = []
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
var _placement: Node3D
var _wave: Node
var _rng := RandomNumberGenerator.new()
var _round := 0
var _rewarded_round := 0

func setup(placement: Node3D, wave: Node) -> void:
	_placement = placement
	_wave = wave
	coins = maxi(0, initial_coins)
	_rng.seed = random_seed
	view.open_requested.connect(open_shop)
	view.close_requested.connect(close_shop)
	view.purchase_requested.connect(buy)
	view.reroll_requested.connect(reroll)
	if _wave != null:
		_wave.wave_started.connect(_on_wave_started)
		_wave.wave_finished.connect(_on_wave_finished)
		if _wave.active: _on_wave_started()
	_refresh()

func _on_wave_started() -> void:
	if not is_inside_tree() or not view.is_inside_tree(): return
	_round += 1
	hide_for_wave_start()

func hide_for_wave_start() -> void:
	available = false
	close_shop()
	view.set_available(false)
	if is_instance_valid(_wave.controls): _wave.controls.set_shop_present(false)

func _on_wave_finished() -> void:
	if not is_inside_tree() or not view.is_inside_tree() or _round <= _rewarded_round or _wave.active:
		return
	_rewarded_round = _round
	coins += maxi(0, wave_reward)
	available = _deal()
	_refresh()
	view.set_available(available)
	if is_instance_valid(_wave.controls): _wave.controls.set_shop_present(available)

func roll_cards(count: int) -> Array[BuildCard]:
	var result: Array[BuildCard] = []
	var valid: Array[TowerDefinition] = []
	for tower in catalog:
		if tower == null: continue
		var preset := tower.first_tile_preset()
		if preset != null and BuildCard.from_parts(tower, preset).configuration_error().is_empty(): valid.append(tower)
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
		var preset := tower.roll_tile_preset(_rng)
		result.append(BuildCard.from_parts(tower, preset))
	return result

func _deal() -> bool:
	var next := roll_cards(ShopConstants.OFFER_COUNT)
	if next.is_empty(): return false
	_accept_deal(next)
	return true

func _accept_deal(next: Array[BuildCard]) -> void:
	offers.assign(next)
	prices.clear()
	sold.clear()
	for card in offers:
		prices.append(card.price)
		sold.append(0)
	deals += 1

func open_shop() -> void:
	if _placement.pause_locked or _placement.entry_selection_active or get_tree().paused or not available or _wave.active:
		return
	_placement.set_shop_open(true)
	view.set_open(true)
	if is_instance_valid(_wave.controls): _wave.controls.visible = false

func close_shop() -> void:
	_placement.set_shop_open(false)
	view.set_open(false)
	if is_instance_valid(_wave.controls): _wave.controls.visible = true

func buy(index: int) -> bool:
	if _placement.pause_locked or _placement.entry_selection_active or get_tree().paused or not available or not view.opened or _wave.active or index < 0 or index >= offers.size() or sold[index] != 0 or offers[index] == null:
		return false
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
	_refresh()
	return true

func reroll() -> bool:
	if _placement.pause_locked or _placement.entry_selection_active or get_tree().paused or not available or not view.opened or _wave.active or catalog.is_empty() or view.rerolling:
		return false
	if coins < maxi(0, reroll_price):
		return false
	var next := roll_cards(ShopConstants.OFFER_COUNT)
	if next.is_empty(): return false
	coins -= maxi(0, reroll_price)
	_accept_deal(next)
	_refresh(true)
	view.animate_reroll()
	return true

func _refresh(insert_offers := false) -> void:
	view.show_offers(offers, prices, sold, coins, maxi(0, reroll_price), insert_offers)
	balance_changed.emit(coins)

func _exit_tree() -> void:
	if is_instance_valid(_wave):
		if _wave.wave_started.is_connected(_on_wave_started): _wave.wave_started.disconnect(_on_wave_started)
		if _wave.wave_finished.is_connected(_on_wave_finished): _wave.wave_finished.disconnect(_on_wave_finished)
