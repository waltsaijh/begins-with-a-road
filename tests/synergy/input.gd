extends "res://tests/synergy/playground.gd"
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
var failures: Array[String] = []
var checks := 0
var observations := {}
func _ready() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame
func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	viewport_target.push_input(event,true)
func click(point: Vector2) -> void:
	motion(point)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		viewport_target.push_input(event,true)
	await frames()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	viewport_target.get_texture().get_image().save_png(Artifacts.path("synergy/"+name+".png"))
func lane_counts(forecast: RoadFlowForecast, profile: Troop) -> Array:
	var paths: Dictionary = forecast.by_troop.get(profile,{})
	return [int(paths.get(Vector4i(8,0,9,0),0)),int(paths.get(Vector4i(8,6,9,6),0))]
func overlap(a: Array,b: Array) -> float:
	if a[0]+a[1] == 0 or b[0]+b[1] == 0: return 0.0
	return minf(float(a[0])/(a[0]+a[1]),float(b[0])/(b[0]+b[1]))+minf(float(a[1])/(a[0]+a[1]),float(b[1])/(b[0]+b[1]))
func verify() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Synergy input requires real rendering")
		get_tree().quit(1)
		return
	TranslationServer.set_locale("zh_TW")
	viewport_target = TestViewport.new()
	viewport_target.size = Vector2i(1440,900)
	viewport_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport_target)
	create_ui()
	for case in 4:
		await load_scenario(case)
		await frames(35)
		viewport_target.mouse_entered.emit()
		var wave: Node = session.get_node("EnemyWave")
		var preview: Node = session.get_node("WaveFlowPreview")
		var hud: CanvasLayer = session.get_node("LevelHUD")
		check(not preview.baseline.all.is_empty(),"case %d has actual forecast" % case)
		var action: Button = hud.start_callouts[0]
		motion(action.get_global_rect().get_center())
		await frames(5)
		var list: Node = action.get_node("NextWaveIntel/Scroll/Items")
		var item: Control = list.get_child(0)
		motion(item.get_node("Body").get_global_rect().get_center())
		await frames(5)
		check(action._hovered and preview.selected_origin == 0 and action.get_node("NextWaveIntel").selected == item.profile,"new troop hover filters correct origin and profile")
		await click(item.get_node("Info").get_global_rect().get_center())
		check(session.enemy_intelligence.panel.visible and not wave.active and not session._wave_starting,"Info opens details without starting a wave")
		check(session.enemy_intelligence.description.text.contains(item.profile.body_size),"intelligence shows tags and route behavior")
		await capture("case_%d_intelligence" % case)
		await click(session.enemy_intelligence.get_node("Screen/Panel/Layout/Close").get_global_rect().get_center())
		if case < 3:
			var rat := TroopCatalog.find("rat_swarm")
			var guard := TroopCatalog.find("shield_guardian")
			var mage := TroopCatalog.find("blood_mage")
			var a := lane_counts(preview.baseline,rat if case == 0 else mage)
			var b := lane_counts(preview.baseline,guard)
			await click(split_button.get_global_rect().get_center())
			await frames(5)
			check(split_structures.size() == 2,"real click places both test splitting structures")
			if case == 0 or case == 1:
				var aa := lane_counts(preview.baseline,rat if case == 0 else mage)
				var bb := lane_counts(preview.baseline,guard)
				observations[str(case)] = {"before":[a,b],"after":[aa,bb],"overlap_before":overlap(a,b),"overlap_after":overlap(aa,bb)}
				check(overlap(aa,bb) < overlap(a,b),"splitting reduces guardian/support route overlap")
		else:
			var flyer := TroopCatalog.find("winged_beast")
			var old: Dictionary = preview.baseline.by_troop[flyer].duplicate(true)
			await click(new_roads_button.get_global_rect().get_center())
			await frames(8)
			check(new_roads_added and preview.baseline.by_troop[flyer] == old,"new longer roads never redirect shortest flyers")
			var scout := TroopCatalog.find("scout")
			var schedule := WaveSpawnSchedule.build(wave.definition,session.get_node("PortalMap"),0,false)
			var north := 0
			var south := 0
			for member: Dictionary in schedule.pending:
				if member.profile != scout: continue
				check(member.route.birth_wave == 1,"scout selects current prep wave birth")
				if Vector2(8,-3) in member.route.cells: north += 1
				if Vector2(8,9) in member.route.cells: south += 1
			check(north > 0 and south > 0,"both same-wave new routes receive actual scouts")
			observations["3"] = {"north_scouts":north,"south_scouts":south}
			await click(air_button.get_global_rect().get_center())
			check(session.get_node("TowerMap").relics.held.has(&"air_strike"),"real click grants anti-air relic")
			await click(air_button.get_global_rect().get_center())
			check(not session.get_node("TowerMap").relics.held.has(&"air_strike"),"real click removes anti-air relic")
		await capture("case_%d_preparation" % case)
		var expected: Dictionary = preview.baseline.all.duplicate(true)
		await click(action.get_global_rect().get_center())
		check(session._wave_starting,"real diamond click starts opening wait")
		session._advance_wave_start(1.5)
		check(wave.active and not preview.preparation,"wave starts and hides forecast")
		check(RoadFlowForecast.from_pending(wave._pending).all == expected,"actual committed routes equal displayed preview")
		Engine.time_scale = 4
		await get_tree().create_timer(9.0).timeout
		Engine.time_scale = 1
		await capture("case_%d_battle" % case)
		var combat: Node = session.get_node("TowerMap").combat
		if case == 1:
			# Continue real simulation until healing is observable in the split fixture.
			Engine.time_scale = 4
			await get_tree().create_timer(9.0).timeout
			Engine.time_scale = 1
			check(combat.enemy_abilities.heals > 0,"playable B produces actual heals")
		if case == 2:
			Engine.time_scale = 4
			await get_tree().create_timer(8.0).timeout
			Engine.time_scale = 1
			check(combat.enemy_abilities.disables > 0,"playable C produces actual tower disables")
		if case == 1 or case == 2: observations["abilities_%d" % case] = {"heals":combat.enemy_abilities.heals,"disables":combat.enemy_abilities.disables}
		check(not wave.visuals._appearances.is_empty(),"new models are actually rendered")
	Engine.time_scale = 1
	var result := {"checks":checks,"failures":failures,"observations":observations,"rendered":true}
	FileAccess.open(Artifacts.path("synergy/input.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("SYNERGY_INPUT:",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
