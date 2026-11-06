extends SceneTree
const IDS = ["great_ballista","watchtower","barracks","mortar","crossfire","broadside_airship"]
const CENTERS = [Vector3(.35,0,.5),Vector3.ZERO,Vector3.ZERO,Vector3(-.5,0,.5),Vector3(.5,0,-.5),Vector3(0,0,.5)]
var camera: Camera3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800)
	var stage := Node3D.new();root.add_child(stage)
	var world := WorldEnvironment.new();world.environment=load("res://assets/data/rendering/level_environment.tres");stage.add_child(world)
	var sun := DirectionalLight3D.new();sun.light_color=Color(1,.9411765,.8470588);sun.light_energy=1.12;sun.shadow_enabled=true;stage.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO,Vector3(.42261827,-.74240386,-.5198368),Vector3.UP)
	var floor_node := MeshInstance3D.new();var plane := PlaneMesh.new();plane.size=Vector2(100,100);floor_node.mesh=plane
	var floor_mat := StandardMaterial3D.new();floor_mat.albedo_color=Color("a6b6bc");floor_mat.roughness=.88;floor_node.material_override=floor_mat;floor_node.position.y=-.016;stage.add_child(floor_node)
	var angle := deg_to_rad(30.0)
	var right := Vector3(cos(angle),0,-sin(angle));var back := Vector3(-sin(angle),0,-cos(angle))
	for i in IDS.size():
		var model: Node3D = load("res://assets/models/towers/art_slice_d/"+IDS[i]+"_visual.tscn").instantiate()
		stage.add_child(model)
		model.position=right*([-3.15,0,3.15][i%3])+back*((1.85 if i<3 else -1.85)/.7071)-CENTERS[i]
	camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	var target := Vector3(0,.5,0)
	camera.look_at_from_position(target+Vector3(sin(angle)*.70710678,.70710678,cos(angle)*.70710678)*35,target,Vector3.UP)
	for size in [18.5,7.2]:
		camera.size=size
		await process_frame;await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://godot_game_scale.png" if size>10 else "res://godot_family.png"
		var image := root.get_texture().get_image()
		assert(image.save_png(path)==OK)
	print("GODOT_RENDER_PASS");quit()
