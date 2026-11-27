extends Node3D
## Short mesh bursts, real-time visual lifetime; never delays a simulation event.
const K = preload("res://scripts/combat/rendering/restored_art.gd")
var bursts: Array[Dictionary] = []
const LIMIT := 72

func emit(at: Vector3, kind: String) -> void:
	if bursts.size() >= LIMIT: return
	var root := K.group(self,kind,at)
	var muzzle := kind in ["arrow","shell","bolt","broadside","radial"]
	var color := "cyan" if kind == "radial" else ("amber" if kind in ["shell","broadside"] else ("ivory" if kind in ["arrow","bolt"] else ("red" if kind == "spawn" else ("cyan" if kind == "respawn" else ("dust" if kind in ["build","death"] else "hit")))))
	var particles: Array[Node3D] = []
	for i in (2 if muzzle else (5 if kind != "hit" else 3)):
		particles.append(K.part(root,"rock",Vector3.ONE*(0.055 if kind == "hit" else 0.075),Vector3.ZERO,color))
	var ring: MeshInstance3D
	if kind in ["spawn","respawn","build"]:
		ring = K.part(root,"ring",Vector3.ONE*0.3,Vector3(0,0.025,0),color)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bursts.append({"root":root,"particles":particles,"ring":ring,"age":0.0,"life":0.18 if muzzle else (0.28 if kind == "hit" else 0.45),"kind":kind})

func clear() -> void:
	for burst in bursts:
		burst.root.queue_free()
		if burst.has("blast"): burst.blast.queue_free()
	bursts.clear()

## Without its core, for a tower pulsing around itself. With it (a landing
## shell): a flash, fireballs, a shockwave ring, debris, rising smoke, a scorch
## mark and a brief light, all in one burst entry.
func mortar_impact(at: Vector3, radius := 1.0, with_core := true) -> void:
	if bursts.size() >= LIMIT: return
	var root := K.group(self,"MortarImpact",at+Vector3.UP*0.11)
	root.scale = Vector3.ONE*maxf(0.01,radius)
	var ring := K.part(root,"ring",Vector3.ONE,Vector3.ZERO,"amber")
	ring.material_override = SolidMaterials.transparent(K.COLORS.amber)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core := K.part(root,"rock",Vector3.ONE*0.48,Vector3(0,0.35,0),"amber")
	core.visible = false
	var particles: Array[Node3D] = []
	if not with_core:
		for i in 6: particles.append(K.part(root,"rock",Vector3.ONE*0.08,Vector3.ZERO,"dust"))
		bursts.append({"root":root,"particles":particles,"ring":ring,"core":core,"age":0.0,"life":0.24,"kind":"mortar_impact"})
		return
	var size := maxf(0.2, radius)
	var blast := K.group(self,"MortarBlast",at+Vector3.UP*0.1)   # road top, like the ring
	var flash := _ball(blast, BLAST_FLASH, Vector3(0, 0.4*size, 0))
	var fire: Array[MeshInstance3D] = []
	var fire_rest: Array[Vector3] = []
	for i in 5:
		var a := float(i)*TAU/5.0+_rng.randf_range(-.4,.4)
		var rest := Vector3(cos(a)*0.32*size, _rng.randf_range(0.3,0.7)*size, sin(a)*0.32*size)
		fire.append(_ball(blast, BLAST_FIRE, rest))
		fire_rest.append(rest)
	var smoke: Array[MeshInstance3D] = []
	var smoke_rest: Array[Vector3] = []
	for i in 4:
		var a := float(i)*TAU/4.0+_rng.randf_range(-.5,.5)
		var rest := Vector3(cos(a)*0.22*size, 0.35*size, sin(a)*0.22*size)
		smoke.append(_ball(blast, BLAST_SMOKE, rest))
		smoke_rest.append(rest)
	var scorch := MeshInstance3D.new()
	scorch.mesh = _scorch_mesh()
	scorch.material_override = SolidMaterials.transparent(BLAST_SCORCH)
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scorch.position = Vector3.UP*0.006
	scorch.scale = Vector3(0.5*size, 1, 0.5*size)
	blast.add_child(scorch)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.32)
	light.omni_range = 1.8*size
	light.light_energy = 0.0
	light.position = Vector3.UP*0.35*size
	blast.add_child(light)
	var sparks: Node3D = preload("res://scripts/combat/rendering/hit_sparks.gd").current
	if is_instance_valid(sparks): sparks.emit(at+Vector3.UP*0.12*size, at, "blast")
	bursts.append({"root":root,"particles":particles,"ring":ring,"core":core,"age":0.0,"life":BLAST_LIFE,"kind":"mortar_impact",
		"blast":blast,"size":size,"flash":flash,"fire":fire,"fire_rest":fire_rest,"smoke":smoke,"smoke_rest":smoke_rest,"scorch":scorch,"light":light})

const BLAST_LIFE := 1.5
const BLAST_FLASH := Color("fff0b0")
const BLAST_FIRE := Color("ffb347")
const BLAST_EMBER := Color("e0522a")
const BLAST_SMOKE := Color("8f877c")
const BLAST_SCORCH := Color(0.17, 0.14, 0.12, 0.6)
var _rng := RandomNumberGenerator.new()
static var _ball_mesh: SphereMesh
static var _disc_mesh: CylinderMesh

func _ball(parent: Node3D, color: Color, at: Vector3) -> MeshInstance3D:
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 0.5
		_ball_mesh.height = 1.0
		_ball_mesh.radial_segments = 8
		_ball_mesh.rings = 4
	var node := MeshInstance3D.new()
	node.mesh = _ball_mesh
	node.material_override = SolidMaterials.transparent(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	node.scale = Vector3.ONE*0.001
	parent.add_child(node)
	return node

func _scorch_mesh() -> CylinderMesh:
	if _disc_mesh == null:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.004
		_disc_mesh.radial_segments = 12
		_disc_mesh.rings = 1
	return _disc_mesh

## Shell landing timeline in seconds: flash 0-0.18, fire 0-0.6, ring 0-0.32,
## smoke 0.1-1.5, scorch fades over the last half.
func _advance_blast(burst: Dictionary) -> void:
	var age: float = burst.age
	var size: float = burst.size
	var r := clampf(age/0.32, 0.0, 1.0)
	burst.ring.scale = Vector3(maxf(0.01,r*1.15),1,maxf(0.01,r*1.15))
	burst.ring.material_override.albedo_color = Color("edc184", (1.0-r)*0.9)
	burst.ring.visible = r < 1.0
	var f := clampf(age/0.18, 0.0, 1.0)
	burst.flash.scale = Vector3.ONE*maxf(0.001, size*1.2*sqrt(f)*(1.0-f*0.3))
	burst.flash.material_override.albedo_color = Color(BLAST_FLASH, (1.0-f)*0.95)
	burst.flash.visible = f < 1.0
	var g := clampf(age/0.6, 0.0, 1.0)
	for i in burst.fire.size():
		var ball: MeshInstance3D = burst.fire[i]
		var grow := minf(1.0, g*5.0)
		ball.scale = Vector3.ONE*maxf(0.001, size*0.6*grow*(1.0-g*g))
		ball.position = burst.fire_rest[i]*(0.6+g*0.8)+Vector3.UP*g*0.15*size
		var tint := BLAST_FIRE.lerp(BLAST_EMBER, minf(1.0, g*1.6)).lerp(BLAST_SMOKE, maxf(0.0, g*2.0-1.0))
		ball.material_override.albedo_color = Color(tint, 1.0-g*0.5)
		ball.visible = g < 1.0
	var k := clampf((age-0.1)/(BLAST_LIFE-0.1), 0.0, 1.0)
	for i in burst.smoke.size():
		var puff: MeshInstance3D = burst.smoke[i]
		puff.scale = Vector3.ONE*maxf(0.001, size*(0.25+0.4*sqrt(k))*(1.0 if k > 0.0 else 0.0))
		puff.position = burst.smoke_rest[i]*(1.0+k*0.8)+Vector3.UP*k*1.1*size
		puff.material_override.albedo_color = Color(BLAST_SMOKE, 0.7*(1.0-k)*minf(1.0, k*8.0))
	var fade := clampf((age/BLAST_LIFE-0.5)*2.0, 0.0, 1.0)
	burst.scorch.material_override.albedo_color = Color(BLAST_SCORCH, BLAST_SCORCH.a*(1.0-fade))
	var l := clampf(age/0.28, 0.0, 1.0)
	burst.light.light_energy = 2.4*(1.0-l)*(1.0-l)
	burst.light.visible = l < 1.0

func _process(delta: float) -> void:
	for i in range(bursts.size()-1,-1,-1):
		var burst: Dictionary = bursts[i]; burst.age += delta
		var t: float = burst.age/burst.life
		if t >= 1:
			burst.root.queue_free()
			if burst.has("blast"): burst.blast.queue_free()
			bursts.remove_at(i); continue
		if burst.has("blast"):
			_advance_blast(burst)
			continue
		if burst.kind == "mortar_impact":
			burst.ring.scale = Vector3(maxf(0.01,t*2),1,maxf(0.01,t*2))
			burst.ring.material_override.albedo_color = Color("edc184",1-t)
			burst.core.scale = Vector3.ONE*maxf(0.001,(1-t)*0.48)
			for j in burst.particles.size():
				var angle: float = j*TAU/6.0
				burst.particles[j].position = Vector3(cos(angle)*t,sin(PI*t)*0.24,sin(angle)*t)
				burst.particles[j].scale = Vector3.ONE*maxf(0.001,0.09*(1-t))
			continue
		for j in burst.particles.size():
			var a: float = j*TAU/burst.particles.size()+0.3
			burst.particles[j].position = Vector3(cos(a)*t*0.32,0.08+sin(PI*t)*0.18,sin(a)*t*0.32)
			burst.particles[j].scale = Vector3.ONE*0.07*(1-t)
		if burst.ring != null: burst.ring.scale = Vector3(0.25+t*0.7,1-t,0.25+t*0.7)
