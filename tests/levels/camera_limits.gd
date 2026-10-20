extends Node
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited

var failures := 0
var checks := 0
var _viewport: SubViewport

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func wheel(camera: Camera3D, direction: MouseButton, amount := 1.0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = direction
	event.factor = amount
	event.pressed = true
	check(camera.handle_navigation_input(event), "Camera did not handle a zoom input")

func check_range(camera: Camera3D) -> void:
	var offset: Vector3 = camera.focus-camera._initial_focus
	check(absf(offset.x) <= camera.pan_range+0.001 and absf(offset.z) <= camera.pan_range+0.001, "Camera left its fixed square range")
	checks += 1

func verify() -> void:
	_viewport = TestViewport.new()
	_viewport.size = Vector2i(1152, 648)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var scene := load("res://scenes/main.tscn").instantiate() as Node3D
	scene.get_node("EnemyWave").auto_start = false
	_viewport.add_child(scene)
	await frames(5)
	var camera: Camera3D = scene.get_node("Camera3D")
	var initial: float = camera._initial_size
	check_range(camera)
	wheel(camera, MOUSE_BUTTON_WHEEL_DOWN, 20.0)
	check(is_equal_approx(initial/camera.size, 0.6), "Camera did not stop zooming out at 0.6x")
	for i in 10: wheel(camera, MOUSE_BUTTON_WHEEL_DOWN)
	check(is_equal_approx(initial/camera.size, 0.6), "Repeated zoom-out bypassed its limit")
	wheel(camera, MOUSE_BUTTON_WHEEL_UP, 40.0)
	check(is_equal_approx(camera.size, camera.minimum_size), "Existing close zoom limit was lost")
	for dimensions: Vector2i in [Vector2i(1152, 648), Vector2i(800, 800), Vector2i(2400, 600)]:
		_viewport.size = dimensions
		await frames()
		wheel(camera, MOUSE_BUTTON_WHEEL_DOWN, 40.0)
		for delta: Vector2 in [Vector2(10000, 0), Vector2(-20000, 0), Vector2(0, 10000), Vector2(0, -20000), Vector2(20000, 20000)]:
			var center := Vector2(dimensions)*0.5
			camera.pan(center, center+delta)
			check_range(camera)
		# Zooming at the square edge must leave the focus exactly where it is.
		var edge: Vector3 = camera.focus
		wheel(camera, MOUSE_BUTTON_WHEEL_UP, 40.0)
		wheel(camera, MOUSE_BUTTON_WHEEL_DOWN, 40.0)
		check(camera.focus.is_equal_approx(edge) and is_equal_approx(initial/camera.size, 0.6), "Zoom or window aspect changed the fixed pan bounds")
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		camera.focus = camera._initial_focus+Vector3(corner.x*1000, 0, corner.y*1000)
		camera.update_pose()
		check(camera.focus.is_equal_approx(camera._initial_focus+Vector3(corner.x, 0, corner.y)*camera.pan_range), "Square corners did not clamp X and Z independently")
	camera.pan_range = 0.0
	camera.update_pose()
	check(camera.focus.is_equal_approx(camera._initial_focus), "Zero pan range did not lock the camera center")
	camera.pan_range = 24.0
	_viewport.size = Vector2i(1152, 648)
	await frames()
	get_tree().paused = true
	Engine.time_scale = 0.0
	camera.pan(Vector2.ZERO, Vector2(-10000, 10000))
	wheel(camera, MOUSE_BUTTON_WHEEL_DOWN, 20.0)
	check_range(camera)
	check(camera.can_process(), "Camera limits disabled paused navigation")
	get_tree().paused = false
	Engine.time_scale = 1.0
	print("CAMERA_LIMITS_CHECK:"+JSON.stringify({"failures": failures, "range_checks": checks, "minimum_zoom": 0.6, "square_pan_range": true, "zoom_keeps_focus": true, "aspect_independent": true, "paused": true}))
	get_tree().quit(1 if failures else 0)
