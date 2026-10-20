extends Node3D
const Profile = preload("res://scripts/enemies/troops/troop.gd")

func _ready() -> void:
	var scene: Node3D = load("res://scenes/11x11big.tscn").instantiate()
	add_child(scene)
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing:
		await get_tree().process_frame
	assert(controller.graph.valid and controller.plan.valid and controller.plan.reachable)
	assert(controller.start_nodes.size() == 2 and controller.start_nodes[0] != controller.start_nodes[1])
	assert(scene.get_node("Start2").position - scene.get_node("Start").position == Vector3(0, 0, -5))
	var profile: Resource = controller.troop
	var map: GridMap = scene.get_node("TileMap")
	var results := []
	for index in 2:
		var plan: Dictionary = controller.plan_for(profile, index)
		assert(plan.valid and plan.reachable and not plan.has("rank"))
		assert(controller.plan_for(profile, index).cached)
		var start: Vector2i = controller.graph.nodes[controller.start_nodes[index]].cell
		assert(controller.graph.nodes[controller.start_nodes[index]].is_start)
		var samples := []
		for seed in 32:
			var route: Dictionary = controller.sample_for(profile, seed, index)
			assert(not route.is_empty())
			assert(route.nodes[0] == controller.start_nodes[index] and route.nodes[-1] == controller.graph.goal_node)
			assert(route.cells[0] == Vector2(start) and route.length == route.cells.size()-1)
			assert(route.score == route.length and route.score-plan.score < profile.score_threshold)
			var seen := {}
			for id: int in route.nodes:
				assert(not seen.has(id))
				seen[id] = true
			var cells := []
			for cell: Vector2 in route.cells:
				assert(map.get_cell_item(Vector3i(int(cell.x), 0, int(cell.y))) > 0)
				cells.append([int(cell.x), int(cell.y)])
			for n in range(1, route.cells.size()):
				var delta: Vector2 = route.cells[n]-route.cells[n-1]
				assert(absi(int(delta.x))+absi(int(delta.y)) == 1)
			samples.append({"nodes": Array(route.nodes), "cells": cells, "score": route.score})
		results.append({"start": [start.x, start.y], "vertex": controller.start_nodes[index], "score": plan.score, "threshold": plan.score_threshold, "routes": plan.routes, "samples": samples})
	assert(controller.plan_for(profile, 0).cached and controller.plan_for(profile, 1).cached)
	assert(not controller.plan_for(profile, -1).valid and not controller.plan_for(profile, 2).valid)
	# Cost changes invalidate both origins, including the one not being displayed.
	controller.tile_parameters.get_tile(Vector2i(0, -5)).damage_per_second = 1
	assert(controller.sample_for(profile, 0, 0).is_empty() and controller.sample_for(profile, 0, 1).is_empty())
	await get_tree().process_frame
	assert(controller.plan_for(profile, 0).reachable and controller.plan_for(profile, 1).reachable)
	profile.score_threshold = 10
	assert(controller.sample_for(profile, 0, 0).is_empty() and controller.sample_for(profile, 0, 1).is_empty())
	await get_tree().process_frame
	var other := Profile.new()
	for index in 2:
		var alternate: Dictionary = controller.plan_for(other, index)
		assert(alternate.valid)
		assert(not controller.sample_for(other, 0, index).is_empty())
	# Preview can switch between origins without mixing their route pools.
	var overlay: Node3D = scene.get_node("PortalOverlay")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_R
	overlay._unhandled_key_input(event)
	assert(controller.active_start == 1 and controller.plan.reachable)
	event.keycode = KEY_F1
	overlay._unhandled_key_input(event)
	assert(overlay.show_routes)
	assert(overlay._origin.text == "起點 2/2 (R)")
	var report := {"scene": "11x11big", "tiles": controller.graph.stats.tiles, "plans": results, "preview_start": controller.active_start, "cache_and_invalidation": true}
	print("MULTISTART_CHECK:" + JSON.stringify(report))
	if not OS.has_feature("web"):
		get_tree().quit()
