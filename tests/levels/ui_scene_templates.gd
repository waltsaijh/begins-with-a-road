extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func pixel_at(image: Image, point: Vector2) -> Color:
	return image.get_pixelv(Vector2i(point.round()))

func verify() -> void:
	var scene := load("res://scenes/level.tscn").instantiate() as Node3D
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	scene.set_process(false)
	await frames(12)
	var timeline: WaveTimeline = scene.timeline
	var markers := timeline.get_node("Track/Markers")
	var filled := timeline.get_node("Progress/Fill/Markers")
	check(markers.get_child_count() == scene.level.wave_count() and filled.get_child_count() == markers.get_child_count(), "Timeline did not instantiate matching marker templates")
	var marker_id := markers.get_child(0).get_instance_id()
	var act_id := timeline.get_node("Acts").get_child(0).get_instance_id()
	var nodes_before := timeline.find_children("*", "", true, false).size()
	for i in 121: timeline.set_state(0, float(i)/120.0, false)
	check(markers.get_child(0).get_instance_id() == marker_id and timeline.get_node("Acts").get_child(0).get_instance_id() == act_id, "Progress updates replaced reusable scene nodes")
	check(timeline.find_children("*", "", true, false).size() == nodes_before, "Progress updates grew the UI tree")
	check(timeline.get_node("Progress").clip_contents, "Timeline no longer clips its fill")
	var center_x := timeline.size.x*timeline.node_fraction(0)
	var fraction := (center_x-1.5)/timeline._marker_right_edge(0)
	timeline.set_state(0, fraction, false)
	await frames()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var center := timeline.global_position+Vector2(center_x, timeline.get_node("Track/Line").points[0].y)
		var left := pixel_at(image, center-Vector2(2, 0))
		var right := pixel_at(image, center+Vector2(2, 0))
		check(left.r < 0.4 and left.g > 0.4 and right.r > 0.75, "Circle was not filled continuously from left to right")
		image.save_png(Artifacts.path("levels/timeline_partial_fill.png"))
		timeline.set_state(0, 1.0, true)
		await frames()
		await RenderingServer.frame_post_draw
		image = get_viewport().get_texture().get_image()
		var complete := pixel_at(image, center+Vector2(2, 0))
		check(complete.r < 0.4 and complete.g > 0.4, "Circle was not completely filled on wave start")
	var appearance := scene.get_node("EnemyWave").visuals.status_overlay.get_node("Appearance") as Control
	check(appearance.scene_file_path == "res://scenes/enemies/components/enemy_status_appearance.tscn", "Batched status overlay no longer reads its scene template")
	check(not appearance.visible, "Status appearance template leaked into the live HUD")
	print("UI_SCENE_TEMPLATES_CHECK:"+JSON.stringify({"failures": failures, "stable_nodes": true, "continuous_fill": true, "batched_status_template": true}))
	get_tree().quit(1 if failures else 0)
