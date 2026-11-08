extends RefCounted
## One immutable world-space walk per distinct route in this wave build.
## A fresh cache captures the current map transform; no cross-wave invalidation.
## Flyers given junctions skip every tile between two of them and fly straight.
static func for_route(route: Dictionary, map: GridMap, cache: Dictionary, flight_height := 0.0, junctions: Dictionary = {}) -> PackedVector3Array:
	var cells: PackedVector2Array = route.cells
	var straight := flight_height > 0.0 and not junctions.is_empty()
	var key := [cells, flight_height, straight]
	if not cache.has(key):
		var points := PackedVector3Array()
		for i in cells.size():
			var cell := Vector2i(cells[i])
			if straight and i > 0 and i < cells.size()-1 and not junctions.has(cell): continue
			points.append(map.to_global(map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*(EnemyConstants.GROUND_OFFSET+flight_height*map.cell_size.y)))
		cache[key] = points
	return cache[key]

## Road tiles where three or more reciprocal links meet: the route graph's nodes.
static func junctions(snapshot: Dictionary) -> Dictionary:
	var masks := {}
	for i in snapshot.get("ports",PackedByteArray()).size(): masks[Vector2i(snapshot.cells[2*i],snapshot.cells[2*i+1])] = int(snapshot.ports[i])
	var steps := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	var result := {}
	for cell: Vector2i in masks:
		var links := 0
		for d in 4:
			if masks[cell] & (1 << d) and int(masks.get(cell+steps[d],0)) & (1 << ((d+2)%4)): links += 1
		if links >= 3: result[cell] = true
	return result
