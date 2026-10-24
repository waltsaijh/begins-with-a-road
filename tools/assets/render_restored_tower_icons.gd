extends SceneTree
## Icons are renders of the imported original models, not replacement artwork.
func _initialize() -> void: generate.call_deferred()
func generate() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/towers")
	for key: String in ["mortar","ballista","broadside","crossfire","barracks"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(160,160)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var model: Node3D = load("res://assets/models/towers/"+key+".tscn").instantiate()
		viewport.add_child(model)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.current = true
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.35
		camera.position = Vector3(1.5,1.2,-1.8)
		camera.look_at(Vector3(0,0.45,0))
		var light := DirectionalLight3D.new()
		viewport.add_child(light)
		light.rotation_degrees = Vector3(-55,-35,0)
		var env := WorldEnvironment.new()
		viewport.add_child(env)
		env.environment = Environment.new()
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.65
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://assets/sprites/towers/"+key+".png"
		assert(viewport.get_texture().get_image().save_png(path) == OK)
		viewport.queue_free()
		print("ICON:",key)
	quit()
