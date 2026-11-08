extends RefCounted
## Production planners on an isolated proposed graph; never consumes departure RNG.
const Portal = preload("res://scripts/navigation/portal_map.gd")

static func build(tower_map: Node, proposal: Dictionary, wave: Node) -> Dictionary:
	if not proposal.ok: return {"ok":false,"error":proposal.error,"pending":[]}
	if wave == null or wave.definition == null: return {"ok":true,"error":"","pending":[]}
	if not ClassDB.class_exists("RoadPortalGraph") or not ClassDB.class_exists("RoadRoutePlanner"):
		return {"ok":false,"error":"原生道路擴充尚未載入","pending":[]}
	var source: Node = tower_map.controller
	var terminals: Array[Vector2i] = source.terminal_cells()
	var probe := Portal.new()
	probe.map = source.map
	probe.troop = source.troop
	probe.traffic_effects = source.traffic_effects.duplicate(true)
	probe.route_history.wave = source.route_history.wave
	probe.route_history.tile_waves = source.route_history.tile_waves.duplicate()
	probe.route_history.current = source.route_history.current.duplicate(true)
	probe.route_history.revision = source.route_history.revision
	probe.route_history.record(proposal.snapshot,terminals)
	var builder: RefCounted = ClassDB.instantiate("RoadPortalGraph")
	probe.graph = builder.build(proposal.snapshot.cells,proposal.snapshot.ports,terminals[1],terminals[0],false,PackedVector2Array(terminals.slice(1)))
	var result := {"ok":false,"error":"無法建立預擺路線","pending":[]}
	if not probe.graph.get("valid",false):
		result.error = str(probe.graph.get("error",result.error))
		probe.free()
		return result
	var node_at := {}
	for node: Dictionary in probe.graph.nodes: node_at[node.cell] = node.id
	for terminal in terminals.slice(1):
		if not node_at.has(terminal):
			probe.free()
			return result
		probe.start_nodes.append(node_at[terminal])
	probe.graph.start_nodes = probe.start_nodes
	probe.planner = ClassDB.instantiate("RoadRoutePlanner")
	var prepared: Dictionary = probe.planner.prepare(probe.graph)
	if not prepared.get("valid",false):
		probe.free()
		return result
	probe._candidate_routes.prepare(probe.graph)
	probe.tile_parameters.sync(probe.graph.tiles,proposal.blocked)
	# Copy authored score inputs; no mutable records or callbacks are shared.
	for tile in probe.tile_parameters.all_tiles():
		var original = source.tile_parameters.get_tile(tile.cell)
		if original != null:
			for property in ["terrain_id","movement_multiplier","damage_per_second","cover","num_towers_around","threat"]:
				tile.set(property,original.get(property))
			tile._parameters = original._parameters.duplicate(true)
		else:
			tile.threat = source.tile_parameters._tower_threat.get(tile.cell,0.0)
			tile.num_towers_around = source.tile_parameters._tower_counts.get(tile.cell,0)
	probe.tile_parameters.set_road_ages(probe.route_history.tile_ages())
	for entry: Dictionary in proposal.builds:
		var cells: Array[Vector2i] = tower_map.relics.preview_cells(entry.card.tower,entry.at,entry.turns,TowerBodyGeometry.local_cells(entry.card.tile_preset))
		for tile in probe.tile_parameters.all_tiles():
			if tile.cell in cells: tile.threat += entry.card.tower.threat
			var offset: Vector2i = tile.cell-entry.at
			if offset != Vector2i.ZERO and absi(offset.x) <= 1 and absi(offset.y) <= 1: tile.num_towers_around += 1
	var geometry := tower_map.get_node_or_null("../GeometryBonuses")
	if geometry != null: geometry.apply_proposed_influence(probe.tile_parameters,proposal)
	var schedule := WaveSpawnSchedule.build(wave.definition,probe,wave._next_enemy_id,false,wave.additional_start_indices)
	if not schedule.is_empty():
		result = {"ok":true,"error":"","pending":schedule.pending,"pool_size":schedule.pool_size}
	else:
		for group in wave.definition.groups:
			for origin in WaveSpawnSchedule.origins_for(group,wave.additional_start_indices):
				var plan: Dictionary = probe.plan_for(group.troop,origin)
				if not plan.get("valid",false) or plan.get("routes",0) == 0:
					result.error = group.troop.localized_name()+"："+str(plan.get("error","沒有可用路線"))
	probe.free()
	return result
