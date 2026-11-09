extends SceneTree
var failures := 0
func _initialize() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames() -> void:
	for i in 4: await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/construction-"+name+".png")
func verify() -> void:
	TranslationServer.set_locale("zh_TW")
	root.size = Vector2i(1152,648)
	var menu: Node = load("res://scenes/menus/main_menu.tscn").instantiate()
	root.add_child(menu)
	await frames()
	menu._show_map_selection("frontier")
	var selection: Control = menu.map_selection
	# Local fixture unlock; no completion file or Level resource is changed.
	for map in selection.maps: map.unlocked = true
	selection.refresh()
	await create_timer(0.4).timeout
	var fixed := {}
	for path in ["Footer/Column/MapRow","Footer/Column/Actions","Footer/Column/Details"]:
		fixed[path] = selection.get_node(path).get_global_rect()
	selection.start_button.pressed.emit()
	await frames()
	check(selection.current_step == 1,"Frontier did not enter options")
	var choices: Node = selection.get_node("Footer/Column/Details/RunOptions/LeftColumn/Group/Difficulty/Choices")
	var hint: Label = selection.get_node("Footer/Column/Details/RunOptions/LeftColumn/Group/ExtraEvents/Enabled/ConstructionHint")
	var enabled: Control = hint.get_parent()
	check(is_equal_approx(hint.get_global_rect().get_center().y,enabled.get_global_rect().get_center().y) and hint.global_position.x > enabled.global_position.x+enabled.size.x,"Construction hint is not beside the extra-events toggle")
	check(selection.get_node("Footer/Column/Details/RunOptions/RightColumn/Group/Hint").text == "ui.run.prototype_hint","Starting-hand hint was not restored")
	for name in ["Relaxed","Standard","Challenge"]:
		choices.get_node(name).button_pressed = true
		choices.get_node(name).pressed.emit()
		await frames()
		check(tr(hint.text).begins_with("該功能該還在施工"),"Construction hint did not translate")
		check(hint.text.ends_with(str(choices.get_node(name).get_meta("value"))),"Difficulty did not change the single hint")
	await capture("options")
	selection.go_back()
	selection.select_level("bridge")
	await frames()
	var notice: Control = selection.get_node("Footer/Column/Details/Construction")
	check(notice.visible,"Bridge construction notice is hidden")
	for path in fixed:
		check(selection.get_node(path).get_global_rect() == fixed[path],"Construction notice moved existing layout: "+path)
	selection.start_button.pressed.emit()
	await create_timer(0.11).timeout
	var word: Label = notice.get_node("Row/Word/Label")
	check(selection.current_step == 0 and not menu._starting,"Bridge Next advanced or launched")
	check(word.modulate.g < 0.5 and word.position.x != 0,"Only the unfinished word should turn red and shake")
	await capture("bridge-shake")
	selection.start_button.pressed.emit()
	await create_timer(0.8).timeout
	check(word.position == Vector2.ZERO and word.modulate == Color.WHITE,"Repeated feedback did not settle")
	await capture("bridge")
	TranslationServer.set_locale("en")
	await frames()
	check(word.get_parent().size.x >= word.get_minimum_size().x,"English unfinished word overlaps the suffix")
	check(tr(hint.text).begins_with("This feature"),"Construction hint did not switch language")
	selection.select_level("tutorial")
	check(not notice.visible,"Construction notice leaked to another map")
	selection.start_button.pressed.emit()
	check(selection.current_step == 1,"Bridge block leaked to another map")
	menu.queue_free()
	await frames()
	print("CONSTRUCTION_NOTICE_CHECK: failures=%d" % failures)
	quit(1 if failures else 0)
