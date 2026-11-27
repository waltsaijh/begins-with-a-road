extends Node3D
## Night road torches along the roads (only built while the level's time of day has
## tower_lights, see TimeOfDayPreset). Display-only: one post on a curb every few
## road cells, alternating sides, each with a warm, short-range light. Rebuilt when
## the road network changes (PortalMap.graph_changed).
const ROAD_ITEMS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const SPACING := 3            ## one lamp per this many road cells (by x+z)
const CURB := 0.42            ## distance from the cell centre to the post
const CURB_HEIGHT := 0.065    ## road_surface.gd BANK_HEIGHT
const LAMP_COLOR := Color(1.0, 0.6, 0.28)   ## road torches: warm fire
var map: GridMap
static var _meshes := {}

func _ready() -> void:
	name = "RoadLamps"
	var level := get_parent()
	var towers := level.get_node_or_null("TowerMap")
	if towers != null: map = towers.map
	var portal := level.get_node_or_null("PortalMap")
	if portal != null: portal.graph_changed.connect(_queue_build)
	_queue_build()

func _queue_build() -> void:
	if not is_queued_for_deletion(): build.call_deferred()

func build() -> void:
	for child in get_children(): child.free()
	if map == null or not TimeOfDayPreset.lights_on: return
	var cells := {}
	for cell: Vector3i in map.get_used_cells():
		if map.get_cell_item(cell) in ROAD_ITEMS: cells[Vector2i(cell.x, cell.z)] = true
	for c: Vector2i in cells:
		if posmod(c.x+c.y, SPACING) != 0: continue
		# A curb side: a neighbour that is not road. Alternate between the two
		# candidates so a straight road gets lamps on both sides in turn.
		var sides: Array[Vector2i] = []
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if not cells.has(c+d): sides.append(d)
		if sides.is_empty(): continue
		var side: Vector2i = sides[posmod(c.x+c.y, SPACING*2)/SPACING % sides.size()]
		var at := map.map_to_local(Vector3i(c.x, 0, c.y))
		var base := Vector3(at.x+side.x*CURB, CURB_HEIGHT, at.z+side.y*CURB)
		_lamp(base, Vector3(-side.x, 0, -side.y))
	set_process(false)

func _lamp(at: Vector3, _inward: Vector3) -> void:
	# A wooden torch post with an iron fire bowl and a live flame on top.
	var lamp := Node3D.new(); lamp.position = at
	add_child(lamp)
	lamp.add_child(_part("post", Vector3(0, .17, 0)))
	lamp.add_child(_part("band", Vector3(0, .30, 0)))
	var head := Vector3(0, .38, 0)
	lamp.add_child(_part("bowl", head-Vector3.UP*.025))
	lamp.add_child(_part("flame", head+Vector3.UP*.03))
	lamp.add_child(_part("tip", head+Vector3.UP*.085))
	lamp.add_child(_part("halo", head+Vector3.UP*.04))
	var light := OmniLight3D.new()
	light.light_color = LAMP_COLOR; light.light_energy = 1.15; light.omni_range = 1.1
	light.shadow_enabled = false; light.position = head+Vector3.UP*.06
	lamp.add_child(light)
	var flicker := light.create_tween().set_loops()
	flicker.tween_property(light, "light_energy", 0.9, .17+randf()*.08).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(light, "light_energy", 1.3, .21+randf()*.08).set_trans(Tween.TRANS_SINE)
	var dance := lamp.get_child(4).create_tween().set_loops()   # flame tip sways
	dance.tween_property(lamp.get_child(4), "scale", Vector3(0.85, 1.25, 0.85), .2+randf()*.1)
	dance.tween_property(lamp.get_child(4), "scale", Vector3(1.1, 0.85, 1.1), .24+randf()*.1)

static func _material(color: Color, glow := false, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	if glow: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.roughness = 1.0
	return m

func _part(kind: String, at: Vector3, along := Vector3.ZERO) -> MeshInstance3D:
	if not _meshes.has(kind):
		var mesh: PrimitiveMesh
		match kind:
			"post":
				mesh = CylinderMesh.new(); mesh.top_radius = .02; mesh.bottom_radius = .028; mesh.height = .34
				mesh.radial_segments = 6; mesh.material = _material(Color("5a3b28"))
			"band":
				mesh = CylinderMesh.new(); mesh.top_radius = .03; mesh.bottom_radius = .03; mesh.height = .025
				mesh.radial_segments = 6; mesh.material = _material(Color("2e3236"))
			"bowl":
				mesh = CylinderMesh.new(); mesh.top_radius = .06; mesh.bottom_radius = .03; mesh.height = .06
				mesh.radial_segments = 6; mesh.material = _material(Color("2e3236"))
			"flame":
				mesh = SphereMesh.new(); mesh.radius = .05; mesh.height = .1; mesh.radial_segments = 6; mesh.rings = 3
				mesh.material = _material(Color(1.0, 0.62, 0.2), true)
			"tip":
				mesh = CylinderMesh.new(); mesh.top_radius = .0; mesh.bottom_radius = .035; mesh.height = .09
				mesh.radial_segments = 5; mesh.material = _material(Color(1.0, 0.88, 0.45), true)
			"halo":
				mesh = SphereMesh.new(); mesh.radius = .12; mesh.height = .24; mesh.radial_segments = 8; mesh.rings = 4
				mesh.material = _material(Color(1.0, 0.5, 0.15), true, .3)
		_meshes[kind] = mesh
	var part := MeshInstance3D.new(); part.mesh = _meshes[kind]; part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if along != Vector3.ZERO: part.basis = Basis.looking_at(along, Vector3.UP)
	return part
