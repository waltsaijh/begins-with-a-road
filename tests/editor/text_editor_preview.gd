extends SceneTree
func _initialize() -> void: verify.call_deferred()
func verify() -> void:
	root.size = Vector2i(1280,800)
	var background := ColorRect.new()
	background.color = Color("282b31")
	background.size = root.get_visible_rect().size
	root.add_child(background)
	var panel: Control = load("res://addons/text_editor/text_editor.tscn").instantiate()
	root.add_child(panel)
	panel.position = Vector2(20,20)
	panel.size = root.get_visible_rect().size-Vector2(40,40)
	panel.select_entry("relic.assembled_cannon.description")
	for i in 10: await process_frame
	if panel.get_global_rect().end.y > root.get_visible_rect().size.y:
		push_error("Text editor layout escaped the viewport")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/text-editor/panel-preview.png")
	print("TEXT_EDITOR_PREVIEW: rendered")
	quit()
