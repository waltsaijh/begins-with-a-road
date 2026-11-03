extends CanvasLayer
## Shared white cover survives scene replacement; callers only supply an action.
signal started
signal covered
signal finished(error: int)
@export_range(0.1, 2.0, 0.05) var duration := 0.5
var active := false
@onready var veil: ColorRect = $WhiteVeil
@onready var loading: Control = $WhiteVeil/Loading
@onready var loading_stage: Label = $WhiteVeil/Loading/Column/Stage
@onready var loading_bar: ProgressBar = $WhiteVeil/Loading/Column/Progress
@onready var loading_count: Label = $WhiteVeil/Loading/Column/Count

func _ready() -> void:
	# The web shell stays readable until the first native frame is actually drawn.
	if OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		JavaScriptBridge.eval("window.roadStartupPresented?.()")

func run(action: Callable) -> bool:
	return _begin(action, false)

## Optional scene method: async prepare(report: Callable) -> Error.
## The target owns its preparation; the transition only displays reported work.
func change_scene(path: String, preparation_method: StringName = &"", loading_message: StringName = &"") -> bool:
	if not ResourceLoader.exists(path):
		push_error("Transition target does not exist: "+path)
		return false
	return _begin(func() -> int: return get_tree().change_scene_to_file(path), true, preparation_method, loading_message)

func _begin(action: Callable, scene_change: bool, preparation_method: StringName = &"", loading_message: StringName = &"") -> bool:
	if active or not action.is_valid(): return false
	active = true
	_front()
	veil.color.a = 0.0
	veil.show()
	if loading_message.is_empty():
		loading.hide()
	else:
		report_progress(0, 0, loading_message)
		loading.show()
	started.emit()
	_run(action, scene_change, preparation_method, loading_message)
	return true

func _front() -> void:
	# Input callbacks run in reverse tree order. Cover input before scene UI,
	# including camera handlers that intentionally run before normal GUI input.
	get_tree().root.move_child(self, get_tree().root.get_child_count()-1)

func _run(action: Callable, scene_change: bool, preparation_method: StringName, loading_message: StringName) -> void:
	var previous_path := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	var half := duration*0.5
	await _fade(1.0, half)
	# Present a fully white frame before replacing a camera, layout or scene.
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw
	covered.emit()
	if not preparation_method.is_empty():
		report_progress(0, 0, &"ui.loading.scene")
		loading.show()
	if not preparation_method.is_empty() or not loading_message.is_empty():
		await _present()
	var error := OK
	if action.is_valid():
		var result: Variant = action.call()
		if result is int: error = result
	else: error = ERR_UNAVAILABLE
	if scene_change and error == OK: await get_tree().scene_changed
	_front()
	if error == OK and not preparation_method.is_empty():
		var target := get_tree().current_scene
		if target == null or not target.has_method(preparation_method):
			error = ERR_UNAVAILABLE
		else:
			var previous_mode := target.process_mode
			target.process_mode = Node.PROCESS_MODE_DISABLED
			var task := {"done": false, "error": ERR_UNAVAILABLE}
			_prepare(target, preparation_method, task)
			# Also finish if a target exits while its preparation is awaiting a draw.
			while not task.done and is_instance_valid(target) and target.is_inside_tree():
				await get_tree().process_frame
			error = int(task.error)
			if is_instance_valid(target): target.process_mode = previous_mode
		if error != OK and not previous_path.is_empty():
			if get_tree().change_scene_to_file(previous_path) == OK:
				await get_tree().scene_changed
				_front()
			loading.hide()
	await get_tree().process_frame
	await _fade(0.0, half)
	veil.hide()
	loading.hide()
	active = false
	finished.emit(error)
	if error != OK: push_error("Screen transition failed: "+error_string(error))

func _prepare(target: Node, method: StringName, task: Dictionary) -> void:
	var result: Variant = await target.call(method, report_progress)
	task.error = result if result is int else ERR_INVALID_DATA
	task.done = true

func report_progress(completed: int, total: int, stage: StringName) -> void:
	loading.report(completed, total, stage)

func _present() -> void:
	if DisplayServer.get_name() == "headless": await get_tree().process_frame
	else: await RenderingServer.frame_post_draw

func _fade(alpha: float, seconds: float) -> void:
	var motion := create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_property(veil, "color:a", alpha, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await motion.finished

func _input(_event: InputEvent) -> void:
	if active: get_viewport().set_input_as_handled()
