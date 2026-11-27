extends Node3D
## Display-only dynamite bundle lobbed by a sabotage cast. The ability drives the
## flight with set_flight(t) from simulation time, so it lands exactly when the
## disable applies (and freezes with pause / scales with game speed). explode()
## plays a short burst and frees itself; fizzle() removes it on a cancelled cast.
const ARC_HEIGHT := 1.1
const BURST_SECONDS := 0.55
const SMOKE_SECONDS := 1.3
var from := Vector3.ZERO
var to := Vector3.ZERO
## The bomber. A bomb still in the air when its thrower dies or leaves the road, or
## that stops receiving flight updates (cast interrupted without stop()), fizzles.
var caster: WeakRef
const ORPHAN_SECONDS := 1.0
var _idle := 0.0
var _spark: MeshInstance3D
var _body: Node3D
var _flash: MeshInstance3D
var _smoke: MeshInstance3D
var _burst := -1.0
var _core: MeshInstance3D
var _fire2: MeshInstance3D
var _ring: MeshInstance3D
var _debris: Array = []
var _puffs: Array = []
var _fires: Array = []

func _ready() -> void:
	_body = Node3D.new()
	_body.scale = Vector3.ONE*1.6
	add_child(_body)
	var red := SolidMaterials.opaque(Color("b33a2e"))
	var band := SolidMaterials.opaque(Color("2b2522"))
	for i in 3:
		var stick := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035; cyl.bottom_radius = 0.035; cyl.height = 0.2; cyl.radial_segments = 8
		stick.mesh = cyl; stick.material_override = red
		stick.position = Vector3((i-1)*0.06, 0, 0.02 if i == 1 else -0.015)
		_body.add_child(stick)
	var tie := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.1; ring.bottom_radius = 0.1; ring.height = 0.035; ring.radial_segments = 10
	tie.mesh = ring; tie.material_override = band; tie.scale = Vector3(1.0, 1.0, 0.6)
	_body.add_child(tie)
	_spark = MeshInstance3D.new()
	var sphere := SphereMesh.new(); sphere.radius = 0.035; sphere.height = 0.07
	_spark.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffd25a")
	_spark.material_override = glow
	_spark.position = Vector3(0, 0.13, 0)
	_body.add_child(_spark)
	_flash = _burst_mesh(Color(1.0, 0.5, 0.1, 1.0), 0.3, 2)
	_smoke = _burst_mesh(Color(0.35, 0.33, 0.32, 0.75), 0.36)
	_flash.hide(); _smoke.hide()

func _burst_mesh(color: Color, radius: float, priority := 0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new(); sphere.radius = radius; sphere.height = radius*2.0
	sphere.radial_segments = 12; sphere.rings = 6
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true   # the burst reads over the tower it hits
	material.render_priority = priority   # fire draws over its own smoke
	mesh.material_override = material
	add_child(mesh)
	return mesh

## t: 0 = in the bomber's hands, 1 = landing on the tower.
func set_flight(t: float) -> void:
	_idle = 0.0
	t = clampf(t, 0.0, 1.0)
	var flat := from.lerp(to, t)
	position = flat+Vector3.UP*ARC_HEIGHT*4.0*t*(1.0-t)
	_body.rotation = Vector3(t*TAU*1.5, 0, t*TAU*0.5)
	_spark.scale = Vector3.ONE*(0.8+0.4*absf(sin(t*40.0)))

func explode() -> void:
	position = to
	_body.hide()
	_flash.show(); _smoke.show()
	_burst = 0.0
	var fire := Color(1.0, 0.55, 0.15, 0.95)
	_core = _burst_mesh(Color(1.0, 0.97, 0.75, 1.0), 0.2, 3)
	_fire2 = _burst_mesh(Color(1.0, 0.25, 0.05, 0.0), 0.01, 1)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new(); torus.inner_radius = 0.42; torus.outer_radius = 0.5; torus.rings = 24; torus.ring_segments = 4
	_ring.mesh = torus
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.no_depth_test = true
	ring_material.albedo_color = Color(1.0, 0.8, 0.45, 0.8)
	_ring.material_override = ring_material
	_ring.scale = Vector3(0.3, 0.2, 0.3)
	add_child(_ring)
	var rng := RandomNumberGenerator.new(); rng.seed = hash(to)
	# Burning sparks and stone chips thrown out, falling under gravity.
	for n in 14:
		var spark := n < 8
		var chip := MeshInstance3D.new()
		if spark:
			var ball := SphereMesh.new(); ball.radius = 0.05; ball.height = 0.1; ball.radial_segments = 6; ball.rings = 3
			chip.mesh = ball
			var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.no_depth_test = true; m.render_priority = 10
			m.albedo_color = fire.lerp(Color("ffe27a"), rng.randf()); chip.material_override = m
		else:
			var box := BoxMesh.new(); var size := rng.randf_range(0.06, 0.11); box.size = Vector3(size, size*0.7, size)
			chip.mesh = box; chip.material_override = SolidMaterials.opaque(Color("6f716b").darkened(rng.randf()*0.3))
		add_child(chip)
		var angle := rng.randf()*TAU
		var speed := rng.randf_range(1.2, 2.4) if spark else rng.randf_range(0.8, 1.6)
		_debris.append([chip, Vector3(cos(angle)*speed, rng.randf_range(1.6, 3.0), sin(angle)*speed), Vector3(rng.randf(), rng.randf(), rng.randf())*8.0])
	# Lumpy fireball: several overlapping puffs from yellow to deep red.
	for n in 7:
		var tone := Color("ffd04a").lerp(Color("d8401a"), float(n)/6.0)
		tone.a = 0.95
		var lump := _burst_mesh(tone, rng.randf_range(0.1, 0.17), 2 + (6-n))
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		_fires.append([lump, dir*rng.randf_range(0.18, 0.38), rng.randf_range(0.7, 1.0)])
	# Smoke puffs that keep rising after the fire is gone.
	for n in 4:
		var puff := _burst_mesh(Color(0.42, 0.42, 0.42, 0.65), rng.randf_range(0.14, 0.2))
		puff.position = Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(0.0, 0.15), rng.randf_range(-0.18, 0.18))
		_puffs.append([puff, puff.position, rng.randf_range(0.6, 1.0)])

func fizzle() -> void:
	queue_free()

func _caster_alive() -> bool:
	if caster == null: return true
	var enemy = caster.get_ref()
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion(): return false
	if enemy.get("_finished") == true: return false
	return enemy.health > 0.0

func _process(delta: float) -> void:
	if _burst < 0.0:
		_idle += delta
		if _idle > ORPHAN_SECONDS or not _caster_alive(): fizzle()
		return
	_burst += delta
	var k := clampf(_burst/BURST_SECONDS, 0.0, 1.0)
	# White-hot core pops first, then the fireball swells and fades.
	var kc := clampf(_burst/0.12, 0.0, 1.0)
	_core.scale = Vector3.ONE*(1.0+2.5*kc)
	(_core.material_override as StandardMaterial3D).albedo_color.a = 1.0-kc
	_core.visible = kc < 1.0
	var kf := clampf(_burst/0.18, 0.0, 1.0)
	_flash.scale = Vector3.ONE*(0.6+1.6*kf)
	(_flash.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.45, 0.9*(1.0-kf))
	_fire2.visible = false
	for entry in _fires:
		var lump: MeshInstance3D = entry[0]
		var kl := clampf(_burst/(BURST_SECONDS*entry[2]), 0.0, 1.0)
		lump.position = entry[1]*(0.3+1.0*sqrt(kl))+Vector3.UP*0.2*kl
		lump.scale = Vector3.ONE*(0.5+1.6*sqrt(kl))*(1.0-0.5*kl*kl)
		(lump.material_override as StandardMaterial3D).albedo_color.a = 0.95*(1.0-kl*kl)
		lump.visible = kl < 1.0
	_smoke.scale = Vector3.ONE*(0.8+2.4*k)
	_smoke.position = Vector3.UP*0.5*k
	(_smoke.material_override as StandardMaterial3D).albedo_color.a = 0.55*(1.0-k)
	# Shock ring races outward across the tower top.
	var kr := clampf(_burst/0.35, 0.0, 1.0)
	_ring.scale = Vector3(0.3+2.6*kr, 0.2, 0.3+2.6*kr)
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.8*(1.0-kr)
	for entry in _debris:
		var chip: Node3D = entry[0]
		if not is_instance_valid(chip): continue
		entry[1].y -= 7.0*delta
		chip.position += entry[1]*delta
		chip.rotation += entry[2]*delta
		chip.scale = Vector3.ONE*maxf(0.0, 1.0-_burst/SMOKE_SECONDS)
		if chip.position.y < -1.2: chip.visible = false
	for entry in _puffs:
		var puff: MeshInstance3D = entry[0]
		var kp := clampf(_burst/(SMOKE_SECONDS*entry[2]), 0.0, 1.0)
		puff.position = entry[1]+Vector3.UP*0.9*kp
		puff.scale = Vector3.ONE*(1.0+2.0*kp)
		(puff.material_override as StandardMaterial3D).albedo_color.a = 0.6*(1.0-kp)
	if _burst >= SMOKE_SECONDS: queue_free()
