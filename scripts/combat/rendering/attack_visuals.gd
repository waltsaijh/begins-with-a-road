extends Node3D
## Trails share one mesh; pooled scene-authored bursts handle AOE impacts.
var projectiles: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var impacts: Array[Node3D]:
	get: return $ImpactEffects.active
@onready var _instance: MeshInstance3D = $Geometry
var _visible_last_frame := false
var restored_bursts: Node3D
var _shot_players: Array[AudioStreamPlayer] = []
var _last_shot := {}

func _ready() -> void:
	process_priority = 100
	_instance.global_transform = Transform3D.IDENTITY
	restored_bursts = preload("res://scripts/combat/rendering/restored_bursts.gd").new()
	add_child(restored_bursts)
	# Prototype's shared six-voice / 25 ms-per-kind budget, real-time cosmetic only.
	for i in 6:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -20
		add_child(voice)
		_shot_players.append(voice)

func play_restored_shot(kind: int,stream: AudioStream) -> void:
	if stream == null: return
	var now := Time.get_ticks_usec()
	if now-int(_last_shot.get(kind,-25000)) < 25000: return
	for voice in _shot_players:
		if not voice.playing:
			voice.stream = stream
			voice.play()
			_last_shot[kind] = now
			return

func add_beam(start: Vector3, end: Vector3, color: Color, width: float, duration: float) -> void:
	beams.append({"start": start, "end": end, "color": color, "width": width, "duration": duration, "age": 0.0})

func add_impact(center: Vector3, radius: float, _color: Color, map: GridMap) -> void:
	var basis := map.global_basis*Basis.from_scale(map.cell_size)
	$ImpactEffects.emit_at(center, basis, radius)

func _process(delta: float) -> void:
	$ImpactEffects.advance(delta)
	for entries: Array in [beams]:
		for i in range(entries.size()-1, -1, -1):
			entries[i].age += maxf(0.0, delta)
			if entries[i].age >= entries[i].duration:
				entries.remove_at(i)
	if beams.is_empty() and projectiles.is_empty():
		if _visible_last_frame:
			_instance.mesh = null
			_visible_last_frame = false
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for beam in beams:
		var color: Color = beam.color
		color.a *= 1.0-beam.age/beam.duration
		_ribbon(mesh, beam.start, beam.end, beam.width, color)
	for shot in projectiles:
		if shot.get("arrow", false):
			_arrow(mesh, shot)
			continue
		var fraction: float = clampf(shot.age/shot.duration, 0.0, 1.0)
		var position: Vector3 = shot.start.lerp(shot.end, fraction)+Vector3.UP*sin(fraction*PI)*shot.arc
		var x: Vector3 = Vector3.RIGHT*shot.visual_size
		var z: Vector3 = Vector3.BACK*shot.visual_size
		var y: Vector3 = Vector3.UP*shot.visual_size
		for edge: Array in [[x, z], [z, -x], [-x, -z], [-z, x]]:
			_triangle(mesh, position+y, position+edge[0], position+edge[1], shot.color)
			_triangle(mesh, position-y, position+edge[1], position+edge[0], shot.color)
	mesh.surface_end()
	_instance.mesh = mesh
	_visible_last_frame = true

func _arrow(mesh: ImmediateMesh, shot: Dictionary) -> void:
	var forward: Vector3 = shot.direction
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	var up := side.cross(forward).normalized()
	var tip: Vector3 = shot.position
	var length: float = shot.length
	var tail := tip-forward*length
	var neck := tip-forward*minf(length*0.4, shot.width*4.0)
	# Crossed shaft/head planes remain visible from any camera angle.
	for axis: Vector3 in [side, up]:
		var half_width: Vector3 = axis*shot.width*0.5
		_triangle(mesh, tail-half_width, tail+half_width, neck+half_width, shot.color)
		_triangle(mesh, tail-half_width, neck+half_width, neck-half_width, shot.color)
		_triangle(mesh, tip, neck+axis*shot.width*2.0, neck-axis*shot.width*2.0, shot.color.lightened(0.25))
	var trail: float = minf(shot.trail_length, maxf(0.0, shot.travelled-length))
	if trail <= 0.000001:
		return
	var end := tail-forward*trail
	var half_width: Vector3 = side*shot.trail_width*0.5
	var color: Color = shot.color
	color.a *= 0.4
	# Taper both width and alpha to zero, with no particles or per-arrow nodes.
	for point: Vector3 in [tail-half_width, tail+half_width, end]:
		var tint := color
		if point == end:
			tint.a = 0.0
		mesh.surface_set_color(tint)
		mesh.surface_add_vertex(point)

func _ribbon(mesh: ImmediateMesh, start: Vector3, end: Vector3, width: float, color: Color) -> void:
	var side := (end-start).cross(Vector3.UP).normalized()
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side *= width/2.0
	_triangle(mesh, start-side, start+side, end+side, color)
	_triangle(mesh, start-side, end+side, end-side, color)

func _triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
