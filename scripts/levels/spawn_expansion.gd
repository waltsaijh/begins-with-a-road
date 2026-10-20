extends Node3D
## Two-stage ACT transition. UI and world artwork live in editable scene nodes.
signal completed(start_index: int)
const Planner = preload("res://scripts/levels/spawn_expansion_planner.gd")
@export_range(6, 24, 1) var search_depth := 8
@export_range(2, 6, 1) var frontier_band := 3
@export var start_scene: PackedScene = preload("res://scenes/levels/components/expansion_start.tscn")
@onready var controller: Node = $"../PortalMap"
@onready var placement: Node3D = $"../TilePlacement"
@onready var cards: Node3D = $"../CardPlacement"
@onready var panel: Control = $Interface/Root/Panel
@onready var buttons: HBoxContainer = $Interface/Root/Panel/Margin/Content/Directions
@onready var heading: Label = $Interface/Root/Panel/Margin/Content/Heading
@onready var back: Button = $Interface/Root/Panel/Margin/Content/Back
var active := false
var committing := false
var choices: Array[Dictionary] = []
var selected_direction := -1
var hovered_cell := TileConstants.INVALID_CELL
var _revision := -1
var _new_start_index := -1
var _saved_focus := Vector3.ZERO
var _camera_framed := false
var _mouse_inside := true

func _ready() -> void:
	for i in buttons.get_child_count():
		var button := buttons.get_child(i) as Button
		button.pressed.connect(choose_direction.bind(i))
		button.mouse_entered.connect(func():
			if active and selected_direction < 0: _show_candidates(i))
		button.mouse_exited.connect(func():
			if active and selected_direction < 0: _show_candidates(-1))
	back.pressed.connect(back_to_directions)
	controller.plan_changed.connect(_on_plan_ready)
	get_viewport().mouse_entered.connect(func(): _mouse_inside = true)
	get_viewport().mouse_exited.connect(func():
		_mouse_inside = false
		_clear_hover())
	for visual in $World/EntrancePreview.get_children():
		_fade_preview(visual)
	panel.hide()
	$World.hide()
	set_process(false)
	set_process_unhandled_input(false)

func _fade_preview(node: Node) -> void:
	if node is GeometryInstance3D:
		node.transparency = 0.55
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): _fade_preview(child)

func begin() -> bool:
	if active: return false
	choices = Planner.generate(controller, search_depth, frontier_band)
	# Obstacles may hide a nearby frontier; search farther before omitting it.
	if choices.size() < 3: choices = Planner.generate(controller, search_depth+8, frontier_band)
	if choices.is_empty(): return false
	active = true
	committing = false
	selected_direction = -1
	_revision = controller.revision
	$World.global_transform = controller.map.global_transform
	panel.show()
	$World.show()
	_show_candidates(-1)
	_update_labels()
	set_process(true)
	set_process_unhandled_input(true)
	return true

func _interactive() -> bool:
	return active and not committing and not cards.pause_locked and not get_tree().paused

func choose_direction(index: int) -> void:
	if not _interactive() or index < 0 or index >= choices.size(): return
	selected_direction = index
	_clear_hover()
	_show_candidates(index)
	_frame_candidates()
	_update_labels()

func back_to_directions() -> void:
	if not _interactive(): return
	selected_direction = -1
	_clear_hover()
	_restore_camera()
	_show_candidates(-1)
	_update_labels()

func _show_candidates(index: int) -> void:
	var cells: Array[Vector2i] = []
	for i in choices.size():
		if index >= 0 and i != index: continue
		for cell: Vector2i in choices[i].paths: cells.append(cell)
	_set_cells($World/Candidates, cells)

func _set_cells(view: MultiMeshInstance3D, cells: Array[Vector2i]) -> void:
	view.multimesh.instance_count = cells.size()
	for i in cells.size():
		var point: Vector3 = controller.map.map_to_local(Vector3i(cells[i].x, 0, cells[i].y))
		view.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(controller.map.cell_size), point))

func _frame_candidates() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not "focus" in camera: return
	if not _camera_framed:
		_saved_focus = camera.focus
		_camera_framed = true
	var center := Vector3.ZERO
	var paths: Dictionary = choices[selected_direction].paths
	for cell: Vector2i in paths:
		center += controller.map.to_global(controller.map.map_to_local(Vector3i(cell.x, 0, cell.y)))
	camera.focus = center/paths.size()
	camera.update_pose()

func _restore_camera() -> void:
	if not _camera_framed: return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		camera.focus = _saved_focus
		camera.update_pose()
	_camera_framed = false

func _process(_delta: float) -> void:
	if not _interactive() or selected_direction < 0 or not _mouse_inside or get_viewport().gui_get_hovered_control() != null:
		_clear_hover()
		return
	show_hover(placement.pick_cell(get_viewport().get_mouse_position()))

func show_hover(cell: Vector3i) -> void:
	if not _interactive() or selected_direction < 0 or hovered_cell == cell: return
	_clear_hover()
	if cell.y != 0 or cell == TileConstants.INVALID_CELL: return
	var at := Vector2i(cell.x, cell.z)
	var paths: Dictionary = choices[selected_direction].paths
	if not paths.has(at) or _revision != controller.revision or not Planner.valid(controller, at, paths[at]): return
	hovered_cell = cell
	_set_cells($World/PathPreview, paths[at])
	$World/Hover.position = controller.map.map_to_local(cell)
	$World/Hover.show()
	$World/EntrancePreview.position = controller.map.map_to_local(cell)+Vector3.UP*get_parent().level.marker_height
	$World/EntrancePreview.rotation.y = _entrance_angle(paths[at])
	$World/EntrancePreview.show()

func _clear_hover() -> void:
	hovered_cell = TileConstants.INVALID_CELL
	$World/PathPreview.multimesh.instance_count = 0
	$World/Hover.hide()
	$World/EntrancePreview.hide()

func commit(cell: Vector3i) -> bool:
	if not _interactive() or selected_direction < 0 or _revision != controller.revision: return false
	if cell.y != 0 or cell == TileConstants.INVALID_CELL: return false
	var at := Vector2i(cell.x, cell.z)
	var paths: Dictionary = choices[selected_direction].paths
	if not paths.has(at) or not Planner.valid(controller, at, paths[at]): return false
	committing = true
	var added: Array[Vector3i] = []
	for point: Vector2i in paths[at]: added.append(Vector3i(point.x, 0, point.y))
	placement.add_cells(added, false)
	# Keep the logical marker fixed while its child artwork rises with the tile.
	var marker := start_scene.instantiate() as Node3D
	_new_start_index = controller.start_paths.size()
	marker.name = "ActStart%d" % (_new_start_index+1)
	get_parent().add_child(marker)
	marker.global_position = controller.map.to_global(controller.map.map_to_local(cell)+Vector3.UP*get_parent().level.marker_height)
	marker.get_node("Visual").rotation.y = _entrance_angle(paths[at])
	controller.start_paths.append(controller.get_path_to(marker))
	controller.rebuild()
	placement.notify_cells(added)
	get_node("../TileVisuals").follow_new_cell(cell, marker.get_node("Visual"))
	panel.hide()
	$World.hide()
	set_process(false)
	_restore_camera()
	return true

func _entrance_angle(path: Array) -> float:
	if path.size() < 2: return 0.0
	var direction: Vector2i = path[1]-path[0]
	return atan2(float(direction.x), float(direction.y))

func _on_plan_ready() -> void:
	if not active or not committing or controller.computing: return
	active = false
	committing = false
	set_process_unhandled_input(false)
	completed.emit(_new_start_index)

func _unhandled_input(event: InputEvent) -> void:
	if not _interactive(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and selected_direction >= 0:
		back_to_directions()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		if event.button_index == MOUSE_BUTTON_LEFT and selected_direction >= 0:
			commit(placement.pick_cell(event.position))
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): _update_labels()

func _update_labels() -> void:
	var placing := selected_direction >= 0
	heading.text = tr("ui.expansion.choose_position") if placing else tr("ui.expansion.choose_direction")
	$Interface/Root/Panel/Margin/Content/Note.text = tr("ui.expansion.countdown_held")
	buttons.visible = not placing
	back.visible = placing
	back.text = tr("ui.expansion.back")
	for i in buttons.get_child_count():
		var button := buttons.get_child(i) as Button
		button.visible = i < choices.size()
		if i < choices.size(): button.text = tr("ui.expansion."+choices[i].direction)
