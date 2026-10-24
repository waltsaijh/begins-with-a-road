extends SceneTree
const Baker = preload("res://tools/assets/solid_mesh_baker.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
func _initialize(): verify.call_deferred()
func check(value: bool, message: String):
	if not value:
		failures += 1
		push_error(message)
func verify():
	var library := load("res://assets/models/mesh_library.tres") as MeshLibrary
	var counts := []
	for id in library.get_item_list():
		var mesh := library.get_item_mesh(id)
		var solids := 0
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface)
			check(not mat is StandardMaterial3D,"World library retained color materials")
			if mat == Baker.MATERIAL: solids += 1
		check(solids == 1,"Tile did not merge opaque colors into one surface")
		check(Baker.mesh(mesh)==mesh,"Rebaking a settled library item needlessly repacked normals")
		counts.append({"id":id,"surfaces":mesh.get_surface_count()})
	for path in ["sentry_base","sentry_weapon"]:
		check(load("res://assets/models/towers/"+path+"_mesh.res").surface_get_material(0)==Baker.MATERIAL,"Tower does not use shared material")
	for id in ["soldier","quickfeet","heavy"]:
		var gpu = preload("res://scripts/enemies/rendering/enemy_model.gd").gpu_for(TroopCatalog.find(id))
		check(gpu.material()==Baker.MATERIAL and gpu.mesh.surface_get_material(0)==Baker.MATERIAL,"Enemy material is not shared")
		check(Baker.gait(gpu.mesh,gpu)==gpu.mesh,"Unchanged gait was needlessly repacked")
		var arrays: Array = gpu.mesh.surface_get_arrays(0)
		var data: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var limb: float = arrays[Mesh.ARRAY_TEX_UV][i].x
			check(is_equal_approx(data[i*4],signf(limb)*(-gpu.arm_swing if absf(limb)>1.5 else gpu.leg_swing)) and is_equal_approx(data[i*4+1],gpu.body_bob) and is_equal_approx(data[i*4+2],gpu.body_sway) and data[i*4+3]==gpu.keyframe_intervals+1,"Baked gait differs from model configuration")
	var special := StandardMaterial3D.new()
	special.roughness=0.98
	special.metallic_specular=0.12
	check(Baker.supports(special),"Default opaque palette rejected")
	special.emission_enabled=true
	check(not Baker.supports(special),"Emission was flattened")
	special.emission_enabled=false
	special.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	check(not Baker.supports(special),"Transparency was flattened")
	var errors := []
	if DisplayServer.get_name()!="headless": errors = await pixels()
	var result := {"failures":failures,"tiles":counts,"pixel_errors":errors}
	FileAccess.open(Artifacts.path("rendering/shared_material/functional.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	print("SOLID_MATERIAL_CHECK:",JSON.stringify(result))
	quit(int(failures>0))
func pixels() -> Array:
	root.size=Vector2i(640,640)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment=load("res://assets/data/rendering/level_environment.tres")
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,-25,0)
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.5
	camera.position=Vector3(2,2,3)
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	var node := MeshInstance3D.new()
	world.add_child(node)
	var errors := []
	for color in [Color("c8bda2"),Color("d2c6ab"),Color("594c43"),Color("a16459"),Color("ad8760")]:
		var material := StandardMaterial3D.new()
		material.albedo_color=color
		material.roughness=0.98
		material.metallic_specular=0.12
		if color==Color("ad8760"):
			material.roughness=1.0
			material.metallic_specular=0.08
		var box := BoxMesh.new()
		box.material=material
		node.mesh=box
		var original := await capture()
		node.mesh=Baker.mesh(box)
		var converted := await capture()
		var error := 0.0
		var count := 0
		var background := original.get_pixel(0,0)
		for y in 640:
			for x in 640:
				var a := original.get_pixel(x,y)
				var b := converted.get_pixel(x,y)
				if a.is_equal_approx(background) and b.is_equal_approx(background): continue
				count += 1
				error += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3
		error /= maxi(1,count)
		errors.append(error)
		check(count>1000 and error<0.003,"Static palette pixel difference: "+str(error))
		original.save_png(Artifacts.path("rendering/shared_material/color_"+color.to_html()+"_before.png"))
		converted.save_png(Artifacts.path("rendering/shared_material/color_"+color.to_html()+"_after.png"))
	world.free()
	return errors
func capture() -> Image:
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
