extends PanelContainer
signal saved
signal test_requested(card: BuildCard)
signal close_requested
signal policy_changed
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
const Grid = preload("res://scripts/tower_tile_editor/grid.gd")
var catalog = Catalog.new()
var draft: TilePreset
var key := "sentry"
var entries: Array[Dictionary] = []
var undo_stack: Array[TilePreset] = []
var redo_stack: Array[TilePreset] = []
var dirty := false
var syncing := false
var builtin := false
var grid: Control
var tower_picker: OptionButton
var preset_list: ItemList
var name_edit: LineEdit
var weight: SpinBox
var default_check: CheckBox
var facing: OptionButton
var initial: OptionButton
var manual: CheckBox
var home_check: CheckBox
var rotation_picker: OptionButton
var rotations: Array[CheckBox] = []
var port_checks: Array[CheckBox] = []
var offsets: Array[SpinBox] = []
var status: Label
var info: Label
var save_button: Button
var add_button: Button
var new_button: Button
var clone_button: Button
var delete_button: Button
var undo_button: Button
var redo_button: Button
var close_button: Button
var reload_button: Button
var brush_picker: OptionButton
var confirm: ConfirmationDialog
var pending := Callable()
var exclude_builtins: CheckBox
var hide_builtins: CheckBox
var combination_button: Button
var combinations: ConfirmationDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("18272f")
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel",style)
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansTC-Light.ttf")
	theme.default_font_size = 15
	var stack := VBoxContainer.new(); add_child(stack)
	var heading := Label.new(); heading.text = "TOWER TILE EDITOR  /  防禦塔地塊工作台"; heading.add_theme_font_size_override("font_size",23); stack.add_child(heading)
	var subtitle := Label.new(); subtitle.text = "畫塔體 → 畫道路 → 儲存 → 加入手牌試玩　｜　藍綠＝真實障礙，金色＝道路，白十字＝放置原點，白圓＝塔錨點"; stack.add_child(subtitle)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var columns := HBoxContainer.new(); columns.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation",18); stack.add_child(columns)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 205; columns.add_child(left)
	tower_picker = OptionButton.new(); left.add_child(tower_picker)
	for tower_key in Catalog.KEYS: tower_picker.add_item(Catalog.tower(tower_key).localized_name())
	tower_picker.item_selected.connect(func(index): _guard(func(): key = Catalog.KEYS[index]; _list(); _load_row(0)))
	exclude_builtins = CheckBox.new(); exclude_builtins.text = "內建不參與測試"; left.add_child(exclude_builtins)
	hide_builtins = CheckBox.new(); hide_builtins.text = "隱藏內建配置"; left.add_child(hide_builtins)
	exclude_builtins.button_pressed = catalog.data.exclude_builtins; hide_builtins.button_pressed = catalog.data.hide_builtins
	exclude_builtins.toggled.connect(func(value):
		if syncing: return
		if catalog.save_settings(value,hide_builtins.button_pressed): policy_changed.emit()
		else: status.text = catalog.error)
	hide_builtins.toggled.connect(func(value):
		if syncing: return
		if catalog.save_settings(exclude_builtins.button_pressed,value): _list(draft.preset_id)
		else: status.text = catalog.error)
	combination_button = button(left,"管理／儲存測試組合…",func(): combinations.open(catalog))
	combinations = preload("res://scripts/tower_tile_editor/combinations.gd").new(); add_child(combinations)
	combinations.applied.connect(func(): _sync_policy(); policy_changed.emit())
	preset_list = ItemList.new(); preset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL; preset_list.custom_minimum_size.y = 120; left.add_child(preset_list)
	preset_list.item_selected.connect(func(index): _guard(func(): _load_row(index)))
	new_button = button(left,"＋ 新配置",func(): _guard(_new))
	clone_button = button(left,"複製為獨立配置",_clone)
	reload_button = button(left,"重新載入磁碟配置",func(): _guard(_reload))
	delete_button = button(left,"移出候選…",_delete)
	var note := Label.new(); note.text = "內建配置只能複製。\n自建配置可改名、改權重。\n刪除保留 .tres，避免引用失聯。"; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(note)
	var middle := VBoxContainer.new(); middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL; columns.add_child(middle)
	var tools := HBoxContainer.new(); middle.add_child(tools)
	brush_picker = OptionButton.new(); tools.add_child(brush_picker)
	for title in ["塔體筆刷","道路筆刷","橡皮擦","塔錨點","接口筆刷","放置原點","兵營駐點"]: brush_picker.add_item(title)
	brush_picker.item_selected.connect(func(index): grid.brush = index)
	var scale_picker := OptionButton.new(); tools.add_child(scale_picker)
	for n in [9,11,15,21]: scale_picker.add_item("%d × %d" % [n,n])
	scale_picker.select(1); scale_picker.item_selected.connect(func(index): grid.cells = [9,11,15,21][index]; grid.queue_redraw())
	var rotation := OptionButton.new(); tools.add_child(rotation)
	rotation_picker = rotation
	for n in 4: rotation.add_item("預覽 %d°" % (n*90))
	rotation.item_selected.connect(func(index): grid.turns = index; grid.queue_redraw())
	var ports := HBoxContainer.new(); middle.add_child(ports)
	manual = CheckBox.new(); manual.text = "手動接口"; ports.add_child(manual)
	manual.toggled.connect(func(value):
		if syncing: return
		_record()
		grid.manual = value; draft.manual_ports = value; draft.explicit_road_ports.clear()
		if value:
			for cell in draft.road_offsets: draft.explicit_road_ports[cell] = 15
		_refresh())
	for i in 4:
		var check := CheckBox.new(); check.text = ["北","東","南","西"][i]; check.button_pressed = true; ports.add_child(check)
		port_checks.append(check)
		check.toggled.connect(func(value): grid.port_mask = (grid.port_mask | (1<<i)) if value else (grid.port_mask & ~(1<<i)))
	grid = Grid.new(); grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; grid.custom_minimum_size = Vector2(360,320); middle.add_child(grid)
	grid.edited.connect(func(before): undo_stack.append(before); redo_stack.clear(); dirty = true; _refresh())
	var bottom := HBoxContainer.new(); middle.add_child(bottom)
	undo_button = button(bottom,"復原 Ctrl+Z",undo)
	redo_button = button(bottom,"重做 Ctrl+Y",redo)
	var cursor := Label.new(); bottom.add_child(cursor); grid.hover_cell.connect(func(cell): cursor.text = "  (%d, %d)" % [cell.x,cell.y])
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.x = 270; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; columns.add_child(scroll)
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(right)
	label(right,"配置名稱（直接編輯即改名）")
	name_edit = LineEdit.new(); right.add_child(name_edit)
	name_edit.text_changed.connect(func(value):
		if syncing: return
		_record(); draft.display_name = value; _refresh(false))
	label(right,"抽取權重（0＝不抽取）")
	weight = number(right,0,1000,1)
	weight.value_changed.connect(func(_value): if not syncing: dirty = true; _refresh(false))
	default_check = CheckBox.new(); default_check.text = "此塔的預設選用配置"; right.add_child(default_check)
	default_check.toggled.connect(func(_value): if not syncing: dirty = true; _refresh(false))
	label(right,"塔朝向（與地塊旋轉疊加）")
	facing = OptionButton.new(); right.add_child(facing)
	initial = OptionButton.new()
	for i in 4: facing.add_item("%d°" % (i*90)); initial.add_item("%d°" % (i*90))
	facing.item_selected.connect(func(index): _record(); draft.facing_steps = index; _refresh())
	label(right,"允許旋轉")
	var allowed := HBoxContainer.new(); right.add_child(allowed)
	for i in 4:
		var check := CheckBox.new(); check.text = str(i*90); allowed.add_child(check); rotations.append(check)
		check.toggled.connect(func(value):
			if syncing: return
			_record()
			if value: draft.allowed_rotations.append(i)
			else: draft.allowed_rotations.erase(i)
			_refresh())
	label(right,"卡牌預設旋轉")
	right.add_child(initial); initial.item_selected.connect(func(index): _record(); draft.default_rotation = index; _refresh())
	label(right,"模型視覺位移 X / Y / Z（格）")
	var model_row := HBoxContainer.new(); right.add_child(model_row)
	for i in 3:
		var spin := number(model_row,-10,10,0.1); offsets.append(spin)
		spin.custom_minimum_size.x = 78
		spin.value_changed.connect(func(value):
			if syncing: return
			_record(); draft.model_offset[i] = value; _refresh(false))
	home_check = CheckBox.new(); home_check.text = "使用指定兵營駐點"; right.add_child(home_check)
	home_check.toggled.connect(func(value):
		if syncing: return
		_record(); draft.custom_home = value; _refresh())
	info = label(right,""); info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var actions := HBoxContainer.new(); stack.add_child(actions)
	save_button = button(actions,"儲存並套用候選",save_draft)
	add_button = button(actions,"儲存 → 加入手牌試玩",_test)
	close_button = button(actions,"返回即時測試關卡",func(): _guard(func(): close_requested.emit()))
	status = label(stack,""); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.y = 44
	confirm = ConfirmationDialog.new(); add_child(confirm)
	confirm.confirmed.connect(func(): if pending.is_valid(): pending.call())
	confirm.canceled.connect(func():
		tower_picker.select(Catalog.KEYS.find(key))
		preset_list.deselect_all()
		for i in entries.size():
			if entries[i].id == draft.preset_id: preset_list.select(i))
	_list(); _load_row(0)

static func button(parent: Node, title: String, action: Callable) -> Button:
	var result := Button.new(); result.text = title; parent.add_child(result); result.pressed.connect(action); return result
static func label(parent: Node, text: String) -> Label:
	var result := Label.new(); result.text = text; parent.add_child(result); return result
static func number(parent: Node, low: float, high: float, step: float) -> SpinBox:
	var result := SpinBox.new(); result.min_value = low; result.max_value = high; result.step = step; parent.add_child(result); return result

func _guard(action: Callable) -> void:
	if not dirty: action.call(); return
	pending = action; confirm.dialog_text = "尚有未儲存的修改。捨棄修改並繼續？"; confirm.popup_centered()

func _list(select_id := "") -> void:
	entries = catalog.rows(key).filter(func(row): return not (catalog.data.hide_builtins and row.builtin)); preset_list.clear()
	for row in entries:
		preset_list.add_item(("內建 · " if row.builtin else "自建 · ")+Catalog.title(row)+(" ★" if row.default else ""))
		if row.id == select_id: preset_list.select(preset_list.item_count-1)
	tower_picker.select(Catalog.KEYS.find(key))

func _load_row(index: int) -> void:
	if entries.is_empty(): _new(); dirty = false; _refresh(); return
	index = clampi(index,0,entries.size()-1)
	var row := entries[index]; preset_list.select(index)
	draft = row.preset.duplicate(true); builtin = row.builtin
	if builtin and draft.localized_prefix().is_empty(): draft.display_name = Catalog.title(row)
	if draft.tower_footprint.is_empty(): draft.tower_footprint = Catalog.tower(key).cells_at(draft.tower_offset,0)
	for cell in draft.tower_footprint: draft.road_offsets.erase(cell); draft.explicit_road_ports.erase(cell)
	draft.occupied_offsets.clear()
	syncing = true; weight.value = row.weight; default_check.button_pressed = row.default; syncing = false
	dirty = false; undo_stack.clear(); redo_stack.clear(); _refresh()

func _new() -> void:
	draft = TilePreset.new(); draft.preset_id = Catalog.fresh_id(); draft.display_name = "新配置"; draft.tower_footprint = [Vector2i.ZERO]
	builtin = false; dirty = true; undo_stack.clear(); redo_stack.clear()
	syncing = true; weight.value = 1; default_check.button_pressed = false; syncing = false; _refresh()

func _clone() -> void:
	draft = draft.duplicate(true); draft.preset_id = Catalog.fresh_id(); draft.display_name = draft.localized_prefix()+" 副本"; draft.prefix_key = ""
	builtin = false; dirty = true; undo_stack.clear(); redo_stack.clear(); default_check.button_pressed = false; _refresh()

func _record() -> void:
	undo_stack.append(draft.duplicate(true)); redo_stack.clear(); dirty = true

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(draft.duplicate(true)); draft = undo_stack.pop_back(); dirty = true; _refresh()
func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(draft.duplicate(true)); draft = redo_stack.pop_back(); dirty = true; _refresh()

func _refresh(fields := true) -> void:
	grid.preset = draft; grid.manual = draft.has_explicit_ports(); grid.queue_redraw()
	home_check.visible = key == "barracks"
	brush_picker.set_item_disabled(6,key != "barracks")
	if key != "barracks" and grid.brush == 6: grid.brush = 0; brush_picker.select(0)
	var error := BuildCard.from_parts(Catalog.tower(key),draft).configuration_error()
	if draft.tower_footprint.is_empty(): error = "請畫出塔體"
	if draft.display_name.strip_edges().is_empty() and not builtin: error = "請輸入配置名稱"
	if builtin: error = "內建來源；修改須先「複製為獨立配置」才能儲存，不會覆寫原檔。"
	save_button.disabled = not error.is_empty(); add_button.disabled = not error.is_empty(); delete_button.disabled = builtin
	undo_button.disabled = undo_stack.is_empty(); redo_button.disabled = redo_stack.is_empty()
	info.text = "ID: %s\n塔體 %d 格／道路 %d 格\n錨點 (%d,%d) · 放置原點 (0,0)\n%s" % [draft.preset_id,draft.tower_footprint.size(),draft.road_offsets.size(),draft.tower_offset.x,draft.tower_offset.y,"未儲存" if dirty else "已儲存"]
	var low := draft.tower_offset; var high := low
	for cell in draft.tower_footprint+draft.road_offsets: low = low.min(cell); high = high.max(cell)
	info.text += "\n佔地 %d × %d\n%s" % [high.x-low.x+1,high.y-low.y+1,Catalog.tower(key).localized_name()]
	status.text = error if not error.is_empty() else "配置合法。地圖放置時仍會檢查完整塔體、道路連通與已固定行程。"
	status.modulate = Color("e5c891") if builtin else (Color("ff9b83") if not error.is_empty() else Color("a5dfca"))
	if not fields: return
	syncing = true
	home_check.button_pressed = draft.custom_home
	name_edit.text = draft.localized_prefix(); facing.select(draft.facing_steps); initial.select(draft.default_rotation); manual.button_pressed = grid.manual
	for i in 4: rotations[i].button_pressed = i in draft.allowed_rotations
	for i in 3: offsets[i].value = draft.model_offset[i]
	syncing = false

func _reload() -> void:
	var id := draft.preset_id
	catalog = Catalog.new(catalog.root)
	_sync_policy()
	_list(id)
	var selected := preset_list.get_selected_items()
	_load_row(selected[0] if not selected.is_empty() else 0)
	saved.emit()

func save_draft() -> bool:
	if builtin: return false
	if not catalog.save(key,draft,weight.value,default_check.button_pressed): status.text = catalog.error; return false
	dirty = false; _list(draft.preset_id); _refresh(); status.text = "已儲存並套用商店候選；已在手牌／地圖上的配置保持原快照。"; saved.emit(); return true

func _test() -> void:
	if not save_draft(): return
	var card := BuildCard.from_parts(Catalog.tower(key),draft)
	var denied: String = catalog.card_error(card)
	if not denied.is_empty(): status.text = denied+"；請先在「測試組合」勾選此配置。"; return
	test_requested.emit(card)

func _sync_policy() -> void:
	syncing = true
	exclude_builtins.button_pressed = catalog.data.exclude_builtins
	hide_builtins.button_pressed = catalog.data.hide_builtins
	syncing = false
	_list(draft.preset_id if draft != null else "")

func _delete() -> void:
	if builtin: return
	pending = func():
		if catalog.archive(draft.preset_id): dirty = false; _list(); _load_row(0); saved.emit()
		else: status.text = catalog.error
	confirm.dialog_text = "將此配置移出編輯清單和抽牌候選？\n資源檔保留，既有卡牌／場景引用仍有效。"; confirm.popup_centered()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey and event.ctrl_pressed:
		if event.keycode == KEY_Z: undo(); accept_event()
		elif event.keycode == KEY_Y: redo(); accept_event()
		elif event.keycode == KEY_S: save_draft(); accept_event()
