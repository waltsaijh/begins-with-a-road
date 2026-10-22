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
	for burst in bursts: burst.root.queue_free()
	bursts.clear()

func mortar_impact(at: Vector3, radius := 1.0) -> void:
	if bursts.size() >= LIMIT: return
	var root := K.group(self,"MortarImpact",at+Vector3.UP*0.11)
	root.scale = Vector3.ONE*maxf(0.01,radius)
	var ring := K.part(root,"ring",Vector3.ONE,Vector3.ZERO,"amber")
	ring.material_override = ring.material_override.duplicate()
	ring.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := K.part(root,"rock",Vector3.ONE*0.48,Vector3(0,0.35,0),"amber")
	var particles: Array[Node3D] = []
	for i in 6: particles.append(K.part(root,"rock",Vector3.ONE*0.08,Vector3.ZERO,"dust"))
	bursts.append({"root":root,"particles":particles,"ring":ring,"core":core,"age":0.0,"life":0.24,"kind":"mortar_impact"})

func _process(delta: float) -> void:
	for i in range(bursts.size()-1,-1,-1):
		var burst: Dictionary = bursts[i]; burst.age += delta
		var t: float = burst.age/burst.life
		if t >= 1:
			burst.root.queue_free(); bursts.remove_at(i); continue
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
