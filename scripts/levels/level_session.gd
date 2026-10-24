extends Node3D
## Loads terrain before gameplay children become ready; owns finite progression.
signal level_finished
const TIMELINE_ADVANCE_SECONDS := 1.0
const WAVE_START_SECONDS := 1.5
@export var level: LevelDefinition
var current_wave := 0
var finished := false
var timeline: WaveTimeline
var _waves: Array[WaveDefinition] = []
var _valid := false
var _wave: Node
var _wave_starting := false
var _wave_start_elapsed := 0.0
var _balance: Label
var _hud: CanvasLayer
var choosing_start := false
@onready var expansion: Node3D = $SpawnExpansion

func _enter_tree() -> void:
	get_node("EnemyWave").auto_start = false
	if level == null: return
	var error := level.configuration_error()
	if not error.is_empty():
		push_error(error)
		return
	var source_node := level.terrain.instantiate()
	if not source_node is GridMap:
		source_node.free()
		push_error("Level terrain must have a GridMap root")
		return
	var source := source_node as GridMap
	var map: GridMap = get_node("TileMap")
	map.clear()
	map.mesh_library = source.mesh_library
	map.transform = source.transform
	map.cell_size = source.cell_size
	map.cell_center_x = source.cell_center_x
	map.cell_center_y = source.cell_center_y
	map.cell_center_z = source.cell_center_z
	for cell in source.get_used_cells():
		map.set_cell_item(cell, source.get_cell_item(cell), source.get_cell_item_orientation(cell))
	var layout := level.endpoint_layout(source)
	var paths: Array[NodePath] = []
	for i in layout.starts.size():
		var marker: Node3D
		var marker_name := "Start" if i == 0 else "Start%d" % (i+1)
		if layout.from_scene:
			marker = _install_endpoint(source, layout.starts[i], marker_name, map)
		else:
			marker = get_node("Start") if i == 0 else get_node("Start").duplicate()
			if i > 0:
				marker.name = marker_name
				add_child(marker)
			marker.position = map.transform*layout.starts[i].transform.origin
		paths.append(NodePath("../"+str(marker.name)))
	if layout.from_scene:
		_install_endpoint(source, layout.goal, "Goal", map)
	else:
		get_node("Goal").position = map.transform*layout.goal.transform.origin
	source.free()
	get_node("PortalMap").start_paths = paths
	for act in level.acts:
		_waves.append_array(act.waves)
	_valid = true

func _install_endpoint(source: GridMap, point: Dictionary, marker_name: String, map: GridMap) -> Node3D:
	var previous := get_node_or_null(NodePath(marker_name))
	if previous != null:
		remove_child(previous)
		previous.free()
	var marker := source.get_node(point.path).duplicate() as Node3D
	marker.name = marker_name
	marker.transform = map.transform*point.transform
	add_child(marker)
	return marker

func _ready() -> void:
	_wave = get_node("EnemyWave")
	if not _valid:
		_wave.start_allowed = false
		_wave._update_button()
		get_node("CardPlacement").set_entry_selection(true)
		set_process(false)
		return
	_hud = get_node("LevelHUD")
	timeline = get_node("LevelHUD/Header/WaveTimeline")
	timeline.configure(level)
	var shop: Node = get_node("CardPlacement/Shop")
	_balance = get_node("LevelHUD/Header/Balance/Amount")
	shop.balance_changed.connect(_on_balance_changed)
	_on_balance_changed(shop.coins)
	_wave.wave_started.connect(_on_wave_started)
	_wave.wave_finished.connect(_on_wave_finished)
	expansion.completed.connect(_on_start_added)
	if _wave.controls != null:
		# Formal levels own the opening transition; standalone maps start immediately.
		_wave.controls.spawn_requested.disconnect(_wave.start_wave)
		_wave.controls.spawn_requested.connect(_on_start_requested)
	_prepare_wave()

func _on_balance_changed(coins: int) -> void:
	_balance.text = str(coins)

func _prepare_wave() -> void:
	_wave_starting = false
	_wave_start_elapsed = 0.0
	if _wave.controls != null: _wave.controls.start_pending = false
	_wave.apply_definition(_waves[current_wave])
	get_node("CardPlacement/Shop").wave_reward = _waves[current_wave].reward
	timeline.set_state(current_wave, 0.0, false)
	_update_start_callout()
	set_process(false)

func _update_start_callout() -> void:
	_hud.set_start_available(not finished and not choosing_start and not _wave.active and not _wave_starting)

func _on_start_requested() -> void:
	if choosing_start or get_tree().paused or _hud.pause_requested: return
	_begin_wave_start()

func _begin_wave_start() -> void:
	if finished or choosing_start or _wave.active or _wave_starting or not _wave.start_allowed: return
	_wave_starting = true
	_wave_start_elapsed = 0.0
	if _wave.controls != null: _wave.controls.start_pending = true
	get_node("CardPlacement").prepare_wave_start()
	_update_start_callout()
	set_process(true)

func _on_wave_started() -> void:
	_wave_starting = false
	if _wave.controls != null: _wave.controls.start_pending = false
	timeline.set_state(current_wave, 1.0, true)
	_update_start_callout()
	set_process(false)

func _process(delta: float) -> void:
	if not _valid or finished or choosing_start or _wave.active: return
	if _wave_starting:
		_advance_wave_start(maxf(0.0, delta))

func _advance_wave_start(delta: float) -> void:
	_wave_start_elapsed = minf(WAVE_START_SECONDS, _wave_start_elapsed+delta)
	var progress: float = Tween.interpolate_value(0.0, 1.0, minf(_wave_start_elapsed, TIMELINE_ADVANCE_SECONDS), TIMELINE_ADVANCE_SECONDS, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	timeline.set_state(current_wave, progress, false)
	if _wave_start_elapsed >= WAVE_START_SECONDS:
		_wave.start_wave()

func _on_wave_finished() -> void:
	# Enemy tree_exiting callbacks also run while the level is being removed,
	# after later siblings such as the HUD have already left the tree.
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not is_instance_valid(_hud) or not _hud.is_inside_tree(): return
	set_process(false)
	current_wave += 1
	if current_wave == _waves.size():
		finished = true
		_wave.start_allowed = false
		timeline.set_state(current_wave, 0.0, false)
		level_finished.emit()
	else:
		_prepare_wave()
		if level.expand_starts_after_act and _is_act_boundary(current_wave):
			choosing_start = true
			_wave.start_allowed = false
			get_node("CardPlacement").set_entry_selection(true)
			_update_start_callout()
			_wave._update_button()
			set_process(false)
			if not expansion.begin():
				# A completely enclosed custom terrain may have no expandable frontier.
				push_warning("No reachable frontier for a new entrance")
				_on_start_added(-1)

func _is_act_boundary(index: int) -> bool:
	var count := 0
	for act in level.acts:
		count += act.waves.size()
		if count == index: return true
	return false

func _on_start_added(index: int) -> void:
	if index >= 0:
		_wave.additional_start_indices.append(index)
		_wave.routes_changed.emit()
	choosing_start = false
	_wave.start_allowed = true
	get_node("CardPlacement").set_entry_selection(false)
	_wave._update_button()
	_update_start_callout()
	set_process(false)
