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
	await frames()
	var markers := timeline.get_node("Track/Markers")
	check(markers.get_child_count() == 6, "Timeline does not use a bounded marker pool")
	var opening_events := 0
	for marker: Node2D in markers.get_children():
		if marker.visible and marker.position.x >= 0 and marker.position.x <= timeline.size.x: opening_events += 1
	check(opening_events == 4 and not markers.get_child(0).visible,"Opening history slot did not stay empty")
	check(is_equal_approx(timeline.get_node("Track/Current").position.x,timeline.size.x*0.3),"Current point is not in the second slot")
	check(timeline.act_boundaries() == PackedInt32Array([0,4,9,13,18]),"ACT dividers do not follow their rewards")
	var opening_relic: Node2D = markers.get_child(4)
	check(opening_relic.get_node("EventIcon").visible and not opening_relic.get_node("Dot").visible,"Relic still looks like a wave with an attached icon")
	check(is_equal_approx(opening_relic.get_node("EventIcon").position.y,0.0),"Relic is not its own chronological track marker")
	var marker_id := markers.get_child(0).get_instance_id()
	var act_id := timeline.get_node("Acts").get_child(0).get_instance_id()
	var current: Node2D = timeline.get_node("Track/Current")
	var anchor := current.global_position
	var width := timeline.size.x
	var nodes_before := timeline.find_children("*", "", true, false).size()
	timeline.set_state(0,1.0,true)
	timeline.set_state(1,0.0,false)
	var before := timeline.event_position("wave",1)
	timeline.set_state(1,0.5,false)
	check(timeline.event_position("wave",1).x < before.x,"Upcoming events did not move left")
	check(current.global_position.is_equal_approx(anchor),"Current black point moved with the timeline")
	check(current.scale.x > 1.0 and current.scale.x <= 1.17,"Current point has no subtle pulse")
	check(timeline.get_node("Track").clip_contents and not timeline.get_node("Progress").visible,"Timeline still displays a progress fill")
	await frames()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var image_scale := Vector2(image.get_size())/get_viewport().get_visible_rect().size
		var left := pixel_at(image,(anchor-Vector2(2,0))*image_scale)
		var right := pixel_at(image,(anchor+Vector2(2,0))*image_scale)
		check(left.r < 0.3 and right.r < 0.3,"Current point is not solid dark on both sides")
		image.save_png(Artifacts.path("levels/timeline_scroll_midpoint.png"))
	for i in 121: timeline.set_state(1,float(i)/120.0,false)
	check(markers.get_child(0).get_instance_id() == marker_id and timeline.get_node("Acts").get_child(0).get_instance_id() == act_id,"Scrolling replaced reusable scene nodes")
	check(timeline.find_children("*", "", true, false).size() == nodes_before,"Scrolling grew the UI tree")
	check(current.global_position.is_equal_approx(anchor) and is_equal_approx(current.scale.x,1.0),"Point did not return to its fixed resting state")
	timeline.set_state(1,1.0,true)
	var visible_events := 0
	for marker: Node2D in markers.get_children():
		if marker.visible and marker.position.x >= 0 and marker.position.x <= width: visible_events += 1
	check(visible_events == 5,"Resting timeline does not show exactly five events")
	check(is_equal_approx(markers.get_child(0).position.x,width*0.1) and markers.get_child(0).get_node("Caption").text == "第 1 波","Previous wave is not in the left slot")
	check(is_equal_approx(timeline.event_position("wave",1).x,width*0.3) and is_equal_approx(timeline.event_position("wave",2).x,width*0.5),"Past/current/future chronology is wrong")
	timeline.set_state(3,1.0,true)
	check(timeline.get_node("Acts").get_child(0).text == "ACT II","ACT did not update across the boundary")
	var track: Control = timeline.get_node("Track")
	check(track._act_dividers[1].visible and is_equal_approx(track._act_dividers[1].position.x,width*0.2),"ACT divider was not restored between the relic and next wave")
	check(timeline.event_position("relic",2).x < current.position.x,"Previous relic was not retained on the left")
	timeline.set_state(5,1.0,true)
	check(markers.get_child(0).get_node("EventIcon").visible and not markers.get_child(0).get_node("Dot").visible and markers.get_child(0).get_node("Caption").text == "新入口","Entrance event still shares a wave circle")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("levels/timeline_history_events.png"))
	timeline.manage_header_width(180)
	check(timeline.size.x == width,"Header changed the fixed timeline length")
	var reward: RelicDefinition = scene.get_node("TowerMap").relics.catalog.find(&"gold")
	if reward != null: scene.get_node("TowerMap").relics.acquire(reward)
	await frames()
	check(current.global_position.is_equal_approx(anchor),"Adding a relic shifted the current point on screen")
	timeline.set_state(2,1.0,true)
	timeline.set_reward_active(true)
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = true
	var paused_cursor := timeline.event_cursor
	await get_tree().create_timer(0.15,true,false,true).timeout
	check(is_equal_approx(paused_cursor,timeline.event_cursor),"Paused timeline event animation kept moving")
	get_tree().paused = false
	await get_tree().create_timer(0.4).timeout
	check(is_equal_approx(timeline.event_cursor,timeline.event_index("relic",2)),"Relic animation did not reach its slot")
	var appearance := scene.get_node("EnemyWave").visuals.status_overlay.get_node("Appearance") as Control
	check(appearance.scene_file_path == "res://scenes/enemies/components/enemy_status_appearance.tscn", "Batched status overlay no longer reads its scene template")
	check(not appearance.visible, "Status appearance template leaked into the live HUD")
	print("UI_SCENE_TEMPLATES_CHECK:"+JSON.stringify({"failures": failures, "stable_nodes": true, "fixed_point_left_scroll": true, "batched_status_template": true}))
	get_tree().quit(1 if failures else 0)
