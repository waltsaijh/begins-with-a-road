extends MeshInstance3D
## Three shared planes give cloud thickness and parallax, without ray marching.

@export_node_path("GridMap") var map_path: NodePath = ^"../TileMap"
## Opaque bottom; the two translucent strata sit one and two cells above it.
@export_range(2.0, 16.0, 0.25) var depth := 4.0
@export_range(4.0, 160.0, 1.0) var padding := 80.0
@onready var map := get_node_or_null(map_path) as GridMap
var _minimum := Vector2i(2147483647, 2147483647)
var _maximum := Vector2i(-2147483647, -2147483647)

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if map == null:
		visible = false
		return
	mesh = PlaneMesh.new()
	for child: MeshInstance3D in [$MidMist, $HighWisps]:
		child.mesh = mesh
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for cell in map.get_used_cells():
		_include(cell)
	_resize()
	var placement := get_node_or_null("../TilePlacement")
	if placement != null:
		placement.cell_placed.connect(_on_cell_placed)

func _include(cell: Vector3i) -> bool:
	if cell.y != 0:
		return false
	var minimum := Vector2i(mini(_minimum.x, cell.x), mini(_minimum.y, cell.z))
	var maximum := Vector2i(maxi(_maximum.x, cell.x), maxi(_maximum.y, cell.z))
	if minimum == _minimum and maximum == _maximum:
		return false
	_minimum = minimum
	_maximum = maximum
	return true

func _on_cell_placed(cell: Vector3i) -> void:
	if _include(cell):
		_resize()

func _resize() -> void:
	visible = _minimum.x <= _maximum.x
	if not visible:
		return
	var first := map.map_to_local(Vector3i(_minimum.x, 0, _minimum.y))
	var last := map.map_to_local(Vector3i(_maximum.x, 0, _maximum.y))
	var center := (first + last) * 0.5
	center.y -= depth * map.cell_size.y
	(mesh as PlaneMesh).size = Vector2(last.x - first.x + map.cell_size.x, last.z - first.z + map.cell_size.z) + Vector2.ONE * padding * 2.0
	global_transform = map.global_transform * Transform3D(Basis.IDENTITY, center)
	$MidMist.position.y = map.cell_size.y
	$HighWisps.position.y = 2.0 * map.cell_size.y
