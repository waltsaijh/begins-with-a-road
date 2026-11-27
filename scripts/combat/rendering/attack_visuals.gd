extends Node3D
## Trails share one mesh; pooled scene-authored bursts handle AOE impacts.
var projectiles: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var impacts: Array[Node3D]:
	get: return $ImpactEffects.active
@onready var _instance: MeshInstance3D = $Geometry
var _visible_last_frame := false
var restored_bursts: Node3D
var streams: MultiMeshInstance3D
var _shot_players: Array[AudioStreamPlayer] = []
var _last_shot := {}

func _ready() -> void:
	process_priority = 100
	_instance.global_transform = Transform3D.IDENTITY
	restored_bursts = preload("res://scripts/combat/rendering/restored_bursts.gd").new()
	add_child(restored_bursts)
	streams = preload("res://scripts/combat/rendering/crossfire_streams.gd").new()
	add_child(streams)
	add_child(preload("res://scripts/combat/rendering/hit_sparks.gd").new())
	# Prototype's shared six-voice / 25 ms-per-kind budget, real-time cosmetic only.
	for i in 6:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"Combat"
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
		if shot.get("mortar",false):
			_mortar_shell(mesh, shot, fraction)
			continue
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

const SHELL_IRON := Color("33383d")
const SHELL_SHINE := Color("6b737a")
const SHELL_BAND := Color("b08a4a")
const FUSE_HOT := Color("ffe27a")
const FUSE_GLOW := Color(1.0, 0.55, 0.18, 0.75)
const SHELL_SMOKE := Color(0.45, 0.43, 0.4, 0.7)
const MARKER := Color(0.92, 0.32, 0.18)

static func _arc(shot: Dictionary, fraction: float) -> Vector3:
	return shot.start.lerp(shot.end, fraction)+Vector3.UP*4.0*fraction*(1.0-fraction)*shot.arc

## A round iron shell with a brass band and a sputtering fuse, a fading smoke
## trail behind it, and a landing marker that tightens on the target as it falls.
func _mortar_shell(mesh: ImmediateMesh, shot: Dictionary, fraction: float) -> void:
	var size: float = shot.visual_size*1.35
	var position := _arc(shot, fraction)
	var ahead := _arc(shot, minf(1.0, fraction+0.02))-position
	var spin: float = shot.age*9.0
	# Ball: an 8-sided bipyramid with a middle band (reads round at game zoom).
	var ring: Array[Vector3] = []
	for i in 8:
		var a := spin+i*TAU/8.0
		ring.append(Vector3(cos(a), 0, sin(a))*size)
	var top := position+Vector3.UP*size
	var bottom := position-Vector3.UP*size
	var band := Vector3.UP*size*0.22
	for i in 8:
		var a := ring[i]
		var b := ring[(i+1)%8]
		var shade := SHELL_SHINE if i < 3 else SHELL_IRON
		_triangle(mesh, top, position+band+b*0.86, position+band+a*0.86, shade)
		_triangle(mesh, bottom, position-band+a*0.86, position-band+b*0.86, SHELL_IRON.darkened(0.25))
		_triangle(mesh, position+band+a*0.86, position+band+b*0.86, position-band+b*0.86, SHELL_BAND if i % 2 == 0 else SHELL_BAND.darkened(0.2))
		_triangle(mesh, position+band+a*0.86, position-band+b*0.86, position-band+a*0.86, SHELL_BAND if i % 2 == 0 else SHELL_BAND.darkened(0.2))
	# Fuse: a flickering spark on the trailing side of the shell.
	var back := -ahead.normalized() if ahead.length_squared() > 0.000001 else Vector3.UP
	var fuse := position+(back*0.7+Vector3.UP*0.7).normalized()*size*1.15
	var flicker := 0.75+0.25*sin(shot.age*47.0)
	_diamond(mesh, fuse, size*0.75*flicker, FUSE_GLOW)
	_diamond(mesh, fuse, size*0.38*flicker, FUSE_HOT)
	# Smoke trail: puffs at earlier points on the arc, older ones larger and fainter.
	for k in range(1, 7):
		var f := fraction-k*0.035
		if f <= 0.0: break
		var puff := SHELL_SMOKE
		puff.a *= 1.0-k/7.0
		_diamond(mesh, _arc(shot, f)+back*size*0.6, size*(0.45+k*0.12), puff)
	# Landing marker: a ring on the ground that closes in and darkens.
	var radius: float = shot.get("ground_radius", 0.0)
	if radius > 0.0:
		var ground: Vector3 = shot.end+Vector3.UP*0.12   # just above the road top
		var marker := MARKER if not shot.get("special", false) else Color("f18655")
		marker.a = 0.18+0.5*fraction*fraction
		_ground_ring(mesh, ground, radius*(1.25-0.25*fraction), radius*0.06+0.01, marker)
		var fill := marker
		fill.a *= 0.22
		_ground_disc(mesh, ground, radius*fraction, fill)

func _diamond(mesh: ImmediateMesh, at: Vector3, size: float, color: Color) -> void:
	var x := Vector3.RIGHT*size
	var z := Vector3.BACK*size
	var y := Vector3.UP*size
	for edge: Array in [[x, z], [z, -x], [-x, -z], [-z, x]]:
		_triangle(mesh, at+y, at+edge[0], at+edge[1], color)
		_triangle(mesh, at-y, at+edge[1], at+edge[0], color)

func _ground_ring(mesh: ImmediateMesh, at: Vector3, radius: float, width: float, color: Color) -> void:
	for i in 24:
		var a := i*TAU/24.0
		var b := (i+1)*TAU/24.0
		var ia := at+Vector3(cos(a), 0, sin(a))*(radius-width)
		var oa := at+Vector3(cos(a), 0, sin(a))*radius
		var ib := at+Vector3(cos(b), 0, sin(b))*(radius-width)
		var ob := at+Vector3(cos(b), 0, sin(b))*radius
		_triangle(mesh, ia, oa, ob, color)
		_triangle(mesh, ia, ob, ib, color)

func _ground_disc(mesh: ImmediateMesh, at: Vector3, radius: float, color: Color) -> void:
	if radius <= 0.001: return
	for i in 16:
		var a := i*TAU/16.0
		var b := (i+1)*TAU/16.0
		_triangle(mesh, at, at+Vector3(cos(a), 0, sin(a))*radius, at+Vector3(cos(b), 0, sin(b))*radius, color)

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
