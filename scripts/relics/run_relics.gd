class_name RunRelics
extends Node
## One run, one RNG, one authoritative acquisition path. Independent of routing/shop.
signal changed
signal acquired(relic: RelicDefinition)
@export var catalog: RelicCatalog = preload("res://assets/data/relics/catalog.tres")
var tower_map: Node3D
var held: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _base_reroll_price := -1

func _ready() -> void:
	_rng.seed = catalog.random_seed
	if tower_map != null: tower_map.towers_changed.connect(refresh_towers)

func can_acquire(relic: RelicDefinition) -> bool:
	return relic != null and catalog.entries.has(relic) and relic.configuration_error().is_empty() and int(held.get(relic.id,0)) < (relic.max_stacks if relic.repeatable else 1)

func acquire(relic: RelicDefinition) -> bool:
	if not can_acquire(relic): return false
	held[relic.id] = int(held.get(relic.id,0))+1
	var shop := tower_map.get_node_or_null("../CardPlacement/Shop") if tower_map != null else null
	if shop != null and relic.id == &"gold":
		shop.coins += int(relic.parameters.amount)
		shop._refresh()
	refresh_towers()
	changed.emit()
	acquired.emit(relic)
	return true

func effects_for(definition: TowerDefinition) -> Dictionary:
	var result := {}
	for id: StringName in held:
		var relic := catalog.find(id)
		if relic == null or (relic.tower != null and relic.tower != definition): continue
		result[id] = relic.parameters.duplicate(true)
		result[id]["stacks"] = held[id]
	return result

func remove(relic: RelicDefinition) -> bool:
	if relic == null or not catalog.entries.has(relic): return false
	var count := int(held.get(relic.id,0))
	if count <= 0: return false
	if count == 1: held.erase(relic.id)
	else: held[relic.id] = count-1
	# Already resolved hits and instant gold are history; future attacks use the
	# refreshed effects. The manual playground is the only UI exposing removal.
	refresh_towers()
	changed.emit()
	return true

func refresh_towers() -> void:
	if not is_instance_valid(tower_map) or not tower_map.is_inside_tree(): return
	var shop := tower_map.get_node_or_null("../CardPlacement/Shop")
	if shop != null:
		if _base_reroll_price < 0: _base_reroll_price = shop.reroll_price
		var discount := catalog.find(&"reroll_discount")
		var amount := int(discount.parameters.get("amount",0)) if discount != null else 0
		shop.reroll_price = maxi(0, _base_reroll_price-int(held.get(&"reroll_discount",0))*amount)
		shop._refresh()
	for tower: DefenseTower in tower_map.towers.values():
		var previous_effects: Dictionary = tower.relic_effects
		var previous_right := tower.has_relic(&"crew_concentration")
		var previous_patrol := tower.has_relic(&"departure")
		tower.relic_effects = effects_for(tower.definition)
		for id in previous_effects:
			if not tower.relic_effects.has(id): tower.relic_clocks.erase(id)
		if previous_patrol and not tower.has_relic(&"departure"):
			tower.patrol_distance = 0.0
			tower.set_patrol_offset(0.0)
		if not tower.has_relic(&"rapid_fire"): tower.rapid_remaining = 0
		tower.support_bonus = 0.0
		var fuel := catalog.find(&"fuel_supply")
		if held.has(&"fuel_supply"):
			for other: DefenseTower in tower_map.towers.values():
				if other != tower and other.definition == fuel.tower and Vector2(other.grid_cell-tower.grid_cell).length() <= float(fuel.parameters.radius):
					tower.support_bonus += float(fuel.parameters.bonus)
		tower.isolated = true
		if tower.has_relic(&"secret_mission"):
			for other: DefenseTower in tower_map.towers.values():
				if other != tower and Vector2(other.grid_cell-tower.grid_cell).length() <= tower.relic_value(&"secret_mission", &"radius"):
					tower.isolated = false
		var previous_range := tower.range_multiplier
		tower.range_multiplier = float(tower.effect(&"support_attack").get("range_multiplier",1.0))
		tower.unlimited_levels = tower.has_relic(&"protagonist")
		tower.refresh_stats()
		if previous_range != tower.range_multiplier or previous_right != tower.has_relic(&"crew_concentration") or previous_patrol != tower.has_relic(&"departure"): tower._invalidate_attack_area()

func options() -> Array[RelicDefinition]:
	var result: Array[RelicDefinition] = []
	var generic: Array[RelicDefinition] = []
	var related: Array[RelicDefinition] = []
	var all: Array[RelicDefinition] = []
	var counts := {}
	if tower_map != null:
		for tower: DefenseTower in tower_map.towers.values(): counts[tower.definition] = int(counts.get(tower.definition,0))+1
	for relic in catalog.entries:
		if not can_acquire(relic): continue
		all.append(relic)
		if relic.tower == null: generic.append(relic)
		elif counts.has(relic.tower): related.append(relic)
	for pool: Array[RelicDefinition] in [generic,related,all]:
		var available: Array[RelicDefinition] = []
		for relic in pool:
			if not result.has(relic): available.append(relic)
		if available.is_empty():
			for relic in all:
				if not result.has(relic): available.append(relic)
		if available.is_empty(): break
		var weights: Array[float] = []
		var total := 0.0
		for relic in available:
			var weight := 1.0
			if pool == related: weight = maxf(0.001, catalog.weak_base_weight+catalog.weak_count_weight*sqrt(float(counts.get(relic.tower,0))))
			weights.append(weight)
			total += weight
		var roll := _rng.randf()*total
		var selected := available[-1]
		for i in available.size():
			roll -= weights[i]
			if roll < 0:
				selected = available[i]
				break
		result.append(selected)
	return result

func preview_cells(definition: TowerDefinition, anchor: Vector2i, turns: int) -> Array[Vector2i]:
	var effects := effects_for(definition)
	var factor := float(effects.get(&"support_attack",{}).get("range_multiplier",1.0))
	if effects.has(&"departure"): return definition.patrol_attack_cells(anchor,turns,factor,effects.has(&"crew_concentration"))
	return definition.effective_attack_cells(anchor, turns, factor, effects.has(&"crew_concentration"))
