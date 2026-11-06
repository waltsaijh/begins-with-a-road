extends "res://tests/road_refinement/depth_flow.gd"
## Fixed world lighting, opposite cameras: both road-bank contacts must read.
var measurements: Array = []

func _ready() -> void:
	super._ready()
	if not automatic: run.call_deferred()

func luminance(image: Image, point: Vector2) -> float:
	var world := logical.to_global(logical.map_to_local(Vector3i.ZERO)+Vector3(point.x,0.001,point.y))
	var pixel := Vector2i(camera.unproject_position(world))
	var total := 0.0
	for y in range(pixel.y-1,pixel.y+2):
		for x in range(pixel.x-1,pixel.x+2):
			var color := image.get_pixel(x,y)
			total += color.r*0.2126+color.g*0.7152+color.b*0.0722
	return total/9.0

func run() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	build_case(0); ribbon.hide()
	camera.size = 4.0
	var target := logical.to_global(Vector3(3,0,0.5))
	for view in 2:
		camera.position = target+(Vector3(4,7,6) if view == 0 else Vector3(-4,7,-6))
		camera.look_at(target)
		label.text = "路肩接觸暗部 · 相反視角 %d · 世界光源固定" % (view+1)
		var image := await frame_image()
		for side: float in [-1.0,1.0]:
			var edge := luminance(image,Vector2(2.5,side*0.31))
			var floor_value := luminance(image,Vector2(2.5,side*0.22))
			var ratio := edge/maxf(floor_value,0.0001)
			measurements.append({"view":view,"side":side,"contact":edge,"floor":floor_value,"ratio":ratio})
			check(ratio < 0.90,"Lit and shaded bank contacts both retain visible contrast: "+str(measurements.back()))
		image.save_png(Artifacts.path("bank_contact/view_%s.png" % ("a" if view == 0 else "b")))
	var result := {"checks":checks,"failures":failures,"measurements":measurements,"rendered":true}
	FileAccess.open(Artifacts.path("bank_contact/rendered.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("BANK_CONTACT_BOTH_VIEWS:",JSON.stringify(result))
	if automatic: get_tree().quit(0 if failures.is_empty() else 1)
