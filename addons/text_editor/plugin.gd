@tool
extends EditorPlugin
const PanelScene = preload("res://addons/text_editor/text_editor.tscn")
var panel: Control
func _enter_tree() -> void:
	panel = PanelScene.instantiate()
	panel.editor_plugin = self
	get_editor_interface().get_editor_main_screen().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.hide()
	add_tool_menu_item("遊戲文本編輯器",_open_text_editor)
	if "--test-text-editor" in OS.get_cmdline_user_args(): _run_test.call_deferred()
func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "遊戲文本"
func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Translation","EditorIcons")
func _make_visible(value: bool) -> void:
	if panel != null: panel.visible = value
func _open_text_editor() -> void:
	get_editor_interface().set_main_screen_editor("遊戲文本")
func _get_unsaved_status(for_scene: String) -> String:
	return "遊戲文本（%d 筆未儲存）" % panel.document.modified_count() if panel != null and for_scene.is_empty() and panel.document.modified_count() > 0 else ""
func _save_external_data() -> void:
	if panel != null and panel.document.modified_count() > 0: panel.save_document()
func _exit_tree() -> void:
	remove_tool_menu_item("遊戲文本編輯器")
	if panel != null: panel.queue_free()
func _run_test() -> void:
	_open_text_editor()
	var runner: Node = load("res://tests/editor/text_editor_check.gd").new()
	runner.panel = panel
	get_tree().root.add_child(runner)
