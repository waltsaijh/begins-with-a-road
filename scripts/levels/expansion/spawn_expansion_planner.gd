extends RefCounted
## Bounded multi-source flood: paths only add empty cells to reachable road edges.
## The source game's frontier spacing is retained without copying its grid manager.
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]
const KEYS := ["north", "west", "south", "east"]
const MIN_GOAL_DISTANCE := 8
const MIN_START_DISTANCE := 6

static func generate(controller: Node, depth: int, band: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var map: GridMap = controller.map
	var reserved := _traffic_cells(controller)
	var terminals: Array[Vector2i] = controller.terminal_cells()
	if terminals.is_empty() or controller.computing: return result
	var snapshot := Snapshot.capture(map, controller.blocked_cells)
	var ports := {}
	for i in snapshot.ports.size():
		ports[Vector2i(snapshot.cells[i*2], snapshot.cells[i*2+1])] = int(snapshot.ports[i])
	if not ports.has(terminals[0]): return result
	var queue: Array[Vector2i] = [terminals[0]]
	var visited := {terminals[0]: true}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for d in 4:
			var offset: Vector3i = TileConstants.DIRECTIONS[d]
			var next := cell+Vector2i(offset.x, offset.z)
			if visited.has(next) or not (int(ports[cell]) & (1 << d)) or not (int(ports.get(next, 0)) & (1 << ((d+2)%4))): continue
			visited[next] = true
			queue.append(next)
	# Every BFS root already reaches the goal; existing tiles are never traversed
	# by an extension, overwritten, or used as candidate endpoints.
	var minimum := queue[0]
	var maximum := queue[0]
	var parent := {}
	var distances := {}
	for cell in queue:
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
		parent[cell] = cell
		distances[cell] = 0
	head = 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if int(distances[cell]) >= depth: continue
		for offset in DIRECTIONS:
			var next: Vector2i = cell+offset
			if reserved.has(next): continue
			if distances.has(next) or absi(next.x) >= 32767 or absi(next.y) >= 32767: continue
			if map.get_cell_item(Vector3i(next.x, 0, next.y)) != GridMap.INVALID_CELL_ITEM: continue
			parent[next] = cell
			distances[next] = int(distances[cell])+1
			queue.append(next)
	var zones: Array[Dictionary] = [{}, {}, {}, {}]
	for cell: Vector2i in distances:
		if int(distances[cell]) < band or _distance(cell, terminals[0]) < MIN_GOAL_DISTANCE: continue
		var safe := true
		for origin in terminals.slice(1):
			if _distance(cell, origin) < MIN_START_DISTANCE:
				safe = false
				break
		if not safe: continue
		var outside := [minimum.y-cell.y, minimum.x-cell.x, cell.y-maximum.y, cell.x-maximum.x]
		var sector := 0
		for d in range(1, 4):
			if outside[d] > outside[sector]: sector = d
		if outside[sector] < band: continue
		var path: Array[Vector2i] = []
		var cursor := cell
		while parent[cursor] != cursor:
			path.append(cursor)
			cursor = parent[cursor]
		zones[sector][cell] = path
	# Offer the three frontiers facing away from the goal first. A blocked sector
	# can be replaced by the fourth direction, keeping real, disjoint choices.
	var away := Vector2(terminals[0]-terminals[1]).normalized()
	var order := [0, 1, 2, 3]
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := Vector2(DIRECTIONS[a]).dot(away)
		var db := Vector2(DIRECTIONS[b]).dot(away)
		return da < db if not is_equal_approx(da, db) else a < b)
	for d: int in order:
		if zones[d].is_empty(): continue
		result.append({"direction": KEYS[d], "paths": zones[d]})
		if result.size() == 3: break
	return result

static func valid(controller: Node, cell: Vector2i, path: Array) -> bool:
	if controller.computing or path.is_empty() or path[0] != cell: return false
	var additions := {}
	var reserved := _traffic_cells(controller)
	for point: Vector2i in path:
		if reserved.has(point): return false
		if controller.map.get_cell_item(Vector3i(point.x, 0, point.y)) != GridMap.INVALID_CELL_ITEM: return false
		additions[point] = true
	var terminals: Array[Vector2i] = controller.terminal_cells()
	terminals.append(cell)
	return Snapshot.connects_terminals(Snapshot.capture(controller.map, controller.blocked_cells, additions), terminals)

static func _traffic_cells(controller: Node) -> Dictionary:
	var towers := controller.get_node_or_null("../TowerMap")
	return towers.traffic.occupied if towers != null and towers.traffic != null else {}

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
