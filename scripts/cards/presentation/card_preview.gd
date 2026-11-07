extends Node3D
## Placement and attack tiles share the definition used by real combat/threat.
@export var valid_color := Color(0.35, 0.93, 0.75, 0.52)
@export var invalid_color := Color(1.0, 0.3, 0.22, 0.56)
@export var range_fill_color := Color(0.96, 0.68, 0.21, 0.18)
@export var range_border_color := Color(0.85, 0.53, 0.12, 0.5)
@onready var ground: MeshInstance3D = $Ground
@onready var attack_area: MeshInstance3D = $AttackArea
var range_cells: Array[Vector2i] = []
var ghost: Node3D
var _definition: Resource
var _ghost_stamp := ""
var _material: ShaderMaterial
var _flash_started := -1
var _preview_key := ""

func flash_invalid() -> void:
	_flash_started = Time.get_ticks_usec()
	_material.set_shader_parameter("rejection_flash", 1.0)
	set_process(true)

func _process(_delta: float) -> void:
	var age := (Time.get_ticks_usec()-_flash_started)/1000000.0
	var strength := 1.0-smoothstep(0.0, 0.4, age)
	_material.set_shader_parameter("rejection_flash", strength)
	if strength <= 0.0: set_process(false)
var hint_anchor := Vector3.ZERO
var upgrade_mode := false
var upgrade_label: Label3D
var relics: RunRelics
var geometry_cells: Variant = null
## Optional independent editor playground overlay; formal cards keep their style.
var detailed_geometry := false
var prospective_ports := {}
var footprint_body: Node3D
var displayed_ground: Array[Vector2i] = []

func _ready() -> void:
	_material = ground.material_override.duplicate()
	ground.material_override = _material
	set_process(false)
	upgrade_label = Label3D.new()
	upgrade_label.font = preload("res://assets/fonts/NotoSansTC-Light.ttf")
	upgrade_label.font_size = 40
	upgrade_label.pixel_size = 0.011
	upgrade_label.outline_size = 4
	upgrade_label.outline_modulate = Color("304b44")
	upgrade_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	upgrade_label.no_depth_test = true
	add_child(upgrade_label)
	upgrade_label.hide()

func show_upgrade(map: GridMap, tower: DefenseTower, error: String) -> void:
	if tower.placement_preset != null:
		show_at(map,BuildCard.from_parts(tower.definition,tower.placement_preset),Vector3i(tower.placement_origin.x,0,tower.placement_origin.y),tower.geometry_turns,error.is_empty())
	else:
		show_at(map, BuildCard.from_parts(tower.definition, tower.definition.first_tile_preset()), Vector3i(tower.grid_cell.x, 0, tower.grid_cell.y), tower.rotation_steps, error.is_empty())
	upgrade_mode = true
	if ghost != null: preload("res://scripts/towers/body_visual.gd").set_level(ghost,mini(tower.level+1,3))
	if ghost != null: hint_anchor.y = _top_height(ghost,hint_anchor.y)
	ground.mesh = null
	upgrade_label.text = "Lv.%d → Lv.%d" % [tower.level, tower.level+1] if error.is_empty() else error
	upgrade_label.modulate = Color("87e0b2") if error.is_empty() else Color("ff9b83")
	upgrade_label.global_position = hint_anchor+Vector3.UP*0.3
	upgrade_label.show()

func show_at(map: GridMap, card: BuildCard, cell: Vector3i, turns: int, valid: bool) -> void:
	upgrade_mode = false
	upgrade_label.hide()
	visible = true
	global_transform = map.global_transform
	var key := str([card,cell,turns,valid])
	if key != _preview_key:
		_preview_key = key
		_material.set_shader_parameter("rejection_flash", 0.0)
		set_process(false)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var footprint := card.tower_cells(Vector2i(cell.x,cell.z),turns)
	var towers := map.get_node_or_null("../TowerMap")
	displayed_ground = towers.card_ground(card,Vector2i(cell.x,cell.z),turns) if towers != null and card.traffic == null else card.ground_cells(Vector2i(cell.x,cell.z),turns)
	for pos in displayed_ground:
		var center := map.map_to_local(Vector3i(pos.x,0,pos.y))+Vector3.UP*0.05
		var existing := map.get_cell_item(Vector3i(pos.x,0,pos.y)) > 0
		var paint := Color(0.86,0.78,0.57,0.5)
		if pos in footprint: paint = Color(0.85,0.28,0.2,0.55) if existing else Color(0.13,0.53,0.61,0.65)
		elif existing: paint = Color(0.65,0.85,0.92,0.32)
		_range_quad(mesh,center,-0.44,-0.44,0.44,0.44,paint)
		var outline := valid_color if valid else invalid_color
		_range_quad(mesh,center,-0.46,-0.46,0.46,-0.43,outline)
		_range_quad(mesh,center,-0.46,0.43,0.46,0.46,outline)
		_range_quad(mesh,center,-0.46,-0.43,-0.43,0.43,outline)
		_range_quad(mesh,center,0.43,-0.43,0.46,0.43,outline)
	mesh.surface_end()
	ground.mesh = mesh
	var tower_at := card.tower_anchor(Vector2i(cell.x,cell.z),turns)
	var tower_cell := Vector3i(tower_at.x,0,tower_at.y)
	var body := TowerBodyGeometry.local_cells(card.tile_preset)
	_show_attack_area(map,card.visual_definition(),tower_cell,card.tower_facing(turns),body)
	var stamp := str([card.visual_definition().get_instance_id(),body])
	if _ghost_stamp != stamp:
		if ghost != null: ghost.free()
		_definition = card.visual_definition(); _ghost_stamp = stamp
		ghost = null
		if _definition != null and _definition.model != null:
			if _definition is TowerDefinition:
				ghost = preload("res://scripts/towers/body_visual.gd").create(_definition,body)
			else: ghost = _definition.model.instantiate()
			add_child(ghost)
			ghost.process_mode = Node.PROCESS_MODE_DISABLED
			_tint(ghost)
	if ghost != null:
		preload("res://scripts/towers/body_visual.gd").set_level(ghost,1)
		var basis := Basis(Vector3.UP,-card.tower_facing(turns)*PI/2)
		var offset := card.tile_preset.model_offset if card.tile_preset != null else Vector3.ZERO
		ghost.transform = Transform3D(basis,map.map_to_local(tower_cell)+Vector3.UP*TowerConstants.GROUND_OFFSET+basis*offset)
	hint_anchor = map.to_global(map.map_to_local(tower_cell))
	if ghost != null: hint_anchor.y = _top_height(ghost,hint_anchor.y)
	hint_anchor += Vector3.UP*0.12

func _show_attack_area(map: GridMap, definition: Resource, cell: Vector3i, turns: int, body: Array[Vector2i] = []) -> void:
	var anchor := Vector2i(cell.x,cell.z)
	if definition is TrafficStructureDefinition:
		range_cells.assign(definition.effect_at(anchor,turns).cells.keys())
	else:
		range_cells = relics.preview_cells(definition,anchor,turns,body) if relics != null else definition.effective_attack_cells(anchor,turns,1,false,-1,body)
		if geometry_cells != null: range_cells.assign(geometry_cells)
	var mesh := ImmediateMesh.new()
	if not range_cells.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		if definition is TowerDefinition and definition.attack_area == null and geometry_cells == null:
			var factor := 1.0
			if relics != null: factor = float(relics.effects_for(definition).get(&"support_attack",{}).get("range_multiplier",1.0))
			var origin := TowerBodyGeometry.origin(definition,body)
			var local := Basis(Vector3.UP,-turns*PI/2)*Vector3(origin.x,0,origin.y)
			var center := map.map_to_local(cell)+local+Vector3.UP*0.12
			_circle(mesh,center,definition.attack_radius*factor)
		else:
			# A single seamless coverage layer: only exposed edges get a contour.
			var covered := {}
			for at in range_cells: covered[at] = true
			for at in range_cells:
				var center := map.map_to_local(Vector3i(at.x,0,at.y))+Vector3.UP*0.12
				_range_quad(mesh,center,-0.5,-0.5,0.5,0.5,range_fill_color)
				var edge_center := center+Vector3.UP*0.001
				if not covered.has(at+Vector2i.UP): _range_quad(mesh,edge_center,-0.5,-0.5,0.5,-0.47,range_border_color)
				if not covered.has(at+Vector2i.DOWN): _range_quad(mesh,edge_center,-0.5,0.47,0.5,0.5,range_border_color)
				if not covered.has(at+Vector2i.LEFT): _range_quad(mesh,edge_center,-0.5,-0.5,-0.47,0.5,range_border_color)
				if not covered.has(at+Vector2i.RIGHT): _range_quad(mesh,edge_center,0.47,-0.5,0.5,0.5,range_border_color)
		mesh.surface_end()
	attack_area.mesh = mesh

func _circle(mesh: ImmediateMesh, center: Vector3, radius: float) -> void:
	for i in 96:
		var a := Vector3(cos(TAU*i/96),0,sin(TAU*i/96))
		var b := Vector3(cos(TAU*(i+1)/96),0,sin(TAU*(i+1)/96))
		mesh.surface_set_color(range_fill_color)
		for point in [Vector3.ZERO,a*radius,b*radius]: mesh.surface_add_vertex(center+point)
		mesh.surface_set_color(range_border_color)
		for point in [a*radius,a*(radius-0.035),b*radius,b*radius,a*(radius-0.035),b*(radius-0.035)]: mesh.surface_add_vertex(center+point+Vector3.UP*0.001)

func _range_quad(mesh: ImmediateMesh, center: Vector3, left: float, top: float, right: float, bottom: float, color: Color) -> void:
	mesh.surface_set_color(color)
	for point in [Vector3(left, 0, top), Vector3(right, 0, top), Vector3(right, 0, bottom), Vector3(left, 0, top), Vector3(right, 0, bottom), Vector3(left, 0, bottom)]:
		mesh.surface_add_vertex(center+point)

func _top_height(node: Node, height: float) -> float:
	if node is Node3D and not node.visible: return height
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.get_aabb()
		for i in 8:
			height = maxf(height, (node.global_transform*bounds.get_endpoint(i)).y)
	for child in node.get_children():
		height = _top_height(child, height)
	return height

func _tint(node: Node) -> void:
	# Authored palette stays intact; the existing ground/occupancy colors carry validity.
	if node.has_method("set_preview"):
		node.set_preview()
		return
	if node is MeshInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_tint(child)
