@tool
extends RefCounted
## Read scene-local endpoint transforms without entering the SceneTree.
const Endpoint = preload("res://scripts/levels/terrain_endpoint.gd")

static func empty(error: String) -> Dictionary:
	return {"error": error, "from_scene": false, "starts": [], "goal": {}, "start_cells": [], "goal_cell": Vector2i.ZERO}

static func read(map: GridMap, use_markers: bool, fallback_starts: Array[Vector2i], fallback_goal: Vector2i, height: float) -> Dictionary:
	var points: Array[Dictionary] = []
	if use_markers: _collect(map, map, Transform3D.IDENTITY, points)
	var result := {"error": "", "from_scene": not points.is_empty(), "starts": [], "goal": {}, "start_cells": [], "goal_cell": fallback_goal}
	if points.is_empty():
		for cell in fallback_starts:
			result.starts.append({"cell": cell, "path": NodePath(), "transform": Transform3D(Basis.IDENTITY, map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*height)})
		result.goal = {"cell": fallback_goal, "path": NodePath(), "transform": Transform3D(Basis.IDENTITY, map.map_to_local(Vector3i(fallback_goal.x, 0, fallback_goal.y))+Vector3.UP*height)}
	else:
		var goals := 0
		var occupied := {}
		for point in points:
			var marker: Node3D = map.get_node(point.path)
			var cell := map.local_to_map(point.transform.origin)
			cell.y = 0
			point.cell = Vector2i(cell.x, cell.z)
			point.transform.origin = map.map_to_local(cell)+Vector3.UP*marker.height_offset
			if map.get_cell_item(cell) <= 0:
				result.error = "起終點 %s 必須放在道路地塊上" % point.path
				return result
			if occupied.has(point.cell):
				result.error = "起終點不可重疊：%s" % point.cell
				return result
			occupied[point.cell] = true
			if marker.role == Endpoint.Role.START:
				result.starts.append(point)
			else:
				goals += 1
				result.goal = point
		if result.starts.is_empty() or goals != 1:
			result.error = "地形場景需要至少一個 Start，以及剛好一個 Goal"
			return result
	if result.starts.is_empty():
		result.error = "關卡尚未設定出生入口"
		return result
	for point: Dictionary in result.starts: result.start_cells.append(point.cell)
	result.goal_cell = result.goal.cell
	if result.from_scene and not _connected(map, result.start_cells, result.goal_cell):
		result.error = "地形場景中有入口無法沿道路通往終點"
	return result

static func _collect(map: GridMap, parent: Node, relative: Transform3D, result: Array[Dictionary]) -> void:
	for child in parent.get_children():
		var transform := relative
		if child is Node3D: transform *= child.transform
		if child is Endpoint:
			result.append({"path": map.get_path_to(child), "transform": transform})
		else:
			_collect(map, child, transform, result)

static func _connected(map: GridMap, starts: Array, goal: Vector2i) -> bool:
	var visited := {goal: true}
	var queue: Array[Vector2i] = [goal]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for direction in TileConstants.DIRECTIONS:
			var next := cell+Vector2i(direction.x, direction.z)
			if not visited.has(next) and map.get_cell_item(Vector3i(next.x, 0, next.y)) > 0:
				visited[next] = true
				queue.append(next)
	for start: Vector2i in starts:
		if not visited.has(start): return false
	return true
