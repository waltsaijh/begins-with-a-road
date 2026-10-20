extends Node
## Visual variants use the existing entrance graph, never rebuild it themselves.

signal layout_changed

const Layout = preload("res://scripts/map/tile/appearance/tile_appearance_layout.gd")
@onready var map: GridMap = $"../TileMap"
@onready var controller: Node = $"../PortalMap"
var layout: Dictionary = {}
var _applied := {}
var _queued := false

func _ready() -> void:
	controller.graph_changed.connect(_queue_refresh)
	$"../TilePlacement".cell_placed.connect(_on_cell_placed)
	_queue_refresh()

func _on_cell_placed(_cell: Vector3i) -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if not _queued:
		_queued = true
		refresh.call_deferred()

func refresh() -> void:
	_queued = false
	if controller.computing or not controller.graph.get("valid", false):
		return
	var roads: Array[Vector3i] = []
	var straight_cells := {}
	for cell in map.get_used_cells():
		var base := TileConstants.base_item(map.get_cell_item(cell))
		if cell.y == 0 and base > 0:
			roads.append(cell)
			if base == 1 and not controller.blocked_cells.has(Vector2i(cell.x, cell.z)):
				straight_cells[cell] = true
	var entrances := {}
	for node: Dictionary in controller.graph.nodes:
		entrances[Vector3i(int(node.cell.x), 0, int(node.cell.y))] = true
	var terminals: Array[Vector3i] = []
	for path: NodePath in controller.start_paths:
		var marker := controller.get_node_or_null(path) as Node3D
		if marker != null:
			terminals.append(map.local_to_map(map.to_local(marker.global_position)))
	var goal := get_node_or_null("../Goal") as Node3D
	if goal != null:
		terminals.append(map.local_to_map(map.to_local(goal.global_position)))
	layout = Layout.select(roads, straight_cells, entrances, terminals, layout)
	var next: Dictionary = layout.variants
	# Only changed appearances touch GridMap; IDs map back to the same ports.
	for cell: Vector3i in _applied:
		if not next.has(cell):
			_set_appearance(cell, TileConstants.Appearance.STONE)
	for cell: Vector3i in next:
		_set_appearance(cell, next[cell])
	_applied = next
	layout_changed.emit()

func _set_appearance(cell: Vector3i, appearance: TileConstants.Appearance) -> void:
	var original := map.get_cell_item(cell)
	if original <= 0:
		return
	var item := TileConstants.item_for(original, appearance)
	if item != original:
		map.set_cell_item(cell, item, map.get_cell_item_orientation(cell))
