@tool
extends EditorPlugin
const PanelScene = preload("res://addons/wave_editor/wave_editor.tscn")
var panel: Control

func _enter_tree() -> void:
	panel = PanelScene.instantiate()
	panel.editor_plugin = self
	add_control_to_bottom_panel(panel, "波次編輯器")
	scene_changed.connect(_scene_changed)
	resource_saved.connect(panel.resource_saved)
	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(panel._refresh)
	_open_initial.call_deferred()

func _open_initial() -> void:
	_scene_changed(get_editor_interface().get_edited_scene_root())
	if panel.level == null:
		panel.edit_level(load("res://assets/data/levels/frontier.tres"))
	if "--test-wave-editor" in OS.get_cmdline_user_args():
		var runner: Node = load("res://tests/editor/wave_editor_check.gd").new()
		runner.panel = panel
		get_tree().root.add_child(runner)
	elif "--test-card-resource-refresh" in OS.get_cmdline_user_args():
		get_tree().root.add_child(load("res://tests/editor/card_resource_refresh.gd").new())

func _scene_changed(scene: Node) -> void:
	if scene == null or panel.has_unsaved_changes(): return
	for property in scene.get_property_list():
		if property.name == "level" and scene.get("level") is LevelDefinition:
			panel.edit_level(scene.get("level"))
			return

func _handles(object: Object) -> bool:
	return object is LevelDefinition

func _edit(object: Object) -> void:
	if object is LevelDefinition:
		panel.request_level(object)

func _make_visible(visible: bool) -> void:
	if visible and panel != null: make_bottom_panel_item_visible(panel)

func _get_unsaved_status(for_scene: String) -> String:
	return panel.unsaved_names() if panel != null and for_scene.is_empty() else ""

func _save_external_data() -> void:
	if panel != null: panel.save_all()

func _exit_tree() -> void:
	if panel != null:
		var filesystem := get_editor_interface().get_resource_filesystem()
		if filesystem.filesystem_changed.is_connected(panel._refresh): filesystem.filesystem_changed.disconnect(panel._refresh)
		if resource_saved.is_connected(panel.resource_saved): resource_saved.disconnect(panel.resource_saved)
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
