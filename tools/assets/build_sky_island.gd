extends SceneTree
## Art Slice G "sky island": replaces the stone pillar under PILLAR tiles with a
## faceted floating-rock underside (earth band, then rock tapering into the clouds).
## Keeps pillar_support.tscn's node names, the -0.37 attachment height and the
## pillar_stone.tres shader (growth animation + cloud fade) unchanged.
## Run: godot --headless --path . --script res://tools/assets/build_sky_island.gd
const MATERIAL := preload("res://assets/materials/pillar_stone.tres")
const MESH_PATH := "res://assets/models/tiles/variants/sky_rock.res"
const SCENE_PATH := "res://assets/models/tiles/variants/pillar_support.tscn"
## Stacked stone blocks: [center_x, center_z, half_x, half_z, top_y, bottom_y, yaw_degrees]
const BLOCKS := [[0.0, 0.0, 0.55, 0.52, -0.37, -0.82, 2.0], [0.05, -0.03, 0.42, 0.38, -0.82, -1.28, -6.0],
	[0.33, 0.24, 0.17, 0.15, -0.82, -1.08, 14.0], [-0.04, 0.05, 0.30, 0.27, -1.28, -1.74, 9.0],
	[0.06, 0.02, 0.18, 0.20, -1.74, -2.16, -4.0], [0.03, 0.05, 0.08, 0.09, -2.16, -2.48, 20.0]]
const STONE := [Color("c2c8c1"), Color("b0b7b1"), Color("ccd1ca"), Color("a8afa9")]
const STRIPS := 3

func _initialize() -> void: call_deferred("build")

func build() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 7041
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := [Vector3.ZERO]
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color):
		var n := (c-a).cross(b-a).normalized()
		if n.dot((a+b+c+d)*0.25-centre[0]) < 0.0: n = -n
		for v in [a, b, c, a, c, d]:
			st.set_color(color); st.set_normal(n); st.add_vertex(v)
	for k in BLOCKS.size():
		var spec: Array = BLOCKS[k]
		var basis := Basis(Vector3.UP, deg_to_rad(spec[6]))
		var c := Vector3(spec[0], 0, spec[1])
		var corner := func(sx: float, sz: float, y: float) -> Vector3: return c+basis*Vector3(sx*spec[2], 0, sz*spec[3])+Vector3(0, y, 0)
		var top: float = spec[4]; var bottom: float = spec[5]
		centre[0] = c+Vector3(0, (top+bottom)*0.5, 0)
		var depth := 0.06*k
		# Four sides, each split into vertical strips for a carved, columnar look.
		var sides := [[-1.0,-1.0,1.0,-1.0],[1.0,-1.0,1.0,1.0],[1.0,1.0,-1.0,1.0],[-1.0,1.0,-1.0,-1.0]]
		for edge: Array in sides:
			for i in STRIPS:
				var u0 := float(i)/STRIPS; var u1 := float(i+1)/STRIPS
				var x0: float = lerpf(edge[0], edge[2], u0); var z0: float = lerpf(edge[1], edge[3], u0)
				var x1: float = lerpf(edge[0], edge[2], u1); var z1: float = lerpf(edge[1], edge[3], u1)
				var color: Color = STONE[rng.randi() % STONE.size()].darkened(depth)
				var lip: float = top-rng.randf_range(0.0, 0.05)*(0.0 if k == 0 else 1.0)
				quad.call(corner.call(x0, z0, lip), corner.call(x1, z1, lip), corner.call(x1, z1, bottom), corner.call(x0, z0, bottom), color)
		var under: Color = STONE[1].darkened(0.3+depth)
		quad.call(corner.call(-1, -1, bottom), corner.call(-1, 1, bottom), corner.call(1, 1, bottom), corner.call(1, -1, bottom), under)
		if k > 0:
			quad.call(corner.call(-1, -1, top), corner.call(1, -1, top), corner.call(1, 1, top), corner.call(-1, 1, top), STONE[0].darkened(0.1))
	st.set_material(MATERIAL)
	var mesh := st.commit()
	assert(ResourceSaver.save(mesh, MESH_PATH) == OK)
	var text := '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="ArrayMesh" path="%s" id="1"]\n\n[node name="PillarSupport" type="Node3D"]\n\n[node name="FacetedStone" type="MeshInstance3D" parent="."]\nmesh = ExtResource("1")\n' % MESH_PATH
	FileAccess.open(SCENE_PATH, FileAccess.WRITE).store_string(text)
	print("SKY_ISLAND_BUILT ", mesh.get_faces().size()/3, " triangles")
	quit()
