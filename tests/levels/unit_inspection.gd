extends SceneTree
const Fixture = preload("res://tests/fixtures/level_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Picker = preload("res://scripts/levels/presentation/unit_pick.gd")
var failures := 0
var checks := 0
var scene: Node3D
var inspect: Node3D
var camera: Camera3D
var towers: Node3D
var wave: Node

func _initialize() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count := 4) -> void:
	for i in count: await process_frame
func wait_real(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout
	await frames(2)
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await frames()
func escape() -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.pressed = down
		root.push_input(event,true)
	await frames()
func point_for(unit: Node3D) -> Vector2:
	var parts: Array[Dictionary] = Picker.mesh_parts(unit) if unit is DefenseTower else wave.visuals.inspection_parts(unit)
	for part in parts:
		var p: Vector3 = part.transform*part.bounds.get_center()
		var screen := camera.unproject_position(p)
		if screen.y < 350 and Picker.pick(camera,screen,towers,wave.visuals) == unit: return screen
	return Vector2(-100,-100)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await wait_real(0.25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Artifacts.path("levels/inspection_"+name+".png"))
func build(definition: TowerDefinition, at: Vector2i, turns := 0) -> DefenseTower:
	var t := DefenseTower.new()
	t.definition = definition
	t.rotation_steps = turns
	t.placement_preset = definition.first_tile_preset()
	t.grid_cell = at
	for cell in TowerBodyGeometry.local_cells(t.placement_preset): t.occupied_cells.append(at+BuildCard.rotate_cell(cell,turns))
	return towers._commit(t,at,{at:true})

func verify() -> void:
	root.size = Vector2i(1152,648)
	var definition := Fixture.level("")
	definition.acts[0].waves[0].groups[0].enemy_count = 8
	definition.acts[0].waves.append(definition.acts[0].waves[0].duplicate(true))
	scene = load("res://scenes/level.tscn").instantiate()
	scene.level = definition
	root.add_child(scene)
	current_scene = scene
	await frames(25)
	inspect = scene.unit_inspection
	towers = scene.get_node("TowerMap")
	wave = scene.get_node("EnemyWave")
	camera = root.get_camera_3d()
	camera.set_process(false)
	camera.set_physics_process(false)
	var sentry := build(load("res://assets/data/towers/sentry.tres"),Vector2i(2,-2))
	await wait_real(0.6)
	var p := point_for(sentry)
	check(p.x >= 0,"Tower has a ray-pickable visible point")
	await click(p)
	check(inspect.target == sentry and not paused,"Real click selects a tower without pausing")
	var hover: Control = towers.find_children("TowerHover","Control",true,false)[0]
	hover.feedback_tower = sentry
	hover.feedback_seconds = 1.0
	hover._process(0.0)
	check(not hover.visible,"Formal placement and upgrade never show the old world-space hover bubble")
	await frames()
	check(inspect.range_view.cells.size() == sentry.attack_offsets().size(),"Shaped tower uses actual combat offsets")
	for offset in sentry.attack_offsets(): check(inspect.range_view.cells.has(sentry.grid_cell+offset),"Selected coverage matches attack cell")
	var updates: int = inspect.updates
	var rebuilds: int = inspect.range_view.rebuilds
	await frames(8)
	check(inspect.updates == updates and inspect.range_view.rebuilds == rebuilds,"Unchanged selection does not rebuild UI or mesh")
	sentry.upgrade()
	await frames()
	check(inspect.column.get_node("Heading/Name").text.contains("Lv.2"),"Tower upgrade updates live title")
	check(inspect.column.get_node("Stats/First").text.contains(str(snappedf(sentry.damage*sentry.attack.damage_multiplier,0.01))),"Damage reads upgraded live payload value")
	sentry.relic_effects[&"global_damage"] = {"bonus":0.25,"stacks":1}
	sentry.refresh_stats()
	await frames()
	check(inspect.column.get_node("Stats/First").text.contains(str(snappedf(sentry.damage*sentry.attack.damage_multiplier,0.01))),"Buffed damage updates without reselection")
	await capture("sentry")
	check(inspect.panel.size.y <= 90 and inspect.panel.size.x <= 550,"Tower panel stays compact and flat")
	check(not inspect.column.get_node("Stats/Third").visible and not inspect.column.get_node("Heading/Kind").visible,"Shaped range and duplicate tower type are omitted")
	check(inspect.column.get_node_or_null("Hint") == null,"Closing hint does not add a row")
	check(inspect.range_view.FILL.g > inspect.range_view.FILL.r and inspect.range_view.EDGE.g > 0.6,"Range uses clear green preview-style colors")
	check(not inspect.panel.get_global_rect().intersects(cards_rect()),"Preparation panel leaves hand cards unobstructed")
	await click(inspect.panel.get_global_rect().get_center())
	check(inspect.target == sentry,"Panel clicks do not reach the battlefield")
	await escape()
	check(not inspect.has_selection() and not paused and inspect.range_view.mesh == null,"First Esc clears selection and range without pausing")
	await wait_real(0.2)
	check(not inspect.panel.visible,"Closing fades out")
	await escape()
	check(paused,"Esc without selection retains pause behavior")
	await escape()
	var cards: Node = scene.get_node("CardPlacement")
	cards.select_card(0,false)
	await click(p)
	check(not inspect.has_selection(),"Holding a card preserves construction priority")
	cards.select_card(-1)
	await click(p)
	await click(Vector2(45,150))
	check(not inspect.has_selection(),"Empty-space click clears selection")
	# A camera drag over a unit never becomes a selection click.
	var press := InputEventMouseButton.new()
	press.position = p
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press,true)
	var drag := InputEventMouseMotion.new()
	drag.position = p+Vector2(25,0)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(drag,true)
	press = press.duplicate()
	press.position = drag.position
	press.pressed = false
	root.push_input(press,true)
	await frames()
	check(not inspect.has_selection(),"Camera drag does not select units")
	var mortar := build(load("res://assets/data/towers/mortar.tres"),Vector2i(5,-2),2)
	await wait_real(0.6)
	await click(point_for(mortar))
	await frames()
	check(inspect.target == mortar and inspect.range_view.circular,"Mortar uses continuous circular range")
	check(inspect.range_view.center.is_equal_approx(Vector3(towers.map.to_local(mortar.combat_origin()).x,inspect.range_view.center.y,towers.map.to_local(mortar.combat_origin()).z)),"Multi-cell mortar uses actual combat origin")
	check(is_equal_approx(inspect.range_view.radius,mortar.attack_radius*mortar.range_multiplier),"Circle radius matches active combat radius")
	mortar.range_multiplier = 1.5
	mortar._invalidate_attack_area()
	await frames()
	check(is_equal_approx(inspect.range_view.radius,mortar.attack_radius*1.5),"Range buff updates selected mesh")
	await capture("mortar")
	for id in ["ballista","broadside","crossfire","barracks"]:
		var tower := build(load("res://assets/data/towers/"+id+".tres"),Vector2i(12+checks,2),1)
		inspect.select_unit(tower)
		await frames()
		check(inspect.target == tower and inspect.range_view.visible and inspect.range_view.mesh != null,"Switch to "+id+" clears old presentation")
		if id in ["ballista","broadside"]:
			check(not inspect.range_view.circular,"Directional tower is not shown as a circle")
			for offset in tower.attack_offsets(): check(inspect.range_view.cells.has(tower.grid_cell+offset),"Rotated shaped range matches combat")
		if id == "barracks":
			check(inspect.column.get_node("Stats/First").text.contains(str(snappedf(tower.deployment.damage,0.01))),"Barracks shows live soldier damage")
			check(inspect.column.get_node("Stats/Second").text.contains(str(snappedf(tower.deployment.interval,0.01))),"Barracks shows meaningful soldier interval")
			for at in inspect.range_view.cells:
				check(not towers.combat.barracks.path(tower.garrison_cell(),at,tower.garrison_cell(),tower.deployment.local_radius).is_empty(),"Garrison cells follow real road reachability")
	inspect.cancel_selection(false)
	towers.combat.enabled = false
	wave.start_allowed = true
	check(wave.start_wave(),"Combat fixture starts")
	wave._process(0)
	var enemy: Node3D = wave.living_enemies()[0]
	for e: Node3D in wave.living_enemies(): e.set_process(false)
	enemy.global_position = towers.map.to_global(towers.map.map_to_local(Vector3i(4,0,0)))
	wave.visuals.update_enemy(enemy)
	await frames()
	p = point_for(enemy)
	check(p.x >= 0,"Rendered enemy has a ray-pickable point")
	await click(p)
	check(inspect.target == enemy and not paused,"Real combat click selects enemy without pausing")
	await frames()
	check(inspect.range_view.cells.is_empty() and not inspect.range_view.circular,"Enemy has only a selection mark")
	enemy.take_damage(3)
	enemy.add_shield(7)
	await frames()
	check(inspect.column.get_node("Stats/First").text.contains(str(snappedf(enemy.health,0.01))),"Enemy HP is live")
	check(is_equal_approx(inspect.column.get_node("Health").value,100*enemy.health/enemy.max_health),"Health bar follows damage")
	check(inspect.column.get_node("Stats/Third").text.contains("7"),"Live shield is shown")
	check(inspect.column.get_node("Stats/Second").text.contains(str(int(enemy.abilities.get("base_damage",1)))),"Base damage uses wave snapshot")
	check(not inspect.column.get_node("Heading/Kind").text.contains("ui.progress"),"Enemy types are readable localized text")
	check(inspect.column.get_node("Heading/Kind").get_parent() == inspect.column.get_node("Heading"),"Enemy tags share the name row")
	var rook: Node3D = load("res://scenes/enemies/enemy.tscn").instantiate()
	rook.troop = load("res://assets/data/troops/rook.tres")
	rook.abilities = rook.troop.ability_snapshot()
	var rook_data: Dictionary = inspect.Data.enemy(rook)
	check(rook_data.notes.count("25") == 1 and not rook_data.notes.contains("優先級") and not rook_data.notes.contains("出生順序"),"Rook description contains one reduction and no internal tie-break rules")
	rook.free()
	await capture("enemy")
	TranslationServer.set_locale("en")
	root.size = Vector2i(800,600)
	await frames(6)
	await capture("enemy_small_en")
	check(root.get_visible_rect().encloses(inspect.panel.get_global_rect()),"Small English panel remains inside viewport")
	check(inspect.column.get_node("Stats/Second").text.begins_with("Base damage"),"Language change updates selected info in place")
	TranslationServer.set_locale("zh_TW")
	root.size = Vector2i(1152,648)
	await frames(4)
	var before := enemy.global_position
	enemy.set_process(true)
	await wait_real(0.1)
	check(enemy.global_position.distance_to(before) > 0 and inspect.target == enemy,"Selected enemy keeps moving normally")
	enemy.set_process(false)
	enemy.take_damage(100000)
	await frames()
	check(not inspect.has_selection() and inspect.range_view.mesh == null,"Enemy death removes selection and marker")
	var other: Node3D = wave.living_enemies()[0]
	inspect.select_unit(other)
	other.queue_free()
	await frames()
	check(not inspect.has_selection(),"Enemy external removal clears references")
	inspect.select_unit(sentry)
	towers.remove_tower(Vector3i(sentry.grid_cell.x,0,sentry.grid_cell.y))
	await frames()
	check(not inspect.has_selection(),"Tower removal clears references")
	# Nearest ray depth, independent of list order; a near box hides a far box.
	var far_parts: Array[Dictionary] = [{"transform":Transform3D(Basis.IDENTITY,Vector3(0,0,-8)),"bounds":AABB(Vector3(-1,-1,-1),Vector3(2,2,2))}]
	var near_parts: Array[Dictionary] = [{"transform":Transform3D(Basis.IDENTITY,Vector3(0,0,-3)),"bounds":AABB(Vector3(-1,-1,-1),Vector3(2,2,2))}]
	check(Picker.hit_distance(Vector3.ZERO,Vector3.FORWARD,near_parts) < Picker.hit_distance(Vector3.ZERO,Vector3.FORWARD,far_parts),"Ray depth ranks overlap geometrically")
	var fake: Node3D = load("res://scripts/towers/tower_map.gd").new()
	root.add_child(fake)
	var picked: Array[DefenseTower] = []
	for depth in [7.0,3.0]:
		var unit := DefenseTower.new()
		fake.add_child(unit)
		unit.global_position = camera.project_position(Vector2(576,324),depth)
		var view := MeshInstance3D.new()
		view.mesh = BoxMesh.new()
		unit.add_child(view)
		fake.towers[depth] = unit
		picked.append(unit)
	check(Picker.pick(camera,Vector2(576,324),fake,wave.visuals) == picked[1],"Actual overlapping candidates choose the nearer ray hit despite insertion order")
	fake.towers = {3.0:picked[1],7.0:picked[0]}
	check(Picker.pick(camera,Vector2(576,324),fake,wave.visuals) == picked[1],"Reversing candidate order does not change overlap selection")
	fake.queue_free()
	scene.queue_free()
	await wait_real(0.2)
	print("UNIT_INSPECTION: checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func cards_rect() -> Rect2:
	var views: Array = scene.get_node("CardPlacement").hand.views
	var rect := Rect2()
	for view: Control in views:
		var transform := view.get_global_transform_with_canvas()
		for point in [Vector2.ZERO,Vector2(view.size.x,0),view.size,Vector2(0,view.size.y)]:
			var at: Vector2 = transform*point
			rect = Rect2(at,Vector2.ONE) if rect == Rect2() else rect.expand(at)
	return rect
