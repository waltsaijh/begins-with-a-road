extends RefCounted
## Select a defended stretch of road and freeze a walk from the clearing to the goal.
const STEPS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func plan(controller: Node) -> Dictionary:
	var graph: Dictionary = controller.route_history.current
	if graph.is_empty(): return {}
	var goal: Vector2i = graph.goal
	var ports := {}
	for i in graph.ports.size():
		ports[Vector2i(graph.cells[2*i],graph.cells[2*i+1])] = graph.ports[i]
	var toward_goal := {goal:goal}
	var road: Array[Vector2i] = [goal]
	var head := 0
	while head < road.size():
		var cell := road[head]
		head += 1
		for d in 4:
			var next: Vector2i = cell+STEPS[d]
			if toward_goal.has(next): continue
			if int(ports[cell]) & (1<<d) and int(ports.get(next,0)) & (1<<((d+2)%4)):
				toward_goal[next] = cell
				road.append(next)
	var terminals: Array[Vector2i] = controller.terminal_cells()
	var active_roads: Dictionary = controller.route_history.tile_ages()
	var best := []
	var join := goal
	var direction := Vector2i.ZERO
	for cell in road:
		var tile = controller.tile_parameters.get_tile(cell)
		var neighbors: int = tile.num_towers_around if tile != null else 0
		var threat: float = tile.threat if tile != null else 0.0
		for step: Vector2i in STEPS:
			var center := cell+3*step
			if center in terminals or cell+step in terminals or cell+2*step in terminals: continue
			var blocked := 0
			var open := 0
			for n in range(1,4):
				var at := cell+step*n
				if controller.blocked_cells.has(at): blocked += 1
				if controller.map.get_cell_item(Vector3i(at.x,0,at.y)) < 0: open += 1
			# Prefer a clear approach, then a non-terminal active road under dense fire.
			var score := [-blocked,int(not cell in terminals),int(active_roads.has(cell)),neighbors,threat,open,cell.distance_squared_to(goal)]
			if best.is_empty() or best < score:
				best = score
				join = cell
				direction = step
	if best.is_empty(): return {}
	var cells := PackedVector2Array()
	for n in range(3,0,-1): cells.append(join+direction*n)
	var cursor := join
	while cursor != goal:
		cells.append(cursor)
		cursor = toward_goal[cursor]
	cells.append(goal)
	return {"length":cells.size()-1,"cells":cells,"center":join+direction*3,"connector":join+direction}
