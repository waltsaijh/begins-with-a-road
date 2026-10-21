extends RefCounted
## Build once per combat frame; both aiming and splash query whole tile buckets.
var buckets := {}
var map: GridMap
var _ranges := {}

func _offsets(radius: float) -> Array[Vector2i]:
	if not _ranges.has(radius):
		_ranges[radius] = covered_cells(Vector2i.ZERO, radius)
	return _ranges[radius]

func rebuild(enemies: Array[Node3D], grid: GridMap) -> void:
	map = grid
	buckets.clear()
	for enemy in enemies:
		var cell := cell_for(enemy.global_position)
		if not buckets.has(cell):
			buckets[cell] = []
		buckets[cell].append(enemy)

func cell_for(position: Vector3) -> Vector2i:
	var cell := map.local_to_map(map.to_local(position))
	return Vector2i(cell.x, cell.z)

func target_for(center: Vector2i, radius: float) -> Node3D:
	return target_in_offsets(center, _offsets(radius))

func target_in_offsets(center: Vector2i, offsets: Array[Vector2i]) -> Node3D:
	var best: Node3D
	var best_distance := INF
	for offset in offsets:
		var cell := center+offset
		var distance := float(offset.length_squared())
		if distance > best_distance or not buckets.has(cell):
			continue
		for enemy: Node3D in buckets[cell]:
			if not is_instance_valid(enemy) or not enemy.can_be_targeted():
				continue
			if distance < best_distance or best == null or enemy.enemy_id < best.enemy_id:
				best = enemy
				best_distance = distance
	return best

func targets_in(center: Vector2i, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for offset in _offsets(radius):
		var cell := center+offset
		if buckets.has(cell):
			for enemy: Node3D in buckets[cell]:
				if is_instance_valid(enemy) and enemy.can_be_targeted():
					result.append(enemy)
	return result

static func covered_cells(center: Vector2i, radius: float) -> Array[Vector2i]:
	return TowerAttackArea.circle_cells(center, radius)
