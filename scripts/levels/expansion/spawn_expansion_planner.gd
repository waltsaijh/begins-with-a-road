extends RefCounted
## Enumerate legal frontiers, then route toward the base instead of the nearest road.
const Search = preload("res://scripts/map/tile/road_construction_search.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const DIRECTIONS = Search.STEPS
const KEYS := ["north","east","south","west"]
const MIN_GOAL_DISTANCE := 8
const MIN_START_DISTANCE := 6

static func generate(controller: Node, depth: int, band: int, blocked_goal_sides := 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if controller.computing: return result
	var context := Search.capture(controller,depth)
	if context.is_empty(): return result
	var snapshot := Snapshot.capture(context.map,controller.blocked_cells)
	var ports := {}
	for i in snapshot.ports.size(): ports[Vector2i(snapshot.cells[i*2],snapshot.cells[i*2+1])] = int(snapshot.ports[i])
	var goal: Vector2i = context.goal
	if not ports.has(goal): return result
	var reachable := {goal:true}
	var queue: Array[Vector2i] = [goal]
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for d in 4:
			var next: Vector2i = at+DIRECTIONS[d]
			if reachable.has(next) or not int(ports[at]) & (1<<d) or not int(ports.get(next,0)) & (1<<((d+2)%4)): continue
			reachable[next] = true
			queue.append(next)
	# Flooding only enumerates endpoints. It never supplies the final nearest-road path.
	var distances := {}
	for at in queue: distances[at] = 0
	head = 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		if int(distances[at]) >= depth: continue
		for step in DIRECTIONS:
			var next: Vector2i = at+step
			if distances.has(next) or context.protected.has(next) or absi(next.x) >= 32767 or absi(next.y) >= 32767: continue
			if context.map.get_cell_item(Vector3i(next.x,0,next.y)) != GridMap.INVALID_CELL_ITEM: continue
			distances[next] = int(distances[at])+1
			queue.append(next)
	var independent := Search.tree(context)
	var fallback: Dictionary = {}
	var zones: Array[Dictionary] = [{},{},{},{}]
	var proposals: Array[Dictionary] = [{},{},{},{}]
	for cell: Vector2i in distances:
		if not permitted_side(cell,goal,blocked_goal_sides): continue
		if int(distances[cell]) < band or Search.distance(cell,goal) < MIN_GOAL_DISTANCE: continue
		if context.terminals.slice(1).any(func(origin): return Search.distance(cell,origin) < MIN_START_DISTANCE): continue
		var outside: Array[int] = [context.map_low.y-cell.y,cell.x-context.map_high.x,cell.y-context.map_high.y,context.map_low.x-cell.x]
		var sector := 0
		for d in range(1,4):
			if outside[d] > outside[sector]: sector = d
		if outside[sector] < band: continue
		var route := Search.path(independent,cell)
		var strict := not route.is_empty()
		if not strict:
			if fallback.is_empty(): fallback = Search.tree(context,Search.INVALID,true)
			route = Search.path(fallback,cell)
		if route.is_empty(): continue
		var proposed := Search.proposal(context,route,strict)
		if proposed.fresh < band: continue
		zones[sector][cell] = route
		proposals[sector][cell] = proposed
	for sector in 4:
		if not zones[sector].is_empty(): result.append({"direction":KEYS[sector],"paths":zones[sector],"proposals":proposals[sector]})
	return result

static func allowed(choices: Array[Dictionary], last_region: String) -> Array[Dictionary]:
	var alternatives: Array[Dictionary] = []
	for choice in choices:
		if choice.direction != last_region: alternatives.append(choice)
	if alternatives.is_empty(): alternatives = choices.duplicate()
	# Keep every permitted location: the player, not RNG, chooses the entrance.
	return alternatives

static func permitted_side(cell: Vector2i, goal: Vector2i, blocked_goal_sides: int) -> bool:
	var delta := cell-goal
	return not ((blocked_goal_sides & 1 and delta.y < 0) or (blocked_goal_sides & 2 and delta.x > 0) or (blocked_goal_sides & 4 and delta.y > 0) or (blocked_goal_sides & 8 and delta.x < 0))

static func valid(controller: Node, cell: Vector2i, path: Array, blocked_goal_sides := 0) -> bool:
	if controller.computing or path.is_empty() or path[0] != cell or controller.map.get_cell_item(Vector3i(cell.x,0,cell.y)) != GridMap.INVALID_CELL_ITEM: return false
	var context := Search.capture(controller,0,0)
	if context.is_empty() or Search.distance(cell,context.goal) < MIN_GOAL_DISTANCE: return false
	if not permitted_side(cell,context.goal,blocked_goal_sides): return false
	for origin: Vector2i in context.terminals.slice(1):
		if Search.distance(cell,origin) < MIN_START_DISTANCE: return false
	var route: Array[Vector2i] = []
	route.assign(path)
	return not Search.validate(controller,Search.proposal(context,route),[cell]).is_empty()
