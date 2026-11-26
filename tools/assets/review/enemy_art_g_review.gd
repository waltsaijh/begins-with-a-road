extends Node3D
## Lines up the Art Slice G enemies next to the old Rats model for scale; F6 to view.
const TROOPS := ["heavy", "quickfeet", "soldier", "rook", "bloodmage", "scout", "bomber", "winged"]

func _ready() -> void:
	var x := -4.2
	for troop: String in TROOPS:
		var model: Node3D = (load("res://assets/models/enemies/art_g/%s.tscn" % troop) as PackedScene).instantiate()
		model.position = Vector3(x, 0, 0)
		add_child(model)
		x += 1.4
	var rats: Node3D = (load("res://assets/models/enemies/art_g/rats.tscn") as PackedScene).instantiate()
	rats.position = Vector3(x, 0, 0)
	add_child(rats)
	var cam := Camera3D.new(); cam.position = Vector3(0.3, 1.6, -7.5); cam.fov = 50
	add_child(cam); cam.look_at(Vector3(0.3, 0.6, 0))
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); sun.light_energy = 1.0
	add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.45
	add_child(env)
	var ground := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(14, 6); ground.mesh = plane
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.56, 0.68, 0.36); ground.material_override = gm
	add_child(ground)
	if "--shot" in OS.get_cmdline_user_args():
		for i in 4: await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://")
		img.save_png("/tmp/enemy_art_g.png")
		get_tree().quit()
