extends Node
## Render representatives through the real batch before gameplay becomes interactive.
## No wave entries, route allocation, RNG or combat registration are involved.
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const LoadingOverlay = preload("res://scenes/levels/components/loading_overlay.tscn")

func prepare(renderer: MultiMeshInstance3D, profiles: Array[Troop], world: Node) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := LoadingOverlay.instantiate()
	add_child(overlay)
	# Rendering continues while gameplay, GUI callbacks and camera input are disabled.
	var previous_mode := world.process_mode
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await RenderingServer.frame_post_draw
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var seen := {}
		for profile in profiles:
			if profile == null or seen.has(profile): continue
			seen[profile] = true
		var completed := 0
		for profile: Troop in seen:
			overlay.show_progress(completed, seen.size())
			await RenderingServer.frame_post_draw
			await get_tree().process_frame
			var sample := EnemyScene.instantiate() as Node3D
			sample.troop = profile
			sample.max_health = profile.max_health
			sample.health = profile.max_health
			sample.max_shield = maxf(1.0, profile.max_shield)
			sample.shield = sample.max_shield
			sample.skill_progress = 0.5
			# Keep the sample's simulation disabled even though this node processes always.
			sample.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(sample)
			sample.global_position = camera.project_position(get_viewport().get_visible_rect().size*0.5, maxf(camera.near+5.0, 10.0))
			renderer.add_enemy(sample)
			# Exercise the animation pose and the same overlay used during play.
			for frame in 2:
				sample.travelled_distance += 0.05
				renderer._process(1.0/60.0)
				renderer.status_overlay._process(0.0)
				await RenderingServer.frame_post_draw
				await get_tree().process_frame
			renderer.remove_enemy(sample)
			sample.queue_free()
			await get_tree().process_frame
			completed += 1
			overlay.show_progress(completed, seen.size())
	await overlay.finish()
	world.process_mode = previous_mode
	queue_free()
