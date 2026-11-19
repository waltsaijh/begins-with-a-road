extends RefCounted
## Geometry for entrance expansion and scout events. Never selects enemy routes.
const Layout = preload("res://scripts/map/tile/construction_layout.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const STEPS = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const INVALID := Vector2i(2147483647,2147483647)

static func capture(controller: Node, margin := 8, limit := 12000) -> Dictionary:
	var terminals: Array[Vector2i] = controller.terminal_cells()
	if terminals.size() < 2: return {}
	var map: GridMap = controller.map
	var protected: Dictionary = controller.blocked_cells.duplicate()
	var towers := controller.get_node_or_null("../TowerMap")
	if towers != null:
		if towers.traffic != null:
			for cell in towers.traffic.occupied: protected[cell] = true
		for tower: DefenseTower in towers.towers.values():
			if tower.deployment != null: protected[tower.garrison_cell()] = true
	var low := terminals[0]
	var high := low
	var roads := {}
	for cell in map.get_used_cells():
		if cell.y != 0: continue
		var at := Vector2i(cell.x,cell.z)
		low = low.min(at); high = high.max(at)
		if map.get_cell_item(cell) > 0 and not protected.has(at): roads[at] = true
	var proximity := {}
	for at: Vector2i in roads:
		for step in STEPS:
			proximity[at+step] = float(proximity.get(at+step,0.0))+8.0
			proximity[at+step*2] = float(proximity.get(at+step*2,0.0))+2.0
	var minimum := low-Vector2i.ONE*margin
	var maximum := high+Vector2i.ONE*margin
	if limit > 0 and (maximum.x-minimum.x+1)*(maximum.y-minimum.y+1) > limit: return {}
	return {"map":map,"goal":terminals[0],"terminals":terminals,"protected":protected,"roads":roads,"proximity":proximity,"low":minimum,"high":maximum,"map_low":low,"map_high":high}

static func distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

## A reverse shortest-cost tree serves every expansion candidate in one search.
## Scout events additionally allow their existing entrance's two-cell merge zone.
static func tree(context: Dictionary, entrance := INVALID, early_merge := false) -> Dictionary:
	if context.is_empty(): return {}
	var goal: Vector2i = context.goal
	var costs := {goal:0.0}
	var parents := {}
	var heap: Array = []
	_push(heap,0.0,goal)
	while not heap.is_empty():
		var entry := _pop(heap)
		var at: Vector2i = entry[1]
		if float(entry[0]) > float(costs[at])+0.000001: continue
		for step in STEPS:
			var next: Vector2i = at+step
			if next.x < context.low.x or next.y < context.low.y or next.x > context.high.x or next.y > context.high.y: continue
			if absi(next.x) >= 32767 or absi(next.y) >= 32767 or context.protected.has(next): continue
			if context.map.get_cell_item(Vector3i(next.x,0,next.y)) == 0: continue
			var near_end := distance(next,goal) <= 2 or (entrance != INVALID and distance(next,entrance) <= 2)
			if context.roads.has(next) and not near_end and not early_merge: continue
			var step_cost := 1.0
			if distance(at,goal) > 2 and (entrance == INVALID or distance(at,entrance) > 2):
				if context.roads.has(at):
					step_cost = 2.0
					if not context.roads.has(next): step_cost += 8.0+distance(at,goal)*0.25
				else: step_cost += float(context.proximity.get(at,0.0))
			var cost: float = costs[at]+step_cost
			if cost+0.000001 >= float(costs.get(next,INF)): continue
			costs[next] = cost; parents[next] = at
			_push(heap,cost,next)
	return {"parents":parents,"goal":goal,"costs":costs}

static func path(tree_data: Dictionary, start: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if tree_data.is_empty() or not tree_data.costs.has(start): return result
	var at := start
	result.append(at)
	while at != tree_data.goal:
		if not tree_data.parents.has(at):
			result.clear()
			return result
		at = tree_data.parents[at]
		result.append(at)
	# Avoid extreme detours even when they have a better separation cost.
	if result.size()-1 > ceili(distance(start,tree_data.goal)*1.75)+6: result.clear()
	return result

static func proposal(context: Dictionary, route: Array[Vector2i], independent := true) -> Dictionary:
	if route.size() < 2: return {}
	var ground := {}
	var ports := {}
	var fresh := 0
	var separated := 0
	for i in route.size():
		var at := route[i]
		ground[at] = true
		if not context.roads.has(at):
			fresh += 1
			if STEPS.all(func(step): return not context.roads.has(at+step)): separated += 1
		var mask := 0
		for d in 4:
			if (i > 0 and route[i-1] == at+STEPS[d]) or (i+1 < route.size() and route[i+1] == at+STEPS[d]): mask |= 1<<d
		ports[at] = mask
	return {"ground":ground,"ports":ports,"path":route,"fresh":fresh,"separated":separated,"independent":independent}

static func validate(controller: Node, proposed: Dictionary, extra: Array[Vector2i] = []) -> Dictionary:
	if proposed.is_empty(): return {}
	var placement := controller.get_node("../TilePlacement")
	var context := capture(controller,0,0)
	if context.is_empty(): return {}
	for at: Vector2i in proposed.ground:
		if context.protected.has(at) or context.map.get_cell_item(Vector3i(at.x,0,at.y)) == 0: return {}
	var requested: Dictionary = proposed.ports.duplicate()
	for cell: Vector2i in requested:
		# Do not turn authored manual card exits into automatic junctions.
		if not placement.port_overrides.has(cell) or int(placement.port_overrides[cell]) & Layout.GENERATED:
			requested[cell] = int(requested[cell]) | Layout.GENERATED
	var layout: Dictionary = Layout.build(context.map,proposed.ground,requested,placement.port_overrides,controller.blocked_cells)
	var terminals: Array[Vector2i] = context.terminals.duplicate()
	terminals.append_array(extra)
	if not Snapshot.connects_terminals(layout.snapshot,terminals): return {}
	var route: Array[Vector2i] = proposed.path
	for i in range(route.size()-1):
		var d: int = STEPS.find(route[i+1]-route[i])
		if d < 0 or not int(layout.masks.get(route[i],0)) & (1<<d) or not int(layout.masks.get(route[i+1],0)) & (1<<((d+2)%4)): return {}
	return layout

static func commit(controller: Node, proposed: Dictionary, extra: Array[Vector2i] = [], publish := true) -> Dictionary:
	var layout := validate(controller,proposed,extra)
	if layout.is_empty(): return {"ok":false,"added":[]}
	var placement := controller.get_node("../TilePlacement")
	var added: Array[Vector3i] = Layout.apply(placement,layout)
	if publish:
		controller.rebuild()
		placement.notify_cells(added)
	return {"ok":true,"added":added}

static func _push(heap: Array, cost: float, cell: Vector2i) -> void:
	var item := [cost,cell]
	var index := heap.size()
	heap.append(item)
	while index > 0:
		var parent := (index-1)>>1
		if float(heap[parent][0]) <= cost: break
		heap[index] = heap[parent]
		index = parent
	heap[index] = item

static func _pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty(): return first
	var index := 0
	while index*2+1 < heap.size():
		var child := index*2+1
		if child+1 < heap.size() and float(heap[child+1][0]) < float(heap[child][0]): child += 1
		if float(last[0]) <= float(heap[child][0]): break
		heap[index] = heap[child]
		index = child
	heap[index] = last
	return first
