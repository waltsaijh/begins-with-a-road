extends RefCounted
## Independent reciprocal-port graph measurements; no route-candidate-count claim.
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const MAX_PATHS := 256
const MAX_EXPANSIONS := 200000
var _paths: Array = []
var _expanded := 0
var _truncated := false

func measure(session: Node3D) -> Dictionary:
	var towers: Node = session.get_node("TowerMap")
	var snapshot := Snapshot.capture(session.get_node("TileMap"), towers.occupied)
	var terminals: Array[Vector2i] = session.get_node("PortalMap").terminal_cells()
	var ports := {}
	for index in snapshot.ports.size(): ports[Vector2i(snapshot.cells[index*2], snapshot.cells[index*2+1])] = int(snapshot.ports[index])
	var graph := {}
	var edges := 0
	for cell: Vector2i in ports:
		graph[cell] = []
		for direction in 4:
			var next: Vector2i = cell+DIRECTIONS[direction]
			if ports[cell] & (1 << direction) and ports.get(next, 0) & (1 << ((direction+2)%4)):
				graph[cell].append(next)
				edges += 1
	_paths.clear()
	_expanded = 0
	_truncated = false
	if terminals.size() > 1: _walk(graph, terminals[1], terminals[0], [terminals[1]], {terminals[1]:true})
	var used := {}
	var occurrences := {}
	for path: Array in _paths:
		for cell: Vector2i in path:
			used[cell] = true
			occurrences[cell] = int(occurrences.get(cell, 0))+1
	var junctions := 0
	var effective_edges := 0
	for cell: Vector2i in used:
		var degree := 0
		for next: Vector2i in graph[cell]:
			if used.has(next): degree += 1
		if degree >= 3: junctions += 1
		effective_edges += degree
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	var first := true
	for cell: Vector2i in used:
		if first:
			minimum = cell
			maximum = cell
			first = false
		else:
			minimum = Vector2i(mini(minimum.x, cell.x), mini(minimum.y, cell.y))
			maximum = Vector2i(maxi(maximum.x, cell.x), maxi(maximum.y, cell.y))
	var bounds := Rect2i(minimum, maximum-minimum+Vector2i.ONE) if not first else Rect2i()
	var pairs: Array = []
	for a in _paths.size():
		for b in range(a+1, _paths.size()):
			var left: Array = _paths[a]
			var right: Array = _paths[b]
			var common := 0
			var exclusive_left: Array = []
			var exclusive_right: Array = []
			for cell in left:
				if cell in right: common += 1
				else: exclusive_left.append(cell)
			for cell in right:
				if not cell in left: exclusive_right.append(cell)
			pairs.append({"shared_fraction":float(common)/maxi(1, mini(left.size(), right.size())), "separation":(_nearest(exclusive_left, exclusive_right)+_nearest(exclusive_right, exclusive_left))*0.5})
	var covered_multiple := 0
	for tower: DefenseTower in towers.towers.values():
		var covered := 0
		for path: Array in _paths:
			for cell: Vector2i in path:
				# Ignore the unavoidable common trunk, including start and goal.
				if int(occurrences[cell]) < _paths.size() and tower.covers_cell(cell):
					covered += 1
					break
		if covered >= 2: covered_multiple += 1
	var average_separation := 0.0
	var average_shared := 0.0
	for pair: Dictionary in pairs:
		average_separation += pair.separation
		average_shared += pair.shared_fraction
	var small_cycle_edges := 0
	var minimum_cycle := 0
	for cell: Vector2i in used:
		for next: Vector2i in graph[cell]:
			if not used.has(next) or cell.x > next.x or (cell.x == next.x and cell.y > next.y): continue
			var cycle_length := _cycle_length(graph, used, cell, next)
			if cycle_length > 0:
				minimum_cycle = cycle_length if minimum_cycle == 0 else mini(minimum_cycle, cycle_length)
				if cycle_length <= 8: small_cycle_edges += 1
	var result := {
		"road_cells":ports.size(), "effective_cells":used.size(), "effective_junctions":junctions,
		"bbox_width":bounds.size.x, "bbox_height":bounds.size.y, "bbox_area":bounds.get_area(),
		"effective_cycle_rank":maxi(0, effective_edges/2-used.size()+1) if not used.is_empty() else 0,
		"minimum_cycle_edges":minimum_cycle, "edges_in_cycles_at_most_8":small_cycle_edges,
		"micro_cycle_edge_fraction":float(small_cycle_edges)/maxi(1, effective_edges/2),
		"simple_routes_measured":_paths.size(), "route_enumeration_truncated":_truncated, "route_expansions":_expanded,
		"mean_exclusive_route_separation":average_separation/maxi(1, pairs.size()), "mean_pair_shared_fraction":average_shared/maxi(1, pairs.size()),
		"towers_covering_multiple_branch_routes":covered_multiple, "tower_count":towers.towers.size(),
		"multiple_branch_coverage_ratio":float(covered_multiple)/maxi(1, towers.towers.size()),
		"cells":[], "towers":[], "edges":[], "routes":[]}
	for cell: Vector2i in ports: result.cells.append([cell.x, cell.y, ports[cell]])
	for tower: DefenseTower in towers.towers.values(): result.towers.append([tower.grid_cell.x, tower.grid_cell.y])
	for cell: Vector2i in graph:
		for next: Vector2i in graph[cell]:
			if cell.x < next.x or (cell.x == next.x and cell.y < next.y): result.edges.append([cell.x, cell.y, next.x, next.y])
	for path: Array in _paths:
		var coordinates: Array = []
		for cell: Vector2i in path: coordinates.append([cell.x, cell.y])
		result.routes.append(coordinates)
	return result

func _walk(graph: Dictionary, cell: Vector2i, goal: Vector2i, path: Array, visited: Dictionary) -> void:
	if _paths.size() >= MAX_PATHS or _expanded >= MAX_EXPANSIONS:
		_truncated = true
		return
	_expanded += 1
	if cell == goal:
		_paths.append(path.duplicate())
		return
	for next: Vector2i in graph.get(cell, []):
		if visited.has(next): continue
		visited[next] = true
		path.append(next)
		_walk(graph, next, goal, path, visited)
		path.pop_back()
		visited.erase(next)

func _nearest(left: Array, right: Array) -> float:
	if left.is_empty() or right.is_empty(): return 0.0
	var total := 0.0
	for a: Vector2i in left:
		var best := INF
		for b: Vector2i in right: best = minf(best, Vector2(a).distance_to(Vector2(b)))
		total += best
	return total/left.size()

func _cycle_length(graph: Dictionary, used: Dictionary, start: Vector2i, goal: Vector2i) -> int:
	# BFS with one physical edge removed measures the shortest cycle using that edge.
	var queue: Array[Vector2i] = [start]
	var distance := {start:0}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for next: Vector2i in graph[cell]:
			if not used.has(next) or distance.has(next) or (cell == start and next == goal): continue
			if next == goal: return int(distance[cell])+2
			distance[next] = int(distance[cell])+1
			queue.append(next)
	return 0

static func svg(result: Dictionary, title: String) -> String:
	var min_x := 0
	var min_y := 0
	var max_x := 16
	var max_y := 0
	for cell: Array in result.cells:
		min_x = mini(min_x, cell[0])
		max_x = maxi(max_x, cell[0])
		min_y = mini(min_y, cell[1])
		max_y = maxi(max_y, cell[1])
	var scale := 30
	var width := (max_x-min_x+2)*scale
	var height := (max_y-min_y+3)*scale
	var drawing := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><rect width="100%%" height="100%%" fill="#f4f3ec"/><text x="15" y="22" font-family="sans-serif" font-size="14">%s</text>' % [width, height, width, height, title.xml_escape()]
	for edge: Array in result.edges:
		drawing += '<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#6e8579" stroke-width="13" stroke-linecap="round"/>' % [(edge[0]-min_x+1)*scale, (edge[1]-min_y+2)*scale, (edge[2]-min_x+1)*scale, (edge[3]-min_y+2)*scale]
	for cell: Array in result.towers:
		drawing += '<rect x="%d" y="%d" width="18" height="18" fill="#c18c54" stroke="#604b38"/>' % [(cell[0]-min_x+1)*scale-9, (cell[1]-min_y+2)*scale-9]
	return drawing+'</svg>'
