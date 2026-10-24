extends Node
## One clean snapshot/build per edit frame. No route enumeration or movement.
signal graph_changed
signal plan_changed
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Parameters = preload("res://scripts/map/tile/tile_parameter_store.gd")
const CandidateRoutes = preload("res://scripts/navigation/routes/candidate_routes.gd")
@export var troop: Troop = TroopCatalog.default_troop()
## Every marker becomes a protected graph vertex, even inside a wide region.
@export var start_paths: Array[NodePath] = [^"../Start"]
@onready var map: GridMap = $"../TileMap"
var start_nodes := PackedInt32Array()
var active_start := 0
var graph: Dictionary = {}
var computing := false
var compute_us := 0
var revision := 0
var _queued := false
var plan: Dictionary = {}
var planner: RefCounted
var plan_us := 0
var tile_parameters := Parameters.new()
var evaluation_us := 0
var evaluation_calls := 0
var _cost_update_queued := false
var _candidate_routes := CandidateRoutes.new()
var _edit_guard: RefCounted
var _edit_guard_ready := false
## Physical road cells occupied by obstacles. Rendering keeps the underlying tiles.
var blocked_cells := {}
var traffic_effects: Array = []
var _traffic_distributions := {}
var route_history := preload("res://scripts/navigation/routes/route_history.gd").new()
var _special_routes := preload("res://scripts/navigation/routes/special_routes.gd").new()

func set_traffic_effects(effects: Array) -> void:
	_special_routes.invalidate()
	traffic_effects = effects.duplicate(true)
	_traffic_distributions.clear()
	plan_changed.emit()

func _traffic_distribution(profile: Troop, start_index: int, effects: Array) -> Dictionary:
	var key := _profile_key(profile, start_index)
	var cache_key := [key, effects]
	if not _traffic_distributions.has(cache_key):
		_traffic_distributions[cache_key] = _candidate_routes.modified_distribution(key, profile, effects)
	return _traffic_distributions[cache_key]

func clear_traffic_preview_cache() -> void:
	_special_routes.invalidate()
	_traffic_distributions.clear()


func terminal_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var goal := get_node_or_null("../Goal") as Node3D
	if goal == null:
		return result
	var goal_cell := map.local_to_map(map.to_local(goal.global_position))
	result.append(Vector2i(goal_cell.x, goal_cell.z))
	for path in start_paths:
		var marker := get_node_or_null(path) as Node3D
		if marker == null:
			return []
		var cell := map.local_to_map(map.to_local(marker.global_position))
		result.append(Vector2i(cell.x, cell.z))
	return result if result.size() > 1 else []

func set_blocked_cells(cells: Dictionary) -> void:
	blocked_cells = cells.duplicate()
	rebuild()

func _ready() -> void:
	$"../TilePlacement".cell_placed.connect(_on_cell_placed)
	tile_parameters.costs_changed.connect(_on_costs_changed)
	rebuild()

func _on_cell_placed(cell: Vector3i) -> void:
	# Every physical tile gets data even when it is outside the last graph.
	tile_parameters.ensure_tile(Vector2i(cell.x, cell.z))
	if computing:
		return # The pending snapshot already includes this frame's additions.
	if _edit_guard_ready and not _edit_guard.add_cell(Vector2i(cell.x, cell.z)):
		return
	rebuild()

func rebuild() -> void:
	_special_routes.invalidate()
	_traffic_distributions.clear()
	_edit_guard_ready = false
	revision += 1
	graph = {}
	plan = {}
	planner = null
	_candidate_routes = CandidateRoutes.new()
	start_nodes.clear()
	plan_us = 0
	computing = true
	graph_changed.emit()
	if not _queued:
		_queued = true
		_build.call_deferred()

func _build() -> void:
	_queued = false
	var began := Time.get_ticks_usec()
	if ClassDB.class_exists("RoadPortalGraph"):
		var builder: RefCounted = ClassDB.instantiate("RoadPortalGraph")
		var snapshot := Snapshot.capture(map, blocked_cells)
		route_history.record(snapshot,terminal_cells())
		_special_routes.history = route_history
		var starts: Array[Vector2i] = []
		for path in start_paths:
			var marker := get_node_or_null(path) as Node3D
			if marker == null:
				graph = {"valid": false, "error": "找不到起點：%s" % path}
				break
			var cell := map.local_to_map(map.to_local(marker.global_position))
			starts.append(Vector2i(cell.x, cell.z))
		var goal := map.local_to_map(map.to_local($"../Goal".global_position))
		if graph.is_empty():
			graph = builder.build(snapshot.cells, snapshot.ports, starts[0], Vector2i(goal.x, goal.z), false, PackedVector2Array(starts)) if not starts.is_empty() else {"valid": false, "error": "尚未設定起點"}
		if graph.get("valid", false):
			var node_at := {}
			for node: Dictionary in graph.nodes:
				node_at[node.cell] = node.id
			for cell in starts:
				if not node_at.has(cell):
					graph.valid = false
					graph.error = "起點 %s 未能建立移動節點" % cell
					break
				start_nodes.append(node_at[cell])
			graph.start_nodes = start_nodes
			for node: Dictionary in graph.nodes:
				node.is_start = node.id in start_nodes
			if graph.valid and ClassDB.class_exists("RoadEditGuard"):
				_edit_guard = ClassDB.instantiate("RoadEditGuard")
				var terminals := PackedVector2Array([Vector2(goal.x, goal.z)])
				for cell in starts:
					terminals.append(Vector2(cell))
				_edit_guard_ready = _edit_guard.prepare(snapshot.cells, snapshot.ports, terminals).valid
		active_start = clampi(active_start, 0, maxi(0, start_nodes.size()-1))
	else:
		push_error("RoadPortalGraph is missing. Build the extension and restart Godot.")
	compute_us = Time.get_ticks_usec()-began
	computing = false
	graph_changed.emit()
	if graph.get("valid", false) and ClassDB.class_exists("RoadRoutePlanner"):
		var began_plan := Time.get_ticks_usec()
		planner = ClassDB.instantiate("RoadRoutePlanner")
		var prepared: Dictionary = planner.prepare(graph)
		tile_parameters.sync(graph.tiles, blocked_cells)
		_candidate_routes.prepare(graph)
		plan = plan_for(troop, active_start) if prepared.valid else prepared
		_apply_region_paths()
		plan_us = Time.get_ticks_usec()-began_plan
		plan_changed.emit()
	elif graph.get("valid", false):
		plan = {"valid": false, "error": "原生路線規劃器未載入，請重新啟動 Godot"}
		plan_changed.emit()

func sample_route(seed: int) -> Dictionary:
	return sample_for(troop, seed, active_start) if plan.get("reachable", false) else {}

func _profile_key(profile: Troop, start_index := 0) -> String:
	var key := "profile:%d" % profile.get_instance_id()
	return key if start_index == 0 else key+":start:%d" % start_index

func plan_for(profile: Troop, start_index := 0, modifiers: Variant = null) -> Dictionary:
	if profile == null: return {"valid": false, "error": "尚未設定可用兵種"}
	if planner == null:
		return {"valid": false, "error": "尚未建立移動圖"}
	if start_index < 0 or start_index >= start_nodes.size():
		return {"valid": false, "error": "起點索引超出範圍"}
	if profile.route_rule != Troop.RouteRule.COST:
		var callback := _on_costs_changed.bind(profile.get_instance_id())
		if not profile.changed.is_connected(callback): profile.changed.connect(callback)
		return _special_routes.plan_for(profile,start_index,traffic_effects if modifiers == null else modifiers)
	var began := Time.get_ticks_usec()
	var evaluated := tile_parameters.evaluate(profile)
	evaluation_us = Time.get_ticks_usec()-began
	evaluation_calls = evaluated.evaluation_calls
	if not evaluated.valid:
		planner.invalidate("guided:"+_profile_key(profile, start_index))
		_candidate_routes.invalidate(_profile_key(profile, start_index))
		return evaluated
	var result: Dictionary = _candidate_routes.plan_for(planner, profile, _profile_key(profile, start_index), start_nodes[start_index], evaluated.costs)
	var effects: Array = traffic_effects if modifiers == null else modifiers
	if result.get("valid", false) and not effects.is_empty():
		var distribution := _traffic_distribution(profile, start_index, effects)
		if not distribution.get("valid", false): return distribution
		result.route_probabilities = distribution.probabilities
	return result

func sample_for(profile: Troop, seed: int, start_index := 0, route_index := -1) -> Dictionary:
	if planner == null or profile == null: return {}
	if profile.route_rule != Troop.RouteRule.COST: return _special_routes.route_for(profile,start_index,traffic_effects,0,1,seed,route_index)
	if traffic_effects.is_empty(): return _candidate_routes.sample(_profile_key(profile,start_index),seed,route_index)
	var entry := plan_for(profile,start_index)
	if not entry.get("reachable",false): return {}
	var distribution := _traffic_distribution(profile,start_index,traffic_effects)
	var index := route_index if route_index >= 0 else preload("res://scripts/navigation/routes/route_distribution.gd").sample(distribution.cdf,seed)
	var result: Dictionary = _candidate_routes.sample(_profile_key(profile,start_index),seed,index)
	if not result.is_empty(): result.selection_probability = distribution.probabilities[index]
	return result

func debug_graph_for(profile: Troop, start_index := 0) -> Dictionary:
	if profile.route_rule != Troop.RouteRule.COST: return {"nodes":PackedInt32Array(),"edges":[]}
	var entry := plan_for(profile, start_index)
	return _candidate_routes.debug_graph(_profile_key(profile, start_index)) if entry.get("valid", false) else {}

## Deterministic wave allocation through cumulative probability intervals.
func allocate_route_for(profile: Troop, index: int, total: int, start_index := 0, modifiers: Variant = null) -> Dictionary:
	if profile != null and profile.route_rule != Troop.RouteRule.COST:
		return _special_routes.route_for(profile,start_index,traffic_effects if modifiers == null else modifiers,index,total)
	var entry := plan_for(profile, start_index, modifiers)
	if not entry.get("reachable", false):
		return {}
	var effects: Array = traffic_effects if modifiers == null else modifiers
	if not effects.is_empty(): return _candidate_routes.allocate_modified(_profile_key(profile, start_index), index, total, _traffic_distribution(profile, start_index, effects))
	return _candidate_routes.allocate(_profile_key(profile, start_index), index, total)

## Stateless sampling for probes and previews;
## previews and other origins cannot consume or change an allocation cursor.
func next_route_for(profile: Troop, seed: int, start_index := 0) -> Dictionary:
	var entry := plan_for(profile, start_index)
	if not entry.get("reachable", false):
		return {}
	return sample_for(profile, seed, start_index)

func select_troop(profile: Troop) -> void:
	if profile == null:
		return
	troop = profile
	if planner == null:
		return
	plan = plan_for(profile, active_start)
	_apply_region_paths()
	graph_changed.emit()
	plan_changed.emit()

func select_start(start_index: int) -> void:
	if planner == null or start_index < 0 or start_index >= start_nodes.size():
		return
	active_start = start_index
	var began := Time.get_ticks_usec()
	plan = plan_for(troop, active_start)
	_apply_region_paths()
	plan_us = Time.get_ticks_usec()-began
	graph_changed.emit()
	plan_changed.emit()

func _apply_region_paths() -> void:
	# The debug overlay reads the accepted candidate paths, not native guides.
	graph.local_routes = []
	graph.stats.local_routes = 0
	for region: Dictionary in graph.regions:
		region.route_visible_links = PackedInt32Array()

func _on_costs_changed(id: int) -> void:
	_special_routes.invalidate()
	_traffic_distributions.clear()
	if id == 0:
		_candidate_routes.invalidate()
	else:
		for index in start_nodes.size():
			var key := "profile:%d" % id if index == 0 else "profile:%d:start:%d" % [id, index]
			_candidate_routes.invalidate(key)
	if planner != null:
		if id == 0:
			planner.invalidate()
		else:
			var key := "guided:profile:%d" % id
			planner.invalidate(key)
			for index in range(1, start_nodes.size()):
				planner.invalidate(key+":start:%d" % index)
	if id != 0 and (troop == null or id != troop.get_instance_id()):
		return
	# Clear the visible decision immediately; coalesce several parameter edits.
	plan = {}
	graph_changed.emit()
	if not _cost_update_queued:
		_cost_update_queued = true
		_refresh_costs.call_deferred()

func _refresh_costs() -> void:
	_cost_update_queued = false
	if planner == null or computing:
		return
	var began := Time.get_ticks_usec()
	plan = plan_for(troop, active_start)
	plan_us = Time.get_ticks_usec()-began
	_apply_region_paths()
	graph_changed.emit()
	plan_changed.emit()
