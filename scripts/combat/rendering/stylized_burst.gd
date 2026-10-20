extends Node3D
## Compact ring and six low-poly fragments, adapted from card-tower-defense effects_3d.
signal finished(burst: Node3D)
@export_range(0.05, 2.0, 0.01) var duration := 0.3
@export_range(0.01, 4.0, 0.01) var radius := 0.35
## Applied only when an attack supplies its splash radius, in tile units.
@export_range(0.05, 2.0, 0.05) var radius_scale := 1.0
@export_range(0.0, 1.0, 0.01) var start_radius_fraction := 0.2
@export_range(0.0, 1.0, 0.01) var hop_height := 0.12
var age := 0.0
var playing := false
var _reach := 0.35
var _directions: Array[Vector3] = []
var _scales: Array[Vector3] = []
var _materials: Array[StandardMaterial3D] = []
var _colors: Array[Color] = []
var _core_scale := Vector3.ONE
var _show_core := false

func _ready() -> void:
	_reach = radius
	_core_scale = $Core.scale
	_show_core = $Core.visible
	for shard: Node3D in $Shards.get_children():
		_directions.append(shard.position.normalized())
		_scales.append(shard.scale)
	var meshes: Array[Node] = [$Ring, $Core]
	meshes.append_array($Shards.get_children())
	for mesh: MeshInstance3D in meshes:
		var material := mesh.material_override as StandardMaterial3D
		if material == null or _materials.has(material): continue
		_materials.append(material)
		_colors.append(material.albedo_color)
	hide()

func play(splash_radius := -1.0) -> void:
	age = 0.0
	_reach = splash_radius*radius_scale if splash_radius >= 0.0 else radius
	playing = true
	show()
	_render_phase(0.0)

func advance(delta: float) -> void:
	if not playing: return
	age += maxf(0.0, delta)
	var phase := clampf(age/maxf(0.01, duration), 0.0, 1.0)
	_render_phase(phase)
	if phase >= 1.0:
		playing = false
		hide()
		finished.emit(self)

func _render_phase(phase: float) -> void:
	var reach := lerpf(_reach*start_radius_fraction, _reach, phase)
	$Ring.scale = Vector3(maxf(0.001, reach), 1.0, maxf(0.001, reach))
	$Core.visible = _show_core
	$Core.scale = _core_scale*maxf(0.001, 1.0-phase)
	for i in $Shards.get_child_count():
		var shard: Node3D = $Shards.get_child(i)
		shard.position = _directions[i]*reach+Vector3.UP*sin(PI*phase)*hop_height
		shard.scale = _scales[i]*maxf(0.001, 1.0-phase)
	for i in _materials.size():
		var color := _colors[i]
		color.a *= 1.0-phase
		_materials[i].albedo_color = color
