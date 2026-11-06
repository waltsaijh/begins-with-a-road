extends Node3D
const Fixture = preload("res://tests/construction/fixture.gd")
const Batch = preload("res://scripts/construction/construction_batch.gd")
const Geometry = preload("res://scripts/construction/geometry_bonuses.gd")
const SHAPES := ["straight","corner","tee","cross","pocket"]
var session: Node3D
var batch: Node3D
var mode := 2
var busy := false
var mode_picker: OptionButton
var shape_picker: OptionButton
var draft_picker: OptionButton
var move_button: Button
var rotate_button: Button
var remove_button: Button
var earlier_button: Button
var confirm_button: Button
var refill_button: Button
var status_label: Label
var feedback_label: Label
var body: VBoxContainer
var message := ""
var _shape_card: BuildCard

func _ready() -> void:
	TranslationServer.set_locale("zh_TW")
	create_ui()
	load_mode(2)

func create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var paper := PanelContainer.new()
	screen.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	paper.offset_left = -318
	paper.offset_right = -16
	paper.offset_top = 70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96,0.95,0.91,0.94)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(7)
	paper.add_theme_stylebox_override("panel",style)
	var stack := VBoxContainer.new()
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansTC-Light.ttf")
	theme.default_font_size = 14
	for kind in ["Label","Button","OptionButton","PopupMenu"]:
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
			theme.set_color(state,kind,Color("294744"))
		theme.set_color("font_disabled_color",kind,Color("70817a"))
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled"]:
			var face := StyleBoxFlat.new()
			face.bg_color = Color("e2e8df") if state == "normal" else (Color("cedbd0") if state in ["hover","pressed"] else Color("eaece3"))
			face.set_content_margin_all(6)
			face.set_corner_radius_all(4)
			theme.set_stylebox(state,kind,face)
	stack.theme = theme
	paper.add_child(stack)
	var heading := Button.new()
	heading.text = "建造實驗  ▾"
	heading.flat = true
	stack.add_child(heading)
	body = VBoxContainer.new()
	stack.add_child(body)
	heading.pressed.connect(func(): body.visible = not body.visible; heading.text = "建造實驗  ▾" if body.visible else "建造實驗  ▸")
	mode_picker = OptionButton.new()
	for title in Fixture.MODE_NAMES: mode_picker.add_item(title+" · 重開")
	mode_picker.select(mode)
	mode_picker.item_selected.connect(load_mode)
	body.add_child(mode_picker)
	var caption := Label.new()
	caption.text = "測試補助：6 張卡／60 Gold\n無敗北 · 商店仍照價購買"
	caption.add_theme_font_size_override("font_size",12)
	body.add_child(caption)
	shape_picker = OptionButton.new()
	for key in SHAPES:
		var preset: TilePreset = load(Fixture.PRESET_ROOT+key+".tres")
		shape_picker.add_item("換形："+preset.localized_prefix())
	shape_picker.item_selected.connect(change_shape)
	body.add_child(shape_picker)
	draft_picker = OptionButton.new()
	draft_picker.item_selected.connect(func(index): batch.select_entry(index))
	body.add_child(draft_picker)
	var row := HBoxContainer.new()
	body.add_child(row)
	move_button = button("移動",func(): batch.begin_move(),row)
	rotate_button = button("旋轉 R",func(): batch.rotate_entry(batch.selected_entry),row)
	remove_button = button("撤銷",func(): batch.remove_entry(batch.selected_entry),row)
	earlier_button = button("前移 ↑",func(): batch.reorder_entry(batch.selected_entry,maxi(0,batch.selected_entry-1)),row)
	confirm_button = button("確認預擺",func(): batch.commit(),body)
	refill_button = button("補缺牌 B（測試）",refill_cards,body)
	status_label = Label.new()
	status_label.custom_minimum_size.x = 270
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size",13)
	body.add_child(status_label)
	feedback_label = Label.new()
	feedback_label.custom_minimum_size.x = 270
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size",13)
	feedback_label.add_theme_color_override("font_color",Color("91632b"))
	body.add_child(feedback_label)
	var help := Label.new()
	help.text = "點選或拖牌放置 · R 旋轉\n點草稿選取 · Delete 撤銷\n點入口菱形確認並開波"
	help.add_theme_font_size_override("font_size",12)
	body.add_child(help)

func button(title: String, action: Callable, parent: Node) -> Button:
	var result := Button.new()
	result.text = title
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func load_mode(index: int) -> void:
	if busy or get_tree().paused: return
	busy = true
	if is_instance_valid(session):
		remove_child(session)
		session.queue_free()
		await get_tree().process_frame
	mode = index
	mode_picker.select(index)
	session = Fixture.session(mode)
	add_child(session)
	batch = Batch.new()
	batch.name = "ConstructionBatch"
	batch.mode = mode
	session.add_child(batch)
	if mode > 0:
		var geometry := Geometry.new()
		geometry.name = "GeometryBonuses"
		session.add_child(geometry)
	batch.changed.connect(refresh)
	batch.feedback.connect(func(text): message = text; feedback_label.text = text)
	for i in 8: await get_tree().process_frame
	busy = false
	message = "兩張 L 可拼接大繞路；也能直接開波。" if mode == 2 else "每張放置後都必須保持道路連通。"
	feedback_label.text = message
	refresh()

func refresh() -> void:
	if not is_instance_valid(batch): return
	draft_picker.clear()
	for i in batch.entries.size():
		var entry: Dictionary = batch.entries[i]
		draft_picker.add_item("#%d  %s" % [i+1,entry.card.localized_name()])
	if batch.selected_entry >= 0: draft_picker.select(batch.selected_entry)
	if batch.entries.is_empty(): draft_picker.add_item("尚無預擺地塊")
	draft_picker.visible = mode == 2
	move_button.get_parent().visible = mode == 2
	confirm_button.visible = mode == 2
	shape_picker.visible = mode > 0
	status_label.text = batch.status if mode == 2 else "即時放置 · 成功才消耗卡牌"

func change_shape(index: int) -> void:
	if busy or not batch.editable(): return
	var cards: Node = session.get_node("CardPlacement")
	if cards.selected < 0: return
	var card: BuildCard = cards.cards[cards.selected]
	if card.tower == null or card.tower.deployment != null: return
	card.tile_preset = load(Fixture.PRESET_ROOT+SHAPES[index]+".tres")
	cards._invalidate()
	message = "測試換形："+card.localized_name()
	feedback_label.text = message

func refill_cards() -> void:
	if busy or not batch.editable(): return
	var cards: Node = session.get_node("CardPlacement")
	for card in Fixture.starting_cards(mode):
		if cards.cards.any(func(existing): return existing.tower == card.tower and existing.tile_preset.stable_id() == card.tile_preset.stable_id()): continue
		cards.add_card(card)
	feedback_label.text = "已補上缺少的測試牌；未扣金幣"

func _process(_delta: float) -> void:
	if busy or not is_instance_valid(batch): return
	var allowed: bool = batch.editable()
	var selected: bool = allowed and batch.selected_entry >= 0
	for control in [move_button,rotate_button,remove_button]: control.disabled = not selected
	earlier_button.disabled = not selected or batch.selected_entry == 0
	draft_picker.disabled = not allowed or batch.entries.is_empty()
	confirm_button.disabled = not allowed or batch.entries.is_empty()
	refill_button.disabled = not allowed
	mode_picker.disabled = get_tree().paused
	var cards: Node = session.get_node("CardPlacement")
	shape_picker.disabled = not allowed or cards.selected < 0 or cards.cards[cards.selected].tower == null or cards.cards[cards.selected].tower.deployment != null
	var selected_card: BuildCard = cards.cards[cards.selected] if cards.selected >= 0 else null
	if selected_card != _shape_card:
		_shape_card = selected_card
		if selected_card != null and selected_card.tile_preset != null:
			for index in SHAPES.size():
				if selected_card.tile_preset == load(Fixture.PRESET_ROOT+SHAPES[index]+".tres"): shape_picker.select(index)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		refill_cards()
		get_viewport().set_input_as_handled()
