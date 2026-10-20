@tool
extends Control
## Changing recipes reuse scene-authored cells; artwork stays editable in Godot.
@export var cell_scene: PackedScene = preload("res://scenes/cards/components/card_diagram_cell.tscn")
@export_range(8.0, 40.0, 1.0) var max_cell_size := 21.0:
	set(value):
		max_cell_size = value
		_refresh()
@export_range(0.0, 8.0, 1.0) var cell_gap := 3.0:
	set(value):
		cell_gap = value
		_refresh()
var card: BuildCard
var turns := 0
var accent := Color.WHITE
var _views: Array[Control] = []

func _ready() -> void:
	resized.connect(_refresh)
	_refresh()

func show_recipe(value: BuildCard, rotation_steps: int, color: Color) -> void:
	card = value
	turns = rotation_steps
	accent = color
	_refresh()

func _refresh() -> void:
	if not is_node_ready(): return
	var cells: Array = card.ground_cells(Vector2i.ZERO, turns) if card != null else []
	while _views.size() < cells.size():
		var view := cell_scene.instantiate() as Control
		add_child(view)
		_views.append(view)
	for i in _views.size(): _views[i].visible = i < cells.size()
	if cells.is_empty(): return
	var blocked := card.tower_cells(Vector2i.ZERO, turns)
	var low: Vector2i = cells[0]
	var high: Vector2i = low
	for cell in cells:
		low = low.min(cell)
		high = high.max(cell)
	var dimensions := Vector2(high-low+Vector2i.ONE)
	var spacing := minf(max_cell_size, minf(size.x/dimensions.x, size.y/dimensions.y))
	var center := size/2.0-Vector2(low+high)*spacing/2.0
	var width := maxf(1.0, spacing-cell_gap)
	for i in cells.size():
		var view := _views[i]
		view.position = center+Vector2(cells[i])*spacing-Vector2.ONE*width/2.0
		view.size = Vector2.ONE*width
		view.get_node("Tower").visible = cells[i] in blocked
		view.get_node("Tower/Accent").self_modulate = accent
