extends Node3D
## Independent playable review fixture. F6, then use either entrance's start button.
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Endpoints = preload("res://tests/fixtures/level_fixture.gd")
var session: Node3D
func _ready() -> void: setup.call_deferred()
func setup() -> void:
	var level := LevelDefinition.new()
	var terrain := GridMap.new()
	terrain.mesh_library = load("res://assets/models/mesh_library.tres")
	terrain.cell_size = Vector3.ONE
	terrain.cell_center_y = false
	terrain.position = Vector3(-9,0,-5)
	for x in 18:
		for y in 10: terrain.set_cell_item(Vector3i(x,0,y),6)
	Endpoints.endpoint(terrain, Endpoints.Start, Vector2i(0,4), "Start")
	Endpoints.endpoint(terrain, Endpoints.Start, Vector2i(0,7), "Start2")
	Endpoints.endpoint(terrain, Endpoints.Goal, Vector2i(17,4), "Goal")
	level.terrain = PackedScene.new()
	level.terrain.pack(terrain)
	terrain.free()
	var wave := WaveDefinition.new()
	wave.move_speed = 1.6
	for origin in 2:
		var group := WaveSpawnGroup.new()
		group.start_index = origin
		group.enemy_count = 24
		group.interval_ticks = 2
		group.troop = load("res://assets/data/troops/soldier.tres").duplicate()
		group.troop.max_health = 250
		wave.groups.append(group)
	var act := ActDefinition.new()
	act.add_start_after_completion = false
	act.waves = [wave,wave,wave]
	level.acts = [act]
	session = load("res://scenes/level.tscn").instantiate()
	session.level = level
	add_child(session)
	for i in 120:
		await get_tree().process_frame
		if not session.get_node("PortalMap").computing: break
	var keys := ["mortar","ballista","broadside","crossfire","barracks","sentry"]
	var anchors := [Vector3i(3,0,5),Vector3i(6,0,5),Vector3i(9,0,4),Vector3i(12,0,5),Vector3i(14,0,5),Vector3i(16,0,7)]
	for i in keys.size():
		var definition: TowerDefinition = load("res://assets/data/towers/"+keys[i]+".tres")
		var tower: DefenseTower = session.get_node("TowerMap").place_card(BuildCard.from_parts(definition,definition.first_tile_preset()),anchors[i])
		if tower == null:
			push_error("Showcase placement failed: "+keys[i])
			get_tree().quit(1)
			return
		var label := Label3D.new()
		tower.add_child(label)
		label.position.y = 1.15
		label.text = definition.localized_name()
		label.font = load("res://assets/fonts/NotoSansTC-Light.ttf")
		label.font_size = 24
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.5).timeout
		await snapshot("preparation")
		session._on_start_requested()
		await get_tree().create_timer(18).timeout
		await snapshot("combat")
		print("RESTORATION_SHOWCASE: shots=",session.get_node("TowerMap").combat.shots_fired," friendlies=",session.get_node("TowerMap").combat.barracks.units.size())
		for tower: DefenseTower in session.get_node("TowerMap").towers.values():
			if tower.attack is VolleyAttack: print("SHOWCASE_TOWER:",tower.definition.name_key," shots=",tower._visual.shot_count)
		get_tree().quit()
func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("combat/tower_restoration_"+label+".png"))
