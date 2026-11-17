extends Node3D
## Art Slice G: a few far-off floating islands drifting among the cloud strata,
## placed in a ring around the map and re-laid-out when the map grows.
const MESHES := [preload("res://assets/models/environment/distant_island_0.res"), preload("res://assets/models/environment/distant_island_1.res"), preload("res://assets/models/environment/distant_island_2.res")]
@export_range(0, 40) var count := 12
@export var layout_seed := 4127
@export_range(1.0, 30.0, 0.5) var near_gap := 3.5
@export_range(2.0, 60.0, 0.5) var far_gap := 18.0

## first/last: global centres of the map's corner cells; cell: cell size.
func layout(first: Vector3, last: Vector3, cell: Vector3) -> void:
	for child in get_children(): child.queue_free()
	var rng := RandomNumberGenerator.new(); rng.seed = layout_seed
	var lo := Vector2(minf(first.x, last.x), minf(first.z, last.z))-Vector2(cell.x, cell.z)*0.5
	var hi := Vector2(maxf(first.x, last.x), maxf(first.z, last.z))+Vector2(cell.x, cell.z)*0.5
	var centre := (lo+hi)*0.5; var half := (hi-lo)*0.5
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < count and tries < 600:
		tries += 1
		var angle := rng.randf()*TAU
		var dir := Vector2(cos(angle), sin(angle))
		var edge := minf(half.x/maxf(absf(dir.x), 0.001), half.y/maxf(absf(dir.y), 0.001))
		var gap := rng.randf_range(near_gap, far_gap)
		var p := centre+dir*(edge+gap)
		if placed.any(func(q): return q.distance_to(p) < 4.5): continue
		placed.append(p)
		var island := MeshInstance3D.new()
		island.mesh = MESHES[rng.randi() % MESHES.size()]
		island.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(island)
		# Farther islands sit lower and larger, deeper in the clouds.
		var t := inverse_lerp(near_gap, far_gap, gap)
		var size := lerpf(0.55, 1.35, t)*rng.randf_range(.8, 1.15)
		island.global_transform = Transform3D(Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3.ONE*size), Vector3(p.x, first.y-lerpf(1.0, 3.2, t)+rng.randf_range(-.3, .3), p.y))
