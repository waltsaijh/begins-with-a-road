extends Node
## Display only: a jagged lightning bolt between two points that re-strikes a few
## times (a new zig-zag every flicker) and then frees itself. Drawn through the
## shared attack-visual beams, so it costs no meshes or materials of its own.
const GLOW := Color(0.42, 0.66, 1.0, 0.7)
const CORE := Color(0.93, 0.97, 1.0, 1.0)
const FLICKER := 0.05
var from := Vector3.ZERO
var to := Vector3.ZERO
var lifetime := 0.36
var segments := 9
var jitter := 0.16
var host: Node              ## enemy_abilities: has beam(from, to, color, width, seconds)
var _age := 0.0
var _next := 0.0
var _rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	if _age >= lifetime or not is_instance_valid(host):
		queue_free()
		return
	if _age < _next: return
	_next = _age+FLICKER
	_strike(1.0-_age/lifetime)

func _strike(strength: float) -> void:
	var path := _zigzag(from, to, segments, jitter)
	for i in path.size()-1:
		var glow := GLOW
		glow.a *= strength
		host.beam(path[i], path[i+1], glow, 0.14, FLICKER*1.2)
		host.beam(path[i], path[i+1], CORE, 0.035, FLICKER*1.2)
	# A short fork off a random joint.
	var k := _rng.randi_range(2, path.size()-3)
	var side := (to-from).cross(Vector3.UP).normalized()
	var tip: Vector3 = path[k]+(side*_rng.randf_range(-1, 1)+Vector3.DOWN*0.4).normalized()*from.distance_to(to)*0.16
	var fork := _zigzag(path[k], tip, 3, jitter*0.6)
	for i in fork.size()-1: host.beam(fork[i], fork[i+1], CORE, 0.022, FLICKER*1.2)

func _zigzag(a: Vector3, b: Vector3, count: int, amount: float) -> PackedVector3Array:
	var points := PackedVector3Array([a])
	var axis := b-a
	var side := axis.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01: side = Vector3.RIGHT
	var up := side.cross(axis).normalized()
	for i in range(1, count):
		var t := float(i)/count
		var spread := amount*sin(t*PI)*axis.length()*0.35
		points.append(a+axis*t+side*_rng.randf_range(-spread, spread)+up*_rng.randf_range(-spread, spread)*0.6)
	points.append(b)
	return points
