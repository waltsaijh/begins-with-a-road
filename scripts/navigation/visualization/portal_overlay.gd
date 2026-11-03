extends Node3D
@export var debug_panel_scene: PackedScene = preload("res://scenes/navigation/route_debug_panel.tscn")
@export var vertex_marker_scene: PackedScene = preload("res://scenes/navigation/components/vertex_marker.tscn")
## F1 wave routes and current graph vertices, F2 threat. Refresh on source changes.
@onready var controller: Node = $"../PortalMap"
@onready var map: GridMap = $"../TileMap"
@onready var placement: Node3D = $"../TilePlacement"
var show_routes := false
var show_parameters := false
var routes_mesh: MeshInstance3D
var parameters_mesh: MeshInstance3D
var vertex_markers: Node3D
var _wave: Node
var _buttons: Array[Button] = []
var _origin: Button
var _legend: RichTextLabel
var _tooltip: Label
var _error: Label
var _panel: PanelContainer
var _dirty := [true, true, true]
var _queued := false
var _route_segments := {}
var _troop_names: Array[String] = []
var _troop_colors := {}
var _placement_error := ""

func _ready() -> void:
	routes_mesh = _mesh_node("WaveRoutes", false)
	parameters_mesh = _mesh_node("Threat", true)
	vertex_markers = Node3D.new()
	vertex_markers.name = "GraphVertices"
	add_child(vertex_markers)
	_create_ui()
	controller.graph_changed.connect(_invalidate_vertices)
	controller.plan_changed.connect(_invalidate)
	controller.tile_parameters.costs_changed.connect(func(_id: int): _invalidate())
	controller.tile_parameters.parameters_changed.connect(_invalidate_parameters)
	_wave = get_node_or_null("../EnemyWave")
	if _wave != null:
		_wave.routes_changed.connect(_on_routes_changed)
	var towers := get_node_or_null("../TowerMap")
	if towers != null:
		towers.placement_feedback.connect(func(message: String):
			_placement_error = message
			_update_ui())
	_update_visibility()
	_invalidate()

func _mesh_node(title: String, transparent: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = title
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = material
	add_child(instance)
	return instance

func _create_ui() -> void:
	var layer := debug_panel_scene.instantiate() as CanvasLayer
	add_child(layer)
	_panel = layer.get_node("Panel")
	_panel.hide()
	var row := layer.get_node("Panel/Column/Actions")
	for i in 2:
		var button := row.get_child(i) as Button
		button.pressed.connect(_toggle.bind(i))
		_buttons.append(button)
	_origin = row.get_node("Origin")
	_origin.pressed.connect(_next_origin)
	_legend = layer.get_node("Panel/Column/Legend")
	_tooltip = layer.get_node("Panel/Column/TileDetails")
	_error = layer.get_node("Panel/Column/Error")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: _toggle(0)
		KEY_F2: _toggle(1)
		KEY_R: _next_origin()
		_: return
	get_viewport().set_input_as_handled()

func _next_origin() -> void:
	var count: int = controller.start_nodes.size()
	if count > 1:
		controller.select_start(posmod(controller.active_start+1, count))
		_update_ui()

func _toggle(index: int) -> void:
	match index:
		0: show_routes = not show_routes
		1: show_parameters = not show_parameters
	_update_visibility()
	_queue_refresh()

func _update_visibility() -> void:
	routes_mesh.visible = show_routes
	vertex_markers.visible = show_routes
	parameters_mesh.visible = show_parameters
	set_process(show_parameters)
	if not show_parameters:
		_tooltip.visible = false
	_update_ui()

func _invalidate_vertices() -> void:
	_dirty[2] = true
	_invalidate()

func _invalidate() -> void:
	if _wave == null or not _wave.has_committed_routes(): _dirty[0] = true
	_dirty[1] = true
	_queue_refresh()

func _on_routes_changed() -> void:
	_dirty[0] = true
	_queue_refresh()

func _invalidate_parameters() -> void:
	_dirty[1] = true
	_queue_refresh()

func _queue_refresh() -> void:
	if not _queued:
		_queued = true
		_refresh.call_deferred()

func _refresh() -> void:
	_queued = false
	if show_routes and _dirty[0]:
		_draw_routes()
		_dirty[0] = false
	if show_routes and _dirty[2]:
		_draw_vertices()
		_dirty[2] = false
	if show_parameters and _dirty[1]:
		_draw_parameters()
		_dirty[1] = false
	_update_ui()

func _center(cell: Vector2i, height: float) -> Vector3:
	return to_local(map.to_global(map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*height))

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)

func _line(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var up := (global_basis.inverse()*map.global_basis.y).normalized()
	var side := (b-a).normalized().cross(up)*width
	_triangle(surface, a-side, a+side, b+side, color)
	_triangle(surface, a-side, b+side, b-side, color)

func _quad(surface: SurfaceTool, cell: Vector2i, height: float, half_size: float, color: Color) -> void:
	var at := _center(cell, height)
	var x := global_basis.inverse()*map.global_basis.x*half_size
	var z := global_basis.inverse()*map.global_basis.z*half_size
	_triangle(surface, at-x-z, at+x-z, at+x+z, color)
	_triangle(surface, at-x-z, at+x+z, at-x+z, color)

static func segment_key(a: Vector2i, b: Vector2i) -> Vector4i:
	return Vector4i(a.x, a.y, b.x, b.y) if a.x < b.x or (a.x == b.x and a.y < b.y) else Vector4i(b.x, b.y, a.x, a.y)

static func troop_color(troop_name: String) -> Color:
	var profile := TroopCatalog.find(troop_name)
	if profile != null: return profile.debug_color
	return Color.from_hsv(float(absi(troop_name.hash())%360)/360.0, 0.65, 1.0)

static func threat_color(threat: float) -> Color:
	var strength := threat/(1.0+threat) if is_finite(threat) else 1.0
	return Color(1.0, lerpf(0.65, 0.02, strength), lerpf(0.45, 0.01, strength), lerpf(0.2, 0.85, strength))

func _draw_vertices() -> void:
	for marker in vertex_markers.get_children(): marker.free()
	if not controller.graph.get("valid", false): return
	for node: Dictionary in controller.graph.nodes:
		var marker := vertex_marker_scene.instantiate() as Node3D
		marker.name = "V%d" % node.id
		marker.get_node("ID").text = marker.name
		vertex_markers.add_child(marker)
		marker.position = _center(node.cell, 0.18)

func _draw_routes() -> void:
	routes_mesh.mesh = null
	_route_segments.clear()
	_troop_names.clear()
	_troop_colors.clear()
	if _wave == null: return
	for route: Dictionary in _wave.routes_for_display():
		var troop_name: String = route.troop
		if not _route_segments.has(troop_name):
			_route_segments[troop_name] = {}
			_troop_names.append(troop_name)
			_troop_colors[troop_name] = route.get("color", troop_color(troop_name))
		var cells: PackedVector2Array = route.cells
		for i in cells.size()-1:
			_route_segments[troop_name][segment_key(Vector2i(cells[i]), Vector2i(cells[i+1]))] = true
	_troop_names.sort()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 0
	for index in _troop_names.size():
		var troop_name := _troop_names[index]
		var color: Color = _troop_colors[troop_name]
		# Translate each troop's entire path equally, keeping corners connected
		# and common segments visible side by side on both map axes.
		var lane := (float(index)-float(_troop_names.size()-1)*0.5)*0.1
		var offset := global_basis.inverse()*map.global_basis*Vector3(lane, 0.0, lane)
		for key: Vector4i in _route_segments[troop_name]:
			_line(surface, _center(Vector2i(key.x, key.y), 0.11)+offset, _center(Vector2i(key.z, key.w), 0.11)+offset, 0.03, color)
			segment_count += 1
	if segment_count: routes_mesh.mesh = surface.commit()

func _draw_parameters() -> void:
	parameters_mesh.mesh = null
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for tile: Resource in controller.tile_parameters.all_tiles():
		if tile.threat <= 0.0:
			continue
		_quad(surface, tile.cell, 0.045, 0.46, threat_color(tile.threat))
		count += 1
	if count:
		parameters_mesh.mesh = surface.commit()

func _process(_delta: float) -> void:
	var cell: Vector3i = placement.pick_cell(get_viewport().get_mouse_position())
	_inspect_cell(cell)

func _inspect_cell(cell: Vector3i) -> void:
	var tile: Resource = controller.tile_parameters.get_tile(Vector2i(cell.x, cell.z))
	_tooltip.visible = tile != null
	if tile != null:
		_tooltip.text = "地塊 (%d,%d)\nthreat %.2f　num_towers_around %d\nterrain_id %d　movement_multiplier %.2f\ndamage_per_second %.2f　cover %.2f" % [cell.x, cell.z, tile.threat, tile.num_towers_around, tile.terrain_id, tile.movement_multiplier, tile.damage_per_second, tile.cover]

func _update_ui() -> void:
	if _legend == null:
		return
	for i in 2:
		_buttons[i].set_pressed_no_signal([show_routes, show_parameters][i])
	_origin.visible = controller.start_nodes.size() > 1 and (_wave == null or _wave.definition == null)
	_origin.text = "起點 %d/%d (R)" % [controller.active_start+1, controller.start_nodes.size()]
	var hints := PackedStringArray()
	if show_routes:
		hints.append("深色圓點／V 編號＝目前路網 vertex")
		for troop_name in _troop_names:
			hints.append("[color=#%s]■ %s[/color]" % [_troop_colors[troop_name].to_html(false), troop_name.replace("[", "[lb]")])
		if not _troop_names.is_empty(): hints.append("共用路段以並排色線顯示")
	if show_parameters: hints.append("越紅＝threat 越高")
	_legend.text = "\n".join(hints)
	_legend.visible = not hints.is_empty()
	_error.text = "路網不可用：%s" % controller.graph.get("error", "") if not controller.computing and not controller.graph.is_empty() and not controller.graph.get("valid", false) else ""
	if _error.text.is_empty():
		_error.text = _placement_error
	_error.visible = not _error.text.is_empty()
	_panel.visible = show_routes or show_parameters
