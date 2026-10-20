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
	# Emulate a live resource from before the two boolean exports were added.
	# Its methods must read missing values as defaults rather than pass Nil
	# into the typed terrain reader, even before the editor has reloaded it.
	var legacy_script := GDScript.new()
	legacy_script.source_code = FileAccess.get_file_as_string("res://scripts/levels/definitions/level_definition.gd").replace("class_name LevelDefinition\n", "").replace("@export var use_terrain_endpoints := true\n", "").replace("@export var expand_starts_after_act := true\n", "")
	check(legacy_script.reload() == OK, "Legacy resource fixture did not compile")
	var legacy: Resource = legacy_script.new()
	legacy.terrain = document.terrain
	legacy.acts = document.acts
	check(legacy.get("use_terrain_endpoints") == null and legacy.terrain_endpoints_enabled(), "Missing boolean was not restored to its intended true default")
	var legacy_layout: Dictionary = legacy.endpoint_layout()
	check(legacy_layout.has("error") and legacy_layout.error.is_empty() and not legacy_layout.start_cells.is_empty(), "Editor terrain read still fails when an export is missing")
	check(legacy.configuration_error().is_empty(), "Validation still accesses an absent layout error key")
	# Reload the script while keeping the old instance, as the real editor does.
	legacy_script.source_code = FileAccess.get_file_as_string("res://scripts/levels/definitions/level_definition.gd").replace("class_name LevelDefinition\n", "")
	check(legacy_script.reload(true) == OK, "Hot reload fixture failed")
	legacy.repair_missing_defaults()
	check(legacy.get("use_terrain_endpoints") is bool and legacy.get("expand_starts_after_act") is bool, "Hot reload left new boolean exports as Nil")
	check(ResourceSaver.save(legacy, "res://.godot/wave_editor_legacy_defaults.tres") == OK, "Migrated resource did not save")
	check(not FileAccess.get_file_as_string("res://.godot/wave_editor_legacy_defaults.tres").contains("use_terrain_endpoints = null"), "Save serialized a Nil boolean")
	document.use_terrain_endpoints = false
	check(not document.terrain_endpoints_enabled(), "An explicit false setting was overwritten by legacy repair")
	document.use_terrain_endpoints = true
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
	check(panel._save_document(document, path) == OK and not panel.is_dirty(document), "Save failed or left the level dirty")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as LevelDefinition
	check(loaded != null and loaded.configuration_error().is_empty(), "Saved resource could not be loaded")
	if loaded != null:
		var stored := loaded.acts[0].waves[0].groups[0]
		check(typeof(stored.start_tick) == TYPE_INT and stored.start_tick == 5 and stored.interval_ticks == 6 and stored.batch_size == 3, "Save/reload changed integer scheduling data")
	var contents := FileAccess.get_file_as_string(path)
	check(contents.contains("start_tick = 5") and contents.contains("interval_ticks = 6") and not contents.contains("spawn_interval"), "Saved schedule still uses floating-point time fields")
	check(contents.contains("troop_path = ") and not contents.contains("_troop.gd"), "Saved wave still embeds troop subclasses")
	panel.edit_group_property("start_tick", 9)
	check(panel.has_unsaved_changes(), "Unsaved edits were not tracked")
	check(history.undo() and not panel.is_dirty(document), "Undo back to the saved state did not clear the dirty indicator")
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
	print("WAVE_EDITOR_CHECK:"+JSON.stringify({"failures": failures, "real_plugin": true, "edit_groups": true, "integer_drag": true, "native_undo_redo": true, "save_reload": true, "preview": true, "legacy_nil_exports": true, "hot_reload_defaults": true, "refresh_recovery": true}))
	get_tree().quit(1 if failures else 0)
