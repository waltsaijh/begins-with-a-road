extends SceneTree
const IDS = ["great_ballista","watchtower","barracks","mortar","crossfire","broadside_airship"]
const BASE = "res://assets/models/towers/art_slice_d/"
const Baker = preload("res://tools/assets/solid_mesh_baker.gd")
var results := {}
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func snapshot(nodes: Array[Node]) -> Dictionary:
	var out := {}
	for n in nodes:
		if n is Node3D: out[str(n.get_path())] = n.transform
	return out
func delta(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func descendants(root_node: Node) -> Array[Node]:
	var nodes: Array[Node] = [root_node]
	for child in root_node.get_children(): nodes.append_array(descendants(child))
	return nodes
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	for id in IDS:
		var baked_mode := "--baked" in OS.get_cmdline_user_args()
		var packed := load(BASE+id+("_visual.tscn" if baked_mode else ".glb")) as PackedScene
		check(packed != null,id+" failed import")
		if packed == null: continue
		var model := packed.instantiate()
		root.add_child(model)
		var nodes := descendants(model)
		var player: AnimationPlayer
		for n in nodes:
			if n is AnimationPlayer: player = n
		check(player != null,id+" missing AnimationPlayer")
		if player == null: model.queue_free(); continue
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var animation_report := {}
		for clip_name in manifest[id].clips:
			check(player.has_animation(clip_name),id+" missing "+clip_name)
			if not player.has_animation(clip_name): continue
			var anim := player.get_animation(clip_name)
			check(anim.loop_mode == Animation.LOOP_NONE,id+" unexpectedly loops")
			var paths: Array[String] = []
			for t in anim.get_track_count():
				var path := anim.track_get_path(t)
				var target := player.get_node(player.root_node).get_node_or_null(NodePath(path.get_concatenated_names()))
				check(target != null,id+" invalid track "+str(path))
				paths.append(str(path))
			player.play(clip_name); player.seek(0,true); player.advance(0)
			var initial := snapshot(nodes)
			var movement := 0.0
			for i in range(1,31):
				player.seek(anim.length*float(i)/30.0,true); player.advance(0)
				for n in nodes:
					if n is Node3D: movement = maxf(movement,delta(initial[str(n.get_path())],n.transform))
			player.seek(anim.length,true); player.advance(0)
			var reset_error := 0.0
			for n in nodes:
				if n is Node3D: reset_error = maxf(reset_error,delta(initial[str(n.get_path())],n.transform))
			check(movement>0.01,id+" static animation "+clip_name)
			check(reset_error<0.0001,id+" reset failure "+clip_name)
			if id=="crossfire":
				var index: int = ["fire_north","fire_east","fire_south","fire_west"].find(clip_name)
				for path in paths: check("RecoilAssembly"+str(index) in path,id+" direction track leak")
			if id=="broadside_airship":
				var bank: String = "PortGun" if clip_name=="fire_port" else "StarboardGun"
				for path in paths: check(bank in path,id+" bank track leak")
			animation_report[clip_name] = {"seconds":anim.length,"tracks":anim.get_track_count(),"movement":movement,"reset_error":reset_error,"paths":paths}
			player.stop()
		var lo := Vector3.INF
		var hi := -Vector3.INF
		var meshes := 0
		var supported := 0
		var unsupported := []
		for n in nodes:
			if not n is MeshInstance3D: continue
			meshes += 1
			for surface in n.mesh.get_surface_count():
				var mat: Material = n.mesh.surface_get_material(surface)
				if Baker.supports(mat): supported+=1
				else: unsupported.append(str(n.name)+":"+str(surface))
				var arrays: Array = n.mesh.surface_get_arrays(surface)
				for v in arrays[Mesh.ARRAY_VERTEX]:
					var q: Vector3 = model.global_transform.affine_inverse()*n.global_transform*v
					lo=lo.min(q);hi=hi.max(q)
		var expected: Dictionary = manifest[id].geometry
		var bmin: Array = expected.bounds_min
		var bmax: Array = expected.bounds_max
		var want_lo := Vector3(bmin[0],bmin[2],-bmax[1])
		var want_hi := Vector3(bmax[0],bmax[2],-bmin[1])
		var bounds_error := maxf(lo.distance_to(want_lo),hi.distance_to(want_hi))
		check(bounds_error<0.001,id+" bounds/axis mismatch")
		var movable := true
		var marker_report := {}
		for n in nodes:
			if not n is Node3D or not ("Muzzle" in str(n.name) or "ArrowRelease" in str(n.name)): continue
			var expected_direction := Vector3.FORWARD
			if id=="mortar": expected_direction=Vector3(0,.60,-.53).normalized()
			elif id=="crossfire": expected_direction=[Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT][int(str(n.name).right(1))]
			elif id=="broadside_airship": expected_direction=Vector3.LEFT if "(-1," in str(n.name) else Vector3.RIGHT
			var actual: Vector3 = (model.global_basis.inverse()*(-n.global_basis.z)).normalized()
			check(actual.distance_to(expected_direction)<0.001,id+" muzzle facing mismatch: "+str(n.name))
			if baked_mode: check(n is Marker3D,id+" missing typed muzzle")
			marker_report[str(model.get_path_to(n))]={"forward":str(actual),"position":str(model.to_local(n.global_position))}
		if id=="broadside_airship":
			var ship: Node3D
			var base: Node3D
			for n in nodes:
				if str(n.name).ends_with("__Airship"): ship=n
				if str(n.name).ends_with("__FixedBase"): base=n
			check(ship!=null and base!=null,"ship hierarchy missing")
			if ship and base:
				var pos := base.global_position
				for n in nodes:
					if "Cannon" in str(n.name) or "Muzzle" in str(n.name): movable = movable and ship.is_ancestor_of(n)
				ship.position.x+=1.0
				movable = movable and base.global_position.is_equal_approx(pos)
				ship.position.x-=1.0
			check(movable,"airship cannons not moving with body")
		results[id]={"animations":animation_report,"bounds_error":bounds_error,"meshes":meshes,"baker_supported_surfaces":supported,"baker_unsupported_surfaces":unsupported,"airship_movable":movable,"muzzles":marker_report}
		model.free()
	results["engine"]=Engine.get_version_info()
	results["failures"]=failures
	var f := FileAccess.open("res://godot-baked-check.json" if "--baked" in OS.get_cmdline_user_args() else "res://godot-check.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"));f.close()
	print("ART_SLICE_D_GODOT ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
