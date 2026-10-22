extends CanvasLayer
## Shared white cover survives scene replacement; callers only supply an action.
signal started
signal covered
signal finished(error: int)
@export_range(0.1, 2.0, 0.05) var duration := 0.5
var active := false
@onready var veil: ColorRect = $WhiteVeil

func run(action: Callable) -> bool:
	return _begin(action, false)

func change_scene(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("Transition target does not exist: "+path)
		return false
	return _begin(func() -> int: return get_tree().change_scene_to_file(path), true)

func _begin(action: Callable, scene_change: bool) -> bool:
	if active or not action.is_valid(): return false
	active = true
	_front()
	veil.color.a = 0.0
	veil.show()
	started.emit()
	_run(action, scene_change)
	return true

func _front() -> void:
	# Input callbacks run in reverse tree order. Cover input before scene UI,
	# including camera handlers that intentionally run before normal GUI input.
	get_tree().root.move_child(self, get_tree().root.get_child_count()-1)

func _run(action: Callable, scene_change: bool) -> void:
	var half := duration*0.5
	await _fade(1.0, half)
	# Present a fully white frame before replacing a camera, layout or scene.
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw
	covered.emit()
	var error := OK
	if action.is_valid():
		var result: Variant = action.call()
		if result is int: error = result
	else: error = ERR_UNAVAILABLE
	if scene_change and error == OK: await get_tree().scene_changed
	_front()
	await get_tree().process_frame
	await _fade(0.0, half)
	veil.hide()
	active = false
	finished.emit(error)
	if error != OK: push_error("Screen transition failed: "+error_string(error))

func _fade(alpha: float, seconds: float) -> void:
	var motion := create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_property(veil, "color:a", alpha, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await motion.finished

func _input(_event: InputEvent) -> void:
	if active: get_viewport().set_input_as_handled()
