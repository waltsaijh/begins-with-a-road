extends Node
const Fixture = preload("res://tests/traffic/fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
var viewport: SubViewport
var level: Node3D
var cards: Node
var failures: Array[String] = []
var checks := 0
func _ready() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func frames(n := 3) -> void:
	for i in n: await get_tree().process_frame
func motion(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = mask
	viewport.push_input(event,true)
func left(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	viewport.push_input(event,true)
func hand_point(index: int) -> Vector2:
	var view: Control = cards.hand.views[index]
	return view.get_global_transform_with_canvas()*(view.size*0.5)
func world_point(cell: Vector3i) -> Vector2:
	var map: GridMap = level.get_node("TileMap")
	return viewport.get_camera_3d().unproject_position(map.to_global(map.map_to_local(cell)))
func arrow_centroid(image: Image, color: Color, region: Rect2i) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var pixel := image.get_pixel(x,y)
			if Vector3(pixel.r-color.r,pixel.g-color.g,pixel.b-color.b).length_squared() > 0.001: continue
			total += Vector2(x,y)
			count += 1
	return total/count if count > 0 else Vector2.INF

func verify_arrow_motion(overlay: Control) -> void:
	if DisplayServer.get_name() == "headless": return
	overlay.set_process(false)
	var bounds := Rect2()
	var first := true
	var camera := viewport.get_camera_3d()
	for edge: Vector4i in overlay.markers:
		var a: Vector3 = overlay.map.map_to_local(Vector3i(edge.x,0,edge.y))
		var b: Vector3 = overlay.map.map_to_local(Vector3i(edge.z,0,edge.w))
		var point := camera.unproject_position(overlay.map.to_global(a.lerp(b,0.65)+Vector3.UP*0.18))
		if first:
			bounds = Rect2(point,Vector2.ZERO)
			first = false
		else: bounds = bounds.expand(point)
	var region := Rect2i(bounds.grow(16)).intersection(Rect2i(Vector2i.ZERO,viewport.size))
	overlay._float_elapsed = overlay.float_period*0.2
	overlay.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var early := viewport.get_texture().get_image()
	overlay._float_elapsed = overlay.float_period*0.6
	overlay.queue_redraw()
	await frames()
	await RenderingServer.frame_post_draw
	var late := viewport.get_texture().get_image()
	var up_early := arrow_centroid(early,overlay.increase_color,region)
	var up_late := arrow_centroid(late,overlay.increase_color,region)
	var down_early := arrow_centroid(early,overlay.decrease_color,region)
	var down_late := arrow_centroid(late,overlay.decrease_color,region)
	check(up_early.is_finite() and up_late.is_finite() and up_late.y < up_early.y-0.5,"rendered increase arrows float upward")
	check(down_early.is_finite() and down_late.is_finite() and down_late.y > down_early.y+0.5,"rendered decrease arrows sink downward")
	early.save_png(Artifacts.path("traffic/arrow_float_early.png"))
	late.save_png(Artifacts.path("traffic/arrow_float_late.png"))
	overlay.set_process(true)

func run() -> void:
	viewport = TestViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	level = Fixture.session()
	viewport.add_child(level)
	await frames(15)
	# Let native window focus notifications settle before synthetic pointer input.
	await get_tree().create_timer(0.25,true,false,true).timeout
	viewport.mouse_entered.emit()
	cards = level.get_node("CardPlacement")
	cards.hand.finish_animation()
	var flow: Node = level.get_node("WaveFlowPreview")
	var traffic: TrafficStructures = level.get_node("TowerMap").traffic
	var original: Dictionary = flow.forecast.all.duplicate()
	# Actual drag through the same hand input path as defense cards.
	var start := hand_point(1)
	var target := world_point(Vector3i(6,0,0))
	motion(start)
	left(start,true)
	motion(target,MOUSE_BUTTON_MASK_LEFT)
	await frames()
	check(cards.hand.is_dragging() and cards.preview.visible,"support drag displays hologram")
	check(not cards.traffic_candidate.is_empty() and flow.forecast.all != original,"actual pointer changes weighted forecast")
	check(not flow.delta_overlay.markers.is_empty(),"actual preview shows junction arrows")
	await verify_arrow_motion(flow.delta_overlay)
	var predicted: Dictionary = flow.forecast.all.duplicate()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(Artifacts.path("traffic/drag_preview.png"))
	left(target,false)
	await frames()
	check(traffic.instances.size() == 1 and cards.cards.size() == 2,"drop consumes exactly one support card")
	check(flow.forecast.all == predicted and cards.traffic_candidate.is_empty(),"drop commits same forecast and clears hypothetical state")
	# Narrow Passage rejects existing overlay and retains inventory on failed drop.
	cards.hand.finish_animation()
	start = hand_point(1)
	motion(start)
	left(start,true)
	motion(target,MOUSE_BUTTON_MASK_LEFT)
	await frames()
	check(cards.traffic_candidate.is_empty() and not cards._preview_error.is_empty(),"invalid overlap clears candidate")
	left(target,false)
	await frames()
	check(cards.cards.size() == 2 and traffic.instances.size() == 1,"invalid drop retains card")
	# Flag click-to-place, rotate, cancellation over UI and pause.
	cards.select_card(-1)
	cards.hand.finish_animation()
	start = hand_point(0)
	motion(start)
	left(start,true)
	left(start,false)
	var flag_target := world_point(Vector3i(6,0,1))
	motion(flag_target)
	await frames()
	check(cards.selected == 0 and cards.preview.visible and not cards.traffic_candidate.is_empty(),"flag click selection previews near road")
	cards.rotate_card(1)
	await frames()
	check(cards.turns == 1 and cards.preview.ghost != null,"rotation reuses ghost")
	check(cards.preview.ghost != null and cards.preview.ghost.has_node("Ground/Tile") and cards.preview.ghost.has_node("Ground/Pillar"),"flag preview includes supporting ground and pillar")
	var hud: CanvasLayer = level.get_node("LevelHUD")
	motion(hud.speed_button.get_global_rect().get_center())
	await frames()
	check(cards.traffic_candidate.is_empty(),"UI hover restores baseline")
	motion(flag_target)
	await frames()
	hud.set_paused(true)
	await frames()
	check(cards.traffic_candidate.is_empty() and not flow.delta_overlay.visible,"pause clears candidate and arrows")
	hud.set_paused(false)
	await frames()
	motion(flag_target)
	await frames()
	left(flag_target,true)
	left(flag_target,false)
	await frames(6)
	check(traffic.instances.size() == 2 and cards.cards.size() == 1,"flag click commits after camera arbitration")
	check(traffic.instances[-1].has_node("Visual/Ground/Tile") and traffic.instances[-1].has_node("Visual/Ground/Pillar"),"placed flag includes supporting ground and pillar")
	cards.select_card(-1)
	motion(flag_target)
	await frames()
	check(traffic._hover_label.visible and "3" in traffic._hover_label.text,"hover shows remaining waves")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(Artifacts.path("traffic/placed_hover.png"))
	# Unload during a live wave is safe and a fresh session has no structures.
	var wave: Node = level.get_node("EnemyWave")
	check(wave.start_wave(),"live teardown wave starts")
	level.queue_free()
	await frames()
	level = Fixture.session()
	viewport.add_child(level)
	await frames(12)
	check(level.get_node("TowerMap").traffic.instances.is_empty() and level.get_node("PortalMap").traffic_effects.is_empty(),"restart restores empty modifier state")
	viewport.queue_free()
	await frames()
	var result := {"checks":checks,"failures":failures,"rendered":DisplayServer.get_name() != "headless"}
	FileAccess.open(Artifacts.path("traffic/input.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PHASE2_INPUT:",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)

