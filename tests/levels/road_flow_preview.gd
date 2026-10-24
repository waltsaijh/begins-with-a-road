extends Node
const Fixture = preload("res://tests/levels/road_flow_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
var rendered := false

func _ready() -> void:
	rendered = DisplayServer.get_name() != "headless"
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	get_viewport().push_input(event, true)
	await frames()

func displayed_totals(hud: CanvasLayer) -> Dictionary:
	var result := {}
	for action: Button in hud.start_callouts:
		var counts: Dictionary = action.get_node("NextWaveIntel").counts
		for profile: Troop in counts:
			result[profile] = int(result.get(profile,0))+int(counts[profile])
	return result

func click_now(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event,true)
	# Camera click/drag arbitration replays ordinary clicks deferred.
	await frames(2)

func member(profile: Troop, origin: int, cells: Array) -> Dictionary:
	return {"profile": profile, "start_index": origin, "route": {"cells": PackedVector2Array(cells)}}

func check_rendered_scope(preview: Node, profile: Troop, origin: int) -> void:
	var expected := {}
	var segments: Dictionary = preview.forecast.by_origin[origin] if profile == null else preview.forecast.by_troop_origin[profile][origin]
	for edge: Vector4i in segments:
		expected[Vector2i(edge.x,edge.y)] = true
		expected[Vector2i(edge.z,edge.w)] = true
	check(preview.arrows.rendered_cells.size() == expected.size(), "Hover rendered cells from another entrance")
	for cell: Vector2i in preview.arrows.rendered_cells:
		check(expected.has(cell), "Hover leaked another entrance's road cell: %s" % cell)
	# Compare the actual GPU input, including counts/widths and direction clocks,
	# with a renderer receiving only this entrance's allocated trips.
	var reference: MeshInstance3D = load("res://scenes/navigation/road_flow_renderer.tscn").instantiate()
	add_child(reference)
	reference.line_width = preview.arrows.line_width
	reference.display(segments,preview.forecast.all,preview.controller.map,preview.forecast.animation(profile,origin))
	check(reference.phase_data.get_image().get_data() == preview.arrows.phase_data.get_image().get_data(), "Hover clocks mix another entrance")
	check(reference.flow_data.get_image().get_data() == preview.arrows.flow_data.get_image().get_data(), "Hover GPU data mixes another entrance's counts or directions")
	reference.queue_free()

func statistics() -> void:
	var a := Troop.new()
	var b := Troop.new()
	var shared := Vector4i(0, 0, 1, 0)
	var forecast := RoadFlowForecast.from_pending([
		member(a, 0, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(2, 1)]),
		member(a, 0, [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(2, 1)]),
		member(b, 1, [Vector2(2, 0), Vector2(1, 0), Vector2(0, 0)]),
		member(b, 1, [Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)])])
	check(forecast.all[shared] == 2 and forecast.all[Vector4i(1, 0, 0, 0)] == 2, "Opposite directions were merged")
	check(forecast.all[Vector4i(1, 0, 1, 1)] == 1 and forecast.all[Vector4i(1, 0, 2, 0)] == 1, "Fork visits incorrect")
	check(forecast.all[Vector4i(1, 1, 2, 1)] == 1 and forecast.all[Vector4i(2, 0, 2, 1)] == 1, "Merge visits incorrect")
	for key in forecast.all:
		check(int(forecast.by_troop[a].get(key, 0))+int(forecast.by_troop[b].get(key, 0)) == forecast.all[key], "Troop sums differ from total")
		check(int(forecast.by_origin[0].get(key, 0))+int(forecast.by_origin[1].get(key, 0)) == forecast.all[key], "Entrance sums differ from total")
	check(forecast.by_troop_origin[a][0] == forecast.by_troop[a], "Troop/entrance breakdown incorrect")
	check(RoadFlowForecast.from_pending([]).all.is_empty(), "Empty schedule fabricated flow")

func geometry_clocks(segments: Dictionary) -> RoadFlowPhases:
	var result := RoadFlowPhases.new()
	for edge: Vector4i in segments:
		result.add_trip(PackedVector2Array([Vector2(edge.x,edge.y),Vector2(edge.z,edge.w)]))
	return result

func ribbon_geometry() -> void:
	var map := GridMap.new()
	map.cell_size = Vector3.ONE
	add_child(map)
	var ribbon: MeshInstance3D = load("res://scenes/navigation/road_flow_renderer.tscn").instantiate()
	add_child(ribbon)
	var bend := {Vector4i(0, 0, 1, 0): 5, Vector4i(1, 0, 1, 1): 5}
	var bend_clock := RoadFlowPhases.new()
	bend_clock.add_trip(PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1)]))
	ribbon.display(bend, bend, map, bend_clock)
	var vertices: PackedVector3Array = ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size() == 18 and ribbon.rendered_cells.size() == 3, "Bend did not use three non-overlapping cell patches")
	var data: Image = ribbon.flow_data.get_image()
	var row: int = ribbon.rendered_cells.find(Vector2i(1, 0))
	check(int(data.get_pixel(0, row).r) == 3, "Corner did not contain two straight pieces and one exact arc")
	var first := data.get_pixel(1, row)
	check(is_equal_approx(first.g, first.a), "Approach to corner is curved instead of straight")
	var traffic := {Vector4i(0, 0, 1, 0): 1, Vector4i(0, 1, 1, 1): 12}
	ribbon.display(traffic, traffic, map, geometry_clocks(traffic))
	data = ribbon.flow_data.get_image()
	var low := data.get_pixel(2, ribbon.rendered_cells.find(Vector2i(0, 0)))
	var high := data.get_pixel(2, ribbon.rendered_cells.find(Vector2i(0, 1)))
	check(high.a > low.a and high.r > low.r, "Heavy traffic did not retain thicker/darker static lines")
	var bidirectional := {Vector4i(0, 0, 1, 0): 5, Vector4i(1, 0, 0, 0): 5}
	ribbon.display(bidirectional, bidirectional, map, geometry_clocks(bidirectional))
	data = ribbon.flow_data.get_image()
	row = ribbon.rendered_cells.find(Vector2i.ZERO)
	first = data.get_pixel(1, row)
	var second := data.get_pixel(4, row)
	check(int(data.get_pixel(0,row).r) == 2 and is_zero_approx(first.g) and is_zero_approx(second.g) and is_zero_approx(first.a) and is_zero_approx(second.a), "Opposite traffic did not overlap the road center")
	ribbon.display({Vector4i(1, 0, 0, 0): 5}, bidirectional, map, geometry_clocks({Vector4i(1,0,0,0):5}))
	data = ribbon.flow_data.get_image()
	row = ribbon.rendered_cells.find(Vector2i.ZERO)
	check(is_equal_approx(data.get_pixel(1,row).g, minf(first.g, second.g)), "Hover moved reverse flow away from the center")
	var isolated := {Vector4i(0,0,1,0): 2}
	var unrelated := isolated.duplicate()
	for x in 12: unrelated[Vector4i(x,4,x+1,4)] = 9
	ribbon.display(isolated,unrelated,map,geometry_clocks(isolated))
	var isolated_period: float = ribbon.material_override.get_shader_parameter("stroke_period")
	check(is_equal_approx(isolated_period,maxf(4.0,ceilf(ribbon.highlight_length*2.0))), "Other entrance still controls filtered animation clock")
	var junction := {Vector4i(-1, 0, 0, 0): 5, Vector4i(0, 0, 1, 0): 5, Vector4i(0, 0, 0, 1): 5}
	ribbon.display(junction, junction, map, geometry_clocks(junction))
	data = ribbon.flow_data.get_image()
	row = ribbon.rendered_cells.find(Vector2i.ZERO)
	check(ribbon.rendered_cells.count(Vector2i.ZERO) == 1 and int(data.get_pixel(0,row).r) == 3, "Junction uses stacked transparent patches")
	ribbon.queue_free()
	map.queue_free()

func verify() -> void:
	if get_tree().has_meta(&"road_flow_restart"):
		failures = get_tree().get_meta(&"road_flow_restart")
		get_tree().remove_meta(&"road_flow_restart")
		var restarted: Node3D = load("res://scenes/level.tscn").instantiate()
		add_child(restarted)
		await frames(12)
		check(not get_tree().paused and Engine.time_scale == 1.0 and restarted.current_wave == 0, "Restart retained paused/progression state")
		check(restarted.get_node("WaveFlowPreview").panel.selected == null and restarted.get_node("WaveFlowPreview").panel.counts == RoadFlowForecast.troop_counts(restarted._waves[0]), "Restart retained hover/old troop list")
		check(restarted.get_node("WaveFlowPreview").arrows.mesh != null and restarted.get_node("EnemyWave")._pending.is_empty(), "Restart retained combat or lost arrows")
		var result := {"failures": failures, "rendered": rendered, "counts": true, "directed_edges": true, "rng": true, "quotas": true, "lifecycle": true, "restart": true}
		var output := FileAccess.open(Artifacts.path("levels/road_flow_%s.json" % ("rendered" if rendered else "headless")), FileAccess.WRITE)
		output.store_string(JSON.stringify(result, "\t"))
		print("ROAD_FLOW_CHECK:"+JSON.stringify(result))
		get_tree().quit(1 if failures else 0)
		return
	statistics()
	ribbon_geometry()
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.level = Fixture.level()
	add_child(scene)
	await frames(12)
	var preview: Node = scene.get_node("WaveFlowPreview")
	var panel: Control = preview.panel
	var wave: Node = scene.get_node("EnemyWave")
	var controller: Node = scene.get_node("PortalMap")
	var hud: CanvasLayer = scene.get_node("LevelHUD")
	check(panel.visible and preview.arrows.visible and preview.arrows.mesh != null, "Initial preview missing")
	check(controller.start_nodes.size() == 2 and preview.forecast.by_origin.size() == 2, "Multi-entrance flow missing")
	var vertex_count: int = preview.arrows.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	check(preview.arrows.mesh.get_surface_count() == 1 and vertex_count == preview.arrows.rendered_cells.size()*6, "Flow is not a single batch of disjoint cell patches")
	var soldier: Troop = wave.definition.groups[0].troop
	check(hud.start_callouts.size() == 2, "Each entrance did not get its own start action")
	var second_panel: Control = hud.start_callouts[1].get_node("NextWaveIntel")
	check(panel.counts[soldier] == 10 and panel.counts.size() == 2, "First entrance shows global rather than allocated counts")
	check(second_panel.counts[soldier] == 6 and second_panel.counts.size() == 2, "Second entrance troop counts incorrect")
	check(displayed_totals(hud) == RoadFlowForecast.troop_counts(wave.definition), "Entrance counts do not sum to the wave")
	# Even an authored entrance with no assigned groups has its own zero-count action.
	var unused := Node3D.new()
	unused.name = "UnusedTestEntrance"
	scene.add_child(unused)
	unused.global_position = controller.map.to_global(controller.map.map_to_local(Vector3i(4,0,4)))
	controller.start_paths.append(controller.get_path_to(unused))
	controller.rebuild()
	await frames(10)
	check(hud.start_callouts.size() == 3 and hud.start_callouts[2].get_node("NextWaveIntel").counts.is_empty(),"Unassigned entrance did not display its actual zero count")
	check(hud.start_callouts[2].get_node("NextWaveIntel/Scroll/Items").get_child(0).text == "×0","Empty entrance count is not visible")
	controller.start_paths.pop_back()
	unused.queue_free()
	controller.rebuild()
	await frames(10)
	check(hud.start_callouts.size() == 2,"Removed entrance retained its action")
	var all_before: Dictionary = preview.forecast.all.duplicate()
	var builds: int = preview.rebuild_count
	var before := WaveSpawnSchedule.build(wave.definition, controller, 0, false)
	seed(88271)
	var expected_random := randi()
	seed(88271)
	preview.invalidate()
	await frames()
	check(randi() == expected_random, "Prediction consumed global battle RNG")
	builds = preview.rebuild_count
	var item := panel.get_node("Scroll/Items").get_child(0)
	if rendered:
		await move_mouse(item.body.get_global_rect().get_center())
	else:
		item.body.mouse_entered.emit()
	check(panel.selected == soldier and preview.selected_origin == 0 and not preview.forecast.by_troop_origin[soldier][0].is_empty(), "Hover did not filter troop and entrance")
	check_rendered_scope(preview,soldier,0)
	if rendered:
		await get_tree().create_timer(0.4).timeout
		check_rendered_scope(preview,soldier,0)
	check(preview.rebuild_count == builds, "Hover regenerated schedule")
	if rendered:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("levels/road_flow_hover.png"))
		await move_mouse(Vector2(8, 200))
	else:
		item.body.mouse_exited.emit()
	check(panel.selected == null and preview.forecast.segments() == all_before, "Mouse exit did not restore all flow")
	check(preview.rebuild_count == builds, "Mouse exit regenerated schedule")
	var second_item := second_panel.get_node("Scroll/Items").get_child(0)
	if rendered:
		await move_mouse(second_item.body.get_global_rect().get_center())
	else:
		second_item.body.mouse_entered.emit()
	check(preview.selected_origin == 1 and second_panel.selected == soldier and panel.selected == null, "Second entrance hover did not isolate its own allocation")
	check_rendered_scope(preview,soldier,1)
	if rendered:
		await get_tree().create_timer(0.4).timeout
		check_rendered_scope(preview,soldier,1)
	check(preview.rebuild_count == builds,"Second entrance hover rebuilt the schedule")
	if rendered:
		var action: Button = hud.start_callouts[1]
		await move_mouse(action.get_node("Title").get_global_rect().get_center())
		check(preview.selected_origin == 1 and second_panel.selected == null,"Title hover restored other entrances instead of this entrance")
		check_rendered_scope(preview,null,1)
		await move_mouse(second_item.body.get_global_rect().get_center())
		check_rendered_scope(preview,soldier,1)
		await move_mouse(Vector2(8,200))
	else:
		second_item.body.mouse_exited.emit()
	for key in [KEY_F1, KEY_F2]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		scene.get_node("PortalOverlay")._unhandled_key_input(event)
		await frames()
		check(panel.visible and not preview.arrows.visible, "Debug layer did not take precedence over player arrows")
		scene.get_node("PortalOverlay")._unhandled_key_input(event)
		await frames()
		check(preview.arrows.visible, "Closing debug layer did not restore arrows")
	var overflow := {}
	for i in 12:
		var profile := Troop.new()
		profile.troop_name = "Long troop name %d" % i
		overflow[profile] = i+1
	panel.display(overflow)
	await frames()
	check(panel.get_parent() == hud.early_start and panel.size.x <= 216 and panel.size.y <= 114, "Troop list escaped the start button or expanded without bounds")
	check(panel.get_node("Scroll").get_v_scroll_bar().max_value > panel.size.y, "Troop overflow is not scrollable")
	panel.display(preview.forecast.counts_by_origin[0])
	await frames()
	var after := WaveSpawnSchedule.build(wave.definition, controller, 0, false)
	check(RoadFlowForecast.from_pending(before.pending).all == RoadFlowForecast.from_pending(after.pending).all, "Hover altered quotas")
	# Invalid route must clear arrows, and a non-selected troop's cost signal must refresh.
	var other: Troop = wave.definition.groups[1].troop
	other.score_threshold = 0
	await frames()
	check(preview.forecast.all.is_empty() and preview.arrows.mesh == null, "Invalid route retained/fabricated flow")
	check(displayed_totals(hud) == RoadFlowForecast.troop_counts(wave.definition),"Blocked route incorrectly zeroed scheduled entrance counts")
	other.score_threshold = 25
	await frames()
	check(preview.arrows.mesh != null, "Non-selected troop change did not restore forecast")
	controller.rebuild()
	check(preview.arrows.mesh == null, "Geometry invalidation retained stale mesh")
	await frames(8)
	check(preview.arrows.mesh != null, "Geometry rebuild did not refresh forecast")
	var cost_builds: int = preview.rebuild_count
	var geometry_revision: int = controller.revision
	controller.tile_parameters.get_tile(Vector2i(4, 2)).threat += 1.0
	await frames()
	check(preview.rebuild_count > cost_builds and controller.revision == geometry_revision and preview.arrows.mesh != null, "Tile cost edit did not refresh without rebuilding geometry")
	hud.set_paused(true)
	await frames()
	check(not panel.visible and not second_panel.visible and not preview.arrows.visible, "Pause retained active preview")
	hud.set_paused(false)
	await frames()
	check(panel.visible and preview.arrows.visible and panel.selected == null, "Resume did not restore neutral preview")
	if rendered: await visual_check(scene)
	# Start, finish, ACT expansion and teardown through real session entry points.
	wave.set_process(false)
	scene.get_node("TowerMap").combat.enabled = false
	wave.enemy_spawned.connect(func(enemy: Node3D): enemy.set_process(false))
	for index in 2:
		var expected := RoadFlowForecast.from_pending(WaveSpawnSchedule.build(wave.definition, controller, 0, false, wave.additional_start_indices).get("pending", []))
		if index == 0:
			# The second entrance's row starts the same complete multi-entrance wave.
			var body: Button = second_panel.get_node("Scroll/Items").get_child(0).body
			if rendered:
				await move_mouse(body.get_global_rect().get_center())
				await click_now(body.get_global_rect().get_center())
			else:
				body.pressed.emit()
		else:
			scene._on_start_requested()
		scene.set_process(false)
		var opening_elapsed: float = scene._wave_start_elapsed
		for action: Button in hud.start_callouts:
			check(action.disabled and action.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Opening failed to lock every entrance action")
			action.pressed.emit() # Repeated requests cannot restart the opening.
		check(scene._wave_start_elapsed == opening_elapsed,"Repeated entrance clicks reset or advanced opening")
		check(not panel.visible and preview.arrows.mesh == null, "Opening retained prediction")
		scene._advance_wave_start(1.5)
		check(wave.active and not preview.arrows.visible, "Combat retained prediction")
		var committed := RoadFlowForecast.from_pending(wave._pending)
		check(committed.all == expected.all and committed.by_troop_origin == expected.by_troop_origin, "Combat trips differ from forecast")
		wave._process(100.0)
		for enemy in wave.living_enemies(): enemy.take_damage(100000)
		await frames()
		if index == 0:
			check(panel.visible and second_panel.visible and preview.arrows.mesh != null and panel.counts.size() == 1, "Wave completion did not refresh per-entrance lists")
			check(displayed_totals(hud) == RoadFlowForecast.troop_counts(wave.definition),"Next wave retained stale entrance counts")
		else:
			check(scene.choosing_start and not panel.visible and preview.arrows.mesh == null, "ACT selection retained stale arrows")
	var expansion: Node = scene.get_node("SpawnExpansion")
	expansion.choose_direction(0)
	var new_cell: Vector2i = expansion.choices[0].paths.keys()[0]
	check(expansion.commit(Vector3i(new_cell.x, 0, new_cell.y)), "ACT entrance commit failed")
	check(not panel.visible and preview.arrows.mesh == null, "Entrance rebuild exposed stale prediction")
	await frames(10)
	check(panel.visible and preview.arrows.mesh != null, "ACT completion failed to restore prediction")
	check(controller.start_nodes.size() == 3 and preview.forecast.by_origin.size() == 3, "Added ACT entrance missing from prediction")
	check(hud.start_callouts.size() == 3 and displayed_totals(hud).values().reduce(func(a: int, b: int): return a+b, 0) == 29, "New entrance lacks an action or changed troop totals")
	for i in 3:
		check(hud.start_callouts[i].get_node("NextWaveIntel").counts == preview.forecast.counts_by_origin.get(i,{}),"ACT entrance displayed a count other than its allocated schedule")
	var expanded_forecast: Dictionary = preview.forecast.all.duplicate()
	if rendered:
		var camera: Camera3D = scene.get_node("Camera3D")
		camera.focus = hud.start_markers[2].global_position
		camera.update_pose()
		await get_tree().create_timer(0.45).timeout
		var title: Control = hud.start_callouts[2].get_node("Title")
		await move_mouse(title.get_global_rect().get_center())
		await click_now(title.get_global_rect().get_center())
	else:
		hud.start_callouts[2].pressed.emit()
	scene.set_process(false)
	scene._advance_wave_start(1.5)
	check(RoadFlowForecast.from_pending(wave._pending).all == expanded_forecast, "Added entrance combat trips differ from prediction")
	wave._process(100.0)
	for enemy in wave.living_enemies(): enemy.take_damage(100000)
	await frames()
	check(scene.finished and not panel.visible and preview.arrows.mesh == null, "Final wave left prediction visible")
	var weak_preview: WeakRef = weakref(preview)
	scene.queue_free()
	await frames()
	check(weak_preview.get_ref() == null, "Preview survived scene unload")
	var fresh: Node3D = load("res://scenes/level.tscn").instantiate()
	add_child(fresh)
	await frames(10)
	check(fresh.current_wave == 0 and fresh.get_node("WaveFlowPreview").panel.counts == RoadFlowForecast.troop_counts(fresh._waves[0]), "Fresh formal scene retained previous counts")
	check(fresh.get_node("WaveFlowPreview").arrows.mesh != null, "Formal Frontier smoke failed")
	get_tree().set_meta(&"road_flow_restart", failures)
	fresh.get_node("LevelHUD").set_paused(true)
	fresh.get_node("LevelHUD").request_restart()

func visual_check(scene: Node3D) -> void:
	var preview: Node = scene.get_node("WaveFlowPreview")
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("levels/road_flow_all.png"))
	# Remove animated cloud pixels from the controlled shader phase comparison.
	scene.get_node("CloudLayer").hide()
	# Pixel contrast uses a short reference brush, independent of editor tuning.
	preview.arrows.material_override.set_shader_parameter("highlight_length",0.5)
	preview.arrows.material_override.set_shader_parameter("flow_speed", 0.0)
	# Sample the short stroke away from endpoint models, not at its birth position.
	preview.arrows.material_override.set_shader_parameter("phase_offset", 1.5)
	await frames()
	await RenderingServer.frame_post_draw
	var all_image := get_viewport().get_texture().get_image()
	all_image.save_png(Artifacts.path("levels/road_flow_pixels.png"))
	# Repeated pieces must match within one 8-bit output step, never alpha-over.
	var original_data: Image = preview.arrows.flow_data.get_image()
	var repeated_data := original_data.duplicate() as Image
	for row in repeated_data.get_height():
		var count := int(repeated_data.get_pixel(0,row).r)
		if count == 0 or count >= preview.arrows.MAX_PIECES: continue
		repeated_data.set_pixel(1+count*3,row,repeated_data.get_pixel(1,row))
		repeated_data.set_pixel(2+count*3,row,repeated_data.get_pixel(2,row))
		repeated_data.set_pixel(3+count*3,row,repeated_data.get_pixel(3,row))
		repeated_data.set_pixel(0,row,Color(count+1,0,0,0))
	preview.arrows.flow_data.update(repeated_data)
	await frames()
	await RenderingServer.frame_post_draw
	var repeated_image := get_viewport().get_texture().get_image()
	repeated_image.save_png(Artifacts.path("levels/road_flow_overlap.png"))
	var overlap_changes := 0
	var diff_bounds := Rect2i()
	var max_change := 0.0
	for y in range(260, all_image.get_height()-210):
		for x in range(300, mini(950,all_image.get_width())):
			if repeated_image.get_pixel(x,y) != all_image.get_pixel(x,y):
				overlap_changes += 1
				diff_bounds = Rect2i(Vector2i(x,y),Vector2i.ONE) if overlap_changes == 1 else diff_bounds.expand(Vector2i(x,y))
				var a := repeated_image.get_pixel(x,y)
				var b := all_image.get_pixel(x,y)
				max_change = maxf(max_change,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	print("FLOW_OVERLAP_PIXELS:", overlap_changes, " bounds ",diff_bounds," max ",max_change)
	check(max_change <= 1.01/255.0, "Coincident line pieces darkened the junction beyond output quantization")
	preview.arrows.flow_data.update(original_data)
	var stationary_mesh: int = preview.arrows.mesh.get_instance_id()
	preview.arrows.material_override.set_shader_parameter("phase_offset", 1.73)
	await frames()
	await RenderingServer.frame_post_draw
	var moved := get_viewport().get_texture().get_image()
	check(preview.arrows.mesh.get_instance_id() == stationary_mesh, "Brightness animation changed the static centerline geometry")
	moved.save_png(Artifacts.path("levels/road_flow_moving.png"))
	preview.arrows.hide()
	preview.set_process(false)
	await frames()
	await RenderingServer.frame_post_draw
	var clean := get_viewport().get_texture().get_image()
	clean.save_png(Artifacts.path("levels/road_flow_clean.png"))
	# Zero stroke opacity must leave exactly the bare road, with no hidden base line.
	var stroke_color: Color = preview.arrows.highlight_color
	preview.arrows.material_override.set_shader_parameter("highlight_color",Color(stroke_color,0.0))
	preview.arrows.show()
	await frames()
	await RenderingServer.frame_post_draw
	var transparent_stroke := get_viewport().get_texture().get_image()
	var residual := 0.0
	for y in range(260,clean.get_height()-210):
		for x in range(300,mini(950,clean.get_width())):
			var a := clean.get_pixel(x,y)
			var b := transparent_stroke.get_pixel(x,y)
			residual = maxf(residual,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	check(residual <= 1.01/255.0,"A permanent base line remains when the moving stroke is transparent")
	preview.arrows.material_override.set_shader_parameter("highlight_color",stroke_color)
	var visible_pixels := 0
	var animated_pixels := 0
	var max_light_change := 0.0
	for y in range(180, all_image.get_height()-200):
		for x in all_image.get_width():
			var a := all_image.get_pixel(x, y)
			if a != clean.get_pixel(x, y): visible_pixels += 1
			var shifted := moved.get_pixel(x,y)
			if a != shifted: animated_pixels += 1
			max_light_change = maxf(max_light_change,maxf(absf(a.r-shifted.r),maxf(absf(a.g-shifted.g),absf(a.b-shifted.b))))
	check(visible_pixels > 100 and animated_pixels > 100, "Rendered arrows are invisible or static")
	check(max_light_change >= 0.12, "Moving brush is too weak to distinguish from the road")
	preview.arrows.material_override.set_shader_parameter("phase_offset", 0.0)
	preview.arrows.material_override.set_shader_parameter("flow_speed", preview.arrows.flow_speed)
	preview.arrows.material_override.set_shader_parameter("highlight_length",preview.arrows.highlight_length)
	scene.get_node("CloudLayer").show()
	preview.set_process(true)
	await frames()
