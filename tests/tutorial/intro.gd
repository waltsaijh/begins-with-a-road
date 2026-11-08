extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
var failures: Array[String] = []
var viewport: SubViewport
var session: Node3D
func _ready() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame
func mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT) if pressed else 0
	viewport.push_input(event,true)
func motion(point: Vector2, delta: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = delta
	event.button_mask = mask
	viewport.push_input(event,true)
func snapshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var body: Label = session.tutorial.overlay.get_node("Panel/Margin/Rows/Body")
	if body.is_visible_in_tree():
		check(body.get_line_count() == body.text.count("\n")+1,"Authored tutorial lines should fit without mid-phrase wrapping: "+name)
	viewport.get_texture().get_image().save_png(Artifacts.path("tutorial/"+name+".png"))
func click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas()*(control.size*0.5)
	motion(point,Vector2.ZERO,0)
	mouse(point,MOUSE_BUTTON_LEFT,true)
	mouse(point,MOUSE_BUTTON_LEFT,false)
	await frames()
func place_input(card: BuildCard, cell: Vector3i, turns: int) -> Node3D:
	var cards: Node = session.get_node("CardPlacement")
	cards.select_card(-1)
	cards.hand.finish_animation()
	await click(cards.hand.views[cards.cards.find(card)])
	for i in turns:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		key.pressed = true
		viewport.push_input(key,true)
		key.pressed = false
		viewport.push_input(key,true)
	var camera: Camera3D = session.get_node("Camera3D")
	var offset: Vector2i = card.rotation_anchor_offset(cards.turns, cards._initial_turns)
	var pointer_cell := cell-Vector3i(offset.x,0,offset.y)
	if cards.towers.upgrade_target(cell, card) != null: pointer_cell = cell
	var point := camera.unproject_position(cards.placement.map.to_global(cards.placement.map.map_to_local(pointer_cell)))
	motion(point,Vector2.ZERO,0)
	await frames()
	mouse(point,MOUSE_BUTTON_LEFT,true)
	mouse(point,MOUSE_BUTTON_LEFT,false)
	await frames()
	return cards.towers.upgrade_target(cell)
func place(card: BuildCard, cell: Vector3i, turns: int) -> Node3D:
	var cards: Node = session.get_node("CardPlacement")
	cards.select_card(cards.cards.find(card),false)
	cards.rotate_card(turns)
	return cards.place_selected(cell)
func verify() -> void:
	LevelProgress.load_progress(Artifacts.path("tutorial/completion.cfg"))
	LevelProgress._completed.erase("tutorial")
	TranslationServer.set_locale("zh_TW")
	viewport = TestViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	session = load("res://scenes/level.tscn").instantiate()
	session.level = load("res://assets/data/levels/tutorial.tres")
	viewport.add_child(session)
	await frames(12)
	while session.get_node("PortalMap").computing: await frames(1)
	viewport.mouse_entered.emit()
	var director: Node = session.tutorial
	var data: TutorialDefinition = session.level.tutorial
	var cards: Node = session.get_node("CardPlacement")
	var shop: Node = cards.get_node("Shop")
	var camera: Camera3D = session.get_node("Camera3D")
	var wave: Node = session.get_node("EnemyWave")
	var deals: Array[bool] = []
	cards.cards_changed.connect(func():
		if director.stage == director.Stage.FIRST and cards.cards == data.starting_cards and deals.is_empty():
			deals.append(cards.hand._entering.size() == 3 and cards.hand.views.all(func(view): return view.modulate.a == 0.0)))
	check(session.level.acts.size() == 1 and session.level.wave_count() == 3,"Tutorial has one ACT and three waves")
	check(director != null and cards.cards.is_empty() and cards.hand.views.is_empty(),"Camera practice must begin without cards")
	check(not wave.start_allowed and place(data.starting_cards[0],data.guided_cells[0],0) == null,"Camera step blocks premature building and waves")
	cards.select_card(-1)
	session.get_node("LevelHUD").set_paused(true)
	await frames()
	check(not director.overlay.visible and not director.ghost.visible and not director.focus_layer.visible and director.stage == director.Stage.CAMERA,"Pause hides tutorial presentation without advancing its step")
	session.get_node("LevelHUD").set_paused(false)
	await frames()
	await snapshot("01_camera")
	mouse(Vector2(640,400),MOUSE_BUTTON_LEFT,true)
	motion(Vector2(680,420),Vector2(40,20),MOUSE_BUTTON_MASK_LEFT)
	mouse(Vector2(680,420),MOUSE_BUTTON_LEFT,false)
	mouse(Vector2(640,400),MOUSE_BUTTON_WHEEL_UP,true)
	mouse(Vector2(800,400),MOUSE_BUTTON_RIGHT,true)
	motion(Vector2(640,560),Vector2(-160,160),MOUSE_BUTTON_MASK_RIGHT)
	camera._advance_orbit(0.05)
	mouse(Vector2(640,560),MOUSE_BUTTON_RIGHT,false)
	await frames()
	check(director.stage == director.Stage.FIRST and director.camera_actions == [true,true,true],"Real camera pan/zoom/orbit advances the first step")
	check(cards.cards == data.starting_cards and not deals.is_empty() and deals[0],"Step two deals the authored hand with an arrival animation")
	await snapshot("02_dealing")
	await get_tree().create_timer(0.9,true,false,true).timeout
	await frames()
	check(cards.hand._entering.is_empty() and director.focus.target == cards.hand.views[0],"The first card becomes the spotlight target after dealing")
	check(director._ghost_material.get_shader_parameter("tint").a < 0.5,"Guided tower must be translucent")
	var ghost_alphas: Array[float] = []
	for i in 8:
		ghost_alphas.append(director._ghost_material.get_shader_parameter("tint").a)
		await get_tree().create_timer(0.2,true,false,true).timeout
	check(ghost_alphas.max()-ghost_alphas.min() > 0.12,"Guided tower transparency must pulse over a complete cycle")
	await snapshot("02_first_target")
	cards.select_card(0,false)
	await get_tree().create_timer(0.25,true,false,true).timeout
	check(director.focus.target == null and director.focus._alpha == 0.0 and director.focus._outgoing_alpha == 0.0,"Selecting the requested card must fade out its focus frame")
	cards.select_card(-1)
	session._begin_wave_start()
	check(not session._wave_starting,"Cannot skip placement by starting a wave")
	var count: int = cards.cards.size()
	check(place(data.starting_cards[0],data.guided_cells[0],1) == null and cards.cards.size() == count,"Wrong first orientation is rejected without consuming a card")
	var first := await place_input(data.starting_cards[0],data.guided_cells[0],0)
	check(first != null and director.stage == director.Stage.ROTATED,"First exact hologram placement advances")
	await get_tree().create_timer(0.6,true,false,true).timeout
	await snapshot("02_rotated_target")
	check(cards.placement.map.get_cell_item(Vector3i(3,0,-1)) > 0 and cards.towers.occupied.has(Vector2i(3,0)),"First tower adds a real bypass around its occupied road")
	while session.get_node("PortalMap").computing: await frames(1)
	check(place(data.starting_cards[1],data.guided_cells[1],0) == null,"Second card requires rotation")
	check(await place_input(data.starting_cards[1],data.guided_cells[1],data.guided_turns[1]) != null and director.stage == director.Stage.FREE,"Rotated hologram accepts exactly 90 degrees")
	check(cards.placement.map.get_cell_item(Vector3i(4,0,2)) > 0 and cards.towers.occupied.has(Vector2i(6,1)),"Second tower adds the rotated bypass")
	while session.get_node("PortalMap").computing: await frames(1)
	check(cards.towers.validate_card(data.starting_cards[2],Vector3i(9,0,4),0).is_empty() and cards.towers.validate_card(data.starting_cards[2],Vector3i(10,0,4),0).is_empty(),"Third placement has multiple legal choices")
	check(await place_input(data.starting_cards[2],Vector3i(9,0,4),0) != null and director.stage == director.Stage.START,"Free placement enables the real next-wave control")
	while session.get_node("PortalMap").computing: await frames(1)
	await snapshot("02_built")
	await click(session.get_node("LevelHUD").early_start.get_node("Title"))
	check(session._wave_starting,"Clicking Start next wave starts the opening wait")
	session._advance_wave_start(1.5)
	check(wave.active and director.stage == director.Stage.COMBAT and cards.input_suspended,"Wave start uses the real preparation and combat lock")
	wave._process(20.0)
	for enemy in wave.living_enemies(): enemy.queue_free()
	for i in 240:
		await frames(1)
		if director.stage == director.Stage.BUY_SENTRY: break
	shop.view.finish_animation()
	check(director.stage == director.Stage.BUY_SENTRY and shop.available and shop.offers[0].tower == data.upgrade_card.tower and not session.choosing_relic,"Wave reward guarantees Sentry before any end-of-ACT relic choice")
	check(not shop.view.opened,"Step four must let the player open the shop")
	await frames()
	check(director.focus.target == shop.view.slots.back().get_node("Face/Back"),"The closed shop must receive the focus frame")
	var expanded_width: float = director.focus._rect.size.x
	await get_tree().create_timer(0.6,true,false,true).timeout
	check(director.focus._rect.size.x < expanded_width and director.focus._alpha > 0.95 and director.focus.mouse_filter == Control.MOUSE_FILTER_IGNORE,"The focus frame must contract without intercepting clicks")
	await snapshot("03_open_shop_focus")
	await click(shop.view.slots.back().get_node("Face/Back"))
	shop.view.finish_animation()
	await frames()
	check(shop.view.opened and director.focus.target == shop.view.slots[1].get_node("Face/Card"),"Opening the shop moves the focus frame to the required purchase")
	check(not session.finished and not LevelProgress.snapshot().has("tutorial"),"Finishing the wave alone does not complete the tutorial")
	var coins: int = shop.coins
	check(not shop.reroll() and shop.coins == coins,"Cannot reroll away the required upgrade card")
	await click(shop.view.slots[1].get_node("Face/Card"))
	check(director.stage == director.Stage.UPGRADE,"Buying Sentry advances to upgrade")
	await frames()
	await snapshot("03_upgrade")
	var cells: Array[Vector3i] = cards.placement.map.get_used_cells()
	var revision: int = session.get_node("PortalMap").revision
	check(place(data.upgrade_card,Vector3i(4,0,0),0) == null,"Purchased Sentry must upgrade a matching tower")
	check(await place_input(data.upgrade_card,data.guided_cells[0],3) == first and first.level == 2,"Purchased card upgrades the original tower regardless of its TilePreset orientation")
	await frames()
	shop.view.finish_animation()
	check(director.stage == director.Stage.REROLL and cards.placement.map.get_used_cells() == cells and session.get_node("PortalMap").revision == revision,"Upgrade keeps roads and navigation unchanged")
	coins = shop.coins
	check(not shop.view.opened,"The reroll lesson must also let the player open the shop")
	await click(shop.view.slots.back().get_node("Face/Back"))
	shop.view.finish_animation()
	await click(shop.view.slots[0].get_node("Face/Back"))
	check(shop.coins == coins-shop.reroll_price and director.stage == director.Stage.BUY_NEW,"Player reroll charges the normal fee and advances")
	check(shop.offers[0].tower == data.new_card.tower,"Refresh guarantees the new tower")
	for card in data.starting_cards: check(card.tower != shop.offers[0].tower,"New purchase does not appear in the starting deck")
	shop.view.finish_animation()
	await snapshot("04_new_tower")
	await click(shop.view.slots[1].get_node("Face/Card"))
	check(director.stage == director.Stage.PRACTICE and not session.finished and not LevelProgress.snapshot().has("tutorial") and session.current_wave == 1,"Buying the new tower enters practice without completing the level")
	check(not cards.towers.placement_rule.is_valid() and not shop.purchase_rule.is_valid() and not shop.reroll_rule.is_valid() and not shop.deal_filter.is_valid(),"Practice removes the guided build and shop restrictions")
	check(await place_input(data.new_card,Vector3i(8,0,9),0) != null,"The newly purchased tower can be built during practice")
	await snapshot("05_practice")
	for wave_index in [1,2]:
		while session.get_node("PortalMap").computing: await frames(1)
		await click(session.get_node("LevelHUD").early_start.get_node("Title"))
		check(session._wave_starting,"Practice permits starting the next wave")
		session._advance_wave_start(1.5)
		check(wave.active,"Practice wave really starts")
		wave._process(20.0)
		for enemy in wave.living_enemies(): enemy.queue_free()
		for i in 240:
			await frames(1)
			if session.current_wave == wave_index+1 and not session._settling_wave: break
		if wave_index == 1:
			check(not session.finished and not LevelProgress.snapshot().has("tutorial") and director.stage == director.Stage.PRACTICE,"Wave two does not complete or repeat the teaching sequence")
	check(not session.choosing_relic and session.finished and LevelProgress.snapshot().has("tutorial"),"The third wave completes the tutorial immediately without a relic choice")
	await frames()
	check(not director.overlay.visible and not director.focus_layer.visible and not director.ghost.visible,"Completion must hide every tutorial hint and focus frame")
	check(director.stage == director.Stage.DONE,"All three waves complete the teaching sequence")
	check(session.run_status.get_node("Result/Center/Panel/Margin/Column/Completion").text == tr("tutorial.done") and session.run_status.get_node("Result/Center/Panel/Margin/Column/TutorialActions").visible,"Victory panel owns the completion text and actions")
	check(session.run_status._next_map_id == "frontier","Continue must select the unlocked second battlefield")
	var confetti: Control = session.run_status.get_node("Result/Confetti")
	check(confetti._started and confetti._particles.size() == 24 and GameAudio._victory_pending,"Victory must trigger one small paired burst and a single victory cue")
	var burst_age: float = confetti._elapsed
	session.run_status.finish(true)
	check(confetti._elapsed == burst_age and confetti._particles.size() == 24,"The same result must never restart or duplicate the celebration")
	await frames()
	await get_tree().create_timer(0.3,true,false,true).timeout
	for particle in confetti._particles:
		var pose: Dictionary = confetti.particle_pose(particle)
		if not pose.is_empty():
			check(not confetti.content_rect().grow(8).has_point(pose.position),"Victory paper must stay outside the title, statistics and action area")
			var edge: float = confetti.content_rect().position.x-54.0 if particle.side < 0 else confetti.content_rect().end.x+54.0
			check((pose.position.x-edge)*particle.side > 8.0,"Victory paper must spray outward away from both sides of the result")
	await snapshot("05_victory_burst")
	await get_tree().create_timer(1.2,true,false,true).timeout
	check(confetti._particles.is_empty() and not confetti.is_processing(),"Celebration must clear itself after one short burst")
	await snapshot("05_done")
	viewport.size = Vector2i(800,600)
	TranslationServer.set_locale("en")
	await frames()
	var result_panel: Control = session.run_status.get_node("Result/Center/Panel")
	var result_actions: Control = session.run_status.get_node("Result/Center/Panel/Margin/Column/TutorialActions")
	check(result_actions.get_global_rect().end.y < 600 and result_panel.get_global_rect().encloses(result_actions.get_global_rect()) and not director.overlay.visible,"Small English victory actions stay inside the result panel")
	await snapshot("06_small_en")
	var saved_cards := data.starting_cards.duplicate()
	session.queue_free()
	await frames()
	session = load("res://scenes/level.tscn").instantiate()
	session.level = load("res://assets/data/levels/tutorial.tres")
	viewport.add_child(session)
	await frames(12)
	check(session.tutorial.stage == session.tutorial.Stage.CAMERA and session.get_node("CardPlacement").cards.is_empty() and session.get_node("CardPlacement/Shop").coins == 0 and session.get_node("TowerMap").towers.is_empty(),"Replaying tutorial resets to camera practice without cards")
	await snapshot("07_small_camera_en")
	var edited := data.duplicate() as TutorialDefinition
	edited.starting_cards = [data.starting_cards[1],data.starting_cards[0],data.starting_cards[2]]
	# Footprints differ per preset, so a reordered hand carries its guided targets with it.
	edited.guided_cells = data.guided_cells.duplicate()
	edited.guided_cells.reverse()
	edited.guided_turns = data.guided_turns.duplicate()
	edited.guided_turns.reverse()
	check(edited.configuration_error().is_empty(),"Starting hand supports reordering while retaining the upgrade tower")
	session.queue_free()
	await frames()
	session = load("res://scenes/level.tscn").instantiate()
	session.level = (load("res://assets/data/levels/tutorial.tres") as LevelDefinition).duplicate()
	session.level.tutorial = edited
	viewport.add_child(session)
	await frames(12)
	while session.get_node("PortalMap").computing: await frames(1)
	session.tutorial._set_stage(session.tutorial.Stage.FIRST)
	check(session.get_node("CardPlacement").cards == edited.starting_cards and session.tutorial.overlay.get_node("Panel/Margin/Rows/Body").text.contains(edited.starting_cards[0].tower.localized_name()),"Edited starting cards are used by gameplay and hint text")
	check(place(edited.starting_cards[0],edited.guided_cells[0],edited.guided_turns[0]) != null,"Edited first card follows the first hologram")
	while session.get_node("PortalMap").computing: await frames(1)
	check(place(edited.starting_cards[1],edited.guided_cells[1],edited.guided_turns[1]) != null,"Sentry can be moved to another initial slot")
	session.tutorial._set_stage(session.tutorial.Stage.UPGRADE)
	var target: DefenseTower = session.get_node("TowerMap").upgrade_target(edited.guided_cells[1])
	check(session.tutorial.ghost.upgrade_mode and is_equal_approx(session.tutorial.ghost.hint_anchor.x,target.global_position.x) and is_equal_approx(session.tutorial.ghost.hint_anchor.z,target.global_position.z),"Upgrade hologram finds the matching tower after reordering")
	var output := {"failures":failures,"rendered":DisplayServer.get_name() != "headless","five_steps":true}
	FileAccess.open(Artifacts.path("tutorial/intro.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("TUTORIAL_CHECK:",JSON.stringify(output))
	session.queue_free()
	await frames()
	get_tree().quit(0 if failures.is_empty() else 1)
