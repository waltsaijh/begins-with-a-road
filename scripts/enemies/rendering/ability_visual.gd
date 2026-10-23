extends Node3D
## A restrained reusable ring, attached to the caster; no per-healed-unit spam.
var ring: MeshInstance3D
var material: StandardMaterial3D
var pulse := 0.0
var is_casting := false

func _ready() -> void:
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.35
	mesh.outer_radius = 0.39
	mesh.rings = 16
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.position.y = 0.06
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	add_child(ring)
	ring.hide()

func heal_pulse() -> void:
	pulse = 0.7
	material.albedo_color = Color("72bd9c")
	ring.show()

func casting(progress: float) -> void:
	is_casting = true
	ring.show()
	ring.scale = Vector3.ONE*(1.0+progress*0.5)
	material.albedo_color = Color("e0ac63")

func stop_cast() -> void:
	is_casting = false
	ring.hide()

func _process(delta: float) -> void:
	if is_casting: return
	pulse = maxf(0,pulse-delta)
	if pulse <= 0:
		ring.hide()
		return
	ring.scale = Vector3.ONE*(1.0+(1.0-pulse/0.7)*2.0)
	material.albedo_color.a = pulse/0.7
