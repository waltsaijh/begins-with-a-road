extends Node3D
## Production RoadSurface meshes and tower art, rendered by Compatibility.
const Surface = preload("res://scripts/map/tile/appearance/road_surface.gd")
const Visual = preload("res://scripts/towers/body_visual.gd")
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var camera: Camera3D
var title: Label
var cases: Array[Node3D] = []
var selected := -1
const TITLES := ["單格窄路", "2 × 4 寬路", "3 × 4 平台", "L 形寬路", "T 形交會", "不規則聯集", "2 × 2 迫擊砲旁道路", "1 × 2 側舷砲旁道路", "裁切後道路", "有效路／死路／旁支環"]

func _ready() -> void:
	var environment := WorldEnvironment.new(); environment.environment = load("res://assets/data/rendering/level_environment.tres").duplicate()
	environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("dfe8e7")
	add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-25,0); light.shadow_enabled = true; add_child(light)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; add_child(camera); camera.current = true
	var layer := CanvasLayer.new(); add_child(layer)
	title = Label.new(); title.position = Vector2(22,16); title.add_theme_font_override("font",preload("res://assets/fonts/NotoSansTC-Light.ttf")); title.add_theme_font_size_override("font_size",23); title.add_theme_color_override("font_color",Color("304b50")); layer.add_child(title)
	for i in 10: make_case(i)
	focus(-1)
	if "--capture" in OS.get_cmdline_user_args(): capture.call_deferred()

func rect(cells: Dictionary, x: int, z: int, w: int, h: int) -> void:
	for y in range(z,z+h):
		for column in range(x,x+w): cells[Vector2i(column,y)] = 15

func make_case(index: int) -> void:
	var root := Node3D.new(); root.position = Vector3((index%5)*8,0,(index/5)*9); add_child(root); cases.append(root)
	var cells := {}; var blocked := {}; var ends: Array[Vector2i] = [Vector2i.ZERO,Vector2i(3,0)]
	match index:
		0: rect(cells,0,0,4,1)
		1: rect(cells,0,0,4,2)
		2: rect(cells,0,0,4,3)
		3:
			rect(cells,0,0,2,4); rect(cells,0,2,4,2); ends[1] = Vector2i(3,3)
		4:
			rect(cells,0,0,5,2); rect(cells,2,0,2,4); ends = [Vector2i(0,0),Vector2i(4,0),Vector2i(2,3)]
		5:
			rect(cells,0,0,3,2); rect(cells,1,1,4,2); rect(cells,3,2,2,2); ends[1] = Vector2i(4,3)
		6,7,8:
			rect(cells,0,0,5,4); ends = [Vector2i.ZERO,Vector2i(4,3)]
			var key := "broadside" if index == 7 else "mortar"
			var definition := Catalog.tower(key)
			var body: Array[Vector2i] = [Vector2i.ZERO,Vector2i.DOWN]
			if key == "mortar": body.append_array([Vector2i.RIGHT,Vector2i.ONE])
			for offset in body: blocked[offset+Vector2i(2,1)] = true
			var model := Visual.create(definition,body); model.position = Vector3(2.5,TowerConstants.GROUND_OFFSET,1.5); root.add_child(model)
			if index == 8:
				# Road requests crossing the full existing footprint have been cut;
				# the foundation stays, and all traversable ports stop at its edge.
				cells.erase(Vector2i(4,1)); cells.erase(Vector2i(4,2)); ends[1] = Vector2i(4,3)
		9:
			rect(cells,0,0,6,1); rect(cells,1,1,1,2); rect(cells,3,1,2,2)
			# Single attachment for the side cycle; no complete simple path uses it.
			cells[Vector2i(4,0)] = 10; cells[Vector2i(4,1)] = 14
			ends[1] = Vector2i(5,0)
	var logical := GridMap.new(); logical.mesh_library = load("res://assets/models/mesh_library.tres"); logical.cell_size = Vector3.ONE; logical.cell_center_y = false; root.add_child(logical); logical.hide()
	# Use exact port masks, including the one-sided termination fixture.
	var placement := preload("res://scripts/map/tile/tile_placement.gd").new(); placement.map = logical
	for at: Vector2i in cells:
		var tile: Vector2i = placement.tile_for_mask(cells[at]); logical.set_cell_item(Vector3i(at.x,0,at.y),tile.x,tile.y)
	placement.free()
	var surface := Surface.new(); surface.prepare(logical,blocked,ends)
	var display := GridMap.new(); display.mesh_library = surface.library; display.cell_size = Vector3.ONE; display.cell_center_y = false; root.add_child(display)
	for cell in logical.get_used_cells(): display.set_cell_item(cell,surface.item(logical,cell,logical.get_cell_item(cell)))
	var label := Label3D.new(); label.text = str(index+1)+"  "+TITLES[index]; label.font = preload("res://assets/fonts/NotoSansTC-Light.ttf"); label.font_size = 44; label.pixel_size = 0.012; label.outline_size = 0; label.modulate = Color("304b50"); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.position = Vector3(2,0,5); root.add_child(label)

func focus(index: int) -> void:
	selected = index
	for i in cases.size(): cases[i].visible = index < 0 or index == i
	var target := Vector3(18,0,6) if index < 0 else cases[index].position+Vector3(2,0,1.5)
	camera.size = 27 if index < 0 else 7
	camera.position = target+Vector3(0,25,19); camera.look_at(target)
	title.text = "道路／建造修正 · 1–9、0 檢視個案 · A 全覽" if index < 0 else TITLES[index]+" · A 返回全覽"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_A: focus(-1)
	elif event.keycode == KEY_0: focus(9)
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9: focus(event.keycode-KEY_1)

func capture() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	for index in range(-1,10):
		focus(index)
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("road_refinement/"+("overview" if index < 0 else "case_%02d" % (index+1))+".png"))
	print("ROAD_REFINEMENT_GALLERY: 11 captures"); get_tree().quit()
