@tool
extends VBoxContainer
const Document = preload("res://addons/text_editor/text_document.gd")
var document: Resource = Document.new()
var editor_plugin: EditorPlugin
var selected_key := ""
var _refreshing := false
var _items := {}
var _notice := ""
var _local_undo := UndoRedo.new()
@onready var tree: Tree = %Entries
@onready var chinese: TextEdit = %Chinese
@onready var english: TextEdit = %English
@onready var search: LineEdit = %Search
@onready var category: OptionButton = %Category
@onready var status: Label = %Status

func _ready() -> void:
	document.changed.connect(_document_changed)
	search.text_changed.connect(func(_value): _populate())
	category.item_selected.connect(func(_value): _populate())
	tree.item_selected.connect(_selected)
	chinese.text_changed.connect(_edited.bind("zh_TW"))
	english.text_changed.connect(_edited.bind("en"))
	%Save.pressed.connect(save_document)
	%Reload.pressed.connect(request_reload)
	%Discard.confirmed.connect(reload_document)
	reload_document()

func reload_document() -> void:
	var next: Resource = Document.new()
	var error: String = next.open_file(document.path)
	if not error.is_empty():
		_notice = error
		status.text = error
		return
	document.changed.disconnect(_document_changed)
	document = next
	document.changed.connect(_document_changed)
	_local_undo.clear_history()
	_notice = ""
	var previous := category.get_item_text(category.selected) if category.item_count > 0 else "全部文本"
	category.clear()
	category.add_item("全部文本")
	var names: Array[String] = []
	for key in document.keys():
		var name: String = document.category(key)
		if not names.has(name): names.append(name)
	names.sort()
	for name in names: category.add_item(name)
	for i in category.item_count:
		if category.get_item_text(i) == previous: category.select(i)
	_populate()

func request_reload() -> void:
	if document.modified_count() > 0: %Discard.popup_centered(Vector2i(470,150))
	else: reload_document()

func _populate() -> void:
	if not is_node_ready(): return
	_refreshing = true
	tree.clear()
	_items.clear()
	var root := tree.create_item()
	var first := ""
	var filter := search.text.to_lower().strip_edges()
	var group := category.get_item_text(category.selected) if category.selected >= 0 else "全部文本"
	for key in document.keys():
		if group != "全部文本" and document.category(key) != group: continue
		var haystack: String = key+" "+document.get_text(key,"zh_TW")+" "+document.get_text(key,"en")
		if not filter.is_empty() and not haystack.to_lower().contains(filter): continue
		var item := tree.create_item(root)
		item.set_metadata(0,key)
		item.set_text(0,("● " if document.entry_dirty(key) else "")+document.title_for(key))
		item.set_tooltip_text(0,document.category(key)+" · "+key)
		_items[key] = item
		if first.is_empty(): first = key
	if _items.has(selected_key): _items[selected_key].select(0)
	elif not first.is_empty():
		selected_key = first
		_items[first].select(0)
	_refreshing = false
	if not selected_key.is_empty(): _show_entry()
	%Count.text = "%d / %d 筆" % [_items.size(),document.keys().size()]
	_refresh_status()

func _selected() -> void:
	if _refreshing or tree.get_selected() == null: return
	selected_key = tree.get_selected().get_metadata(0)
	_show_entry()

func select_entry(key: String) -> void:
	if not document.indices.has(key): return
	selected_key = key
	if _items.has(key):
		_items[key].select(0)
		tree.scroll_to_item(_items[key])
	_show_entry()

func _show_entry() -> void:
	_refreshing = true
	%EntryTitle.text = document.category(selected_key)+" ／ "+document.title_for(selected_key)
	%Key.text = selected_key
	if chinese.text != document.get_text(selected_key,"zh_TW"): chinese.text = document.get_text(selected_key,"zh_TW")
	if english.text != document.get_text(selected_key,"en"): english.text = document.get_text(selected_key,"en")
	%ChinesePreview.text = document.preview_text(selected_key,"zh_TW")
	%EnglishPreview.text = document.preview_text(selected_key,"en")
	var required: Array[String] = document.tokens(document.saved_rows[document.indices[selected_key]][1])
	%Parameters.text = "必要參數（保留原樣）： "+"  ".join(required) if not required.is_empty() else "本筆沒有數值參數。可直接輸入文字與換行。"
	_refreshing = false

func _edited(locale: String) -> void:
	if _refreshing or selected_key.is_empty(): return
	var value := chinese.text if locale == "zh_TW" else english.text
	var old: String = document.get_text(selected_key,locale)
	if old == value: return
	_notice = ""
	if editor_plugin != null:
		var undo := editor_plugin.get_undo_redo()
		undo.create_action("文本："+selected_key+" / "+locale,UndoRedo.MERGE_ENDS,document)
		undo.add_do_method(document,"set_text",selected_key,locale,value)
		undo.add_undo_method(document,"set_text",selected_key,locale,old)
		undo.commit_action()
	else:
		_local_undo.create_action("文本："+selected_key+" / "+locale,UndoRedo.MERGE_ENDS)
		_local_undo.add_do_method(document.set_text.bind(selected_key,locale,value))
		_local_undo.add_undo_method(document.set_text.bind(selected_key,locale,old))
		_local_undo.commit_action()

func _document_changed() -> void:
	if not is_node_ready(): return
	for key in _items:
		_items[key].set_text(0,("● " if document.entry_dirty(key) else "")+document.title_for(key))
	if document.indices.has(selected_key): _show_entry()
	_refresh_status()

func _refresh_status() -> void:
	var errors: Array = document.validation_errors()
	%Save.disabled = document.modified_count() == 0 or not errors.is_empty()
	status.text = errors[0] if not errors.is_empty() else (_notice if not _notice.is_empty() else "共 %d 筆文本 · %d 筆未儲存。只儲存文案，不修改戰鬥、價格或技能數值。" % [document.keys().size(),document.modified_count()])
	status.tooltip_text = status.text
	status.modulate = Color("f1a598") if not errors.is_empty() else Color.WHITE

func save_document() -> String:
	var changed: int = document.modified_count()
	var error: String = document.save_changes()
	_notice = error if not error.is_empty() else "已儲存 %d 筆文本。遊戲下次執行會使用新文案。" % changed
	if error.is_empty() and changed > 0 and editor_plugin != null and document.path == Document.DEFAULT_PATH:
		var files := editor_plugin.get_editor_interface().get_resource_filesystem()
		files.update_file(document.path)
		files.reimport_files(PackedStringArray([document.path]))
	_refresh_status()
	return error
