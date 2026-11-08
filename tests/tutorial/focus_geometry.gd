extends SceneTree
var failures := 0

func _initialize() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func verify() -> void:
	var layer := load("res://scenes/tutorial/tutorial_focus.tscn").instantiate() as CanvasLayer
	root.add_child(layer)
	layer.transform = Transform2D(0.0,Vector2(19,-13))
	var focus: Control = layer.get_node("Focus")
	var target_layer := CanvasLayer.new()
	target_layer.layer = 4
	target_layer.transform = Transform2D(0.07,Vector2(23,11))
	root.add_child(target_layer)
	var target := Control.new()
	target.position = Vector2(350,230)
	target.size = Vector2(144,208)
	target.scale = Vector2(0.8,0.9)
	target_layer.add_child(target)
	var artwork := Control.new()
	artwork.name = "Visuals"
	artwork.size = target.size
	artwork.pivot_offset = Vector2(72,208)
	artwork.rotation = 0.012
	target.add_child(artwork)
	focus.follow(target)
	await process_frame
	for angle in [-0.23,0.0,0.17]:
		target.rotation = angle
		var quad: PackedVector2Array = focus.target_quad()
		var reference := PackedVector2Array([Vector2.ZERO,Vector2(144,0),Vector2(144,208),Vector2(0,208)])
		for i in 4:
			check((focus.get_global_transform_with_canvas()*quad[i]).distance_to(artwork.get_global_transform_with_canvas()*reference[i]) < 0.001,"Focus corners must match rendered artwork across CanvasLayers, scale and rotation")
		var area := 0.0
		var regions: Array = focus.mask_regions(quad)
		for region in regions: area += focus.polygon_area(region)
		check(absf(area+focus.polygon_area(quad)-focus.size.x*focus.size.y) < 1.0,"Mask and focus hole must partition the viewport without shifted gaps or overlaps")
		for y in range(20,int(focus.size.y),47):
			for x in range(20,int(focus.size.x),53):
				var point := Vector2(x,y)
				var coverage := 0
				for region in regions:
					if Geometry2D.is_point_in_polygon(point,region): coverage += 1
				check(coverage == (0 if Geometry2D.is_point_in_polygon(point,quad) else 1),"Each mask pixel region must cover the outside exactly once")
	layer.queue_free()
	target_layer.queue_free()
	await process_frame
	root.get_node("GameAudio").queue_free()
	await create_timer(0.15,true,false,true).timeout
	print("TUTORIAL_FOCUS_GEOMETRY: failures=",failures)
	quit(0 if failures == 0 else 1)
