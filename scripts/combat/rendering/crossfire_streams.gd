extends MultiMeshInstance3D
## Cosmetic tracers from every spinning crossfire, in one shared draw call.
## Nothing is stored per bullet: its age alone gives the barrel's angle when it
## fired and how far it has flown, so a frame only fills one packed buffer.
const BodyVisual = preload("res://scripts/towers/body_visual.gd")
const MAX_BULLETS := 512
const FLOATS_PER_BULLET := 20
const SPEED := 8.25
const RATE := 4.0
const LENGTH := 0.18
const WIDTH := 0.034
const COLOR := Color("cfd6cf")
var sources: Array[DefenseTower] = []
var tile := 1.0
var _time := 0.0
var _buffer := PackedFloat32Array()

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3.ONE*-4096.0,Vector3.ONE*8192.0)
	var holder := Node3D.new()
	var bullet := BodyVisual.part(holder,BoxMesh.new(),COLOR,Vector3.ZERO)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# Same layout as the enemy batches, whose shader variant is already warmed.
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = bullet.mesh
	multimesh.instance_count = MAX_BULLETS
	multimesh.visible_instance_count = 0
	holder.free()
	_buffer.resize(MAX_BULLETS*FLOATS_PER_BULLET)
	for bullet_index in MAX_BULLETS:
		for channel in 4: _buffer[bullet_index*FLOATS_PER_BULLET+12+channel] = 1.0
	set_process(false)

func set_sources(towers: Array[DefenseTower], tile_size: float) -> void:
	sources = towers
	tile = tile_size
	if sources.is_empty(): multimesh.visible_instance_count = 0
	set_process(not sources.is_empty())

func _process(delta: float) -> void:
	_time += maxf(0.0,delta)
	var count := 0
	for tower in sources:
		if not is_instance_valid(tower) or tower.is_disabled(): continue
		var visual: Node3D = tower._visual
		if visual.has_method("stream_ready") and visual.stream_ready():
			count = _write(tower,visual,count)
	multimesh.visible_instance_count = count
	if count > 0: multimesh.buffer = _buffer

func _write(tower: DefenseTower, visual: Node3D, count: int) -> int:
	var rotor: Node3D = visual.rotor()
	var origin := rotor.global_position
	var basis := rotor.global_basis
	var scale_factor := basis.x.length()
	var spin: float = visual.spin_speed()
	var life := tower.attack_radius*tower.range_multiplier*tile/SPEED
	var barrels: PackedVector3Array = visual.stream_barrels()
	var period := 1.0/RATE
	for index in barrels.size():
		var barrel := barrels[index]
		var flat := Vector3(barrel.x,0.0,barrel.z).normalized()
		# Barrels take turns against the spin. Firing together, each volley lands
		# just behind the last one and the stream seems to turn the wrong way.
		var turn := float((barrels.size()-index)%barrels.size())/barrels.size()
		var first_age := fposmod(_time-turn*period,period)
		for slot in ceili(life*RATE):
			var age := first_age+slot*period
			var fade := 1.0-age/life
			if fade <= 0.0: break
			if count >= MAX_BULLETS: return count
			# The rotor has turned since this shot left its barrel.
			var fired := basis*Basis(Vector3.UP,-spin*age)
			var at := origin+fired*(barrel+flat*SPEED*age/scale_factor)
			var along := (fired*flat).normalized()
			var side := along.cross(Vector3.UP)
			var x := along*LENGTH
			var y := Vector3.UP*WIDTH*fade
			var z := side*WIDTH*fade
			var i := count*FLOATS_PER_BULLET
			_buffer[i] = x.x; _buffer[i+1] = y.x; _buffer[i+2] = z.x; _buffer[i+3] = at.x
			_buffer[i+4] = x.y; _buffer[i+5] = y.y; _buffer[i+6] = z.y; _buffer[i+7] = at.y
			_buffer[i+8] = x.z; _buffer[i+9] = y.z; _buffer[i+10] = z.z; _buffer[i+11] = at.z
			count += 1
	return count
