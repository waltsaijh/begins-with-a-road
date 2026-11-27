extends Node3D
## Direct world placement: all allowed regions at once, without direction buttons.
signal completed(start_index: int)
const Planner = preload("res://scripts/levels/expansion/spawn_expansion_planner.gd")
const Search = preload("res://scripts/map/tile/road_construction_search.gd")
@export_range(6,24,1) var search_depth := 8
@export_range(2,6,1) var frontier_band := 3
@export var start_scene: PackedScene = preload("res://scenes/levels/components/expansion_start.tscn")
@onready var controller: Node = $"../PortalMap"
@onready var placement: Node3D = $"../TilePlacement"
@onready var cards: Node3D = $"../CardPlacement"
var active := false
var committing := false
var choices: Array[Dictionary] = []
var last_region := ""
var blocked_goal_sides := 0
var selected: Dictionary = {}
var hovered_cell := TileConstants.INVALID_CELL
var _revision := -1
var _new_start_index := -1
var _entrance_height := 0.0
var _mouse_inside := true
var _pointer_known := false
var _pointer_position := Vector2.ZERO

func _ready() -> void:
	controller.plan_changed.connect(_on_plan_ready)
	get_viewport().mouse_entered.connect(func(): _mouse_inside = true)
	get_viewport().mouse_exited.connect(func():
		_mouse_inside = false
		_pointer_known = false
		_clear_hover())
	_fade_preview($World/EntrancePreview)
	$World.hide()
	$Interface.hide()
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)

func _fade_preview(node: Node) -> void:
	if node is GeometryInstance3D:
		node.transparency = 0.55
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): _fade_preview(child)

func begin() -> bool:
	if active or get_tree().paused: return false
	var generated := Planner.generate(controller,search_depth,frontier_band,blocked_goal_sides)
	if generated.is_empty(): generated = Planner.generate(controller,search_depth+8,frontier_band,blocked_goal_sides)
	choices = Planner.allowed(generated,last_region)
	if choices.is_empty(): return false
	var map: GridMap = controller.map
	var first := controller.get_node(controller.start_paths[0]) as Node3D
	var source: Vector3 = map.to_local(first.global_position)
	var source_cell := map.local_to_map(source)
	source_cell.y = 0
	_entrance_height = source.y-map.map_to_local(source_cell).y
	active = true
	committing = false
	selected = {}
	_pointer_known = false
	_revision = controller.revision
	$World.global_transform = map.global_transform
	var cells: Array[Vector2i] = []
	for region in choices:
		for cell: Vector2i in region.paths: cells.append(cell)
	_set_cells($World/Candidates,cells)
	_clear_hover()
	$World.show()
	$Interface.show()
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	return true

func _interactive() -> bool:
	return active and not committing and not cards.pause_locked and not get_tree().paused

func candidate(cell: Vector3i) -> Dictionary:
	if cell.y != 0 or cell == TileConstants.INVALID_CELL: return {}
	var at := Vector2i(cell.x,cell.z)
	for region in choices:
		if region.proposals.has(at): return {"cell":at,"direction":region.direction,"proposal":region.proposals[at]}
	return {}

func _set_cells(view: MultiMeshInstance3D, cells: Array[Vector2i]) -> void:
	view.multimesh.instance_count = cells.size()
	for i in cells.size():
		var point: Vector3 = controller.map.map_to_local(Vector3i(cells[i].x,0,cells[i].y))
		view.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(controller.map.cell_size),point))

func show_hover(cell: Vector3i) -> void:
	if not _interactive() or hovered_cell == cell: return
	_clear_hover()
	var option := candidate(cell)
	if option.is_empty() or _revision != controller.revision or not Planner.valid(controller,option.cell,option.proposal.path,blocked_goal_sides): return
	hovered_cell = cell
	_set_cells($World/PathPreview,option.proposal.path)
	$World/Hover.position = controller.map.map_to_local(cell)
	$World/Hover.show()
	$World/EntrancePreview.position = controller.map.map_to_local(cell)+Vector3.UP*_entrance_height
	$World/EntrancePreview.rotation.y = _entrance_angle(option.proposal.path)
	$World/EntrancePreview.show()

func _clear_hover() -> void:
	hovered_cell = TileConstants.INVALID_CELL
	$World/PathPreview.multimesh.instance_count = 0
	$World/Hover.hide()
	$World/EntrancePreview.hide()

func commit(cell: Vector3i) -> bool:
	if not _interactive() or _revision != controller.revision: return false
	var option := candidate(cell)
	if option.is_empty() or not Planner.valid(controller,option.cell,option.proposal.path,blocked_goal_sides): return false
	var marker := start_scene.instantiate() as Node3D
	if marker == null: return false
	var result := Search.commit(controller,option.proposal,[option.cell],false)
	if not result.ok:
		marker.free()
		return false
	committing = true
	selected = option
	last_region = option.direction
	_new_start_index = controller.start_paths.size()
	marker.name = "ActStart%d" % (_new_start_index+1)
	get_parent().add_child(marker)
	marker.global_position = controller.map.to_global(controller.map.map_to_local(cell)+Vector3.UP*_entrance_height)
	marker.get_node("Visual").rotation.y = _entrance_angle(option.proposal.path)
	controller.start_paths.append(controller.get_path_to(marker))
	controller.rebuild()
	placement.notify_cells(result.added)
	var visuals := get_node_or_null("../TileVisuals")
	if visuals != null: visuals.follow_new_cell(cell,marker.get_node("Visual"))
	var camp := marker.get_node("Visual")
	if camp.has_method("pitch_up"): camp.pitch_up()
	_clear_hover()
	$World.hide()
	$Interface.hide()
	return true

func _entrance_angle(path: Array) -> float:
	var direction: Vector2i = path[1]-path[0]
	return atan2(-float(direction.x),-float(direction.y))   # camp door (-Z) faces the road

func _process(_delta: float) -> void:
	_on_plan_ready()
	if not active: return
	$World.visible = _interactive()
	$Interface.visible = _interactive()
	if not _interactive() or not _mouse_inside or not _pointer_known or get_viewport().gui_get_hovered_control() != null:
		_clear_hover()
		return
	show_hover(placement.pick_cell(_pointer_position))

func _on_plan_ready() -> void:
	if not active or not committing or controller.computing or get_tree().paused: return
	active = false
	committing = false
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	completed.emit(_new_start_index)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_position = event.position
		_pointer_known = true

func _unhandled_input(event: InputEvent) -> void:
	if not _interactive(): return
	# Camera arbitration replays a click only after confirming it was not a drag.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE|MOUSE_BUTTON_MASK_RIGHT): return
		commit(placement.pick_cell(event.position))
		get_viewport().set_input_as_handled()
