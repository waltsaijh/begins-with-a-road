extends SceneTree
## Art Slice G: three small floating-island meshes for the background
## (grass slab, earth band, stacked rock underside, plus ruins or trees).
## Run: godot --headless --path . --script res://tools/assets/build_distant_islands.gd
const MATERIAL := preload("res://assets/models/environment/distant_island.tres")
const OUT := "res://assets/models/environment/distant_island_%d.res"
const GRASS := [Color("8fae5c"), Color("83a253")]
const EARTH := [Color("8c6a48"), Color("7b5c3f")]
const ROCK := [Color("b0b7b1"), Color("a2a9a3"), Color("bcc1bb")]
const STONE := [Color("cbcac2"), Color("b3b2aa")]
var st: SurfaceTool
var rng := RandomNumberGenerator.new()

func _initialize() -> void: call_deferred("build")

func face(points: Array, color: Color, centre: Vector3) -> void:
	var n: Vector3 = (points[2]-points[0]).cross(points[1]-points[0]).normalized()
	var mid := Vector3.ZERO
	for p in points: mid += p
	if n.dot(mid/points.size()-centre) < 0.0: n = -n
	for i in range(1, points.size()-1):
		for v in [points[0], points[i], points[i+1]]:
			st.set_color(color); st.set_normal(n); st.add_vertex(v)

func prism(poly: PackedVector2Array, y0: float, y1: float, top: Color, side: Array, offset := Vector3.ZERO, bottom_scale := 1.0) -> void:
	var centre := offset+Vector3(0, (y0+y1)*0.5, 0)
	var up: Array = []; var down: Array = []
	for p in poly:
		up.append(offset+Vector3(p.x, y1, p.y)); down.append(offset+Vector3(p.x*bottom_scale, y0, p.y*bottom_scale))
	face(up, top, centre); face(down, side[0].darkened(0.3), centre)
	for i in poly.size():
		var j := (i+1) % poly.size()
		face([up[i], up[j], down[j], down[i]], side[rng.randi() % side.size()], centre)

func blob(radius: float, sides: int) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in sides:
		var a := TAU*i/sides + rng.randf_range(-.15, .15)
		poly.append(Vector2(cos(a), sin(a))*radius*rng.randf_range(.82, 1.12))
	return poly

func box(c: Vector3, half: Vector3, yaw: float, color: Array) -> void:
	var b := Basis(Vector3.UP, yaw)
	var poly := PackedVector2Array()
	for s in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		var v := b*Vector3(s.x*half.x, 0, s.y*half.z)
		poly.append(Vector2(v.x, v.z))
	prism(poly, c.y-half.y, c.y+half.y, color[0], color, Vector3(c.x, 0, c.z))

func tree(at: Vector3, height: float) -> void:
	box(at+Vector3(0, height*.18, 0), Vector3(.05, height*.18, .05), 0.3, [Color("6f3e2a")])
	for k in 2:
		var r := height*(.32-.08*k); var y0 := at.y+height*(.30+.28*k)
		var poly := blob(r, 7); var centre := at+Vector3(0, y0+height*.2, 0)
		var tip := at+Vector3(0, y0+height*.42, 0)
		for i in poly.size():
			var j := (i+1) % poly.size()
			face([at+Vector3(poly[i].x, y0, poly[i].y), at+Vector3(poly[j].x, y0, poly[j].y), tip], GRASS[k % 2].darkened(0.08*k), centre)

func build() -> void:
	for variant in 3:
		rng.seed = 900+variant
		st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := blob(1.0, 9)
		prism(top, -0.06, 0.06, GRASS[0], [GRASS[1]])
		prism(top, -0.32, -0.06, EARTH[0], EARTH, Vector3.ZERO, 0.92)
		var y := -0.32; var r := 0.85; var drift := Vector3.ZERO
		while r > 0.12:
			var h := rng.randf_range(.35, .55)
			drift += Vector3(rng.randf_range(-.08,.08), 0, rng.randf_range(-.08,.08))
			box(drift+Vector3(0, y-h*0.5, 0), Vector3(r*rng.randf_range(.8,1.0), h*0.5, r*rng.randf_range(.75,.95)), rng.randf()*TAU, ROCK)
			y -= h*0.92; r *= 0.66
		match variant:
			0:
				for k in 3:
					var a := TAU*k/3.0+0.4
					box(Vector3(cos(a)*.5, 0.06+[.42,.28,.18][k], sin(a)*.5), Vector3(.09, [.42,.28,.18][k], .09), a, STONE)
				box(Vector3(-.1, .11, .2), Vector3(.22, .05, .1), .5, STONE)
			1:
				tree(Vector3(.25, .06, -.2), 1.0); tree(Vector3(-.35, .06, .25), .75)
			2:
				box(Vector3(-.15, .32, 0), Vector3(.07, .26, .07), 0, STONE); box(Vector3(.25, .32, 0), Vector3(.07, .26, .07), 0, STONE)
				box(Vector3(.05, .62, 0), Vector3(.28, .05, .09), 0, STONE); tree(Vector3(.45, .06, .45), .6)
		st.set_material(MATERIAL)
		assert(ResourceSaver.save(st.commit(), OUT % variant) == OK)
	print("DISTANT_ISLANDS_BUILT")
	quit()
