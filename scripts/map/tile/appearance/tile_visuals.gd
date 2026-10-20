extends Node3D
## The original GridMap remains the immediate data authority. This render-only
## GridMap batches settled tiles; only active transitions use temporary meshes.

@export var animate := TileAppearanceConstants.ANIMATE
@export_range(0.05, 1.0, 0.01) var duration := TileAppearanceConstants.ANIMATION_DURATION
@export_range(0.1, 8.0, 0.1) var rise_depth := TileAppearanceConstants.RISE_DEPTH
@onready var map: GridMap = $"../TileMap"
var static_tiles: GridMap
var jobs := {}
var _states := {}
var _new_cells := {}
var _riders := {}
var _queued := false
var _initial_layout := true
var _map_was_visible := true
var _controller: Node
var _appearance: Node
var _support_mesh: Mesh

func _ready() -> void:
	static_tiles = GridMap.new()
	static_tiles.name = "StaticTiles"
	static_tiles.mesh_library = map.mesh_library
	static_tiles.cell_size = map.cell_size
	static_tiles.cell_center_x = map.cell_center_x
	static_tiles.cell_center_y = map.cell_center_y
	static_tiles.cell_center_z = map.cell_center_z
	static_tiles.cell_octant_size = map.cell_octant_size
	static_tiles.collision_layer = 0
	static_tiles.collision_mask = 0
	add_child(static_tiles)
	global_transform = map.global_transform
	_map_was_visible = map.visible
	map.hide()
	_controller = get_node_or_null("../PortalMap")
	_appearance = get_node_or_null("../TileAppearance")
	if _controller != null:
		_controller.graph_changed.connect(_queue_sync)
	if _appearance != null:
		_appearance.layout_changed.connect(_on_layout_changed)
	else:
		_initial_layout = false
	var placement := get_node_or_null("../TilePlacement")
	if placement != null:
		placement.cell_placed.connect(_on_cell_placed)
	sync()
	set_process(false)

func _on_layout_changed() -> void:
	# Initial supports/bridges appear settled, even though the first graph is deferred.
	if _initial_layout:
		_states.clear()
		_initial_layout = false
	_queue_sync()

func _on_cell_placed(cell: Vector3i) -> void:
	_new_cells[cell] = true
	_queue_sync()

func _queue_sync() -> void:
	if not _queued:
		_queued = true
		sync.call_deferred()

## Newly placed tower artwork shares the ground's exact animation clock.
## Its parent keeps the committed logical position and occupancy unchanged.
func follow_new_cell(cell: Vector3i, visual: Node3D) -> void:
	if not animate or visual == null:
		return
	if not _new_cells.has(cell) and not (jobs.has(cell) and jobs[cell].added):
		return
	_restore_rider(cell)
	_riders[cell] = {"visual": visual, "position": visual.position}
	_set_rider_offset(cell, jobs[cell].model.position.y if jobs.has(cell) else -rise_depth)

func _set_rider_offset(cell: Vector3i, offset: float) -> void:
	if not _riders.has(cell):
		return
	var rider: Dictionary = _riders[cell]
	if not is_instance_valid(rider.visual):
		_riders.erase(cell)
		return
	rider.visual.position = rider.position + Vector3.UP * offset

func _restore_rider(cell: Vector3i) -> void:
	if _riders.has(cell):
		var rider: Dictionary = _riders[cell]
		if is_instance_valid(rider.visual):
			rider.visual.position = rider.position
		_riders.erase(cell)

func sync() -> void:
	_queued = false
	if _controller != null and _controller.computing:
		return # graph_changed schedules the completed snapshot.
	global_transform = map.global_transform
	var present := {}
	for cell in map.get_used_cells():
		var target := Vector2i(map.get_cell_item(cell), map.get_cell_item_orientation(cell))
		present[cell] = true
		var previous: Vector2i = _states.get(cell, Vector2i(-1, 0))
		if target == previous:
			continue
		_states[cell] = target
		var added := _new_cells.has(cell)
		var changed_appearance := previous.x >= 0 and TileConstants.appearance_of(previous.x) != TileConstants.appearance_of(target.x)
		if animate and (added or changed_appearance or jobs.has(cell)):
			_transition(cell, previous, target, added)
		else:
			static_tiles.set_cell_item(cell, target.x, target.y)
	for cell: Vector3i in _states.keys():
		if not present.has(cell):
			_remove_job(cell)
			_states.erase(cell)
			static_tiles.set_cell_item(cell, -1)
	for cell: Vector3i in _riders.keys():
		if not present.has(cell):
			_restore_rider(cell)
	_new_cells.clear()

func _transition(cell: Vector3i, previous: Vector2i, target: Vector2i, added: bool) -> void:
	var age := 0.0
	if jobs.has(cell):
		var old: Dictionary = jobs[cell]
		age = old.age
		previous = old.previous
		added = old.added
		_remove_job(cell, true)
	static_tiles.set_cell_item(cell, -1) # Only the display grid is masked.
	var body := Node3D.new()
	body.name = "Transition_%d_%d" % [cell.x, cell.z]
	body.position = map.map_to_local(cell)
	add_child(body)
	var from := TileConstants.appearance_of(previous.x)
	var to := TileConstants.appearance_of(target.x)
	var has_pillar := from == TileConstants.Appearance.PILLAR or to == TileConstants.Appearance.PILLAR
	var fixed_top := not added and has_pillar and to != TileConstants.Appearance.WOOD
	var job := {"cell": cell, "body": body, "age": age, "target": target, "previous": previous, "added": added, "fixed_top": fixed_top}
	# Split only the pillar support; ordinary replacements use one shared mesh.
	var item := TileConstants.base_item(target.x) if to == TileConstants.Appearance.PILLAR else target.x
	job.model = _mesh(body, map.mesh_library.get_item_mesh(item), target.y)
	if has_pillar:
		if _support_mesh == null:
			var source: Node3D = load("res://assets/models/tiles/variants/pillar_support.tscn").instantiate()
			_support_mesh = source.get_child(0).mesh
			source.free()
		job.support = _mesh(job.model if to == TileConstants.Appearance.PILLAR else body, _support_mesh, 0 if to == TileConstants.Appearance.PILLAR else previous.y)
		job.support_material = _support_mesh.surface_get_material(0).duplicate()
		job.support.material_override = job.support_material
		job.add_support = to == TileConstants.Appearance.PILLAR
	jobs[cell] = job
	_pose(job)
	set_process(true)

func _mesh(parent: Node3D, mesh: Mesh, orientation: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.basis = map.get_basis_with_orthogonal_index(orientation)
	parent.add_child(instance)
	return instance

static func rise_offset(progress: float, depth := TileAppearanceConstants.RISE_DEPTH) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return -depth * pow(1.0 - t, 3.0)

func _pose(job: Dictionary) -> void:
	var t := clampf(job.age / duration, 0.0, 1.0)
	job.model.position.y = 0.0 if job.fixed_top else rise_offset(t, rise_depth)
	_set_rider_offset(job.cell, job.model.position.y)
	if job.has("support"):
		var growth := smoothstep(0.0, 1.0, t)
		if not job.add_support:
			growth = 1.0 - growth
		job.support_material.set_shader_parameter("support_growth", growth)
		job.support.visible = growth > 0.001

func _process(delta: float) -> void:
	for cell: Vector3i in jobs.keys():
		var job: Dictionary = jobs[cell]
		job.age += maxf(delta, 0.0)
		if job.age >= duration:
			var target: Vector2i = job.target
			static_tiles.set_cell_item(cell, target.x, target.y)
			_remove_job(cell)
		else:
			_pose(job)
	if jobs.is_empty():
		set_process(false)

func _remove_job(cell: Vector3i, keep_rider := false) -> void:
	if not keep_rider:
		_restore_rider(cell)
	if jobs.has(cell):
		var body: Node3D = jobs[cell].body
		remove_child(body)
		body.queue_free()
		jobs.erase(cell)

func finish() -> void:
	for cell: Vector3i in jobs.keys():
		var target: Vector2i = jobs[cell].target
		static_tiles.set_cell_item(cell, target.x, target.y)
		_remove_job(cell)
	for cell: Vector3i in _riders.keys():
		_restore_rider(cell)
	set_process(false)

func _exit_tree() -> void:
	for cell: Vector3i in _riders.keys():
		_restore_rider(cell)
	if is_instance_valid(map):
		map.visible = _map_was_visible
