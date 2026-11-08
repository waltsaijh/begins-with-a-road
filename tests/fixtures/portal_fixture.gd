extends RefCounted
const Cards = preload("res://tests/fixtures/card_fixture.gd")

static func scene_for(cells: Array[Vector2i], start: Vector2i, goal: Vector2i) -> Node3D:
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.get_node("CardPlacement").cards = Cards.starting_hand()
	var map: GridMap = scene.get_node("TileMap")
	map.clear()
	for cell in cells:
		map.set_cell_item(Vector3i(cell.x, 0, cell.y), 3)
	scene.get_node("Start").position = map.transform*map.map_to_local(Vector3i(start.x, 0, start.y))
	scene.get_node("Goal").position = map.transform*map.map_to_local(Vector3i(goal.x, 0, goal.y))
	return scene

static func annotated() -> Array[Vector2i]:
	var mask := {}
	for y in 3:
		for x in 5:
			mask[Vector2i(x, y)] = true
	for x in range(-3, 12):
		mask[Vector2i(x, 0)] = true
	for y in range(2, 6):
		mask[Vector2i(1, y)] = true
	for x in range(1, 9):
		mask[Vector2i(x, 5)] = true
	for y in range(0, 6):
		mask[Vector2i(8, y)] = true
	var cells: Array[Vector2i] = []
	for cell: Vector2i in mask:
		cells.append(cell)
	return cells

static func room(with_obstacle: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in 11:
		for x in 11:
			if not with_obstacle or not (x in range(4, 7) and y in range(3, 8)):
				cells.append(Vector2i(x, y))
	for x in range(-3, 0):
		cells.append(Vector2i(x, 5))
	for x in range(11, 14):
		cells.append(Vector2i(x, 5))
	return cells

## Plain BFS over reciprocal road ports, independent of every route search.
static func road_distance(snapshot: Dictionary, start: Vector2i, goal: Vector2i) -> int:
	var masks := {}
	for i in snapshot.ports.size(): masks[Vector2i(snapshot.cells[2*i],snapshot.cells[2*i+1])] = int(snapshot.ports[i])
	var steps := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	var distance := {start:0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if at == goal: return distance[at]
		for d in 4:
			var next: Vector2i = at+steps[d]
			if distance.has(next) or not masks.has(next): continue
			if masks[at] & (1 << d) and masks[next] & (1 << ((d+2)%4)):
				distance[next] = distance[at]+1
				queue.append(next)
	return -1
