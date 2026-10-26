extends Camera3D
## Pan the focus on the map plane; circular dragging orbits its world Y axis.

@export_node_path("GridMap") var map_path: NodePath = ^"../TileMap"
@export var minimum_size := 2.0
@export var maximum_size := 48.0
## Zoom is initial size / current size; 0.6x is the farthest zoom-out.
@export_range(0.1, 1.0, 0.05) var minimum_zoom_scale := 0.6
## World-space square centered on the initial focus; each axis allows ±pan_range.
@export_range(0.0, 80.0, 0.5) var pan_range := 16.0
## Separate clicks from drags without changing the one-circle/one-turn ratio.
@export_range(1.0, 16.0, 0.5) var orbit_drag_threshold := 4.0
## Ignore angular changes too close to the projected focus.
@export_range(1.0, 64.0, 1.0) var orbit_dead_zone := 16.0
## Degrees per real second; independent of game speed and pause.
@export_range(1.0, 720.0, 1.0, "or_greater") var maximum_orbit_speed := 360.0
## Real seconds to close 99% of the gap between current and target speed.
@export_range(0.01, 0.5, 0.01) var orbit_smoothing_seconds := 0.15
var _initial_size := 18.5
var _initial_focus := Vector3.ZERO
var _orbiting := false
var _orbit_press: InputEventMouseButton
var _orbit_previous := Vector2.ZERO
var _replaying_click := false
var _orbit_input_angle := 0.0
var _orbit_velocity := 0.0
var _orbit_target_velocity := 0.0
var _last_process_usec := 0
var _navigation_locked := false

var focus := Vector3.ZERO
var azimuth := deg_to_rad(30.0)
var elevation := deg_to_rad(45.0)
var distance := 35.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_process_usec = Time.get_ticks_usec()
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
	get_viewport().mouse_exited.connect(_stop_orbit)
	update_pose()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := (now-_last_process_usec)/1000000.0
	_last_process_usec = now
	_advance_orbit(real_delta)

func _advance_orbit(real_delta: float) -> void:
	if real_delta <= 0.0: return
	var maximum_speed := deg_to_rad(maxf(1.0, maximum_orbit_speed))
	# Consume this frame's pointer movement, never queue unfinished circles.
	_orbit_target_velocity = clampf(_orbit_input_angle/real_delta, -maximum_speed, maximum_speed) if _orbiting else 0.0
	_orbit_input_angle = 0.0
	var previous_velocity := clampf(_orbit_velocity, -maximum_speed, maximum_speed)
	var response := log(100.0)/maxf(0.01, orbit_smoothing_seconds)
	var follow := 1.0-exp(-response*real_delta)
	_orbit_velocity = lerpf(previous_velocity, _orbit_target_velocity, follow)
	# Integrate the same velocity transition exactly, independent of frame rate.
	var step := _orbit_target_velocity*real_delta+(previous_velocity-_orbit_target_velocity)*follow/response
	if is_zero_approx(_orbit_target_velocity) and absf(_orbit_velocity) < deg_to_rad(0.01):
		_orbit_velocity = 0.0
	if not is_zero_approx(step):
		azimuth = wrapf(azimuth+step, -PI, PI)
		update_pose()

func _input(event: InputEvent) -> void:
	# Decide click versus drag before GUI/gameplay can act on the press. Cards
	# retain their normal input; non-card clicks are delivered on release.
	# Middle-button navigation must reach the camera before cards consume GUI
	# motion, including when the pointer crosses a shop slot or its price.
	var middle_drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0
	var middle_button: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE
	if middle_drag or middle_button or _orbit_press != null or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if handle_navigation_input(event): get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if handle_navigation_input(event): get_viewport().set_input_as_handled()

## A host can lock navigation for modal UI without coupling the camera to it.
func set_navigation_locked(value: bool) -> void:
	_navigation_locked = value
	if value: _stop_orbit()

## HUD forwards camera navigation while gameplay input is locked.
func handle_navigation_input(event: InputEvent) -> bool:
	if _navigation_locked: return false
	if _replaying_click: return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				if _orbit_press == null: return false
				var click := _orbit_press if not _orbiting else null
				_stop_orbit(true)
				if click != null: _deliver_click.call_deferred(click, event.duplicate())
				return true
			if not event.button_mask & MOUSE_BUTTON_MASK_MIDDLE and not _over_card(event.position):
				# A new gesture takes control without the previous easing tail.
				_stop_orbit()
				_orbit_press = event.duplicate()
				_orbit_previous = event.position
				return true
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed:
				var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				size = clampf(size*pow(1.12, direction*event.factor), minimum_size, _maximum_view_size())
				update_pose()
			return true
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_stop_orbit()
			return true
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_stop_orbit()
			pan(event.position - event.relative, event.position)
			return true
		if _orbit_press != null:
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_stop_orbit()
				return false
			if not _orbiting and event.position.distance_to(_orbit_press.position) < orbit_drag_threshold:
				return true
			_orbiting = true
			var center := unproject_position(focus)
			var previous := _orbit_previous-center
			var current: Vector2 = event.position-center
			if previous.length() >= orbit_dead_zone and current.length() >= orbit_dead_zone:
				# Screen Y points down: positive angle is clockwise, as is the
				# terrain's apparent rotation when the camera azimuth increases.
				# Accumulate only until this frame's velocity update.
				_orbit_input_angle += previous.angle_to(current)
			_orbit_previous = event.position
			return true
	return false

func _deliver_click(press: InputEventMouseButton, release: InputEventMouseButton) -> void:
	if not is_inside_tree() or _navigation_locked: return
	# Deferred delivery avoids re-entering the viewport's active input dispatch.
	# Retain the original positions/modifiers and GUI -> gameplay propagation.
	_replaying_click = true
	var viewport := get_viewport()
	viewport.push_input(press, true)
	viewport.push_input(release, true)
	_replaying_click = false

func _stop_orbit(smooth := false) -> void:
	_orbit_target_velocity = 0.0
	if not smooth: _orbit_velocity = 0.0
	_orbiting = false
	_orbit_press = null
	_orbit_input_angle = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: _stop_orbit()

func _over_card(point: Vector2) -> bool:
	return CardButton.has_card_at(get_viewport(), point)

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
