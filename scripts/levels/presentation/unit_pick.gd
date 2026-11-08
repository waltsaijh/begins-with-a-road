extends RefCounted
## Click-only CPU ray queries: no physics bodies, no per-frame population scan.
static func mesh_parts(node: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not node.is_visible_in_tree(): return result
	if node is MeshInstance3D and node.mesh != null:
		result.append({"transform":node.global_transform,"bounds":node.get_aabb()})
	for child in node.get_children():
		if child is Node3D: result.append_array(mesh_parts(child))
	return result

static func hit_distance(origin: Vector3, direction: Vector3, parts: Array[Dictionary]) -> float:
	var nearest := INF
	for part in parts:
		var transform: Transform3D = part.transform
		if absf(transform.basis.determinant()) < 0.000001: continue
		var inverse := transform.affine_inverse()
		var local_origin := inverse*origin
		var local_direction := inverse.basis*direction
		var bounds: AABB = part.bounds
		var hit: Variant = bounds.intersects_ray(local_origin,local_direction)
		if hit is Vector3:
			var distance: float = (transform*hit-origin).dot(direction)
			if distance >= 0: nearest = minf(nearest,distance)
	return nearest

static func pick(camera: Camera3D, point: Vector2, towers: Node3D, renderer: Node3D) -> Node3D:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var nearest := INF
	var chosen: Node3D
	for tower: DefenseTower in towers.towers.values():
		if not is_instance_valid(tower) or tower.is_queued_for_deletion() or tower.health <= 0: continue
		var distance := hit_distance(origin,direction,mesh_parts(tower))
		if distance < nearest:
			nearest = distance
			chosen = tower
	for enemy: Node3D in renderer.units:
		if not is_instance_valid(enemy) or not enemy.can_be_targeted(): continue
		var distance := hit_distance(origin,direction,renderer.inspection_parts(enemy))
		if distance < nearest:
			nearest = distance
			chosen = enemy
	return chosen
