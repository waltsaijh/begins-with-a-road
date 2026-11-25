extends "res://tests/road_refinement/depth_flow.gd"
## Fixed world lighting, opposite cameras. The baked dark contact band beside the
## curb was removed (2026-11-24): the road next to the bank must match the road centre.
var measurements: Array = []

func _ready() -> void:
	# Drifting cloud shadows are cosmetic and time-varying; keep pixel probes deterministic.
	RenderingServer.global_shader_parameter_set("cloud_shadow_strength", 0.0)
	super._ready()
	if not automatic: run.call_deferred()

func luminance(image: Image, point: Vector2) -> float:
	var world := logical.to_global(logical.map_to_local(Vector3i.ZERO)+Vector3(point.x,Surface.ROAD_HEIGHT+Surface.PAVER_HEIGHT+0.001,point.y))
	var pixel := Vector2i(camera.unproject_position(world))
	var total := 0.0
	for y in range(pixel.y-1,pixel.y+2):
		for x in range(pixel.x-1,pixel.x+2):
			var color := image.get_pixel(x,y)
			total += color.r*0.2126+color.g*0.7152+color.b*0.0722
	return total/9.0

func same_paver_x(side: float) -> float:
	for cell_x in [2,1,3]:
		var pieces: Array = Surface.paver_layouts()[Surface.paver_layout(Vector2i(cell_x,0))]
		for step in range(-8,9):
			var u := step*0.05
			for piece: Rect2 in pieces:
				var top := piece.grow(-(Surface.PAVER_TOP+0.01))
				if top.has_point(Vector2(u,side*0.31)) and top.has_point(Vector2(u,side*0.24)): return cell_x+u
	return NAN

func run() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	build_case(0); ribbon.hide()
	camera.size = 4.0
	var target := logical.to_global(Vector3(3,0,0.5))
	for view in 2:
		camera.position = target+(Vector3(4,7,6) if view == 0 else Vector3(-4,7,-6))
		camera.look_at(target)
		label.text = "路肩旁無暗帶 · 相反視角 %d · 世界光源固定" % (view+1)
		var image := await frame_image()
		for side: float in [-1.0,1.0]:
			# Both probes must sit on one paver's top, so the per-paver tone does not
			# count as a contact band; the x is found from the actual paver layout.
			var x := same_paver_x(side)
			check(not is_nan(x),"Found a paver spanning both probes")
			var edge := luminance(image,Vector2(x,side*0.31))
			var floor_value := luminance(image,Vector2(x,side*0.24))
			var ratio := edge/maxf(floor_value,0.0001)
			measurements.append({"view":view,"side":side,"contact":edge,"floor":floor_value,"ratio":ratio})
			check(absf(ratio-1.0) < 0.03,"Road beside the bank has no dark contact band: "+str(measurements.back()))
		image.save_png(Artifacts.path("bank_contact/view_%s.png" % ("a" if view == 0 else "b")))
	var result := {"checks":checks,"failures":failures,"measurements":measurements,"rendered":true}
	FileAccess.open(Artifacts.path("bank_contact/rendered.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BANK_CONTACT_BOTH_VIEWS:",JSON.stringify(result))
	if automatic: get_tree().quit(0 if failures.is_empty() else 1)
