extends Node3D
## Real production meshes + allocated complete-walk fixtures, never drawn arrows.
const Surface = preload("res://scripts/map/tile/appearance/road_surface.gd")
const Renderer = preload("res://scenes/navigation/road_flow_renderer.tscn")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D
var label: Label
var ribbon: MeshInstance3D
var logical: GridMap
var display: GridMap
var surface: RefCounted
var checks := 0
var failures: Array[String] = []
var cases := ["narrow", "wide2", "wide3", "wide_L", "wide_T", "narrow_to_wide", "bridge_heads", "tower_edge", "rotated_concave", "opposite_flows"]
var selected := 0
var automatic := false
var turns := 0
var coverage_probes := 0
var pixel_probes := 0
var scheduled_members := 0
var scheduled_projection := {}
var _forecast: RoadFlowForecast
var _snapshot := {}
var _animation_mode := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame
func rect(cells: Dictionary, x: int, y: int, w: int, h: int) -> void:
	for z in range(y,y+h):
		for column in range(x,x+w): cells[Vector2i(column,z)] = 15
func trip(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2i in points: result.append(Vector2(point))
	return result
func row(y: int, count := 4, start := 0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for x in range(start,start+count): result.append(Vector2(x,y))
	return result

func _ready() -> void:
	automatic = "--verify" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args()
	viewport = SubViewport.new(); viewport.size = Vector2i(1440,900); viewport.own_world_3d = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(viewport)
	var container := TextureRect.new(); container.texture = viewport.get_texture(); container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; add_child(container)
	var layer := CanvasLayer.new(); viewport.add_child(layer)
	label = Label.new(); label.position = Vector2(22,18); label.add_theme_font_override("font",preload("res://assets/fonts/NotoSansTC-Light.ttf")); label.add_theme_font_size_override("font_size",22); label.add_theme_color_override("font_color",Color("304b50")); layer.add_child(label)
	if automatic: run.call_deferred()
	else: build_case(0)

func build_case(index: int, rotation := 0) -> void:
	if is_instance_valid(stage): stage.free()
	stage = Node3D.new(); viewport.add_child(stage)
	var env := WorldEnvironment.new(); env.environment = load("res://assets/data/rendering/level_environment.tres").duplicate(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("dce7e8"); stage.add_child(env)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-45,-35,0); light.shadow_enabled = true; stage.add_child(light)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 7.4; stage.add_child(camera)
	camera.position = Vector3(8,10,11); camera.look_at(Vector3(1.8,0,1.0)); camera.current = true
	logical = GridMap.new(); logical.mesh_library = load("res://assets/models/mesh_library.tres"); logical.cell_size = Vector3.ONE; logical.cell_center_y = false; stage.add_child(logical); logical.hide()
	var cells := {}; var blocked := {}; var trips: Array[PackedVector2Array] = []
	var art: Node3D
	match index:
		0: rect(cells,0,0,6,1); trips = [row(0,6)]
		1: rect(cells,0,0,4,2); trips = [row(0),row(1),trip([Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(2,1),Vector2i(3,1)])]
		2: rect(cells,0,0,4,3); trips = [row(0),row(1),row(2)]
		3:
			rect(cells,0,0,2,4); rect(cells,0,2,4,2)
			trips = [trip([Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2)]),trip([Vector2i(1,0),Vector2i(1,1),Vector2i(1,2),Vector2i(1,3),Vector2i(2,3),Vector2i(3,3)])]
		4:
			rect(cells,0,0,5,2); rect(cells,2,0,2,4)
			trips = [trip([Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(2,1),Vector2i(2,2),Vector2i(2,3)]),row(1,5)]
		5:
			rect(cells,0,0,2,1); rect(cells,2,0,4,3)
			trips = [row(0,6),trip([Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(3,1),Vector2i(4,1),Vector2i(5,1)])]
		6:
			rect(cells,0,0,7,1); rect(cells,0,1,2,2); rect(cells,5,-1,2,2)
			trips = [row(0,7)]
		7:
			rect(cells,0,0,5,4)
			for cell in [Vector2i(2,1),Vector2i(3,1),Vector2i(2,2),Vector2i(3,2)]: blocked[cell] = true
			trips = [row(0,5),trip([Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(0,3),Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),Vector2i(4,2),Vector2i(4,1),Vector2i(4,0)])]
			var definition: TowerDefinition = load("res://assets/data/towers/mortar.tres")
			art = preload("res://scripts/towers/body_visual.gd").create(definition,[Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]); art.position = Vector3(2.5,TowerConstants.GROUND_OFFSET,1.5); stage.add_child(art)
		8:
			rect(cells,0,0,4,2); rect(cells,0,1,2,3); cells.erase(Vector2i(1,1))
			trips = [trip([Vector2i(0,0),Vector2i(0,1),Vector2i(0,2),Vector2i(1,2),Vector2i(1,3)])]
		9:
			rect(cells,0,0,4,2); var reverse := row(1); reverse.reverse(); trips = [row(0),reverse]
	if rotation > 0:
		var rotated := {}; var obstacles := {}
		for cell: Vector2i in cells: rotated[BuildCard.rotate_cell(cell,rotation)] = cells[cell]
		for cell: Vector2i in blocked: obstacles[BuildCard.rotate_cell(cell,rotation)] = true
		cells = rotated; blocked = obstacles
		if art != null:
			var anchor := BuildCard.rotate_cell(Vector2i(2,1),rotation)
			art.position = Vector3(anchor.x+0.5,TowerConstants.GROUND_OFFSET,anchor.y+0.5)
			art.rotation.y = -rotation*PI/2
		for i in trips.size():
			var path := PackedVector2Array()
			for cell in trips[i]: path.append(Vector2(BuildCard.rotate_cell(Vector2i(cell),rotation)))
			trips[i] = path
	var placement := preload("res://scripts/map/tile/tile_placement.gd").new(); placement.map = logical
	for cell: Vector2i in cells:
		var mask := 0
		for d in 4:
			var offset: Vector3i = TileConstants.DIRECTIONS[d]
			if cells.has(cell+Vector2i(offset.x,offset.z)): mask |= 1<<d
		var tile: Vector2i = placement.tile_for_mask(mask)
		var item := TileConstants.WOOD_STRAIGHT if index == 6 and cell == BuildCard.rotate_cell(Vector2i(3,0),rotation) else tile.x
		logical.set_cell_item(Vector3i(cell.x,0,cell.y),item,tile.y)
	placement.free()
	if index == 6:
		# Parallel side-ground fixture: used to retain a full-cell bridge hole.
		var at := BuildCard.rotate_cell(Vector2i(1,0),rotation)
		logical.set_cell_item(Vector3i(at.x,0,at.y),TileConstants.WOOD_STRAIGHT,logical.get_orthogonal_index_from_basis(Basis(Vector3.UP,PI/2-rotation*PI/2)))
	var terminals: Array[Vector2i] = [Vector2i(trips[0][-1]),Vector2i(trips[0][0])]
	surface = Surface.new(); surface.prepare(logical,blocked,terminals)
	display = GridMap.new(); display.cell_size = Vector3.ONE; display.cell_center_y = false; display.mesh_library = surface.library; stage.add_child(display)
	for cell in logical.get_used_cells(): display.set_cell_item(cell,surface.item(logical,cell,logical.get_cell_item(cell)))
	var pending: Array = []
	for i in trips.size():
		for duplicate_index in i+1: pending.append({"profile":TroopCatalog.default_troop(),"start_index":i,"route":{"cells":trips[i]}})
	var forecast := RoadFlowForecast.from_pending(pending)
	_forecast = forecast; _animation_mode = false
	ribbon = Renderer.instantiate(); stage.add_child(ribbon); ribbon.flow_speed = 0; ribbon.highlight_length = 40; ribbon.line_width = 0.075
	ribbon.material_override.set_shader_parameter("flow_speed",0.0); ribbon.material_override.set_shader_parameter("highlight_length",40.0); ribbon.material_override.set_shader_parameter("phase_offset",3.0)
	var snapshot := preload("res://scripts/navigation/road_graph_snapshot.gd").capture(logical,blocked)
	_snapshot = snapshot
	ribbon.display(forecast.all,forecast.all,logical,forecast.animation(),snapshot)
	label.text = "道路凹槽／橋頭／寬路流量 · %d  %s\n1–9／0 切換 · R 旋轉 · Space 動畫   （實際完整行程配額，定格長筆觸供輪廓檢視）" % [index+1,cases[index]]
	var center := Vector3.ZERO
	for cell in logical.get_used_cells(): center += logical.map_to_local(cell)
	center /= logical.get_used_cells().size()
	camera.position = center+Vector3(8,10,11); camera.look_at(center)
	if automatic: verify_case(index,trips,forecast,snapshot,rotation)

func verify_case(index: int, trips: Array[PackedVector2Array], forecast: RoadFlowForecast, snapshot: Dictionary, rotation: int) -> void:
	var original := snapshot.duplicate(true)
	check(ribbon.mesh != null,cases[index]+" draws actual allocated flow")
	check(snapshot == original,cases[index]+" projection leaves snapshot unchanged")
	var vertices := display.mesh_library.get_item_mesh(display.get_cell_item(logical.get_used_cells()[0])).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var has_low := false; var has_high := false
	for point in vertices:
		if is_equal_approx(point.y,Surface.ROAD_HEIGHT): has_low = true
		if is_equal_approx(point.y,Surface.BANK_HEIGHT): has_high = true
	check(has_low and has_high,cases[index]+" recessed road and higher bank coexist")
	for path in trips:
		for i in range(path.size()-1):
			var a := Vector2i(path[i]); var b := Vector2i(path[i+1]); var direction := TileConstants.DIRECTIONS.find(Vector3i(b.x-a.x,0,b.y-a.y))
			check(direction >= 0 and surface.connects(a,direction),cases[index]+" allocated walk is reciprocally legal")
	if index in [1,2,3,4,5,9]:
		check(ribbon.wide_projection != null,cases[index]+" uses merged road projection")
		if ribbon.wide_projection != null:
			check(ribbon.wide_projection.fallback_trips == 0,cases[index]+" all projected routes remain on real road surface")
	if index in [1,2]:
		var center := 0.5 if index == 1 else 1.0
		for path: Dictionary in ribbon.wide_projection.projected_trips:
			for point: Vector2 in path.points: check(is_equal_approx(point.y,center),cases[index]+" all lanes share the true width center")
	if index == 6:
		var bridge := BuildCard.rotate_cell(Vector2i(3,0),rotation); var head := BuildCard.rotate_cell(Vector2i(1,0),rotation)
		check(surface.wood_cells.has(Vector3i(bridge.x,0,bridge.y)),"Open bridge span preserved")
		check(not surface.wood_cells.has(Vector3i(head.x,0,head.y)),"Side-contact bridge uses complete continuous foundation")
	if index == 9:
		var east := false; var west := false
		for piece: Dictionary in ribbon.projected_pieces:
			east = east or piece.b.x > piece.a.x
			west = west or piece.b.x < piece.a.x
		check(east and west,"Opposing real directions retain separate geometries and clocks")
	check(forecast.animation().trips.size() == trips.size(),"Duplicate allocations keep original clocks without adding geometry")
	for cell in logical.get_used_cells():
		var mesh := display.mesh_library.get_item_mesh(display.get_cell_item(cell))
		for z in [-0.46,-0.32,0.0,0.32,0.46]:
			for x in [-0.46,-0.32,0.0,0.32,0.46]:
				if surface.wood_cells.has(cell): continue
				check(top_hit(mesh,Vector2(x,z)),cases[index]+" full legal ground cover at "+str(cell)+" / "+str(Vector2(x,z)))
				coverage_probes += 1
	if index == 6:
		var at := BuildCard.rotate_cell(Vector2i(3,0),rotation)
		var bridge_mesh := display.mesh_library.get_item_mesh(display.get_cell_item(Vector3i(at.x,0,at.y)))
		for sign_value: float in [-1.0,1.0]:
			for side: float in [-0.33,0.0,0.33]:
				var point := Vector2(sign_value*0.498,side).rotated(rotation*PI/2)
				check(top_hit(bridge_mesh,point),"Bridge head has a real surface across its road width")
		check(not top_hit(bridge_mesh,Vector2(0.2,0.49).rotated(rotation*PI/2)),"Intentional open bridge side remains sky")

func top_hit(mesh: Mesh, point: Vector2) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	for i in range(0,indices.size(),3):
		if Geometry3D.ray_intersects_triangle(Vector3(point.x,2,point.y),Vector3.DOWN,vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]) != null: return true
	return false

func frame_image() -> Image:
	await frames(2); await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func difference(image: Image, baseline: Image, point: Vector2) -> float:
	var world := logical.to_global(logical.map_to_local(Vector3i.ZERO)+Vector3(point.x,ribbon.surface_height,point.y))
	var screen := Vector2i(camera.unproject_position(world)); var result := 0.0
	for y in range(screen.y-2,screen.y+3):
		for x in range(screen.x-2,screen.x+3):
			var a := image.get_pixel(x,y); var b := baseline.get_pixel(x,y)
			result = maxf(result,Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length())
	pixel_probes += 1
	return result

func verify_pixels(index: int) -> void:
	if index not in [1,9]: return
	ribbon.hide(); var baseline := await frame_image(); ribbon.show()
	var pending: Array = []
	var paths := [row(0),row(1)]
	if index == 9: paths[1].reverse()
	for i in paths.size(): pending.append({"profile":TroopCatalog.default_troop(),"start_index":i,"route":{"cells":paths[i]}})
	var forecast := RoadFlowForecast.from_pending(pending)
	var snapshot := preload("res://scripts/navigation/road_graph_snapshot.gd").capture(logical)
	ribbon.highlight_length = 0.5
	ribbon.material_override.set_shader_parameter("highlight_length",0.5)
	ribbon.material_override.set_shader_parameter("phase_offset",0.75)
	for origin in 2:
		ribbon.display(forecast.by_origin[origin],forecast.all,logical,forecast.animation(null,origin),snapshot)
		var image := await frame_image()
		var x := 2.25 if index == 9 and origin == 1 else 0.75
		check(difference(image,baseline,Vector2(x,0.5)) > 0.025,"Projected actual clock lights centered lane")
		check(difference(image,baseline,Vector2(x,0)) < 0.015,"Old single-cell lane center stays transparent")
		check(difference(image,baseline,Vector2(x,1)) < 0.015,"Second old lane center stays transparent")
		check(difference(image,baseline,Vector2(3-x,0.5)) < 0.015,"No invented or reversed-time pulse at opposite location")
		image.save_png(Artifacts.path("road_depth_flow/"+cases[index]+"_origin%d_phase075.png" % origin))
	# The lateral step inside the wide road is a timed dwell, not a lost second.
	if index == 1:
		var lane_change := trip([Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(2,1),Vector2i(3,1)])
		forecast = RoadFlowForecast.from_pending([{"profile":TroopCatalog.default_troop(),"start_index":0,"route":{"cells":lane_change}}])
		ribbon.display(forecast.all,forecast.all,logical,forecast.animation(),snapshot)
		ribbon.material_override.set_shader_parameter("phase_offset",1.5)
		var dwell := await frame_image()
		check(difference(dwell,baseline,Vector2(1,0.5)) > 0.025,"Collapsed lane change retains its full-trip dwell phase")
		dwell.save_png(Artifacts.path("road_depth_flow/wide2_lane_change_dwell.png"))

func verify_scheduled(index: int) -> void:
	if index not in [1,2,3,4,5]: return
	var coordinates: Array[Vector2i] = []
	for cell in logical.get_used_cells(): coordinates.append(Vector2i(cell.x,cell.z))
	var start: Vector2i = coordinates[0]; var goal: Vector2i = coordinates[-1]
	# Use geometric ends rather than GridMap iteration order.
	coordinates.sort(); start = coordinates[0]; goal = coordinates[-1]
	var fixture := preload("res://tests/fixtures/portal_fixture.gd").scene_for(coordinates,start,goal)
	fixture.get_node("EnemyWave").auto_start = false
	fixture.get_node("CardPlacement").cards.clear(); fixture.get_node("CardPlacement").initial_card_count = 0
	get_tree().root.add_child(fixture); fixture.hide()
	for layer in fixture.find_children("*","CanvasLayer",true,false): layer.hide()
	await frames(4)
	var controller: Node = fixture.get_node("PortalMap")
	var definition := WaveDefinition.new()
	for id in ["soldier","scout","winged"]:
		var group := WaveSpawnGroup.new(); group.troop = TroopCatalog.find(id); group.enemy_count = 8; group.interval_ticks = 1; definition.groups.append(group)
	var rng_state: int = fixture.get_node("EnemyWave").spawn_rng.state
	var revision: int = controller.revision
	var schedule := WaveSpawnSchedule.build(definition,controller,99,false)
	check(not schedule.is_empty() and schedule.pending.size() == 24,"Actual scheduler provides Soldier/Scout/Winged allocations")
	if not schedule.is_empty():
		scheduled_members += schedule.pending.size()
		var forecast := RoadFlowForecast.from_pending(schedule.pending)
		var original: Dictionary = forecast.all.duplicate(true)
		ribbon.highlight_length = 40; ribbon.material_override.set_shader_parameter("highlight_length",40.0); ribbon.material_override.set_shader_parameter("phase_offset",3.0)
		ribbon.display(forecast.all,forecast.all,logical,forecast.animation())
		if ribbon.wide_projection != null:
			scheduled_projection[cases[index]] = {"walks":ribbon.wide_projection.projected_trips.size(),"fallbacks":ribbon.wide_projection.fallback_trips,"pieces":ribbon.projected_pieces.size()}
		check(forecast.all == original and controller.revision == revision and fixture.get_node("EnemyWave").spawn_rng.state == rng_state,"Rendering real schedule preserves quotas, navigation and RNG")
		if index in [1,2] and ribbon.wide_projection != null:
			var center := 0.5 if index == 1 else 1.0
			for path: Dictionary in ribbon.wide_projection.projected_trips:
				for point: Vector2 in path.points: check(is_equal_approx(point.y,center),"Native candidate walks still project to one longitudinal line")
		if index == 5 and ribbon.wide_projection != null:
			for path: Dictionary in ribbon.wide_projection.projected_trips:
				for point: Vector2 in path.points:
					if is_equal_approx(point.x,2.0): check(is_equal_approx(point.y,0.0),"Every native lane uses the same narrow-to-wide entry cross-section")
		if index in [3,4] and ribbon.wide_projection != null:
			for path: Dictionary in ribbon.wide_projection.projected_trips:
				for point: Vector2 in path.points:
					check(is_equal_approx(point.x,0.5) or is_equal_approx(point.y,2.5) if index == 3 else is_equal_approx(point.y,0.5) or is_equal_approx(point.x,2.5),"Real L/T allocations stay on shared arm centers without lane-change spurs")
		for group in definition.groups:
			var selected: Dictionary = forecast.segments(group.troop)
			ribbon.display(selected,forecast.all,logical,forecast.animation(group.troop))
			var isolated := true
			for piece: Dictionary in ribbon.projected_pieces:
				for edge: Vector4i in piece.sources:
					if not selected.has(edge): isolated = false
			check(isolated,"Wide troop Hover projection retains only the selected Soldier/Scout/Winged source data")
		ribbon.display(forecast.all,forecast.all,logical,forecast.animation())
		if DisplayServer.get_name() != "headless":
			label.text = "真實 WaveSpawnSchedule · "+cases[index]+" · 24 名 Soldier／Scout／Winged Beast"
			var image := await frame_image(); image.save_png(Artifacts.path("road_depth_flow/scheduled_"+cases[index]+".png"))
	fixture.queue_free(); await frames(1)

func run() -> void:
	for index in cases.size():
		selected = index; build_case(index); await frames(4)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(Artifacts.path("road_depth_flow/"+cases[index]+".png"))
			await verify_pixels(index)
		await verify_scheduled(index)
		if index == 6 or index == 8:
			for rotation in range(1,4):
				build_case(index,rotation); await frames(2)
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					viewport.get_texture().get_image().save_png(Artifacts.path("road_depth_flow/"+cases[index]+"_rot%d.png" % rotation))
	var result := {"checks":checks,"failures":failures,"coverage_probes":coverage_probes,"pixel_probes":pixel_probes,"scheduled_members":scheduled_members,"scheduled_projection":scheduled_projection,"rendered":DisplayServer.get_name() != "headless","cases":cases}
	FileAccess.open(Artifacts.path("road_depth_flow/"+("rendered" if result.rendered else "headless")+".json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ROAD_DEPTH_FLOW:",JSON.stringify(result)); get_tree().quit(0 if failures.is_empty() else 1)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode >= KEY_1 and event.keycode <= KEY_9: turns = 0; selected = event.keycode-KEY_1; build_case(selected)
	elif event.keycode == KEY_0: turns = 0; selected = 9; build_case(selected)
	elif event.keycode == KEY_R: turns = (turns+1)%4; build_case(selected,turns)
	elif event.keycode == KEY_SPACE:
		_animation_mode = not _animation_mode
		ribbon.highlight_length = 1.2 if _animation_mode else 40.0
		ribbon.material_override.set_shader_parameter("highlight_length",ribbon.highlight_length)
		ribbon.material_override.set_shader_parameter("flow_speed",1.5 if _animation_mode else 0.0)
		ribbon.display(_forecast.all,_forecast.all,logical,_forecast.animation(),_snapshot)
