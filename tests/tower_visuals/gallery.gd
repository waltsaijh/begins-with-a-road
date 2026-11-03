extends Node3D
## Read-only art contact sheet. Gameplay acceptance lives in the editor playground.
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
const Visual = preload("res://scripts/towers/body_visual.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var stage: Node3D
var title: Label
var key_index := 0
var turns := 0
var show_range := false
var previews: Array[Node3D] = []

func _ready() -> void:
	TranslationServer.set_locale("zh_TW")
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color("e3eae7")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.7
	add_child(env)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-25,0); light.shadow_enabled = true; add_child(light)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 32
	camera.position = Vector3(0,34,26); add_child(camera); camera.look_at(Vector3(0,0,-1)); camera.current = true
	var layer := CanvasLayer.new(); add_child(layer)
	title = Label.new(); title.position = Vector2(24,18); title.add_theme_color_override("font_color",Color("304b50")); title.add_theme_font_size_override("font_size",22); layer.add_child(title)
	_rebuild()
	if "--capture" in OS.get_cmdline_user_args(): _capture.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode >= KEY_1 and event.keycode <= KEY_6: key_index = event.keycode-KEY_1; _rebuild()
	elif event.keycode == KEY_R: turns = (turns+1)%4; _rebuild()
	elif event.keycode == KEY_A:
		show_range = not show_range
		for preview in previews: preview.attack_area.visible = show_range

func _rebuild() -> void:
	if is_instance_valid(stage): stage.free()
	previews.clear(); stage = Node3D.new(); add_child(stage)
	var definition := Catalog.tower(Catalog.KEYS[key_index])
	title.text = "20 + 1 · %s   |   1–6 切換塔種   R 旋轉   A 射程\n每列同一配置 · 左 Lv1 / 中 Lv2 / 右 Lv3" % definition.localized_name()
	var options := definition.preset_candidates()
	for row in options.size():
		var card := BuildCard.from_parts(definition,options[row].resolve_preset())
		for level in range(1,4):
			var map := GridMap.new(); map.cell_size = Vector3.ONE; map.cell_center_y = false
			map.position = Vector3((level-2)*9,0,(row-1.5)*8); stage.add_child(map)
			var preview: Node3D = preload("res://scenes/cards/components/card_preview.tscn").instantiate(); stage.add_child(preview)
			preview.show_at(map,card,Vector3i.ZERO,turns,true)
			# Keep the exact preview geometry, but show opaque production art.
			_restore_materials(preview.ghost)
			Visual.set_level(preview.ghost,level)
			preview.attack_area.visible = show_range; previews.append(preview)
			var label := Label3D.new(); label.text = "%s · Lv%d" % [card.localized_prefix() if not card.localized_prefix().is_empty() else "兵營",level]
			label.font = preload("res://assets/fonts/NotoSansTC-Light.ttf"); label.font_size = 42; label.pixel_size = 0.015; label.modulate = Color("304b50"); label.outline_size = 0; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = map.position+Vector3(0,0.1,3.3); stage.add_child(label)

func _restore_materials(node: Node) -> void:
	if node is MeshInstance3D: node.material_override = null; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children(): _restore_materials(child)

func _capture() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	for key in 6:
		key_index = key; show_range = false; _rebuild()
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("tower_visuals/"+Catalog.KEYS[key]+"_levels.png"))
		show_range = true
		for preview in previews: preview.attack_area.show()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Artifacts.path("tower_visuals/"+Catalog.KEYS[key]+"_ranges.png"))
	print("TOWER_VISUAL_GALLERY: 12 captures")
	get_tree().quit()
