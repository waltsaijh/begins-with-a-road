extends Node
var failures: Array[String] = []
var output := "res://.godot/phase5/defeat-input"
func _ready() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(event,true)
	await get_tree().process_frame
func verify() -> void:
	check(DisplayServer.get_name() != "headless","Defeat input evidence requires real rendering")
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	scene.level = scene.level.duplicate(true)
	scene.level.base_health = 1 # Explicit loss fixture; normal Frontier remains 20.
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.6).timeout
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	await click(hud.speed_button)
	await click(hud.speed_button)
	check(Engine.time_scale == 4.0,"Real speed clicks reach 4x")
	await click(hud.start_callouts[0].get_node("Title"))
	check(scene._wave_starting,"Real start click enters opening delay")
	for frame in 3000:
		if scene.finished: break
		await get_tree().process_frame
	check(scene.finished and not scene.victory and scene.total_leaks == 1,"Actual movement to goal ends run in defeat")
	await get_tree().create_timer(0.5,true,false,true).timeout
	check(scene.get_node("EnemyWave").alive == 0 and scene.get_node("EnemyWave")._pending.is_empty(),"Loss cleans living and pending enemies")
	check(scene.get_node("CardPlacement/Shop").coins == 9,"Loss gives no completion Gold")
	check(not scene.run_status.get_node("Result/Confetti")._started and not GameAudio._victory_pending and not GameAudio._victory.playing,"Defeat must not trigger victory confetti or the victory cue")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/defeat.png")
	await click(scene.run_status.get_node("Result/Center/Panel/Margin/Column/Restart"))
	for frame in 8: await get_tree().process_frame
	var restarted: Node = get_tree().current_scene
	check(restarted != scene and restarted.current_wave == 0 and restarted.base_health == restarted.level.base_health and restarted.level.progress_id() == "frontier" and Engine.time_scale == 1.0,"Defeat restart reloads the selected Frontier fixture and resets speed")
	get_tree().current_scene = self
	restarted.queue_free()
	await get_tree().process_frame
	print("PHASE5_DEFEAT_INPUT ",JSON.stringify({"failures":failures,"normal_scene_processing":true,"real_mouse":true}))
	get_tree().quit(0 if failures.is_empty() else 1)
