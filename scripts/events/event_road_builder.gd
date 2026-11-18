extends RefCounted
## Construction search only. The established graph/candidates/distribution stay intact.
const Layout = preload("res://scripts/map/tile/construction_layout.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const STEPS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func propose(towers: Node3D, margin := 8, max_nodes := 12000) -> Dictionary:
	var terminals: Array[Vector2i] = towers.controller.terminal_cells()
	if terminals.size() < 2: return {}
	var map: GridMap = towers.map
	var blocked: Dictionary = towers.blocked_occupancy()
	var low := terminals[0]
	var high := low
	var roads := {}
	for cell in map.get_used_cells():
		var at := Vector2i(cell.x,cell.z)
		low = low.min(at); high = high.max(at)
		if cell.y == 0 and map.get_cell_item(cell) > 0 and not blocked.has(at): roads[at] = true
	# Bound search for very large custom maps, rather than blocking a Web frame forever.
	low -= Vector2i.ONE*margin; high += Vector2i.ONE*margin
	if (high.x-low.x+1)*(high.y-low.y+1) > max_nodes: return {}
	var protected := blocked.duplicate()
	for at in towers.traffic.occupied: protected[at] = true
	for tower: DefenseTower in towers.towers.values():
		if tower.deployment != null: protected[tower.garrison_cell()] = true
	var goal := terminals[0]
	for start in terminals.slice(1):
		var open: Array[Vector2i] = [start]
		var costs := {start: 0.0}
		var parents := {}
		var closed := {}
		while not open.is_empty():
			var best := 0
			for i in range(1,open.size()):
				if costs[open[i]]+_distance(open[i],goal) < costs[open[best]]+_distance(open[best],goal): best = i
			var at: Vector2i = open[best]
			open.remove_at(best)
			if at == goal: break
			closed[at] = true
			for step in STEPS:
				var next: Vector2i = at+step
				if next.x < low.x or next.y < low.y or next.x > high.x or next.y > high.y or closed.has(next) or protected.has(next): continue
				if map.get_cell_item(Vector3i(next.x,0,next.y)) == 0: continue
				var near_terminal := mini(_distance(next,start),_distance(next,goal)) <= 2
				# Existing roads may only be shared near the two ends.
				if roads.has(next) and not near_terminal: continue
				var penalty := 0.0
				if not near_terminal:
					for direction in STEPS:
						if roads.has(next+direction): penalty += 18.0
						if roads.has(next+direction*2): penalty += 4.0
				var cost: float = costs[at]+1.0+penalty
				if cost >= float(costs.get(next,INF)): continue
				costs[next] = cost; parents[next] = at
				if not next in open: open.append(next)
		if not parents.has(goal): continue
		var path: Array[Vector2i] = [goal]
		while path.back() != start: path.append(parents[path.back()])
		path.reverse()
		var fresh := 0
		var separated := 0
		var ground := {}
		var ports := {}
		for i in path.size():
			var at := path[i]
			ground[at] = true
			if not roads.has(at):
				fresh += 1
				if STEPS.all(func(step): return not roads.has(at+step)): separated += 1
			var mask := 0
			for d in 4:
				if (i > 0 and path[i-1] == at+STEPS[d]) or (i+1 < path.size() and path[i+1] == at+STEPS[d]): mask |= 1<<d
			ports[at] = mask
		if fresh < 4 or separated < maxi(2,fresh/3): continue
		var layout: Dictionary = Layout.build(map,ground,ports,towers.placement.port_overrides,blocked)
		if not Snapshot.connects_terminals(layout.snapshot,terminals): continue
		# All path edges must actually exist, including authored end-point ports.
		var valid := true
		for i in range(path.size()-1):
			var d: int = STEPS.find(path[i+1]-path[i])
			if not int(layout.masks[path[i]]) & (1<<d) or not int(layout.masks[path[i+1]]) & (1<<((d+2)%4)): valid = false
		if valid: return {"ground":ground,"ports":ports,"path":path}
	return {}

static func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func commit(towers: Node3D, proposal: Dictionary) -> bool:
	if proposal.is_empty(): return false
	# Revalidate the physical proposal immediately before mutation.
	for at: Vector2i in proposal.ground:
		if towers.blocked_occupancy().has(at) or towers.traffic.occupied.has(at) or towers.map.get_cell_item(Vector3i(at.x,0,at.y)) == 0: return false
	var layout: Dictionary = Layout.build(towers.map,proposal.ground,proposal.ports,towers.placement.port_overrides,towers.blocked_occupancy())
	if not Snapshot.connects_terminals(layout.snapshot,towers.controller.terminal_cells()): return false
	var added: Array[Vector3i] = Layout.apply(towers.placement,layout)
	towers.controller.rebuild()
	towers.placement.notify_cells(added)
	return true
