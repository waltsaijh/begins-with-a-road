extends SceneTree
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0

func _initialize() -> void: verify.call_deferred()

func capture() -> Image:
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func verify() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Pixel comparison requires a rendered window")
		quit(1)
		return
	root.size = Vector2i(640,640)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = load("res://assets/data/rendering/level_environment.tres")
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.7
	camera.position = Vector3(0.65,0.45,1)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0.22,0))
	camera.make_current()
	var batch := Batch.new()
	scene.add_child(batch)
	batch.set_process(false)
	batch.status_overlay.hide()
	var results := []
	for id in ["quickfeet","heavy"]:
		var profile := TroopCatalog.find(id)
		var center := Vector3(0,profile.gpu_model.rest_height*0.5,0)
		camera.size = maxf(0.7,profile.gpu_model.rest_height*1.6)
		camera.position = center+Vector3(0.65,0.23,1)
		camera.look_at(center)
		var cpu := profile.model.instantiate() as Node3D
		scene.add_child(cpu)
		var player: AnimationPlayer = cpu.get_node("AnimationPlayer")
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("Walk")
		var enemy := Enemy.instantiate() as Node3D
		enemy.troop = profile
		scene.add_child(enemy)
		enemy.follow(0,{},PackedVector3Array([Vector3.ZERO,Vector3.FORWARD]))
		enemy.set_process(false)
		batch.add_enemy(enemy)
		var appearance: RefCounted = batch._appearances[0]
		var view: MultiMeshInstance3D = appearance.batch.view
		for fraction in [0.0,0.173,0.647]:
			player.seek(fraction*profile.gpu_model.clip_length,true)
			appearance.clip_phase = fraction*TAU
			batch.update_enemy(enemy)
			view.hide()
			cpu.show()
			var reference := await capture()
			cpu.hide()
			view.show()
			var actual := await capture()
			var name: String = id+"_"+str(roundi(fraction*1000))
			reference.save_png(Artifacts.path("enemies/gpu_batches/"+name+"_cpu.png"))
			actual.save_png(Artifacts.path("enemies/gpu_batches/"+name+"_gpu.png"))
			var difference := 0.0
			var foreground := 0
			var background := reference.get_pixel(0,0)
			for y in reference.get_height():
				for x in reference.get_width():
					var a := reference.get_pixel(x,y)
					var b := actual.get_pixel(x,y)
					if a.is_equal_approx(background) and b.is_equal_approx(background): continue
					foreground += 1
					difference += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
			var mean_error := difference/maxi(1,foreground)
			results.append({"model":id,"phase":fraction,"mean_rgb_error":mean_error,"foreground_pixels":foreground})
			if foreground < 1000 or mean_error > 0.01:
				failures += 1
				push_error("GPU appearance differs: "+name+" error="+str(mean_error))
		enemy.free()
		cpu.free()
	var result := {"failures":failures,"poses":results}
	FileAccess.open(Artifacts.path("enemies/gpu_render.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	print("ENEMY_GPU_RENDER_CHECK:"+JSON.stringify(result))
	scene.free()
	quit(int(failures>0))
