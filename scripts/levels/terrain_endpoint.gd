@tool
class_name TerrainEndpoint
extends Marker3D
## Scene-authored endpoint. Editor snapping never moves a runtime marker.
enum Role { START, GOAL }
@export var role: Role = Role.START
@export var snap_to_grid := true:
	set(value):
		snap_to_grid = value
		_queue_snap()
@export var height_offset := 0.0305:
	set(value):
		height_offset = value
		_queue_snap()
var _snap_queued := false

func _enter_tree() -> void:
	set_notify_local_transform(Engine.is_editor_hint())
	_queue_snap()

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED: _queue_snap()

func _queue_snap() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _snap_queued: return
	_snap_queued = true
	snap.call_deferred()

func grid_map() -> GridMap:
	var parent := get_parent()
	while parent != null:
		if parent is GridMap: return parent
		parent = parent.get_parent()
	return null

func snap() -> void:
	var map := grid_map()
	if snap_to_grid and map != null and is_inside_tree():
		var cell := map.local_to_map(map.to_local(global_position))
		cell.y = 0
		var target := map.to_global(map.map_to_local(cell)+Vector3.UP*height_offset)
		if not global_position.is_equal_approx(target): global_position = target
	_snap_queued = false
	update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	var map := grid_map()
	if map == null: return ["請把起終點放在 GridMap 之下。"]
	if not is_inside_tree(): return []
	var cell := map.local_to_map(map.to_local(global_position))
	cell.y = 0
	if map.get_cell_item(cell) <= 0: return ["起終點必須放在道路地塊上；請在此處繪製道路。"]
	return []
