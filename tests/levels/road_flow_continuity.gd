extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
var probes := 0
var pixel_probes := 0
var rendered := false
var ribbon: MeshInstance3D
var map: GridMap
var camera: Camera3D
var viewport: SubViewport
var junction_probes := 0
var width_samples := 0

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	if failures <= 5: push_error(message)

func _ready() -> void:
	rendered = DisplayServer.get_name() != "headless"
	run.call_deferred()

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func member(profile: Troop, origin: int, cells: PackedVector2Array) -> Dictionary:
	return {"profile":profile,"start_index":origin,"route":{"cells":cells}}

func distance_at(clock: RoadFlowPhases, phases: Dictionary, time: float) -> float:
	var id := clock.register(phases)
	var table := clock.lookup_texture().get_image()
	var phase := fposmod(time-id.y,float(clock.period))
	var gap := table.get_pixel(int(floor(phase)),int(id.x))
	var left := roundf(gap.r*255.0)+roundf(gap.g*255.0)*256.0
	var right := roundf(gap.b*255.0)+roundf(gap.a*255.0)*256.0
	return minf(left+fposmod(phase,1.0),right-fposmod(phase,1.0))

func capture(time: float) -> Image:
	ribbon.material_override.set_shader_parameter("phase_offset",time)
	await frames()
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func pixel_at(point: Vector2, time: float, lit := true) -> void:
	var image := await capture(time)
	var screen := Vector2i(camera.unproject_position(Vector3(point.x,ribbon.surface_height,point.y)))
	var brightness := 0.0
	for y in range(screen.y-2,screen.y+3):
		for x in range(screen.x-2,screen.x+3):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height(): continue
			brightness = maxf(brightness,image.get_pixel(x,y).r)
	# Low-flow lanes deliberately retain lower opacity than the busiest route.
	check(brightness > 0.50 if lit else brightness < 0.40,"Wrong stroke visibility at %s, travel time %.2f (pixel %.3f, lit %s)" % [point,time,brightness,lit])
	pixel_probes += 1

func verify_trips(trips: Array[PackedVector2Array], name_tag: String) -> void:
	var profile := Troop.new()
	var pending: Array = []
	for trip in trips: pending.append(member(profile,0,trip))
	# Repeated allocations must affect traffic, not duplicate animation profiles.
	pending.append(member(profile,0,trips[0]))
	var forecast := RoadFlowForecast.from_pending(pending)
	var clock := forecast.animation()
	ribbon.display(forecast.all,forecast.all,map,clock)
	var mesh_id := ribbon.mesh.get_instance_id()
	for trip in trips:
		for i in range(trip.size()-1):
			var a := trip[i]
			var b := trip[i+1]
			var edge := Vector4i(int(a.x),int(a.y),int(b.x),int(b.y))
			check(distance_at(clock,clock.edges[edge],float(i)) < 0.0001,"Allocated edge visit lost its phase")
			probes += 1
			if rendered:
				await pixel_at((a+b)*0.5,i+0.5)
		var goal := trip[trip.size()-1]
		if rendered: await pixel_at(goal,float(trip.size()-1))
	check(ribbon.mesh.get_instance_id() == mesh_id,"Animation rebuilt the mesh")
	if rendered and not OS.has_feature("web"):
		viewport.get_texture().get_image().save_png(Artifacts.path("levels/flow_continuity_%s.png" % name_tag))
	# Table distances must agree with an independent search over every original visit,
	# including between integer samples and across the periodic seam.
	for phases: Dictionary in clock.edges.values():
		for quarter in range(-8,clock.period*4+8):
			var time := float(quarter)/4.0+0.037
			var expected := INF
			for step: int in phases:
				var gap := fposmod(time-float(step),float(clock.period))
				expected = minf(expected,minf(gap,float(clock.period)-gap))
			var actual := distance_at(clock,phases,time)
			check(is_equal_approx(actual,expected),"Lookup changed arrival distance at the periodic seam: time=%s expected=%s actual=%s format=%s" % [time,expected,actual,clock.lookup_texture().get_image().get_format()])
	# Isolating one entrance must keep only that entrance's complete clocks.
	var other := RoadFlowForecast.from_pending([member(profile,0,trips[0]),member(profile,1,trips.back())])
	check(other.animation(null,0).edges == RoadFlowForecast.from_pending([member(profile,0,trips[0])]).animation().edges,"Entrance filter leaked other trip phases")
	check(other.animation(null,0) == other.animation(null,0),"Hover did not reuse cached clocks")

func rotated_trip(points: Array, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points: result.append(point.rotated(angle).round())
	return result

func local_pieces(forecast: RoadFlowForecast, all_traffic: RoadFlowForecast) -> Array:
	var adjacent: Array = []
	var connections: Array = []
	var clock := forecast.animation()
	var peak := 1
	for edge: Vector4i in all_traffic.all:
		peak = maxi(peak,int(all_traffic.all[edge]))
		if Vector2i(edge.x,edge.y) == Vector2i.ZERO and not Vector2i(edge.z,edge.w) in adjacent: adjacent.append(Vector2i(edge.z,edge.w))
		if Vector2i(edge.z,edge.w) == Vector2i.ZERO and not Vector2i(edge.x,edge.y) in adjacent: adjacent.append(Vector2i(edge.x,edge.y))
	for entering: Vector4i in clock.turns:
		if Vector2i(entering.z,entering.w) != Vector2i.ZERO: continue
		for leaving: Vector4i in clock.turns[entering]: connections.append([entering,leaving,clock.turns[entering][leaving]])
	# Structural checks use CPU geometry: Web float-texture readback clamps
	# negative normals / counts above one. GPU behavior is verified by pixels.
	return ribbon._cell_pieces(Vector2i.ZERO,adjacent,connections,forecast.all,clock,peak)

func junctions() -> void:
	var profile := Troop.new()
	ribbon.highlight_length = 6.1
	ribbon.material_override.set_shader_parameter("highlight_length",6.1)
	for rotation in 4:
		var angle := rotation*PI*0.5
		var forward := rotated_trip([Vector2(0,1),Vector2.ZERO,Vector2(1,0)],angle)
		var reverse := rotated_trip([Vector2(1,0),Vector2.ZERO,Vector2(0,1)],angle)
		var across := rotated_trip([Vector2(-1,0),Vector2.ZERO,Vector2(1,0)],angle)
		var selected := RoadFlowForecast.from_pending([member(profile,0,forward)])
		var all_traffic := RoadFlowForecast.from_pending([member(profile,0,forward),member(profile,1,reverse),member(profile,1,across)])
		ribbon.display(selected.all,all_traffic.all,map,selected.animation())
		var pieces := local_pieces(selected,all_traffic)
		check(pieces.size() == 3 and pieces[1].arc,"T-junction retained a sharp 90-degree turn")
		check(pieces[0].b.is_equal_approx(pieces[1].a) and pieces[1].b.is_equal_approx(pieces[2].a),"Arc does not meet its straight approaches")
		check(pieces[0].clip_b.length_squared() > 0.5,"Internal junction still has a round cap")
		var other := RoadFlowForecast.from_pending([member(profile,0,reverse)])
		var reverse_pieces := local_pieces(other,all_traffic)
		check(pieces[1].a.is_equal_approx(reverse_pieces[1].b) and pieces[1].b.is_equal_approx(reverse_pieces[1].a),"Opposite turns use different curves")
		if rendered:
			ribbon.material_override.set_shader_parameter("highlight_length",6.1)
			# The former miter corner stays transparent; the circle and its joins light.
			await pixel_at(Vector2(-0.04,-0.04).rotated(angle),1.0,false)
			var r: float = ribbon.corner_radius
			var middle := Vector2.ONE*(r-r/sqrt(2.0))
			await pixel_at(middle.rotated(angle),1.0)
			await pixel_at(Vector2(0,r).rotated(angle),1.0)
			await pixel_at(Vector2(r,0).rotated(angle),1.0)
			await pixel_at(Vector2(0,1.055).rotated(angle),0.0)
			await pixel_at(Vector2(1.055,0).rotated(angle),2.0)
			var forward_image := await capture(1.0)
			if rotation == 0 and not OS.has_feature("web"):
				camera.size = 3.5
				camera.position = Vector3(0,10,0)
				var rounded := await capture(1.0)
				rounded.save_png(Artifacts.path("levels/flow_junction_rounded.png"))
				camera.size = 10.0
				camera.position = Vector3(2,10,1)
			# The same curve still carries independent forward / reverse clocks.
			ribbon.material_override.set_shader_parameter("highlight_length",0.5)
			await pixel_at(Vector2(0,r).rotated(angle),1.0-r)
			await pixel_at(Vector2(r,0).rotated(angle),1.0-r,false)
			ribbon.display(other.all,all_traffic.all,map,other.animation())
			await pixel_at(Vector2(r,0).rotated(angle),1.0-r)
			await pixel_at(Vector2(0,r).rotated(angle),1.0-r,false)
			ribbon.material_override.set_shader_parameter("highlight_length",6.1)
			var reverse_image := await capture(1.0)
			if rotation == 0:
				var combined := RoadFlowForecast.from_pending([member(profile,0,forward),member(profile,0,reverse)])
				ribbon.display(combined.all,all_traffic.all,map,combined.animation())
				var union_image := await capture(1.0)
				var center := Vector2i(camera.unproject_position(Vector3(0,ribbon.surface_height,0)))
				var maximum_error := 0.0
				for y in range(center.y-45,center.y+45):
					for x in range(center.x-45,center.x+45):
						var f := forward_image.get_pixel(x,y)
						var back := reverse_image.get_pixel(x,y)
						var both := union_image.get_pixel(x,y)
						maximum_error = maxf(maximum_error,maxf(absf(both.r-maxf(f.r,back.r)),maxf(absf(both.g-maxf(f.g,back.g)),absf(both.b-maxf(f.b,back.b)))))
				check(maximum_error <= 1.01/255.0,"Centered opposite flows alpha-over instead of taking their union")
		junction_probes += 1
	# Every possible four-way connection, including U-turns and trips starting /
	# ending at this junction, fits the same bounded per-cell shader workload.
	var pending: Array = []
	var adjacent := [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]
	for a: Vector2 in adjacent:
		for b: Vector2 in adjacent: pending.append(member(profile,0,PackedVector2Array([a,Vector2.ZERO,b])))
		pending.append(member(profile,0,PackedVector2Array([a,Vector2.ZERO])))
		pending.append(member(profile,0,PackedVector2Array([Vector2.ZERO,a])))
	var worst := RoadFlowForecast.from_pending(pending)
	ribbon.display(worst.all,worst.all,map,worst.animation())
	check(local_pieces(worst,worst).size() == ribbon.MAX_PIECES,"Four-way junction capacity does not cover all transitions and termini")
	check(ribbon.mesh.get_surface_count() == 1 and ribbon.rendered_cells.size() == 5,"Junction lost its single batch / cell patches")
	if rendered: await pixel_at(Vector2(0.3,0),1.0)

func measured_width(image: Image, point: Vector2, normal: Vector2) -> float:
	var step := camera.size/viewport.size.y
	var lit := 0
	for offset in range(-40,41):
		var sample := point+normal*(offset*step)
		var screen := Vector2i(camera.unproject_position(Vector3(sample.x,ribbon.surface_height,sample.y)))
		if image.get_pixel(screen.x,screen.y).r > 0.4: lit += 1
	return lit*step

func width_transitions() -> void:
	var profile := Troop.new()
	var r: float = ribbon.corner_radius
	# Isolate unequal edge traffic without a second crossing stroke hiding the
	# taper. Compare CPU joins and independently measure the rendered silhouette.
	ribbon.highlight_length = 100.0
	ribbon.material_override.set_shader_parameter("highlight_length",100.0)
	camera.size = 2.0
	camera.position = Vector3(0,10,0)
	for rotation in 4:
		var angle := rotation*PI*0.5
		var trip := rotated_trip([Vector2(0,1),Vector2.ZERO,Vector2(1,0)],angle)
		for rising: bool in [true,false]:
			var forecast := RoadFlowForecast.from_pending([member(profile,0,trip)])
			forecast.all[Vector4i(int(trip[0].x),int(trip[0].y),0,0)] = 1 if rising else 16
			forecast.all[Vector4i(0,0,int(trip[2].x),int(trip[2].y))] = 16 if rising else 1
			ribbon.display(forecast.all,forecast.all,map,forecast.animation())
			var pieces := local_pieces(forecast,forecast)
			for i in range(1,pieces.size()):
				check(is_equal_approx(pieces[i-1].end_width,pieces[i].width),"Line width jumps at an arc/straight join")
				check(is_equal_approx(pieces[i-1].end_strength,pieces[i].strength),"Opacity jumps at an arc/straight join")
			if not rendered: continue
			var image := await capture(1.0)
			if rotation == 0 and rising and not OS.has_feature("web"):
				image.save_png(Artifacts.path("levels/flow_width_tapered.png"))
			for u in [0.0,0.1,0.25,0.5,0.75,0.9,1.0]:
				var normal := Vector2.LEFT.rotated(u*PI*0.5)
				var point := Vector2.ONE*r+normal*r
				var actual := measured_width(image,point.rotated(angle),normal.rotated(angle))
				var blend: float = u*u*(3.0-2.0*u)
				var expected: float = 2.0*lerpf(pieces[1].width,pieces[1].end_width,blend)
				check(absf(actual-expected) <= 3.0*camera.size/viewport.size.y,"Rendered taper width differs at %.2f: %.4f vs %.4f" % [u,actual,expected])
				width_samples += 1
	var straight := RoadFlowForecast.from_pending([member(profile,0,PackedVector2Array([Vector2.LEFT,Vector2.ZERO,Vector2.RIGHT]))])
	straight.all[Vector4i(-1,0,0,0)] = 1
	straight.all[Vector4i(0,0,1,0)] = 16
	ribbon.display(straight.all,straight.all,map,straight.animation())
	var halves := local_pieces(straight,straight)
	check(is_equal_approx(halves[0].end_width,halves[1].width),"Straight junction retains a width step")
	check(halves[0].width < halves[0].end_width and halves[1].width < halves[1].end_width,"Unequal straight traffic did not taper")
	camera.size = 10.0
	camera.position = Vector3(2,10,1)
	ribbon.highlight_length = 6.1
	ribbon.material_override.set_shader_parameter("highlight_length",6.1)

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(960,600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.06,0.08,0.1)
	world.add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(2,10,1)
	camera.rotation_degrees = Vector3(-90,0,0)
	world.add_child(camera)
	map = GridMap.new()
	map.cell_size = Vector3.ONE
	map.cell_center_x = false
	map.cell_center_z = false
	world.add_child(map)
	ribbon = load("res://scenes/navigation/road_flow_renderer.tscn").instantiate()
	world.add_child(ribbon)
	ribbon.highlight_length = 0.5
	ribbon.line_width = 0.13
	ribbon.material_override.set_shader_parameter("highlight_length",0.5)
	ribbon.material_override.set_shader_parameter("flow_speed",0.0)
	var short := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(2,0),Vector2(3,0),Vector2(4,0)])
	var long := PackedVector2Array([Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(2,1),Vector2(3,1),Vector2(3,0),Vector2(4,0)])
	await verify_trips([short,long],"merge")
	# The exact same directed edge is revisited at a different trip distance.
	var loop := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(0,0),Vector2(1,0),Vector2(2,0),Vector2(3,0),Vector2(4,0)])
	var reverse := PackedVector2Array([Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(2,0),Vector2(3,0),Vector2(4,0)])
	await verify_trips([short,loop,reverse],"loop")
	var single := RoadFlowForecast.from_pending([member(Troop.new(),0,short)])
	ribbon.display(single.all,single.all,map,single.animation())
	if rendered:
		# Check the soft tail and absence of spurious pulses between true arrivals.
		await pixel_at(Vector2(0.5,0),0.6)
		for time in [1.375,2.375,3.375,4.375]: await pixel_at(Vector2(0.5,0),time,false)
	# Enough distinct arrival gaps to catch accidental truncation or one-clock fallback.
	var many := RoadFlowPhases.new()
	many.steps = 300
	var arrivals := {}
	for i in 70: arrivals[i*4] = true
	many.prepare(0.5)
	for step: int in arrivals: check(distance_at(many,arrivals,float(step)) == 0.0,"High fan-in discarded an arrival")
	await junctions()
	await width_transitions()
	var result := {"failures":failures,"rendered":rendered,"route_probes":probes,"pixel_probes":pixel_probes,"width_samples":width_samples,"junction_rotations":junction_probes,"junction_capacity":48,"unequal_merge":true,"repeated_loop_edge":true,"centered_bidirectional":true,"periodic_seam":true,"many_arrivals":70}
	if not OS.has_feature("web"):
		var output := FileAccess.open(Artifacts.path("levels/flow_continuity_%s.json" % ("rendered" if rendered else "headless")),FileAccess.WRITE)
		output.store_string(JSON.stringify(result,"\t"))
	print("FLOW_CONTINUITY:"+JSON.stringify(result))
	if not OS.has_feature("web"): get_tree().quit(1 if failures else 0)
