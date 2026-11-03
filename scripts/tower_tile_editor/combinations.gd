extends ConfirmationDialog
signal applied
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
var catalog: RefCounted
var picker: OptionButton
var title_edit: LineEdit
var exclude: CheckBox
var tree: Tree
var message: Label
var save_as: Button
var selected_id := ""
var members: Array[String] = []
var syncing := false

func _ready() -> void:
	title = "測試組合"
	get_ok_button().text = "儲存並套用組合"
	get_cancel_button().text = "取消"
	var stack := VBoxContainer.new(); add_child(stack)
	var hint := Label.new(); hint.text = "勾選可抽取／補牌／放置的配置。套用後會重開測試關卡。"; stack.add_child(hint)
	picker = OptionButton.new(); stack.add_child(picker); picker.item_selected.connect(_select)
	title_edit = LineEdit.new(); title_edit.placeholder_text = "組合名稱，例如：長塔體＋兵營"; stack.add_child(title_edit)
	exclude = CheckBox.new(); exclude.text = "排除所有內建配置"; stack.add_child(exclude)
	exclude.toggled.connect(func(_value): if not syncing: _tree())
	tree = Tree.new(); tree.hide_root = true; tree.custom_minimum_size = Vector2(600,330); tree.size_flags_vertical = Control.SIZE_EXPAND_FILL; stack.add_child(tree)
	tree.item_edited.connect(_edited)
	var clear := Button.new(); clear.text = "清空勾選"; stack.add_child(clear)
	clear.pressed.connect(func(): members.clear(); _tree())
	save_as = Button.new(); save_as.text = "另存為新組合並套用"; stack.add_child(save_as)
	save_as.pressed.connect(func(): _save(true))
	message = Label.new(); message.text = ""; stack.add_child(message)
	dialog_hide_on_ok = false
	confirmed.connect(func(): _save(false))

func open(source: RefCounted) -> void:
	catalog = source
	picker.clear(); picker.add_item("新組合（從目前選擇開始）")
	var index := 0
	for item in catalog.data.combinations:
		picker.add_item(item.name)
		if item.id == catalog.data.active_combination: index = picker.item_count-1
	picker.select(index); _select(index)
	popup_centered(Vector2i(660,580))

func _select(index: int) -> void:
	syncing = true
	members.clear()
	selected_id = "" if index == 0 else catalog.data.combinations[index-1].id
	var item: Dictionary = catalog.combination(selected_id)
	if item.is_empty():
		title_edit.text = "新組合"
		exclude.button_pressed = catalog.data.exclude_builtins
		for key in Catalog.KEYS:
			for row in catalog.playable_rows(key): members.append(Catalog.member_key(key,row.id))
	else:
		title_edit.text = item.name
		exclude.button_pressed = item.get("exclude_builtins",false)
		members.assign(item.members)
	syncing = false; _tree(); message.text = "未勾選的配置不能在這一組放置。"

func _tree() -> void:
	tree.clear()
	var root := tree.create_item()
	for key in Catalog.KEYS:
		var group := tree.create_item(root); group.set_text(0,Catalog.tower(key).localized_name()); group.set_selectable(0,false)
		for row in catalog.rows(key):
			if row.builtin and (exclude.button_pressed or catalog.data.hide_builtins): continue
			var item := tree.create_item(group)
			var id: String = Catalog.member_key(key,row.id)
			item.set_cell_mode(0,TreeItem.CELL_MODE_CHECK); item.set_editable(0,true)
			item.set_text(0,("內建 · " if row.builtin else "")+Catalog.title(row)+"  [權重 %s]" % row.weight)
			item.set_metadata(0,id); item.set_checked(0,id in members)

func _edited() -> void:
	var item := tree.get_edited()
	if item == null: return
	var id: String = item.get_metadata(0)
	if item.is_checked(0):
		if not id in members: members.append(id)
	else: members.erase(id)

func _save(copy: bool) -> void:
	var id: String = catalog.save_combination("" if copy else selected_id,title_edit.text,members,exclude.button_pressed)
	if id.is_empty(): message.text = catalog.error; return
	hide(); applied.emit()
