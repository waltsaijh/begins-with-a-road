extends SubViewportContainer
## A static display instance in its own world; never spawns a gameplay enemy.
var model: Node3D

func display(profile: Troop) -> void:
	if model != null:
		model.free()
		model = null
	if profile == null or profile.model == null: return
	model = profile.model.instantiate()
	model.process_mode = Node.PROCESS_MODE_DISABLED
	$Viewport.add_child(model)
	model.scale = profile.model_scale
	model.position = profile.model_offset
	model.rotation_degrees = profile.model_rotation_degrees
	var bounds := AABB()
	var found := false
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		var box := mesh.global_transform*mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found: bounds = AABB(Vector3(-0.5,0,-0.5),Vector3.ONE)
	var center := bounds.get_center()
	var extent := maxf(0.5,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)))
	var camera: Camera3D = $Viewport/Camera
	camera.size = extent*1.65
	camera.position = center+Vector3(3,1.8,4).normalized()*extent*3.0
	camera.look_at(center)
	$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
