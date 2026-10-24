class_name TrafficFlowDelta
extends RefCounted
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")

static func junctions(map: GridMap, blocked: Dictionary) -> Dictionary:
	var snapshot := Snapshot.capture(map,blocked)
	var ports := {}
	for i in snapshot.ports.size(): ports[Vector2i(snapshot.cells[i*2],snapshot.cells[i*2+1])] = int(snapshot.ports[i])
	var result := {}
	for cell: Vector2i in ports:
		var degree := 0
		for d in 4:
			var direction: Vector3i = TileConstants.DIRECTIONS[d]
			var neighbor := cell+Vector2i(direction.x,direction.z)
			if ports[cell] & (1 << d) and int(ports.get(neighbor,0)) & (1 << ((d+2)%4)): degree += 1
		if degree >= 3: result[cell] = true
	return result

static func compare(before: Dictionary, after: Dictionary, branches: Dictionary, minimum := 1) -> Dictionary:
	var keys := before.duplicate()
	keys.merge(after)
	var result := {}
	for edge: Vector4i in keys:
		var difference := int(after.get(edge,0))-int(before.get(edge,0))
		if absi(difference) >= maxi(1,minimum) and branches.has(Vector2i(edge.x,edge.y)):
			result[edge] = signi(difference)
	return result
