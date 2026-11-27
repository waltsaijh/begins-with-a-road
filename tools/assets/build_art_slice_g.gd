extends SceneTree
## Art Slice G: chunky low-poly medieval towers.
## Reads assets/models/towers/art_slice_g/<kind>.glb (from Blender or gltf_writer.py),
## bakes solid-colour meshes, authors the gameplay clips procedurally, batches static
## parts and writes art_slice_g/integrated/<kind>.tscn wrappers for imported_tower_visual.gd.
## Run: godot --headless --path . --script res://tools/assets/build_art_slice_g.gd [-- --use]
##   --use  also points assets/data/towers/*.tres visual_model at the new wrappers.
const SRC := "res://assets/models/towers/art_slice_g/"
const OUT := "res://assets/models/towers/art_slice_g/integrated/"
const KINDS := ["sentry","ballista","barracks","mortar","crossfire","broadside"]
const MATERIAL := preload("res://assets/materials/solid_color.tres")
const Baker := preload("res://tools/assets/solid_mesh_baker.gd")
const FPS := 24.0
var protected: Array[Node] = []
var mesh_index := 0
var kind := ""
var model: Node3D

func _initialize() -> void: call_deferred("build")

## Blender (Z up, +Y front) to Godot (Y up, -Z front).
static func G(x: float, y: float, z: float) -> Vector3: return Vector3(x, z, -y)

static func smooth(f: float, pts: Array) -> float:
	if f <= pts[0][0]: return pts[0][1]
	for i in range(pts.size()-1):
		var a: Array = pts[i]; var b: Array = pts[i+1]
		if f <= b[0]:
			var t := clampf((f-a[0])/maxf(b[0]-a[0], 0.0001), 0.0, 1.0)
			return lerpf(a[1], b[1], t*t*(3.0-2.0*t))
	return pts[-1][1]

func part(function: String) -> Node3D:
	for n in model.find_children("*", "Node3D", true, false):
		if String(n.name).ends_with("__"+function): return n
	push_error("Missing part "+function+" in "+kind)
	return null

## tracks: [[node, "position"|"rotation"|"scale", Callable(frame:int)->value], ...]
func clip(frames: int, tracks: Array) -> Animation:
	var anim := Animation.new()
	anim.length = (frames-1)/FPS
	anim.step = 1.0/FPS
	for spec in tracks:
		var node: Node3D = spec[0]
		var type: int = {"position":Animation.TYPE_POSITION_3D,"rotation":Animation.TYPE_ROTATION_3D,"scale":Animation.TYPE_SCALE_3D}[spec[1]]
		var index := anim.add_track(type)
		anim.track_set_path(index, model.get_path_to(node))
		for f in range(1, frames+1):
			var value: Variant = (spec[2] as Callable).call(f)
			match spec[1]:
				"position": anim.position_track_insert_key(index, (f-1)/FPS, value)
				"rotation": anim.rotation_track_insert_key(index, (f-1)/FPS, value)
				"scale": anim.scale_track_insert_key(index, (f-1)/FPS, value)
		if not node in protected: protected.append(node)
	return anim

func clips() -> Dictionary:
	var result := {}
	match kind:
		"sentry":
			var rec := part("RecoilAssembly"); var r := rec.position
			result.fire = clip(25, [[rec, "position", func(f): return r+G(0, -smooth(f, [[1,0],[5,0],[7,.065],[11,.045],[25,0]]), 0)]])
		"mortar":
			var rec := part("RecoilAssembly"); var r := rec.position
			var bed := part("Suspension"); var b := bed.position
			var kick := func(f): return smooth(f, [[1,0],[7,0],[9,1],[14,.75],[37,0]])
			result.fire = clip(37, [[rec, "position", func(f): return r+G(0,-.055,-.062)*kick.call(f)],
				[bed, "position", func(f): return b+G(0,0,-.018)*kick.call(f)]])
		"crossfire":
			var dirs := [Vector2(0,1), Vector2(1,0), Vector2(0,-1), Vector2(-1,0)]
			for i in 4:
				var rec := part("RecoilAssembly"+str(i)); var r := rec.position; var d: Vector2 = dirs[i]
				result["fire_"+["north","east","south","west"][i]] = clip(25, [[rec, "position",
					func(f): return r-G(d.x, d.y, 0)*smooth(f, [[1,0],[5,0],[7,.085],[11,.055],[25,0]])]])
		"broadside":
			for side in [-1, 1]:
				var bank := "Port" if side < 0 else "Starboard"
				var tracks := []
				for i in 3:
					var gun := part(bank+"Gun"+str(i+1)); var r := gun.position
					tracks.append([gun, "position", func(f): return r+G(-side*smooth(f-i*2, [[1,0],[5,0],[7,.055],[12,.035],[27,0]]), 0, 0)])
				result["fire_"+bank.to_lower()] = clip(33, tracks)
		"barracks":
			var left := part("DoorLeft"); var right := part("DoorRight")
			var ang := func(f): return deg_to_rad(smooth(f, [[1,0],[7,0],[23,82],[43,82],[65,0],[73,0]]))
			result.open_close = clip(73, [[left, "rotation", func(f): return Quaternion(Vector3.UP, ang.call(f))],
				[right, "rotation", func(f): return Quaternion(Vector3.UP, -ang.call(f))]])
		"ballista":
			result.attack = ballista_clip()
	return result

## 72 frames: draw 0-28 (wind_up seeks here), release at 29, bolt hidden until 58, reload 57-70.
func ballista_clip() -> Animation:
	const DRAW := .36
	var slider := part("Slider"); var bolt := part("BoltCarrier"); var link := part("TensionLink")
	var nock := part("Nock")
	var s0 := slider.position; var b0 := bolt.position; var l0 := link.quaternion
	var draw := func(f): return smooth(f-1, [[0,0],[28,1],[29,1],[31,0]])
	var limb := func(f, sgn):
		var u: float = f-1
		var bend: float = 20.0*draw.call(f)
		if u >= 31: bend -= 7.0*exp(-(u-31)/4.0)*cos((u-31)*.9)
		return Quaternion(Vector3.UP, deg_to_rad(-sgn*bend))
	var tracks := [[slider, "position", func(f): return s0+G(0, -DRAW*draw.call(f), 0)],
		[bolt, "position", func(f):
			var u: float = f-1
			if u <= 29: return b0+G(0, -DRAW*draw.call(f), 0)
			return b0+G(0, -.40*(1.0-smooth(u, [[57,0],[70,1]])), 0)],
		[bolt, "scale", func(f): return Vector3.ONE*(0.001 if f-1 >= 30 and f-1 < 57 else 1.0)],
		[link, "rotation", func(f): return l0*Quaternion(Vector3.RIGHT, -TAU*draw.call(f))]]
	for sgn in [-1, 1]:
		var pivot := part("LimbPivot"+str(sgn)); var tip := part("LimbTip"+str(sgn)); var string := part("BowString"+str(sgn))
		var aim := part("StringAim"+str(sgn))
		var q0 := pivot.quaternion
		tracks.append([pivot, "rotation", func(f): return q0*limb.call(f, sgn)])
		var tip_point := func(f): return pivot.position+(Basis(q0*limb.call(f, sgn))*tip.position)
		var nock_point := func(f): return s0+G(0, -DRAW*draw.call(f), 0)+nock.position
		# Aim (rest rotation) and stretch (string, identity rest rotation) are separate
		# nodes: a non-uniform scale track on a node whose rest pose is rotated was
		# applied on the wrong axis, so the strings overshot and crossed.
		tracks.append([aim, "position", func(f): return tip_point.call(f)])
		tracks.append([aim, "rotation", func(f): return Quaternion(Basis.looking_at((nock_point.call(f)-tip_point.call(f)).normalized(), Vector3.UP))])
		tracks.append([string, "scale", func(f): return Vector3(1, 1, (nock_point.call(f)-tip_point.call(f)).length())])
	return clip(72, tracks)

func merge(parent: Node3D) -> void:
	var parts: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if child is MeshInstance3D and not child in protected: parts.append(child)
		elif child is Node3D: merge(child)
	if parts.size() < 2: return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT); tool.set_custom_format(1, SurfaceTool.CUSTOM_RG_FLOAT)
	tool.set_material(MATERIAL)
	for p in parts:
		for surface in p.mesh.get_surface_count(): tool.append_from(p.mesh, surface, p.transform)
		p.free()
	var mesh := MeshInstance3D.new(); mesh.name = "StaticAssembly"; mesh.mesh = tool.commit()
	parent.add_child(mesh); mesh.owner = model

func build() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var report := {}
	for k in KINDS:
		kind = k; mesh_index = 0; protected.clear()
		var source: PackedScene = load(SRC+k+".glb")
		assert(source != null, "Missing "+SRC+k+".glb")
		model = source.instantiate()
		root.add_child(model)
		# Upgrade dressing: body_visual.gd set_level() shows Level<N> from level N on, Below<N> only below it.
		for pattern in ["*__Level*", "*__Below*"]:
			for n in model.find_children(pattern, "Node3D", true, false):
				n.name = String(n.name).get_slice("__", 1)
		for n in model.find_children("*", "", true, false):
			if n is MeshInstance3D:
				for surface in n.mesh.get_surface_count(): assert(Baker.supports(n.mesh.surface_get_material(surface)), "Unsupported material on "+n.name)
				n.mesh = Baker.mesh(n.mesh)
			elif n is Node3D and ("Muzzle" in String(n.name) or "ArrowRelease" in String(n.name)):
				var marker := Marker3D.new(); marker.name = n.name; marker.transform = n.transform
				var parent: Node = n.get_parent(); parent.remove_child(n); parent.add_child(marker); marker.owner = model; n.free()
		var player := AnimationPlayer.new(); player.name = "AnimationPlayer"
		model.add_child(player); player.root_node = NodePath("..")
		var library := AnimationLibrary.new()
		var made := clips()
		for title in made: library.add_animation(title, made[title])
		player.add_animation_library(&"", library)
		merge(model)
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var path: String = OUT+k+"_part_%02d.res" % mesh_index
			assert(ResourceSaver.save(mesh.mesh, path) == OK)
			mesh.mesh = load(path); mesh_index += 1
		for node in model.find_children("*", "", true, false): node.owner = model; node.scene_file_path = ""
		model.scene_file_path = ""
		var packed := PackedScene.new(); assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, OUT+k+"_art.tscn") == OK)
		report[k] = {"meshes": mesh_index, "clips": made.keys(), "animated": protected.size()}
		model.free()
		var text: String = '[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://scripts/towers/imported_tower_visual.gd" id="1"]\n[ext_resource type="PackedScene" path="%s%s_art.tscn" id="2"]\n\n[node name="TowerVisual" type="Node3D"]\nscript = ExtResource("1")\ntower_kind = "%s"\n\n[node name="Art" parent="." instance=ExtResource("2")]\n' % [OUT, k, k]
		if k == "sentry":
			text = text.replace("load_steps=3", "load_steps=4").replace('id="2"]\n', 'id="2"]\n[ext_resource type="AudioStream" path="res://assets/audio/towers/sentry_shot.wav" id="3"]\n').replace('tower_kind = "sentry"\n', 'tower_kind = "sentry"\nshot_sound = ExtResource("3")\n')
		FileAccess.open(OUT+k+".tscn", FileAccess.WRITE).store_string(text)
	if "--use" in OS.get_cmdline_user_args():
		for k in KINDS:
			var path: String = "res://assets/data/towers/%s.tres" % k
			var data := FileAccess.get_file_as_string(path)
			data = data.replace('path="res://assets/models/towers/integrated/%s.tscn" id="art_slice_e"' % k,
				'path="%s%s.tscn" id="art_slice_e"' % [OUT, k])
			FileAccess.open(path, FileAccess.WRITE).store_string(data)
	print("ART_SLICE_G_BUILT ", JSON.stringify(report))
	quit()
