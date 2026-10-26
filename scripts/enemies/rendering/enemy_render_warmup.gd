extends Node
## Presentation-only representatives; never enter the wave or consume routes/RNG.
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")

func prepare(renderer: MultiMeshInstance3D, profiles: Array[Troop], completed: Callable) -> int:
	if DisplayServer.get_name() == "headless":
		for profile in profiles: completed.call(profile)
		return OK
	var camera := get_viewport().get_camera_3d()
	if camera == null: return ERR_UNAVAILABLE
	for profile in profiles:
		# Let the host present the current stage before synchronous first-use work.
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		if not _available(renderer) or not is_instance_valid(camera): return ERR_UNAVAILABLE
		var sample := EnemyScene.instantiate() as Node3D
		sample.process_mode = Node.PROCESS_MODE_DISABLED
		sample.troop = profile
		sample.max_health = profile.max_health
		sample.health = profile.max_health
		sample.max_shield = maxf(1.0, profile.max_shield)
		sample.shield = sample.max_shield
		sample.skill_progress = 0.5
		add_child(sample)
		sample.global_position = camera.project_position(get_viewport().get_visible_rect().size*0.5, maxf(camera.near+5.0, 10.0))
		renderer.add_enemy(sample)
		for frame in 2:
			sample.travelled_distance += 0.05
			renderer._process(1.0/60.0)
			renderer.status_overlay._process(0.0)
			await RenderingServer.frame_post_draw
			await get_tree().process_frame
			if not _available(renderer):
				sample.queue_free()
				return ERR_UNAVAILABLE
		renderer.remove_enemy(sample)
		sample.queue_free()
		await get_tree().process_frame
		completed.call(profile)
	return OK

func _available(renderer: Node) -> bool:
	return is_instance_valid(renderer) and renderer.is_inside_tree() and not renderer.is_queued_for_deletion()
