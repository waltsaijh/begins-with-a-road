extends Node3D
## Read-only scene preview: fit the authored camera, never run gameplay.
@export var definition: MenuMapDefinition
@export_range(0.0, 400.0, 1.0) var top_clearance := 135.0
@export_range(0.0, 400.0, 1.0) var bottom_clearance := 220.0
@export_range(0.3, 1.0, 0.01) var horizontal_fraction := 0.85
@export_range(0.5, 2.0, 0.05) var zoom := 1.0
@onready var camera: Camera3D = $Camera3D
@onready var terrain: GridMap = $Terrain

func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()

func activate() -> void:
	show()
	_fit()
	camera.make_current()

func _fit() -> void:
	if not is_inside_tree() or not is_instance_valid(camera): return
	var cells := terrain.get_used_cells()
	if cells.is_empty(): return
	var bounds := AABB(terrain.to_global(terrain.map_to_local(cells[0])), Vector3.ZERO)
	for cell in cells: bounds = bounds.expand(terrain.to_global(terrain.map_to_local(cell)))
	var target := bounds.get_center()
	camera.global_position = target+camera.global_basis.z*40.0
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for cell in cells:
		var point := terrain.to_global(terrain.map_to_local(cell))-target
		var projected := Vector2(point.dot(camera.global_basis.x), point.dot(camera.global_basis.y))
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	var extent := get_viewport().get_visible_rect().size
	var usable_height := maxf(120, extent.y-top_clearance-bottom_clearance)
	var span := maximum-minimum+Vector2(4, 5)
	camera.size = maxf(span.y*extent.y/usable_height, span.x*extent.y/(extent.x*horizontal_fraction))/zoom
	camera.v_offset = camera.size*(top_clearance-bottom_clearance)*0.5/extent.y
