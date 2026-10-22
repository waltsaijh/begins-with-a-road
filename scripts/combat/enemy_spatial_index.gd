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

func targets_along_segment(start: Vector3, end: Vector3, width: float) -> Array[Node3D]:
	var a3 := map.to_local(start)/map.cell_size
	var b3 := map.to_local(end)/map.cell_size
	var a := Vector2(a3.x,a3.z)
	var b := Vector2(b3.x,b3.z)
	var delta := b-a
	var squared := delta.length_squared()
	var result: Array[Node3D] = []
	var first := cell_for(start)
	var last := cell_for(end)
	var pad := ceili(width)+1
	for y in range(mini(first.y,last.y)-pad,maxi(first.y,last.y)+pad+1):
		for x in range(mini(first.x,last.x)-pad,maxi(first.x,last.x)+pad+1):
			for target: Node3D in buckets.get(Vector2i(x,y),[]):
				if not is_instance_valid(target) or not target.can_be_targeted(): continue
				var point3 := map.to_local(target.global_position)/map.cell_size
				var point := Vector2(point3.x,point3.z)
				var t := clampf((point-a).dot(delta)/squared,0,1) if squared > 0 else 0.0
				if point.distance_squared_to(a+delta*t) <= width*width: result.append(target)
	result.sort_custom(func(left,right): return left.global_position.distance_squared_to(start) < right.global_position.distance_squared_to(start))
	return result

func targets_in_offsets(center: Vector2i, offsets: Array[Vector2i]) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for offset in offsets:
		for enemy: Node3D in buckets.get(center+offset,[]):
			if is_instance_valid(enemy) and enemy.can_be_targeted(): result.append(enemy)
	return result

func targets_near(position: Vector3, radius: float) -> Array[Node3D]:
	var local := map.to_local(position)
	var center := cell_for(position)
	var extent := ceili(radius)+1
	var result: Array[Node3D] = []
	for y in range(-extent,extent+1):
		for x in range(-extent,extent+1):
			for enemy: Node3D in buckets.get(center+Vector2i(x,y),[]):
				if not is_instance_valid(enemy) or not enemy.can_be_targeted(): continue
				var delta := map.to_local(enemy.global_position)-local
				if Vector2(delta.x/map.cell_size.x,delta.z/map.cell_size.z).length_squared() <= radius*radius:
					result.append(enemy)
	return result
