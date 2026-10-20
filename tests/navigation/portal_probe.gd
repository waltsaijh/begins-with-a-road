extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")

func _ready() -> void:
	var obstacle := "--obstacle" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		obstacle = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('obstacle')"))
	var scene := Fixture.scene_for(Fixture.room(true), Vector2i(-3, 5), Vector2i(13, 5)) if obstacle else Fixture.scene_for(Fixture.annotated(), Vector2i(-3, 0), Vector2i(11, 0))
	add_child(scene)
	var camera = scene.get_node("Camera3D")
	camera.size = 18.5 if obstacle else 13.0
	camera.update_pose()
	var controller: Node = scene.get_node("PortalMap")
	while controller.computing:
		await get_tree().process_frame
	var graph: Dictionary = controller.graph
	assert(graph.valid and graph.stats.cycles == 1)
	assert(graph.stats.regions == (4 if obstacle else 1))
	var result := {"stats": graph.stats, "nodes": [], "regions": [], "corridors": [], "local_routes": graph.local_routes}
	for node: Dictionary in graph.nodes:
		result.nodes.append({"id": node.id, "cell": [node.cell.x, node.cell.y], "kind": node.kind, "regions": Array(node.regions)})
	for region: Dictionary in graph.regions:
		result.regions.append({"id": region.id, "nodes": Array(region.nodes), "cells": _pairs(region.cells), "links": Array(region.route_links), "distances": Array(region.route_distances), "visible": Array(region.route_visible_links)})
	for edge: Dictionary in graph.corridors:
		result.corridors.append({"from": edge.from, "to": edge.to, "cells": _pairs(edge.cells)})
	print("PORTAL_CHECK:"+JSON.stringify(result))
	if not OS.has_feature("web"):
		get_tree().quit()

func _pairs(cells: PackedVector2Array) -> Array:
	var result := []
	for cell in cells:
		result.append([int(cell.x), int(cell.y)])
	return result
