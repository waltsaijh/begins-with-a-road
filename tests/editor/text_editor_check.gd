@tool
extends Node
const Document = preload("res://addons/text_editor/text_document.gd")
var panel: Control
var failures := 0
var checks := 0
func _ready() -> void: verify.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame
func verify() -> void:
	await frames(20)
	print("TEXT_EDITOR_STEP:ready")
	var canonical_hash := FileAccess.get_sha256(Document.DEFAULT_PATH)
	var path := "res://.godot/text-editor/editor-fixture.csv"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(Document.DEFAULT_PATH))
	file.close()
	panel.document.path = path
	panel.reload_document()
	panel.select_entry("relic.global_damage.description")
	check(panel.document.keys().size() >= 300 and panel.chinese.text.contains("{bonus_percent}"),"Real editor did not load the selected text")
	check(panel.get_node("%ChinesePreview").text.contains("10%"),"Real editor preview does not show resource values")
	var before: String = panel.chinese.text
	panel.chinese.text = before+"\n測試換行，不改數值。"
	panel._edited("zh_TW")
	check(panel.document.modified_count() == 1 and panel.document.get_text(panel.selected_key,"zh_TW").ends_with("不改數值。"),"Editing did not update the draft")
	print("TEXT_EDITOR_STEP:edited")
	var manager: EditorUndoRedoManager = panel.editor_plugin.get_undo_redo()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(panel.document))
	check(history.undo() and panel.chinese.text == before and panel.document.modified_count() == 0,"Native editor Undo did not restore text/dirty state")
	check(history.redo() and panel.document.modified_count() == 1,"Native editor Redo did not restore the edit")
	check(panel.save_document().is_empty() and panel.document.modified_count() == 0,"Save did not persist/reset the dirty flag")
	print("TEXT_EDITOR_STEP:saved")
	var saved: String = panel.chinese.text
	panel.reload_document()
	check(panel.chinese.text == saved,"Reload lost a saved multiline edit")
	panel.chinese.text = "缺少參數"
	panel._edited("zh_TW")
	check(panel.get_node("%Save").disabled and not panel.save_document().is_empty(),"Invalid parameter removal was saved")
	panel.reload_document()
	panel.search.text = "冰霜"
	panel._populate()
	check(panel._items.size() > 0 and panel._items.size() < panel.document.keys().size(),"Chinese search did not filter entries")
	panel.search.text = ""
	panel._populate()
	panel.select_entry("relic.assembled_cannon.description")
	check(panel.get_node("%ChinesePreview").text.contains("66.67%"),"Read-only attack-speed preview is wrong")
	print("TEXT_EDITOR_STEP:verified")
	check(FileAccess.get_sha256(Document.DEFAULT_PATH) == canonical_hash,"Editor test touched the real catalog")
	print("TEXT_EDITOR_CHECK: checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
