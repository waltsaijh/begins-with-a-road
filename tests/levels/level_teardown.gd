extends Node
## Exercise the same tree-exiting callbacks as closing a running game window.
var failures := 0
var cases := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	push_error(message)

func definition() -> LevelDefinition:
	var level := LevelDefinition.new()
	level.expand_starts_after_act = false
	level.use_terrain_endpoints = false
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-12, 0, -0.5)
	for x in 24: terrain.set_cell_item(Vector3i(x, 0, 0), 3)
	level.terrain = PackedScene.new()
	level.terrain.pack(terrain)
	terrain.free()
	var act := ActDefinition.new()
	for i in 2:
		var wave := WaveDefinition.new()
		var group := WaveSpawnGroup.new()
		group.troop = TroopCatalog.find("soldier")
		group.enemy_count = 3
		group.batch_size = 3
		group.interval_ticks = 0
		wave.groups = [group]
		act.waves.append(wave)
	level.acts = [act]
	return level

func setup_case(speed: float, via_button: bool, phase: String) -> Node3D:
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.level = definition()
	add_child(scene)
	for i in 120:
		if not scene.get_node("PortalMap").computing: break
		await get_tree().process_frame
	var wave: Node = scene.get_node("EnemyWave")
	check(wave.controller.plan.get("reachable", false), "Teardown fixture failed to prepare")
	scene.set_process(false)
	wave.set_process(false)
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	scene.get_node("TowerMap").combat.enabled = false
	Engine.time_scale = speed
	if via_button:
		scene._on_start_requested()
	else:
		scene._begin_wave_start()
	scene.set_process(false)
	check(scene._wave_starting and not wave.active, "Wave skipped its start delay")
	if phase != "start_delay":
		scene._advance_wave_start(scene.WAVE_START_SECONDS)
		check(wave.active, "Wave did not start")
		if phase == "live":
			wave._process(0.0)
			check(wave.alive == 3 and wave._pending.is_empty(), "Last-enemy exit scenario has no live enemies or still has pending spawns")
	return scene

func verify() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--window-close" in arguments:
		var scene := await setup_case(4.0 if "--4x" in arguments else 2.0, not "--direct" in arguments, "live")
		check(scene.get_node("EnemyWave").alive == 3, "Close-window fixture has no live wave")
		print("LEVEL_TEARDOWN_WINDOW_READY:"+JSON.stringify({"speed": Engine.time_scale, "via_button": not "--direct" in arguments, "alive": 3}))
		return # Host closes the real window after this marker.
	if "--repro" in arguments:
		var scene := await setup_case(2.0, true, "live")
		remove_child(scene)
		check(scene.current_wave == 0, "Scene removal advanced the level")
		scene.free()
		print("LEVEL_TEARDOWN_REPRO:"+JSON.stringify({"failures": failures}))
		get_tree().quit(1 if failures else 0)
		return
	for speed: float in [1.0, 2.0, 3.0, 4.0]:
		for via_button: bool in [false, true]:
			for phase: String in ["start_delay", "pending", "live"]:
				for disposal: String in ["remove", "queue_free"]:
					var scene := await setup_case(speed, via_button, phase)
					if disposal == "remove":
						remove_child(scene)
						check(scene.current_wave == 0 and not scene.finished, "Teardown advanced the level: %s/%s/%s" % [speed, via_button, phase])
						scene.free()
					else:
						scene.queue_free()
					await get_tree().process_frame
					cases += 1
	# An independently detached HUD must tolerate late calls and tween setters.
	var scene := await setup_case(2.0, true, "live")
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	var camera: Camera3D = scene.get_node("Camera3D")
	hud.set_paused(true)
	hud.open_settings()
	check(camera._navigation_locked, "Settings did not lock navigation before HUD removal")
	scene.remove_child(hud)
	check(not camera._navigation_locked and not get_tree().paused, "Detached HUD retained the settings navigation lock or pause state")
	hud.set_start_available(true)
	hud._position_callout()
	for enemy: Node3D in scene.get_node("EnemyWave").living_enemies(): enemy.free()
	check(scene.current_wave == 0, "Detached HUD still allowed a next-wave transition")
	scene.free()
	hud.free()
	# Normal wave completion still advances once and awards its configured reward.
	scene = await setup_case(2.0, true, "live")
	var wave: Node = scene.get_node("EnemyWave")
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var before: int = shop.coins
	var reward: int = shop.wave_reward
	for enemy: Node3D in wave.living_enemies(): enemy.take_damage(100000)
	check(scene.current_wave == 1 and not scene.finished and not wave.active, "Normal completion stopped advancing the level")
	check(shop.coins == before+reward, "Normal completion lost or duplicated its reward")
	scene.queue_free()
	await get_tree().process_frame
	print("LEVEL_TEARDOWN_CHECK:"+JSON.stringify({"failures": failures, "cases": cases, "speeds": [1, 2, 3, 4], "button_and_internal_start": true, "delay_pending_live": true, "remove_and_queue_free": true, "detached_hud": true, "normal_completion": true}))
	get_tree().quit(1 if failures else 0)
