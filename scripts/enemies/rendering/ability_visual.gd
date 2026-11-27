extends Node3D
## A restrained reusable ring, attached to the caster; no per-healed-unit spam.
## Also draws the ability's area on the ground: a green ring that sweeps out to
## the heal radius on each pulse, and an amber ring at the sabotage radius that
## fills in during the wind-up.
const HEAL_COLOR := Color("72bd9c")
const CAST_COLOR := Color("e0ac63")
const AREA_LIFT := 0.04
var ring: MeshInstance3D
var material: StandardMaterial3D
var pulse := 0.0
var is_casting := false
var area: MeshInstance3D
var area_fill: MeshInstance3D
var _area_material: StandardMaterial3D
var _fill_material: StandardMaterial3D
var _area_radius := 1.0

func _ready() -> void:
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.35
	mesh.outer_radius = 0.39
	mesh.rings = 16
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.position.y = 0.06
	material = SolidMaterials.transparent()
	ring.material_override = material
	add_child(ring)
	ring.hide()
	# Ground area: unit-radius ring + faint disc, top level so the caster's model
	# scale (rats, boss) never changes the drawn radius.
	var outline := TorusMesh.new()
	outline.inner_radius = 0.965
	outline.outer_radius = 1.0
	outline.rings = 48
	outline.ring_segments = 4
	area = MeshInstance3D.new()
	area.mesh = outline
	area.top_level = true
	area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_area_material = SolidMaterials.transparent()
	_area_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	area.material_override = _area_material
	add_child(area)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.004
	disc.radial_segments = 40
	disc.rings = 1
	area_fill = MeshInstance3D.new()
	area_fill.mesh = disc
	area_fill.top_level = true
	area_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill_material = SolidMaterials.transparent()
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	area_fill.material_override = _fill_material
	add_child(area_fill)
	_hide_area()

func heal_pulse(radius := 0.0) -> void:
	pulse = 0.7
	material.albedo_color = HEAL_COLOR
	ring.show()
	if radius > 0.0: _area_radius = radius

func casting(progress: float, radius := 0.0) -> void:
	is_casting = true
	ring.show()
	ring.scale = Vector3.ONE*(1.0+progress*0.5)
	material.albedo_color = CAST_COLOR
	if radius > 0.0:
		_area_radius = radius
		_show_area(CAST_COLOR, 1.0, 0.55+0.35*progress, 0.06+0.1*progress)

func stop_cast() -> void:
	is_casting = false
	ring.hide()
	_hide_area()

func _show_area(color: Color, scale_fraction: float, ring_alpha: float, fill_alpha: float) -> void:
	var at := global_position
	var basis := Basis.from_scale(Vector3(_area_radius*scale_fraction, 1.0, _area_radius*scale_fraction))
	area.global_transform = Transform3D(basis, Vector3(at.x, at.y+AREA_LIFT, at.z))
	area_fill.global_transform = Transform3D(basis, Vector3(at.x, at.y+AREA_LIFT*0.5, at.z))
	_area_material.albedo_color = Color(color, ring_alpha)
	_fill_material.albedo_color = Color(color, fill_alpha)
	area.show()
	area_fill.show()

func _hide_area() -> void:
	area.hide()
	area_fill.hide()

func _process(delta: float) -> void:
	if is_casting:
		if area.visible: _show_area(CAST_COLOR, 1.0, _area_material.albedo_color.a, _fill_material.albedo_color.a)
		return
	pulse = maxf(0,pulse-delta)
	if pulse <= 0:
		ring.hide()
		_hide_area()
		return
	var t := 1.0-pulse/0.7
	ring.scale = Vector3.ONE*(1.0+t*2.0)
	material.albedo_color.a = pulse/0.7
	# The heal area sweeps out to its true radius, then fades.
	_show_area(HEAL_COLOR, 0.35+0.65*ease(minf(1.0, t*1.6), 0.4), 0.85*(1.0-t*t), 0.14*(1.0-t))
