extends Node3D
const Overlay = preload("res://scripts/navigation/visualization/portal_overlay.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func wait_map(controller: Node) -> void:
	for i in 120:
		if not controller.computing and not controller.plan.is_empty(): return
		await get_tree().process_frame
	check(false, "Map did not become ready")

func press(view: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	view._unhandled_key_input(event)

func group(profile: Troop, count: int, origin := 0) -> WaveSpawnGroup:
	var result := WaveSpawnGroup.new()
	result.troop = profile
	result.enemy_count = count
	result.start_index = origin
	result.interval_ticks = 4
	return result

func segments(entries: Array) -> Dictionary:
	var result := {}
	for entry: Dictionary in entries:
		if not result.has(entry.troop): result[entry.troop] = {}
		var cells: PackedVector2Array = entry.cells
		for i in cells.size()-1:
			result[entry.troop][Overlay.segment_key(Vector2i(cells[i]), Vector2i(cells[i+1]))] = true
	return result

func committed_entries(wave: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in wave._pending:
		var profile: Troop = entry.get("profile", wave._wave_troop)
		result.append({"troop": profile.troop_name, "cells": entry.route.cells})
	return result

func check_vertices(view: Node3D, controller: Node) -> void:
	check(view.vertex_markers.get_child_count() == controller.graph.nodes.size(), "F1 omitted graph vertices or retained stale markers")
	for node: Dictionary in controller.graph.nodes:
		var marker := view.vertex_markers.get_node_or_null("V%d" % node.id) as Node3D
		check(marker != null, "F1 vertex ID is missing")
		if marker == null: continue
		var expected: Vector3 = view.map.to_global(view.map.map_to_local(Vector3i(node.cell.x, 0, node.cell.y))+Vector3.UP*0.18)
		check(marker.global_position.is_equal_approx(expected) and marker.get_node("ID").text == "V%d" % node.id, "F1 vertex ID or map position is incorrect")

func verify() -> void:
	var scene: Node3D = load("res://scenes/9x9.tscn").instantiate()
	var wave: Node = scene.get_node("EnemyWave")
	wave.auto_start = false
	add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	var view: Node3D = scene.get_node("PortalOverlay")
	await wait_map(controller)
	var definition := WaveDefinition.new()
	definition.groups = [group((TroopCatalog.find("soldier").duplicate() as Troop), 7), group((TroopCatalog.find("quickfeet").duplicate() as Troop), 5), group((TroopCatalog.find("heavy").duplicate() as Troop), 3)]
	check(wave.apply_definition(definition), "Mixed definition was rejected")
	check(not view.show_routes and not view.show_parameters and view.routes_mesh.mesh == null and view.parameters_mesh.mesh == null, "Debug layers were visible by default")
	check(not view.vertex_markers.visible and view.vertex_markers.get_child_count() == 0, "Vertex markers must remain hidden and unbuilt until F1 opens")
	check(view._buttons.size() == 2 and view.find_children("PlannedTraffic", "MeshInstance3D", true, false).is_empty(), "Removed F3 layer remains")
	press(view, KEY_F3)
	check(not view.show_routes and not view.show_parameters, "F3 still toggles a layer")
	# Opening F1 must not consume the random sequence for departure timing.
	seed(9276)
	var expected_random := randi()
	seed(9276)
	var preview: Array[Dictionary] = wave.routes_for_display()
	check(randi() == expected_random and wave._pending.is_empty() and not wave.active, "Preview changed spawn state or consumed departure randomness")
	press(view, KEY_F1)
	await frames()
	check(view.show_routes and view.routes_mesh.mesh != null and view._route_segments == segments(preview), "F1 omitted a preview route")
	check(view._troop_names.size() == 3, "F1 displayed only the selected troop")
	check_vertices(view, controller)
	check(view.vertex_markers.visible, "F1 vertex markers are hidden")
	var vertex_instance: int = view.vertex_markers.get_child(0).get_instance_id()
	await frames()
	check(view.vertex_markers.get_child(0).get_instance_id() == vertex_instance, "Vertex markers were rebuilt without a graph change")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("navigation/f1_vertices.png"))
	var colors: PackedColorArray = view.routes_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for troop_name: String in ["soldier", "quickfeet", "heavy"]:
		var expected := Overlay.troop_color(troop_name)
		var found := false
		for color in colors:
			# Mesh vertex colors may be quantized to 8 bits per channel.
			if absf(color.r-expected.r) <= 1.0/255 and absf(color.g-expected.g) <= 1.0/255 and absf(color.b-expected.b) <= 1.0/255: found = true
		check(found and troop_name in view._legend.text, "Troop color/legend is missing: "+troop_name)
	press(view, KEY_F2)
	var towers: Node = scene.get_node("TowerMap")
	check(towers.place_tower(Vector3i(6, 0, 0)) != null and towers.place_tower(Vector3i(7, 0, 0)) != null, "Threat fixture towers failed")
	await wait_map(controller)
	await frames()
	check(view.parameters_mesh.visible and view.parameters_mesh.mesh != null, "F2 threat layer is missing")
	view._inspect_cell(Vector3i(6, 0, 0))
	check(view._tooltip.visible and "threat 2.00" in view._tooltip.text, "F2 tile inspector lost threat values")
	check(Overlay.threat_color(2).g < Overlay.threat_color(1).g, "Threat color no longer reflects threat")
	preview = wave.routes_for_display()
	check(wave.start_wave(), "Mixed wave failed to start")
	wave.set_process(false)
	var actual := committed_entries(wave)
	await frames()
	check(wave.spawned == 0 and view._route_segments == segments(actual), "F1 omitted actual routes of enemies not spawned yet")
	check(segments(preview) == segments(actual), "Wave allocation differs from the F1 preview")
	var mesh_id: int = view.routes_mesh.mesh.get_instance_id()
	check(towers.remove_tower(Vector3i(7, 0, 0)), "Fixture tower could not be removed")
	await wait_map(controller)
	await frames()
	check(view.routes_mesh.mesh.get_instance_id() == mesh_id and view._route_segments == segments(actual), "Map edit redrew committed routes using a new plan")
	check_vertices(view, controller)
	check(view.vertex_markers.get_child(0).get_instance_id() != vertex_instance, "Map edits failed to refresh vertex markers during a committed wave")
	wave._process(0.0)
	wave.set_process(false)
	for enemy: Node3D in wave.living_enemies(): enemy.set_process(false)
	await frames()
	check(view.routes_mesh.mesh.get_instance_id() == mesh_id and view._route_segments == segments(actual), "Spawning discarded a route or rebuilt the overlay")
	press(view, KEY_F1)
	press(view, KEY_F2)
	check(not view.routes_mesh.visible and not view.parameters_mesh.visible and not view._panel.visible and not view.is_processing(), "Debug layers cannot be hidden independently")
	check(not view.vertex_markers.visible, "Closing F1 left vertex markers visible")
	scene.queue_free()
	await frames()
	# Every troop may share the same bridge: all colors must remain visible.
	var bridge: Array[Vector2i] = []
	for x in 24: bridge.append(Vector2i(x, 0))
	scene = Fixture.scene_for(bridge, Vector2i.ZERO, Vector2i(23, 0))
	wave = scene.get_node("EnemyWave")
	wave.auto_start = false
	add_child(scene)
	controller = scene.get_node("PortalMap")
	view = scene.get_node("PortalOverlay")
	await wait_map(controller)
	wave.enemy_count = 5
	preview = wave.routes_for_display()
	press(view, KEY_F1)
	await frames()
	check(wave.start_wave(), "Standalone wave failed to start")
	wave.set_process(false)
	actual = committed_entries(wave)
	await frames()
	check(view._route_segments == segments(actual) and segments(preview) == segments(actual), "Standalone preview missed a committed route")
	for i in 5: wave._process(100.0)
	for enemy: Node3D in wave.living_enemies(): enemy.take_damage(100000)
	await frames()
	check(wave.apply_definition(definition), "Bridge definition failed")
	await frames()
	for troop_name: String in view._troop_names:
		check(view._route_segments[troop_name].size() == 23, "Troop does not cover all 23 bridge segments")
	check(view.routes_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 23*3*6, "Common segments hid a troop color")
	# Preparing a new wave clears the previous wave's frozen paths.
	check(wave.start_wave(), "Bridge wave failed to start")
	wave.set_process(false)
	wave._process(100.0)
	for enemy: Node3D in wave.living_enemies(): enemy.take_damage(100000)
	await frames()
	var next := WaveDefinition.new()
	next.groups = [group((TroopCatalog.find("soldier").duplicate() as Troop), 1)]
	check(wave.apply_definition(next), "Next definition failed")
	await frames()
	check(view._troop_names == ["soldier"] and not wave.has_committed_routes(), "Next wave kept the previous wave's troops")
	scene.queue_free()
	await frames()
	# Authored groups may use different entrances within the same wave.
	scene = load("res://scenes/11x11big.tscn").instantiate()
	wave = scene.get_node("EnemyWave")
	wave.auto_start = false
	add_child(scene)
	controller = scene.get_node("PortalMap")
	view = scene.get_node("PortalOverlay")
	await wait_map(controller)
	definition.groups = [group((TroopCatalog.find("soldier").duplicate() as Troop), 3, 0), group((TroopCatalog.find("quickfeet").duplicate() as Troop), 3, 1)]
	check(wave.apply_definition(definition), "Multi-entrance definition failed")
	press(view, KEY_F1)
	await frames()
	check(wave.start_wave(), "Multi-entrance wave failed to start")
	wave.set_process(false)
	actual = committed_entries(wave)
	await frames()
	check(actual[0].cells[0] != actual[-1].cells[0] and view._route_segments == segments(actual), "F1 missed routes from another entrance")
	check(not view._origin.visible, "Origin selector implies an incorrect per-entrance filter for authored waves")
	scene.queue_free()
	await frames()
	print("DEBUG_CHECK:"+JSON.stringify({"failures": failures, "f1_all_troops": true, "f1_vertices": true, "f3_removed": true, "pending_routes": true, "preview_matches_combat": true, "separate_colors": true, "shared_segments": true, "multiple_entrances": true, "next_wave_reset": true, "no_per_frame_rebuild": true}))
	if not OS.has_feature("web"): get_tree().quit(1 if failures else 0)
