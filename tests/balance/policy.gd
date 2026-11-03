extends RefCounted
## Bounded, player-visible preparation policy. No future waves or random draws.
const PRIORITIES := {
	"generalist":["sentry","crossfire","ballista","mortar","broadside","barracks"],
	"damage":["sentry","ballista","broadside","crossfire","mortar","barracks"],
	"route":["crossfire","sentry","barracks","ballista","mortar","broadside"],
	"swarm":["crossfire","mortar","sentry","barracks","broadside","ballista"],
	"heavy":["ballista","sentry","broadside","barracks","crossfire","mortar"],
	"barracks":["barracks","sentry","crossfire","mortar","ballista","broadside"],
	"core":["sentry","crossfire","ballista","broadside","mortar","barracks"]}
var kind := "generalist"
var session: Node
var exposure := {}
var coverage := {}
var _refresh_key: Array = []
var _traffic_cache := {}
func key(definition: TowerDefinition) -> String: return definition.name_key.split(".")[1]
func refresh() -> void:
	var tm: Node = session.get_node("TowerMap")
	var state: Array = [session.current_wave,tm.controller.revision,tm.traffic.effects()]
	for tower: DefenseTower in tm.towers.values(): state.append([tower.grid_cell,tower.level])
	if state == _refresh_key: return
	_refresh_key = state.duplicate(true)
	_traffic_cache.clear()
	exposure.clear()
	coverage.clear()
	var wave: Node = session.get_node("EnemyWave")
	var schedule := WaveSpawnSchedule.build(wave.definition,wave.controller,0,false)
	for member: Dictionary in schedule.get("pending",[]):
		for cell: Vector2 in member.route.cells:
			var at := Vector2i(cell)
			exposure[at] = float(exposure.get(at,0))+1.0/maxi(1,wave.definition.total_count())
	for tower: DefenseTower in session.get_node("TowerMap").towers.values():
		for at in tower.definition.attack_cells_at(tower.grid_cell,tower.rotation_steps): coverage[at] = float(coverage.get(at,0))+1
func best(card: BuildCard) -> Dictionary:
	var tm: Node = session.get_node("TowerMap")
	if card.traffic != null: return best_traffic(card)
	var upgrading: bool = kind == "core" or tm.towers.size() >= 7
	var upgrade := {}
	for tower: DefenseTower in tm.towers.values():
		if tower.definition != card.tower or not tower.upgrade_error().is_empty(): continue
		var score := score_cells(card.tower.attack_cells_at(tower.grid_cell,tower.rotation_steps),false)
		if score > float(upgrade.get("score",0)): upgrade = {"at":Vector3i(tower.grid_cell.x,0,tower.grid_cell.y),"turns":tower.rotation_steps,"score":score}
	if upgrading and not upgrade.is_empty(): return upgrade
	var possible := {}
	for cell: Vector3i in tm.map.get_used_cells():
		for x in range(-2,3):
			for y in range(-2,3): possible[Vector2i(cell.x+x,cell.z+y)] = true
	var ranked: Array[Dictionary] = []
	for at: Vector2i in possible:
		if tm.occupied.has(at) or at in tm.controller.terminal_cells(): continue
		for turns in 4:
			var score := score_cells(card.tower.attack_cells_at(at,turns),true)
			if score <= 0: continue
			if card.tower.deployment != null:
				if not tm._validate_deployment(card.tower,at,turns).is_empty(): continue
				score *= 1.5
			# Avoid gratuitous new road area; prefer existing supports at equal coverage.
			var added := 0
			for ground in card.ground_cells(at,turns):
				if tm.map.get_cell_item(Vector3i(ground.x,0,ground.y)) < 0: added += 1
			score -= 0.015*added
			ranked.append({"at":Vector3i(at.x,0,at.y),"turns":turns,"score":score})
	ranked.sort_custom(func(a,b):
		if not is_equal_approx(a.score,b.score): return a.score > b.score
		if a.at.x != b.at.x: return a.at.x < b.at.x
		if a.at.z != b.at.z: return a.at.z < b.at.z
		return a.turns < b.turns)
	for candidate in ranked.slice(0,120):
		if tm.validate_card(card,candidate.at,candidate.turns).is_empty(): return candidate
	return upgrade
func score_cells(cells: Array[Vector2i], spread: bool) -> float:
	var score := 0.0
	for at in cells: score += float(exposure.get(at,0))/(1.0+float(coverage.get(at,0))*0.65 if spread else 1.0)
	return score
func best_traffic(card: BuildCard) -> Dictionary:
	if kind != "route": return {}
	if _traffic_cache.has(card.traffic): return _traffic_cache[card.traffic]
	var tm: Node = session.get_node("TowerMap")
	var wave: Node = session.get_node("EnemyWave")
	var original := WaveSpawnSchedule.build(wave.definition,wave.controller,0,false)
	var before := traffic_score(original)
	var result := {}
	# Bounded sample of legal road or adjacent cells. Forecast never shuffles.
	var cells: Array = tm.map.get_used_cells()
	cells.sort_custom(func(a,b): return a.x < b.x if a.x != b.x else a.z < b.z)
	var checked := 0
	for cell: Vector3i in cells:
		var at := Vector2i(cell.x,cell.z)
		if card.traffic.placement == TrafficStructureDefinition.Placement.NEAR_ROAD: at += Vector2i.DOWN
		if not tm.traffic.validate(card.traffic,at,0).is_empty(): continue
		var effects: Array = tm.traffic.effects()
		effects.append(card.traffic.effect_at(at,0))
		var candidate := WaveSpawnSchedule.build(wave.definition,wave.controller,0,false,PackedInt32Array(),effects)
		var gain := traffic_score(candidate)-before
		if gain > float(result.get("score",0))+0.001: result = {"at":Vector3i(at.x,0,at.y),"turns":0,"score":gain}
		checked += 1
		if checked >= 20: break
	_traffic_cache[card.traffic] = result
	return result
func traffic_score(schedule: Dictionary) -> float:
	var score := 0.0
	for member: Dictionary in schedule.get("pending",[]):
		var per_enemy := 0.0
		for cell: Vector2 in member.route.cells: per_enemy += float(coverage.get(Vector2i(cell),0))
		score += per_enemy
	return score
func preference(card: BuildCard) -> float:
	if card == null: return -1000
	if card.traffic != null: return 5.5 if kind == "route" else -1000
	var order: Array = PRIORITIES[kind]
	var score := 6.0-order.find(key(card.tower))
	var count := 0
	for tower: DefenseTower in session.get_node("TowerMap").towers.values():
		if tower.definition == card.tower: count += 1
	if kind == "generalist" and count == 0: score += 3
	if kind == "barracks" and key(card.tower) == "barracks" and count >= 2: score -= 5
	return score
func relic(offers: Array[RelicDefinition]) -> RelicDefinition:
	var chosen: RelicDefinition = offers[0]
	var high := -INF
	for entry in offers:
		var score := 1.0
		if entry.id == &"gold": score = 2.0
		if entry.id in [&"global_damage",&"global_haste"]: score = 4.0
		if entry.tower != null:
			for tower: DefenseTower in session.get_node("TowerMap").towers.values():
				if tower.definition == entry.tower: score = maxf(score,5.0+(6-PRIORITIES[kind].find(key(entry.tower)))*0.2)
		if kind == "core" and entry.id == &"protagonist": score = 10
		if score > high:
			high = score
			chosen = entry
	return chosen
