extends Camera3D
## Fixed viewing angle; panning moves the focus on the map plane.

@export_node_path("GridMap") var map_path: NodePath = ^"../TileMap"
@export var minimum_size := 3.0
@export var maximum_size := 48.0
## Zoom is initial size / current size; 0.6x is the farthest zoom-out.
@export_range(0.1, 1.0, 0.05) var minimum_zoom_scale := 0.6
## World-space square centered on the initial focus; each axis allows ±pan_range.
@export_range(0.0, 80.0, 0.5) var pan_range := 24.0
var _initial_size := 18.5
var _initial_focus := Vector3.ZERO

var focus := Vector3.ZERO
var azimuth := deg_to_rad(30.0)
var elevation := deg_to_rad(45.0)
var distance := 35.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	projection = PROJECTION_ORTHOGONAL
	_initial_size = size
	var map := get_node_or_null(map_path) as GridMap
	if map != null and not map.get_used_cells().is_empty():
		var cells := map.get_used_cells()
		var bounds := AABB(map.to_global(map.map_to_local(cells[0])), Vector3.ZERO)
		for cell in cells:
			bounds = bounds.expand(map.to_global(map.map_to_local(cell)))
		focus = bounds.get_center()
	_initial_focus = focus
	update_pose()

func _unhandled_input(event: InputEvent) -> void:
	if handle_navigation_input(event): get_viewport().set_input_as_handled()

## HUD forwards only camera navigation while gameplay input is locked.
func handle_navigation_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed:
				var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				size = clampf(size*pow(1.12, direction*event.factor), minimum_size, _maximum_view_size())
				update_pose()
			return true
		if event.button_index == MOUSE_BUTTON_MIDDLE: return true
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			pan(event.position - event.relative, event.position)
			return true
	return false

func pan(previous: Vector2, current: Vector2) -> void:
	# Ray/plane intersection keeps dragging aligned with the cursor at any angle/zoom.
	var plane := Plane(Vector3.UP, focus.y)
	var start: Variant = plane.intersects_ray(project_ray_origin(previous), project_ray_normal(previous))
	var end: Variant = plane.intersects_ray(project_ray_origin(current), project_ray_normal(current))
	if start != null and end != null:
		focus += start - end
		update_pose()

func update_pose() -> void:
	size = clampf(size, minimum_size, _maximum_view_size())
	var limit := maxf(0.0, pan_range)
	focus.x = clampf(focus.x, _initial_focus.x-limit, _initial_focus.x+limit)
	focus.z = clampf(focus.z, _initial_focus.z-limit, _initial_focus.z+limit)
	global_position = focus + Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * distance
	look_at(focus, Vector3.UP)

func _maximum_view_size() -> float:
	return maxf(minimum_size, minf(maximum_size, _initial_size/maxf(0.1, minimum_zoom_scale)))
