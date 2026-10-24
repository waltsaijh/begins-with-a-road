@tool
extends Node
## Run the real editor/plugin with: --editor -- --test-wave-editor
var panel: Control
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func verify() -> void:
	for i in 5: await get_tree().process_frame
	# Let the editor finish its startup progress popup before visual capture.
	if DisplayServer.get_name() != "headless":
		var reveal_after := Time.get_ticks_msec()+1000
		while Time.get_ticks_msec() < reveal_after: await get_tree().process_frame
	var original: LevelDefinition = panel.level
	var document := original.duplicate(true) as LevelDefinition
	var path := "res://.godot/wave_editor_round_trip.tres"
	document.take_over_path(path)
	panel.edit_level(document)
	check(not panel.is_dirty(document) and panel.current_wave().groups.size() == 1, "Opening a level dirtied it or lost its groups")
	panel._refreshing = true
	panel._refresh_frame = -1
	panel._refresh()
	check(not panel._refreshing and panel.current_group() != null, "An interrupted refresh left the editor permanently locked")
	# Emulate a live resource from before the expansion toggle was added.
	var legacy_script := GDScript.new()
	legacy_script.source_code = FileAccess.get_file_as_string("res://scripts/levels/definitions/act_definition.gd").replace("class_name ActDefinition\n", "").replace("@export var add_start_after_completion := true\n", "")
	check(legacy_script.reload() == OK, "Legacy resource fixture did not compile")
	var legacy: Resource = legacy_script.new()
	legacy.waves = document.acts[0].waves
	check(legacy.get("add_start_after_completion") == null, "Legacy fixture unexpectedly had the new export")
	# Reload the script while keeping the old instance, as the real editor does.
	legacy_script.source_code = FileAccess.get_file_as_string("res://scripts/levels/definitions/act_definition.gd").replace("class_name ActDefinition\n", "")
	check(legacy_script.reload(true) == OK, "Hot reload fixture failed")
	legacy.repair_missing_defaults()
	check(legacy.get("add_start_after_completion") is bool and legacy.add_start_after_completion, "Hot reload did not restore the checked ACT default")
	check(ResourceSaver.save(legacy, "res://.godot/wave_editor_legacy_defaults.tres") == OK, "Migrated resource did not save")
	check(not FileAccess.get_file_as_string("res://.godot/wave_editor_legacy_defaults.tres").contains("add_start_after_completion = null"), "Save serialized a Nil boolean")
	document.acts[0].add_start_after_completion = false
	document.repair_missing_defaults()
	check(not document.acts[0].add_start_after_completion, "An explicit false ACT setting was overwritten by legacy repair")
	document.acts[0].add_start_after_completion = true
	panel.get_node("%StartTick").value = 5
	panel.get_node("%IntervalTicks").value = 6
	panel.get_node("%Count").value = 7
	panel.get_node("%Batch").value = 3
	check(panel.current_group().start_tick == 5 and panel.current_group().interval_ticks == 6 and panel.current_group().end_tick() == 17, "Editor did not store exact integer ticks")
	check(panel.get_node("%StartSeconds").text == "1.25 秒" and panel.get_node("%IntervalSeconds").text == "1.50 秒", "Tick conversion labels are wrong")
	var manager: EditorUndoRedoManager = panel.editor_plugin.get_undo_redo()
	var history_id: int = manager.get_object_history_id(document)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	check(history.undo() and panel.current_group().batch_size == 1, "Native editor Undo did not restore a field")
	check(history.redo() and panel.current_group().batch_size == 3, "Native editor Redo did not reapply a field")
	check(panel.get_node("%ExpandAfterAct").button_pressed,"Existing ACT checkbox did not start checked")
	panel.get_node("%ExpandAfterAct").button_pressed = false
	check(not document.acts[0].add_start_after_completion,"Checkbox did not update the selected ACT")
	check(history.undo() and document.acts[0].add_start_after_completion and panel.get_node("%ExpandAfterAct").button_pressed,"ACT checkbox Undo failed")
	check(history.redo() and not document.acts[0].add_start_after_completion,"ACT checkbox Redo failed")
	var original_count := document.acts.size()
	panel.get_node("%AddAct").pressed.emit()
	var added_act: ActDefinition = panel.current_act()
	check(document.acts.size()==original_count+1 and added_act.add_start_after_completion and panel.get_node("%ExpandAfterAct").button_pressed,"New ACT was not selected with a checked expansion flag")
	check(added_act.waves.size()==1 and panel.current_wave().configuration_error().is_empty(),"New ACT did not contain a valid independent wave")
	var first_added_wave: WaveDefinition = panel.current_wave()
	panel.get_node("%AddWave").pressed.emit()
	var second_added_wave: WaveDefinition = panel.current_wave()
	check(added_act.waves.size()==2 and second_added_wave!=first_added_wave and second_added_wave.groups[0]!=first_added_wave.groups[0],"Add wave shared mutable wave/group data")
	check(history.undo() and added_act.waves.size()==1 and panel.current_wave()==first_added_wave,"Add-wave Undo lost the original selection")
	check(history.redo() and panel.current_wave()==second_added_wave,"Add-wave Redo did not restore the selected new wave")
	panel.get_node("%DeleteWave").pressed.emit()
	check(added_act.waves.size()==1,"Delete-wave button did not remove the selected wave")
	check(history.undo() and panel.current_wave()==second_added_wave,"Delete-wave Undo did not restore the wave/selection")
	check(history.redo() and added_act.waves.size()==1,"Delete-wave Redo failed")
	panel.delete_wave()
	check(added_act.waves.is_empty() and panel.current_wave()==null and panel.get_node("%Save").disabled and panel.get_node("%Add").disabled and not panel.get_node("%AddWave").disabled,"An empty ACT could not be edited safely")
	check(history.undo() and panel.current_wave()==first_added_wave,"Undo of the last wave deletion failed")
	panel.get_node("%DeleteAct").pressed.emit()
	check(document.acts.size()==original_count and not document.acts.has(added_act),"Delete-ACT button did not remove the selected ACT")
	check(history.undo() and panel.current_act()==added_act and panel.current_wave()==first_added_wave,"Delete-ACT Undo did not restore its waves and selection")
	check(history.redo() and document.acts.size()==original_count,"Delete-ACT Redo failed")
	panel.select_act(0)
	var first: WaveSpawnGroup = panel.current_group()
	panel.duplicate_group()
	check(panel.current_wave().groups.size() == 2 and panel.current_group() != first and panel.current_group().troop == first.troop, "Duplicate shared group data or unnecessarily cloned its troop")
	panel.edit_group_property("start_tick", 13)
	check(first.start_tick == 5, "Editing a duplicated group changed the original")
	panel.delete_group()
	check(panel.current_wave().groups.size() == 1, "Delete did not remove a group")
	panel.preview_tick = 24
	panel.add_group()
	check(panel.current_wave().groups.size() == 2 and panel.current_group().start_tick == 24, "Add did not use the preview tick")
	panel._choose_troop(1)
	check(panel.current_group().troop == TroopCatalog.find("quickfeet"), "Troop picker did not edit the selected group")
	check(panel.get_node("%TroopPicker").get_item_icon(1) == TroopCatalog.find("quickfeet").icon, "Troop picker lost the resource icon")
	check(not panel.get_node("%TroopPicker").get_item_text(1).begins_with("troop."), "Troop picker displayed an untranslated key")
	panel.selected_group = 0
	panel._refresh()
	panel._seek(6)
	check(panel.get_node("%PreviewCounts").text.contains("soldier 3 隻"), "Preview did not evaluate the same integer schedule")
	# A drag shorter than two quarter-second ticks must commit one integer tick.
	var timeline: Control = panel.get_node("%Schedule")
	var bar: Rect2 = timeline._bar(0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = bar.get_center()
	timeline._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position+Vector2((timeline.size.x-160)/timeline.axis_ticks()*1.2, 0)
	timeline._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	timeline._gui_input(release)
	check(first.start_tick == 6 and typeof(first.start_tick) == TYPE_INT, "Timeline drag did not snap to a quarter-second integer")
	check(history.undo() and first.start_tick == 5, "A drag was not one undoable action")
	panel.add_act()
	panel.add_wave()
	panel.select_act(0)
	check(panel._save_document(document, path) == OK and not panel.is_dirty(document), "Save failed or left the level dirty")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as LevelDefinition
	check(loaded != null and loaded.configuration_error().is_empty(), "Saved resource could not be loaded")
	if loaded != null:
		check(loaded.acts.size()==original_count+1 and loaded.acts.back().waves.size()==2 and not loaded.acts[0].add_start_after_completion and loaded.acts.back().add_start_after_completion,"Save/reload lost added ACTs, waves or independent checkbox values")
		var stored := loaded.acts[0].waves[0].groups[0]
		check(typeof(stored.start_tick) == TYPE_INT and stored.start_tick == 5 and stored.interval_ticks == 6 and stored.batch_size == 3, "Save/reload changed integer scheduling data")
	var contents := FileAccess.get_file_as_string(path)
	for removed in ["title_key", "description_key", "use_terrain_endpoints", "marker_height", "starts", "goal", "expand_starts_after_act"]:
		check(not contents.contains(removed+" = "), "Save retained removed Level field: "+removed)
	check(contents.contains("start_tick = 5") and contents.contains("interval_ticks = 6") and not contents.contains("spawn_interval"), "Saved schedule still uses floating-point time fields")
	check(contents.contains("troop_path = ") and not contents.contains("_troop.gd"), "Saved wave still embeds troop subclasses")
	panel.edit_group_property("start_tick", 9)
	check(panel.has_unsaved_changes(), "Unsaved edits were not tracked")
	check(history.undo() and not panel.is_dirty(document), "Undo back to the saved state did not clear the dirty indicator")
	# The last ACT may be removed and recreated; an invalid empty level cannot save.
	var empty_document: LevelDefinition = preload("res://tests/fixtures/level_fixture.gd").level("editor_empty")
	panel.edit_level(empty_document)
	var original_act := empty_document.acts[0]
	panel.delete_act()
	check(empty_document.acts.is_empty() and panel.current_act()==null and panel.get_node("%Save").disabled and not panel.get_node("%AddAct").disabled and panel.get_node("%ExpandAfterAct").disabled,"Deleting the last ACT left an unusable editor")
	var empty_id := manager.get_object_history_id(empty_document)
	var empty_history := manager.get_history_undo_redo(empty_id)
	panel.add_act()
	check(empty_document.acts.size()==1 and not panel.get_node("%Save").disabled,"Adding an ACT did not repair an empty level")
	check(empty_history.undo() and empty_document.acts.is_empty(),"Undo of empty-level recovery failed")
	check(empty_history.undo() and empty_document.acts[0]==original_act,"Undo did not recover the deleted last ACT")
	manager.clear_history(empty_id)
	panel._saved_signatures.erase(empty_document)
	panel.edit_level(document)
	panel.editor_plugin.make_bottom_panel_item_visible(panel)
	for i in 8: await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		panel.editor_plugin.make_bottom_panel_item_visible(panel)
		await get_tree().process_frame
		check(panel.is_visible_in_tree(), "Wave editor bottom panel is not visible")
		# An idle/offscreen editor can stop scheduling draws after startup.
		RenderingServer.force_draw()
		var screenshot := get_viewport().get_texture().get_image()
		screenshot.save_png("res://.godot/wave_editor_actual.png")
	manager.clear_history(history_id)
	panel._saved_signatures.erase(document)
	panel.edit_level(original)
	print("WAVE_EDITOR_CHECK:"+JSON.stringify({"failures": failures, "real_plugin": true, "act_wave_add_delete": true, "per_act_checkbox": true, "empty_recovery": true, "edit_groups": true, "integer_drag": true, "native_undo_redo": true, "save_reload": true, "preview": true, "hot_reload_defaults": true, "refresh_recovery": true}))
	get_tree().quit(1 if failures else 0)
