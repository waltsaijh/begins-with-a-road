class_name SpecialEventManager
extends Node
signal resolved
const RoadBuilder = preload("res://scripts/events/event_road_builder.gd")
@export var catalog: Array[SpecialEventDefinition] = []
@export var road_margin := 8
@export var road_search_limit := 12000
var session: Node3D
var towers: Node3D
var cards: Node3D
var shop: Node
var choice: CanvasLayer
var active: SpecialEventDefinition
var seen := {}
var pending_reinforcements: Array[Dictionary] = []
var batches := {}
var _next_batch := 0
var _rng := RandomNumberGenerator.new()
var _resolving := false
var _target_option := -1
var _road_proposal := {}
var _ceasefire: Array[WeakRef] = []
var _storm_multiplier := 1.0
var _gem_bonus := 0.0
var wave_gold_bonus := 0

func setup(host: Node3D) -> void:
	session = host
	towers = host.get_node("TowerMap")
	cards = host.get_node("CardPlacement")
	shop = cards.get_node("Shop")
	_rng.randomize()
	if host._balance_seed >= 0: _rng.seed = host._balance_seed+4000
	if catalog.is_empty() and host.level.special_event_catalog != null:
		catalog.assign(host.level.special_event_catalog.entries)
		road_margin = host.level.special_event_catalog.road_margin
		road_search_limit = host.level.special_event_catalog.road_search_limit
	choice = preload("res://scenes/events/special_event_choice.tscn").instantiate()
	add_child(choice)
	choice.setup(self)
	cards.card_placed.connect(_on_card_placed)
	cards.selection_changed.connect(func(card: BuildCard):
		if active != null: return
		choice.clear_targets()
		if card != null and card.special != null and card.special.kind == SpecialCardDefinition.Kind.CONSUMABLE:
			choice.highlight_towers("potion"))
	towers.towers_changed.connect(refresh_towers)
	host._wave.wave_started.connect(_on_wave_started)
	host._wave.wave_finished.connect(_on_wave_finished)

static func due(completed: int,total: int) -> bool:
	return completed > 0 and completed < total and completed % 5 == 0

func eligible_towers(mode: String) -> Array[DefenseTower]:
	var result: Array[DefenseTower] = []
	for tower: DefenseTower in towers.towers.values():
		if not is_instance_valid(tower) or tower.health <= 0 or tower.is_queued_for_deletion(): continue
		if mode == "upgrade" and not tower.upgrade_error().is_empty(): continue
		if mode == "downgrade" and tower.level <= 1: continue
		result.append(tower)
	return result

func available_relics() -> Array[RelicDefinition]:
	var result: Array[RelicDefinition] = []
	for relic in towers.relics.catalog.entries:
		if towers.relics.can_acquire(relic): result.append(relic)
	return result

func option_error(definition: SpecialEventDefinition, index: int) -> String:
	var balance: int = shop.coins
	for effect in definition.effects(index):
		match String(effect.type):
			"spend":
				balance -= int(effect.amount)
				if balance < 0: return tr("event.unavailable.gold")
			"health":
				if session.base_health <= int(effect.amount): return tr("event.unavailable.health")
			"upgrade", "downgrade", "remove", "ceasefire":
				if eligible_towers(effect.type).is_empty(): return tr("event.unavailable.tower")
			"relic":
				if available_relics().is_empty(): return tr("event.unavailable.relic")
			"road":
				if _road_proposal.is_empty(): return tr("event.unavailable.road")
			"random_card":
				if shop.catalog.is_empty(): return tr("event.unavailable.card")
	return ""

func begin(forced: SpecialEventDefinition = null) -> bool:
	if active != null or session.finished: return false
	_road_proposal = RoadBuilder.propose(towers,road_margin,road_search_limit)
	var eligible: Array[SpecialEventDefinition] = []
	for definition in catalog:
		if definition != null and (option_error(definition,0).is_empty() or option_error(definition,1).is_empty()): eligible.append(definition)
	if forced != null:
		if not forced in eligible: return false
		active = forced
	else:
		if eligible.is_empty(): return false
		var fresh: Array[SpecialEventDefinition] = []
		for definition in eligible:
			if not seen.has(definition.id): fresh.append(definition)
		# A new cycle only begins after every currently executable event was encountered.
		if fresh.is_empty():
			seen.clear()
			fresh = eligible
		active = fresh[_rng.randi_range(0,fresh.size()-1)]
	seen[active.id] = true
	_resolving = false
	_target_option = -1
	choice.present()
	return true

func choose(index: int) -> bool:
	if active == null or _resolving or index < 0 or index > 1 or get_tree().paused or not option_error(active,index).is_empty(): return false
	_resolving = true
	for effect in active.effects(index):
		if effect.type in ["remove","ceasefire"]:
			_target_option = index
			choice.select_target(effect.type)
			return true
	return _execute(index)

func select_target(tower: DefenseTower) -> bool:
	if active == null or _target_option < 0 or not is_instance_valid(tower) or get_tree().paused: return false
	var index := _target_option
	var mode := ""
	for effect in active.effects(index):
		if effect.type in ["remove","ceasefire"]: mode = effect.type
	if not tower in eligible_towers(mode): return false
	_target_option = -1
	return _execute(index,tower)

func _execute(index: int,target: DefenseTower = null) -> bool:
	# No awaits between final validation and all effects. Guard is held through signals.
	if not option_error(active,index).is_empty():
		_resolving = false
		choice.present()
		return false
	for effect in active.effects(index):
		match String(effect.type):
			"road":
				if not RoadBuilder.commit(towers,_road_proposal):
					_road_proposal = {}
					_resolving = false
					choice.present()
					return false
			"gold": shop.grant_gold(int(effect.amount),"special_event")
			"spend": shop.spend_gold(int(effect.amount),"special_event")
			"health":
				session.base_health -= int(effect.amount)
				session.run_status.refresh()
			"upgrade", "downgrade":
				var pool := eligible_towers(effect.type)
				for i in mini(int(effect.get("count",1)),pool.size()):
					var at := _rng.randi_range(0,pool.size()-1)
					var tower: DefenseTower = pool[at]
					pool.remove_at(at)
					if effect.type == "upgrade": tower.upgrade()
					else: tower.downgrade()
					towers.tower_upgraded.emit(tower)
			"remove": towers.remove_tower(Vector3i(target.grid_cell.x,0,target.grid_cell.y))
			"ceasefire":
				target.event_ceasefire = true
				target._refresh_disable_visual()
				_ceasefire.append(weakref(target))
			"reinforce": pending_reinforcements.append(effect.duplicate(true))
			"card": _give_cards(effect.id,int(effect.count))
			"random_card":
				for card in shop.roll_cards(1): cards.add_card(card)
			"relic":
				var pool := available_relics()
				towers.relics.acquire(pool[_rng.randi_range(0,pool.size()-1)])
	active = null
	choice.dismiss()
	refresh_towers()
	resolved.emit()
	return true

func _give_cards(id: String,count: int) -> void:
	_next_batch += 1
	var definition: SpecialCardDefinition = load("res://assets/data/events/cards/%s.tres" % id)
	batches[_next_batch] = {"id":id,"remaining":count,"damage_bonus":definition.damage_bonus,"wave_gold":definition.wave_gold,"incomplete_multiplier":definition.incomplete_damage_multiplier}
	for i in count:
		var card := BuildCard.new()
		card.special = definition
		card.event_batch = _next_batch
		cards.add_card(card)

func _on_card_placed(card: BuildCard,_instance: Node3D,_cell: Vector3i,_turns: int) -> void:
	if card.special == null or not batches.has(card.event_batch): return
	var batch: Dictionary = batches[card.event_batch]
	if batch.remaining <= 0: return
	batch.remaining -= 1
	if batch.remaining == 0:
		_gem_bonus += float(batch.damage_bonus)
		wave_gold_bonus += int(batch.wave_gold)
	refresh_towers()
	session.refresh_event_wave()

func refresh_towers() -> void:
	if not is_instance_valid(towers): return
	for tower: DefenseTower in towers.towers.values():
		tower.event_damage_multiplier = (1.0+_gem_bonus)*_storm_multiplier
		tower.refresh_stats()

func _on_wave_started() -> void:
	pending_reinforcements.clear()
	_storm_multiplier = 1.0
	for batch: Dictionary in batches.values():
		if batch.remaining > 0: _storm_multiplier = minf(_storm_multiplier,float(batch.incomplete_multiplier))
	refresh_towers()

func _on_wave_finished() -> void:
	for ref in _ceasefire:
		var tower: DefenseTower = ref.get_ref()
		if is_instance_valid(tower):
			tower.event_ceasefire = false
			tower._refresh_disable_visual()
	_ceasefire.clear()

func effective_wave(source: WaveDefinition) -> WaveDefinition:
	var result: WaveDefinition = source.duplicate(true)
	result.reward += wave_gold_bonus
	var origin_count: int = towers.controller.start_paths.size()
	for effect in pending_reinforcements:
		var origins: Array[int] = []
		if effect.get("per_start",false):
			for i in origin_count: origins.append(i)
		else: origins.append(clampi(int(effect.get("start",0)),0,origin_count-1))
		for origin in origins:
			var group := WaveSpawnGroup.new()
			group.troop_path = "res://assets/data/troops/%s.tres" % effect.troop
			group.enemy_count = int(effect.count)
			group.start_index = origin
			group.fixed_start = true
			group.interval_ticks = int(effect.get("interval_ticks",2))
			result.groups.append(group)
	return result
