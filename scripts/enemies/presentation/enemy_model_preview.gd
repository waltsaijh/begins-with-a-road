extends SubViewportContainer
## A display instance in its own world; never spawns a gameplay enemy or tower.
## A nonzero spin turns the model around its own center.
@export var spin_degrees_per_second := 0.0
var model: Node3D
var _pivot: Node3D

func display(profile: Troop) -> void:
	if profile == null or profile.model == null:
		display_node(null)
		return
	var instance: Node3D = profile.model.instantiate()
	instance.scale = profile.model_scale
	instance.position = profile.model_offset
	instance.rotation_degrees = profile.model_rotation_degrees
	display_node(instance)

func display_node(instance: Node3D) -> void:
	if _pivot != null:
		_pivot.free()
		_pivot = null
	model = instance
	if model == null:
		$Viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	model.process_mode = Node.PROCESS_MODE_DISABLED
	_pivot = Node3D.new()
	$Viewport.add_child(_pivot)
	_pivot.add_child(model)
	var bounds := AABB()
	var found := false
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var box := mesh.global_transform*mesh.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	if not found: bounds = AABB(Vector3(-0.5,0,-0.5),Vector3.ONE)
	var center := bounds.get_center()
	var extent := maxf(0.5,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)))
	if not is_zero_approx(spin_degrees_per_second):
		# Every turn must fit, so frame the footprint diagonal.
		extent = maxf(extent,Vector2(bounds.size.x,bounds.size.z).length())
		_pivot.position = Vector3(center.x,0.0,center.z)
		model.position -= _pivot.position
	var camera: Camera3D = $Viewport/Camera
	camera.size = extent*1.65
	camera.position = center+Vector3(3,1.8,4).normalized()*extent*3.0
	camera.look_at(center)
	$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_zero_approx(spin_degrees_per_second) else SubViewport.UPDATE_WHEN_VISIBLE

func _process(delta: float) -> void:
	if _pivot != null: _pivot.rotate_y(deg_to_rad(spin_degrees_per_second)*delta)
