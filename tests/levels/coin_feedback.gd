extends SceneTree
const Fixture = preload("res://tests/fixtures/level_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func wait_real(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout
	await process_frame

func active(feedback: Control) -> Array:
	return feedback.entries.filter(func(entry): return entry.age < feedback.LIFETIME)

func verify() -> void:
	root.size = Vector2i(1152,648)
	var definition := Fixture.level("")
	definition.acts[0].waves[0].groups[0].enemy_count = 20
	definition.acts[0].waves.append(definition.acts[0].waves[0].duplicate(true))
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	scene.level = definition
	root.add_child(scene)
	current_scene = scene
	for i in 25: await process_frame
	var feedback: Control = scene.get_node("LevelHUD/CoinFeedback")
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var camera := root.get_camera_3d()
	camera.set_process(false)
	camera.set_physics_process(false)
	var center: Vector3 = camera.project_position(Vector2(576,324),15)
	feedback.show_gain(center,1)
	await wait_real(0.09)
	check(active(feedback).size() == 1,"Single gain appears")
	var entry: Dictionary = active(feedback)[0]
	var age: float = entry.age
	feedback.show_gain(center,4)
	check(active(feedback).size() == 1 and entry.amount == 5 and entry.age == age,"Nearby gains merge without restarting lifetime")
	check(entry.view.get_node_or_null("Amount") == null and entry.view.get_child_count() == 1,"Popup contains one coin and no number")
	var coin: Control = entry.view.get_node("Coin")
	var actual_age: float = entry.age
	entry.age = 0.0
	feedback._position(entry,camera)
	var face_width: float = absf(coin.scale.x)
	entry.age = feedback.LIFETIME*0.25
	feedback._position(entry,camera)
	check(absf(coin.scale.x) < face_width*0.15 and coin.pivot_offset == coin.size*0.5,"Coin turns edge-on about its center diameter")
	entry.age = feedback.LIFETIME*0.5
	feedback._position(entry,camera)
	check(coin.scale.x < -0.9,"Coin reveals its reverse side during ascent")
	entry.age = actual_age
	feedback._position(entry,camera)
	var before: Vector2 = entry.view.position
	camera.position.x += 0.5
	await process_frame
	feedback._process(0)
	check(entry.view.position.distance_to(before) > 1,"Popup reprojects after camera moves")
	var original_size: Vector2 = entry.view.size
	camera.size *= 1.3
	await process_frame
	check(entry.view.size == original_size,"Camera zoom preserves UI dimensions")
	paused = true
	age = entry.age
	await wait_real(0.15)
	check(is_equal_approx(entry.age,age),"Pause freezes lifetime")
	paused = false
	await wait_real(0.2)
	feedback.show_gain(center,1)
	check(active(feedback).size() == 2,"A gain outside the initial 0.25 second window starts a new popup")
	await wait_real(0.36)
	check(entry.age >= 0.6,"Merge never extends initial lifetime")
	feedback.clear()
	if DisplayServer.get_name() != "headless":
		feedback.show_gain(center,5)
		await wait_real(0.08)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(Artifacts.path("levels/coin_popup.png"))
		feedback.clear()
	for pixel in [Vector2(140,240),Vector2(300,240),Vector2(460,240),Vector2(620,240),Vector2(780,240),Vector2(940,240)]:
		feedback.show_gain(camera.project_position(pixel,15),1)
	check(active(feedback).size() == 6 and feedback.get_child_count() == 6,"Pool contains at most six reused views")
	feedback.show_gain(camera.project_position(Vector2(1080,440),15),7)
	check(active(feedback).size() == 6,"Distant overflow is omitted")
	feedback.show_gain(camera.project_position(Vector2(140,240),15),3)
	check(active(feedback)[0].amount == 4,"Nearby overflow still merges")
	feedback.clear()
	feedback.show_gain(camera.project_position(Vector2(1,1),15),1)
	await wait_real(0.09)
	check(Rect2(Vector2.ZERO,feedback.size).encloses(active(feedback)[0].view.get_global_rect()),"Edge popup stays inside viewport")
	feedback.clear()
	var wave: Node = scene.get_node("EnemyWave")
	wave.start_allowed = true
	check(wave.start_wave(),"Real wave starts")
	wave._process(0)
	var enemies: Array[Node3D] = wave.living_enemies()
	check(enemies.size() == 20,"Real death fixture has twenty enemies")
	var initial: int = shop.coins
	enemies[0].take_damage(100000)
	enemies[0].take_damage(100000)
	check(shop.coins == initial+1 and scene.total_kills == 1,"A real death pays exactly once")
	for i in range(1,enemies.size()): enemies[i].take_damage(100000)
	check(shop.coins == initial+20+definition.acts[0].waves[0].reward,"All kills and original wave reward pay in full")
	check(scene.get_node("LevelHUD/Header/Balance/Amount").text == str(shop.coins),"HUD remains synchronized")
	check(active(feedback).size() <= 6,"Mass death remains bounded")
	var wallet: Label = scene.get_node("LevelHUD/Header/Balance/Amount")
	var motion: Tween = feedback._wallet_motion
	var wallet_rect := wallet.get_rect()
	shop.grant_gold(2,"test_reward")
	check(feedback._wallet_motion == motion,"Burst income reuses one HUD feedback")
	await wait_real(0.3)
	check(wallet.scale.is_equal_approx(Vector2.ONE) and wallet.get_rect() == wallet_rect,"HUD returns to exact original layout")
	var audio: Node = root.get_node("GameAudio")
	check(audio._effects[&"gain_gold"].bus == &"Combat" and audio._effects[&"gain_gold"].max_polyphony == 1,"Gold sound uses combat volume and one voice")
	var ready: int = audio._gold_ready_usec
	audio.play_gold()
	check(audio._gold_ready_usec == ready,"Burst sound is throttled")
	check(not audio.GAIN_GOLD.loop and audio.GAIN_GOLD.get_length() > 0,"Provided gold cue decodes without looping")
	paused = true
	await process_frame
	check(audio._effects[&"gain_gold"].stream_paused,"Pause freezes reward sound")
	paused = false
	feedback.clear()
	Engine.time_scale = 4.0
	feedback.show_gain(center,1)
	await wait_real(0.3)
	check(active(feedback).size() == 1,"Four-times speed does not shorten popup lifetime")
	await wait_real(0.34)
	check(active(feedback).is_empty(),"Popup expires in real time")
	Engine.time_scale = 1.0
	scene.queue_free()
	await wait_real(0.15)
	check(not audio._effects[&"gain_gold"].playing,"Leaving level stops reward sound")
	print("COIN_FEEDBACK: checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
