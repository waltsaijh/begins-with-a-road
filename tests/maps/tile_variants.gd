extends SceneTree
## godot --headless --path . --script tests/maps/tile_variants.gd

const Layout = preload("res://scripts/map/tile/appearance/tile_appearance_layout.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
var failures := 0

func _initialize() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func verify() -> void:
	var roads: Array[Vector3i] = []
	var straight := {}
	var entrances := {}
	for x in 65:
		var cell := Vector3i(x, 0, 0)
		roads.append(cell)
		straight[cell] = true
	for x in [0, 3, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64]:
		entrances[Vector3i(x, 0, 0)] = true
	var terminals: Array[Vector3i] = [Vector3i.ZERO, Vector3i(64, 0, 0)]
	var layout := Layout.select(roads, straight, entrances, terminals)
	check(layout.pillars[2] == Vector3i(4, 0, 0), "Nearest entrance strictly outside radius 3 should be x=4")
	check(not layout.variants.has(Vector3i(3, 0, 0)), "Radius boundary must be excluded")
	check(layout.wood.size() == 4, "65 tiles should produce floor(65/16)=4 wood bridges")
	var reversed := roads.duplicate()
	reversed.reverse()
	check(Layout.select(reversed, straight, entrances, terminals) == layout, "Stable seed must ignore cell iteration order")
	check(Layout.select(roads, straight, entrances, roads).wood.is_empty(), "Mandatory endpoint supports must take priority over wood quota")
	for scene_path in ["res://scenes/main.tscn", "res://scenes/9x9.tscn", "res://scenes/11x11big.tscn"]:
		var scene: Node = load(scene_path).instantiate()
		scene.get_node("EnemyWave").auto_start = false
		root.add_child(scene)
		for i in 5:
			await process_frame
		var map: GridMap = scene.get_node("TileMap")
		var appearance: Node = scene.get_node("TileAppearance")
		var controller: Node = scene.get_node("PortalMap")
		check(controller.graph.get("valid", false) and controller.plan.get("reachable", false), scene_path + ": navigation failed")
		check(not appearance.layout.is_empty(), scene_path + ": no appearance layout")
		var nodes := {}
		for node: Dictionary in controller.graph.nodes:
			nodes[Vector3i(int(node.cell.x), 0, int(node.cell.y))] = true
		for path: NodePath in controller.start_paths:
			var marker: Node3D = controller.get_node(path)
			var cell := map.local_to_map(map.to_local(marker.global_position))
			check(TileConstants.appearance_of(map.get_cell_item(cell)) == TileConstants.Appearance.PILLAR, scene_path + ": start missing support")
		var goal: Node3D = scene.get_node("Goal")
		var goal_cell := map.local_to_map(map.to_local(goal.global_position))
		check(TileConstants.appearance_of(map.get_cell_item(goal_cell)) == TileConstants.Appearance.PILLAR, scene_path + ": goal missing support")
		for cell: Vector3i in appearance.layout.pillars:
			check(nodes.has(cell), "Pillars must be on entrances/terminals")
			var mesh := map.mesh_library.get_item_mesh(map.get_cell_item(cell))
			check(is_equal_approx(mesh.get_aabb().position.y, -4.0), "Pillar bottom should be at Y=-4")
		for cell: Vector3i in appearance.layout.wood:
			check(not nodes.has(cell) and TileConstants.base_item(map.get_cell_item(cell)) == 1, "Wood must be on a non-entrance straight tile")
			for other: Vector3i in appearance.layout.wood:
				check(cell == other or Vector3(cell - other).length_squared() > 4.0, "Wood bridge spacing must be strictly >2")
		check(appearance.layout.wood.size() <= appearance.layout.wood_target, "Wood quota exceeded")
		var before := Snapshot.capture(map)
		var revision: int = controller.revision
		var planner_id: int = controller.planner.get_instance_id()
		for cell in map.get_used_cells():
			map.set_cell_item(cell, TileConstants.base_item(map.get_cell_item(cell)), map.get_cell_item_orientation(cell))
		check(Snapshot.capture(map) == before, "Visual variants changed navigation ports")
		appearance.refresh()
		check(Snapshot.capture(map) == before, "Restoring appearances changed navigation ports")
		check(controller.revision == revision and controller.planner.get_instance_id() == planner_id, "Appearance rebuild invalidated navigation")
		var cloud: MeshInstance3D = scene.get_node("CloudLayer")
		check(is_equal_approx(map.to_local(cloud.global_position).y, -4.0), "Opaque cloud bottom must be four tiles below the road")
		check(cloud.mesh is PlaneMesh, "Cloud sea must use a plane")
		check(cloud.get_node("MidMist").mesh == cloud.mesh and cloud.get_node("HighWisps").mesh == cloud.mesh, "Mist strata must reuse the sea plane geometry")
		check(is_equal_approx(map.to_local(cloud.get_node("MidMist").global_position).y, -3.0), "Middle cloud stratum must be at Y=-3")
		check(is_equal_approx(map.to_local(cloud.get_node("HighWisps").global_position).y, -2.0), "Top cloud stratum must be at Y=-2")
		var shared_noise: Texture2D = cloud.material_override.get_shader_parameter("cloud_noise_texture")
		check(shared_noise != null and cloud.get_node("MidMist").material_override.get_shader_parameter("cloud_noise_texture") == shared_noise and cloud.get_node("HighWisps").material_override.get_shader_parameter("cloud_noise_texture") == shared_noise, "All strata must share the precomputed noise texture")
		if scene_path.ends_with("main.tscn"):
			check(appearance.layout.wood.size() == 1, "24-tile bridge should have one wood tile")
			var wood_cell: Vector3i = appearance.layout.wood[0]
			var extension := wood_cell + Vector3i(0, 0, 1)
			check(scene.get_node("TilePlacement").place_cell(extension), "Failed to attach dead-end tile")
			for i in 3:
				await process_frame
			check(TileConstants.base_item(map.get_cell_item(wood_cell)) == 5 and TileConstants.appearance_of(map.get_cell_item(wood_cell)) != TileConstants.Appearance.WOOD, "Wood bridge did not revert after becoming a junction")
			check(controller.revision == revision, "Appearance update rebuilt a skipped dead end")
		print("VARIANTS: ", scene_path, " pillars=", appearance.layout.pillars.size(), " wood=", appearance.layout.wood.size(), "/", appearance.layout.wood_target)
		scene.queue_free()
		await process_frame
	print("TILE_VARIANTS_CHECK: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
