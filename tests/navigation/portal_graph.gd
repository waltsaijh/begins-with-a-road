extends SceneTree
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Paths = preload("res://scripts/navigation/visualization/region_paths.gd")

func _initialize() -> void:
	call_deferred("verify")

func wait_graph(controller: Node) -> void:
	for frame in 100:
		if not controller.computing:
			return
		await process_frame
	assert(false, "Portal graph did not finish")

func verify_graph(scene: Node3D) -> void:
	var graph: Dictionary = scene.get_node("PortalMap").graph
	assert(graph.valid, str(graph.get("error")))
	assert(graph.stats.cycles == graph.stats.logical_cycles)
	assert(graph.quads.size() == graph.stats.faces)
	for edge: Dictionary in graph.corridors:
		assert(edge.from != edge.to)
		assert(Vector2i(edge.cells[0]) == graph.nodes[edge.from].cell)
		assert(Vector2i(edge.cells[-1]) == graph.nodes[edge.to].cell)
		var visited := {}
		for i in edge.cells.size():
			assert(not visited.has(edge.cells[i]))
			visited[edge.cells[i]] = true
			if i:
				var delta := Vector2i(edge.cells[i]-edge.cells[i-1])
				assert(absi(delta.x)+absi(delta.y) == 1)
	for node: Dictionary in graph.nodes:
		assert(not (node.kind == "junction" and not node.regions.is_empty()), "No artificial junction inside a broad region")
	for region: Dictionary in graph.regions:
		assert(region.route_distances.size() == region.cells.size()*region.nodes.size())
		assert(region.route_node_cells.size() == region.nodes.size())
	for pair: Dictionary in graph.local_routes:
		var region: Dictionary = graph.regions[pair.region]
		var links := Paths.directed_links(graph, pair)
		assert(not links.is_empty() and pair.count > 0)
		var reverse := Paths.directed_links(graph, pair, true)
		assert(reverse.size() == links.size())
		for i in range(0, links.size(), 2):
			assert(links[i] == reverse[i+1] and links[i+1] == reverse[i])
			var offset: int = pair.source_field*region.cells.size()
			assert(region.route_distances[offset+links[i]]+1 == region.route_distances[offset+links[i+1]])

func verify() -> void:
	assert(ClassDB.class_exists("RoadPortalGraph"))
	assert(not ClassDB.class_exists("RoadTopology") and not ClassDB.class_exists("RoadRouteCover"))
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var controller: Node = scene.get_node("PortalMap")
	var view: Node3D = scene.get_node("PortalOverlay")
	var placement: Node = scene.get_node("TilePlacement")
	await wait_graph(controller)
	verify_graph(scene)
	assert(controller.graph.stats.nodes == 2 and controller.graph.stats.corridors == 1 and controller.graph.regions.is_empty())
	assert(view.routes_mesh.mesh == null and not view.show_routes)
	assert(placement.place_cell(Vector3i(8, 0, 1)))
	assert(controller.computing and controller.graph.is_empty() and view.routes_mesh.mesh == null)
	await wait_graph(controller)
	assert(controller.graph.stats.nodes == 4 and controller.graph.stats.corridors == 3)
	# Completing a 2x2 lane-change area creates a broad region with two mouths.
	assert(placement.place_cell(Vector3i(9, 0, 1)))
	assert(placement.place_cell(Vector3i(50, 0, 50)))
	await wait_graph(controller)
	verify_graph(scene)
	assert(controller.graph.stats.cycles == 0 and controller.graph.stats.regions == 1 and controller.graph.stats.components == 2)
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F1
	view._unhandled_key_input(event)
	await process_frame
	assert(view.show_routes and view.routes_mesh.mesh != null)
	view._unhandled_key_input(event)
	assert(not view.routes_mesh.visible)
	scene.queue_free()
	await process_frame
	scene = Fixture.scene_for(Fixture.annotated(), Vector2i(-3, 0), Vector2i(11, 0))
	root.add_child(scene)
	await process_frame
	controller = scene.get_node("PortalMap")
	await wait_graph(controller)
	verify_graph(scene)
	assert(controller.graph.regions.size() == 1 and controller.graph.nodes.size() == 6 and controller.graph.corridors.size() == 4)
	var mouths := []
	for node: Dictionary in controller.graph.nodes:
		if node.kind == "portal":
			mouths.append(node.cell)
		if node.kind == "junction":
			assert(node.cell == Vector2i(8, 0))
	assert(mouths.size() == 3)
	assert(Vector2i(0, 0) in mouths and Vector2i(4, 0) in mouths and Vector2i(1, 2) in mouths)
	assert(controller.graph.local_routes.size() == 3)
	var lengths_and_counts := []
	for pair: Dictionary in controller.graph.local_routes:
		lengths_and_counts.append(Vector2i(pair.length, pair.count))
	assert(Vector2i(3, 3) in lengths_and_counts and Vector2i(4, 1) in lengths_and_counts and Vector2i(5, 10) in lengths_and_counts)
	view = scene.get_node("PortalOverlay")
	event.keycode = KEY_F3
	view._unhandled_key_input(event)
	await process_frame
	assert(not view.show_routes and not view.show_parameters)
	scene.queue_free()
	await process_frame
	scene = Fixture.scene_for([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], Vector2i.ZERO, Vector2i.ONE)
	root.add_child(scene)
	await process_frame
	controller = scene.get_node("PortalMap")
	await wait_graph(controller)
	verify_graph(scene)
	assert(controller.graph.local_routes.size() == 1)
	assert(controller.graph.local_routes[0].count == 2 and controller.graph.local_routes[0].length == 2)
	assert(Paths.directed_links(controller.graph, controller.graph.local_routes[0]).size() == 8)
	scene.queue_free()
	await process_frame
	for obstacle in [false, true]:
		scene = Fixture.scene_for(Fixture.room(obstacle), Vector2i(-3, 5), Vector2i(13, 5))
		root.add_child(scene)
		await process_frame
		controller = scene.get_node("PortalMap")
		await wait_graph(controller)
		verify_graph(scene)
		assert(controller.graph.stats.regions == (4 if obstacle else 1))
		assert(controller.graph.stats.cycles == (1 if obstacle else 0))
		scene.queue_free()
		await process_frame
	scene = load("res://scenes/9x9.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await wait_graph(scene.get_node("PortalMap"))
	verify_graph(scene)
	assert(scene.find_children("*", "Label3D", true, false).is_empty())
	scene.queue_free()
	await process_frame
	var builder: RefCounted = ClassDB.instantiate("RoadPortalGraph")
	assert(not builder.build(PackedInt32Array([1]), PackedByteArray(), Vector2i.ZERO, Vector2i.ONE).valid)
	print("PASS: portal graph, all tied shortest pair DAGs, reverse directions, all three mouths, 2x2 alternatives, edit refresh, opt-in debug layers and original maps")
	quit()
