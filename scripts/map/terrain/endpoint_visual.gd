extends Node3D
## Art Slice G endpoint art (castle goal / enemy camp). Turns its front (+Y in Blender,
## -Z here) toward the road leaving the endpoint cell, and at dusk / night lights a
## flame and a warm light at every "...Lamp" node. Works both inside a terrain
## GridMap (map previews) and on a LevelSession (marker beside "TileMap").
const LAMP_COLOR := Color(1.0, 0.62, 0.3)
const STEPS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
static var _flame: SphereMesh
static var _halo: SphereMesh

func _ready() -> void:
	face_road.call_deferred()
	if TimeOfDayPreset.lights_on and not Engine.is_editor_hint(): _light.call_deferred()

static func road_direction(map: GridMap, cell: Vector3i) -> Vector3i:
	for step: Vector3i in STEPS:
		if map.get_cell_item(cell+step) > 0: return step
	return Vector3i.ZERO

func face_road() -> void:
	var marker := get_parent() as Node3D
	if marker == null or not is_inside_tree(): return
	var map: GridMap = marker.grid_map() if marker.has_method("grid_map") else null
	if map == null: map = marker.get_parent().get_node_or_null("TileMap") as GridMap
	if map == null: return
	var cell := map.local_to_map(map.to_local(marker.global_position)); cell.y = 0
	var d := road_direction(map, cell)
	if d == Vector3i.ZERO: return
	var world := (map.global_transform.basis*Vector3(d)).normalized()
	global_rotation.y = atan2(-world.x, -world.z)

func _light() -> void:
	if not is_inside_tree(): return
	if _flame == null:
		_flame = SphereMesh.new(); _flame.radius = .045; _flame.height = .1; _flame.radial_segments = 6; _flame.rings = 3
		var fire := StandardMaterial3D.new(); fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fire.albedo_color = Color(1.0, 0.66, 0.25); _flame.material = fire
		_halo = SphereMesh.new(); _halo.radius = .12; _halo.height = .24; _halo.radial_segments = 8; _halo.rings = 4
		var glow := StandardMaterial3D.new(); glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_color = Color(1.0, 0.5, 0.15, 0.3); _halo.material = glow
	for node in find_children("*", "Node3D", true, false):
		if not String(node.name).ends_with("Lamp"): continue
		for mesh in [_flame, _halo]:
			var part := MeshInstance3D.new(); part.mesh = mesh
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(part)
		var light := OmniLight3D.new(); light.light_color = LAMP_COLOR
		light.light_energy = 1.1; light.omni_range = 1.2; light.position = Vector3.UP*.05
		node.add_child(light)
		var flicker := light.create_tween().set_loops()
		flicker.tween_property(light, "light_energy", 0.85, .2+randf()*.1).set_trans(Tween.TRANS_SINE)
		flicker.tween_property(light, "light_energy", 1.25, .26+randf()*.1).set_trans(Tween.TRANS_SINE)
