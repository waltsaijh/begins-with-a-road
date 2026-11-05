extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []
var checks := 0
var scene: Node3D
func _ready() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame
func wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds,true,false,true).timeout
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("ui_slice_a/"+name+".png"))
func click(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	await frames(2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event,true)
		await frames(2)

func hover_capture(control: Control, local_point: Vector2, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_transform_with_canvas()*local_point
	get_viewport().push_input(motion,true)
	await wait_real(0.8)
	await capture(name)
func run() -> void:
	var old_path: String = LevelProgress.save_path
	var old_completed: Dictionary = LevelProgress._completed.duplicate()
	var old_enemies: Dictionary = LevelProgress._encountered.duplicate()
	var path := Artifacts.path("ui_slice_a/progress.cfg")
	# A v1 save without a codex must stay readable, including unknown sections.
	var legacy := ConfigFile.new()
	legacy.set_value("progress","version",1)
	legacy.set_value("progress","completed",PackedStringArray(["older_level"]))
	legacy.set_value("future","keep","yes")
	legacy.save(path)
	check(LevelProgress.load_progress(path) == OK and LevelProgress.snapshot().has("older_level") and not LevelProgress.enemy_unlocked("quickfeet"),"v1 save loads with empty codex")
	scene = load("res://scenes/level.tscn").instantiate()
	add_child(scene)
	await frames(12)
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var hud: Node = scene.get_node("LevelHUD")
	var wave: Node = scene.get_node("EnemyWave")
	var guide: Node = scene.enemy_intelligence
	var timeline: Control = hud.get_node("Header/WaveTimeline")
	var choice: Node = scene.relic_choice
	var relics: RunRelics = scene.get_node("TowerMap").relics
	var integrity: Button = scene.run_status.get_node("Integrity")
	check(integrity.icon != null and integrity.text == "20" and integrity.tooltip_text.contains("20 / 20"),"defense uses an icon and number with full health on hover")
	var header_y: float = hud.speed_button.get_global_rect().get_center().y
	for control: Control in [integrity,hud.get_node("Header/Balance"),guide.toggle,choice.get_node("RelicBar")]:
		check(absf(control.get_global_rect().get_center().y-header_y) <= 3,"status control shares the top row: "+str(control.name))
	check(absf(timeline.global_position.y+43-header_y) <= 3,"timeline markers share the status row")
	check(is_equal_approx(hud.status_row_rect.get_center().x,get_viewport().get_visible_rect().size.x*0.5),"compact status group is centered")
	check(not hud.get_node("Header/Balance").tooltip_text.is_empty() and not hud.speed_button.tooltip_text.is_empty() and not hud.pause_button.tooltip_text.is_empty(),"gold/speed/pause expose hover explanations")
	check(timeline.reward_indices() == PackedInt32Array([2,5,8,11]),"formal timeline marks exactly four relic choices")
	var final_reward_level: LevelDefinition = scene.level.duplicate(true)
	final_reward_level.reward_final_act = true
	timeline.configure(final_reward_level)
	check(timeline.reward_indices() == PackedInt32Array([2,5,8,11,14]) and is_equal_approx(timeline.reward_fraction(14),1.0),"optional final ACT reward has its own final milestone")
	timeline.configure(scene.level)
	var compact: Array = timeline.compact_entries()
	check(compact.any(func(entry): return entry.reward),"compact horizon includes its ACT relic choice")
	check(timeline._get_tooltip(timeline.compact_point(0,compact.size())).contains("1 / 15"),"compact wave node explains global progress")
	check(timeline._get_tooltip(timeline.compact_point(3,compact.size())).contains("ACT I"),"compact relic icon explains its ACT reward")
	check(scene.level.wave_count() == 15 and scene.level.acts.size() == 5,"formal five ACT/fifteen waves unchanged")
	check(guide.seen.is_empty() and guide.pending.is_empty(),"preparation does not discover future troops")
	check(not choice.get_node("RelicBar").visible,"empty relic bar has no empty slots")
	check(shop.offers.size() == 4 and shop.view.slots.size() == 5,"opening shop four offers plus reroll")
	for i in 20:
		var offers: Array = shop.roll_offers()
		check(offers.size() == 4 and offers.all(func(card): return card.tower != null and card.traffic == null),"normal deals contain only four towers")
	var towers: Array = shop.catalog.duplicate()
	shop.catalog.clear()
	check(shop.roll_offers().is_empty() and not shop.traffic_catalog.is_empty(),"support cannot rescue an invalid tower pool")
	shop.catalog.assign(towers)
	var relic: RelicDefinition = relics.catalog.find(&"global_damage")
	var state: int = relics._rng.state
	check(relics.acquire(relic) and relics.acquire(relic),"repeatable relic can stack")
	check(relics.held[relic.id] == 2 and choice.get_node("RelicBar/Items").get_child_count() == 1,"one icon reflects stacked count")
	check(choice.get_node("RelicBar/Items").get_child(0).tooltip_text.contains(tr(relic.description_key)),"tooltip includes effect")
	check(relics._rng.state == state,"relic UI consumes no reward RNG")
	shop.open_shop()
	shop.view.finish_animation()
	await wait_real(0.4)
	await capture("compact_shop_relics")
	await hover_capture(integrity,integrity.size*0.5,"health_tooltip")
	var wallet: int = shop.coins
	var fee: int = shop.reroll_price
	check(shop.reroll() and shop.coins == wallet-fee and shop.offers.size() == 4,"reroll four cards charges original fee")
	check(not shop.reroll(),"reroll animation blocks duplicate charge")
	shop.view._stop_reroll_animation()
	shop.view.finish_animation()
	shop.close_shop()
	var center := timeline.get_global_rect().get_center()
	var left_before: float = integrity.position.x
	var right_before: float = hud.get_node("Header/Actions").position.x
	if DisplayServer.get_name() == "headless": timeline.set_expanded(true)
	else:
		var hover := InputEventMouseMotion.new()
		hover.position = center
		get_viewport().push_input(hover,true)
	await wait_real(0.24)
	check(timeline.expanded and timeline.expansion > 0.99 and timeline.size.x > 300,"hover smoothly expands all ACTs")
	check(integrity.position.x < left_before and hud.get_node("Header/Actions").position.x > right_before,"both icon groups move outward with timeline expansion")
	check(is_equal_approx(hud.status_row_rect.get_center().x,get_viewport().get_visible_rect().size.x*0.5),"expanded status group remains centered")
	check(absf(hud.get_node("Header/Actions").position.x-timeline.get_global_rect().end.x-16.0) < 0.1,"expansion preserves the gap beside the timeline")
	check(timeline.get_node("Rewards").get_child_count() == 4 and timeline._get_tooltip(Vector2(timeline.size.x*timeline.reward_fraction(2),43)).contains("ACT I"),"expanded timeline has four relic icons with hover details")
	await capture("expanded_timeline")
	if DisplayServer.get_name() != "headless":
		await click(timeline)
		check(timeline._pinned,"real click pins timeline open")
	else: timeline._pinned = true
	timeline.mouse_exited.emit()
	await wait_real(0.24)
	check(timeline.expanded,"click latch survives pointer exit")
	await hover_capture(timeline,Vector2(timeline.size.x*timeline.reward_fraction(2),43),"relic_node_tooltip")
	timeline._pinned = false
	timeline.mouse_exited.emit()
	await wait_real(0.24)
	check(not timeline.expanded and timeline.size.x == 300 and center.is_equal_approx(timeline.get_global_rect().get_center()),"compact timeline retains center")
	var anchor: Vector2 = timeline.position
	timeline.set_state(6,0.5,true)
	check(timeline.position == anchor and scene.current_wave == 0,"progress display does not move HUD or advance simulation")
	timeline.set_state(0,0,false)
	timeline.set_state(2,1,true)
	scene.choosing_relic = true
	timeline.set_reward_active(true)
	check(timeline.compact_entries()[0].reward,"current relic choice is first in the compact horizon")
	await capture("relic_milestone_active")
	scene.choosing_relic = false
	timeline.set_reward_active(false)
	timeline.set_state(0,0,false)
	# Opening an icon from gameplay and from an already-paused HUD restores each state.
	Engine.time_scale = 2.0
	choice.open_collection(relic)
	check(get_tree().paused and hud.inspection_owner == choice,"relic detail uses HUD pause ownership")
	await capture("relic_detail")
	guide.open_codex()
	check(not guide.panel.visible,"another detail panel cannot steal the pause lease")
	choice.close_collection()
	check(not get_tree().paused and not hud.pause_requested and Engine.time_scale == 2.0,"detail restores gameplay and speed")
	hud.set_paused(true)
	await wait_real(0.4)
	await capture("pause_codex_entry")
	if DisplayServer.get_name() == "headless": hud.get_node("PauseBlocker/Menu/Margin/Actions/Codex/Button").pressed.emit()
	else: await click(hud.get_node("PauseBlocker/Menu/Margin/Actions/Codex/Button"))
	check(guide.panel.visible and guide.title.text == "???","codex conceals undiscovered enemies")
	guide.close_panel()
	check(get_tree().paused and hud.pause_requested and hud.pause_menu.get_node("Menu").visible,"closing codex restores prior pause menu")
	hud.set_paused(false)
	# Also preserve a pause requested outside the HUD.
	get_tree().paused = true
	Engine.time_scale = 4.0
	guide.open_codex()
	guide.close_panel()
	check(get_tree().paused and Engine.time_scale == 4.0 and not hud.pause_requested,"external pause is preserved")
	get_tree().paused = false
	Engine.time_scale = 1.0
	# Actual formal first-wave spawn, not the preview/recipe, triggers discovery.
	scene._on_start_requested()
	scene._advance_wave_start(1.5)
	wave._process(6.1)
	check(wave.active and guide.seen.has("quickfeet") and guide.pending.size() == 1 and not get_tree().paused,"actual spawn queues a single nonblocking notice")
	var spawned: int = wave.spawned
	var focus := get_viewport().gui_get_focus_owner()
	guide._on_enemy_spawned(wave.living_enemies()[0])
	check(guide.pending.size() == 1 and get_viewport().gui_get_focus_owner() == focus,"repeated enemy neither duplicates nor steals focus")
	# Spawn two additional real enemy instances on existing frozen test routes.
	for id in ["soldier","heavy"]:
		var profile := TroopCatalog.find(id)
		var batch: Dictionary = scene.get_node("PortalMap").prepare_route_batch(profile,1)
		var route: Dictionary = batch.routes[0]
		var points: PackedVector3Array = preload("res://scripts/enemies/spawning/route_waypoints.gd").for_route(route,scene.get_node("TileMap"),{},0)
		wave._spawn_entry({"id":10000+wave.spawned,"profile":profile,"route":route,"points":points,"health":profile.max_health,"shield":profile.max_shield,"speed":0.1})
	check(guide.pending.size() == 3 and guide.read.is_empty(),"multiple actual enemy types queue separately from read state")
	await frames(4)
	await capture("discovery_notice")
	if DisplayServer.get_name() == "headless": guide.open_notifications()
	else: await click(guide.toggle)
	check(guide.panel.visible and get_tree().paused and guide.selected.troop_name == "quickfeet","click notice opens first discovered enemy and pauses")
	check(guide.layout.get_node("Close").get_theme_color("font_focus_color").r < 0.5,"focused close button remains readable")
	check(guide.title.text == TroopCatalog.find("quickfeet").localized_name() and guide.detail.get_node("Appearance/Stats").text.contains("50"),"name and HP come from Troop")
	check(not guide.detail.get_node("Route").text.contains("Softmax"),"route explanation contains no developer algorithm terms")
	check(not guide.read.has("quickfeet") and guide.pending.size() == 3,"notice remains unread until leaving its page")
	await capture("new_enemy_detail")
	guide.close_panel()
	check(guide.panel.visible and guide.selected.troop_name == "soldier" and get_tree().paused,"next enemy uses the same paused page")
	guide.close_panel()
	check(guide.selected.troop_name == "heavy" and guide.pending.size() == 1,"queue advances in encounter order")
	guide.close_panel()
	check(guide.pending.is_empty() and guide.read.size() == 3 and not get_tree().paused,"last close clears read notices and resumes")
	check(wave.spawned >= spawned+2,"UI keeps real spawned enemy instances")
	guide._on_enemy_spawned(wave.living_enemies()[0])
	check(guide.pending.is_empty(),"later appearance does not notify again in this run")
	guide.show_profile(TroopCatalog.find("heavy"))
	check(guide.panel.visible and guide.title.text == TroopCatalog.find("heavy").localized_name(),"read enemy can be reopened in codex")
	for i in 6:
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		get_viewport().push_input(tab,true)
		check(guide.panel.is_ancestor_of(get_viewport().gui_get_focus_owner()),"Tab focus remains inside codex")
	await capture("codex_known")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape,true)
	await frames()
	check(not guide.panel.visible and not get_tree().paused,"Escape closes codex and restores prior state")
	# Responsive layout and all ten real model previews, without gameplay spawns.
	guide.show_profile(TroopCatalog.find("heavy"))
	for profile in TroopCatalog.all():
		LevelProgress.encounter_enemy(profile.troop_name)
		guide.show_profile(profile)
		check(guide.detail.get_node("Appearance/Preview").model != null and not profile.route_description().contains("Softmax"),"catalog preview and player wording: "+profile.troop_name)
	if DisplayServer.get_name() != "headless":
		for extent in [Vector2i(800,600),Vector2i(1600,900)]:
			get_window().size = extent
			await frames(8)
			var paper: Control = guide.get_node("Screen/Panel/Paper")
			check(guide.panel.get_global_rect().encloses(paper.get_global_rect()) and paper.get_global_rect().encloses(guide.layout.get_node("Close").get_global_rect()),"codex and close fit viewport "+str(extent))
			await capture("codex_"+str(extent.x))
		get_window().size = Vector2i(1280,800)
	guide.close_panel()
	check(LevelProgress.mark_completed("new_level") == OK,"level completion can still save")
	var saved := ConfigFile.new()
	saved.load(path)
	check(saved.get_value("future","keep") == "yes" and saved.get_value("progress","completed").has("older_level"),"codex save preserves old completion and unknown sections")
	check(LevelProgress.load_progress(path) == OK and LevelProgress.enemy_unlocked("heavy"),"codex reload preserves unlocks")
	scene.free()
	await frames()
	scene = load("res://scenes/level.tscn").instantiate()
	add_child(scene)
	await frames(8)
	guide = scene.enemy_intelligence
	check(guide.seen.is_empty() and guide.pending.is_empty() and LevelProgress.enemy_unlocked("heavy"),"new run resets notices but retains codex")
	guide.show_profile(TroopCatalog.find("heavy"))
	check(guide.title.text == TroopCatalog.find("heavy").localized_name(),"cross-run known page unlock is retained")
	guide.close_panel()
	scene.free()
	LevelProgress.save_path = old_path
	LevelProgress._completed = old_completed
	LevelProgress._encountered = old_enemies
	get_tree().paused = false
	Engine.time_scale = 1.0
	var result := {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name() != "headless"}
	FileAccess.open(Artifacts.path("ui_slice_a/results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("UI_SLICE_A ",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
