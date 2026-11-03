extends Node3D
const Fixture = preload("res://tests/construction/fixture.gd")
const Editor = preload("res://scripts/tower_tile_editor/editor.gd")
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
@export var open_editor := false
var session: Node3D
var editor: Control
var body: VBoxContainer
var tower_picker: OptionButton
var preset_picker: OptionButton
var entries: Array[Dictionary] = []
var status: Label
var edit_button: Button
var add_button: Button
var clear_button: Button
var draw_button: Button
var reset_button: Button
var busy := false
var input_states: Array[Dictionary] = []
var combination_picker: OptionButton
var needs_reset := false
var policy_stamp := ""
var catalog_root := "res://assets/data/tower_tiles/user"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TranslationServer.set_locale("zh_TW")
	var layer := CanvasLayer.new(); layer.layer = 20; add_child(layer)
	editor = Editor.new(); editor.catalog = Catalog.new(catalog_root); editor.hide(); layer.add_child(editor)
	editor.saved.connect(_apply)
	editor.policy_changed.connect(_policy_changed)
	editor.test_requested.connect(func(card): await close_editor(); _add(card))
	editor.close_requested.connect(close_editor)
	var tools_layer := CanvasLayer.new(); tools_layer.layer = 6; add_child(tools_layer)
	var paper := PanelContainer.new(); tools_layer.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); paper.offset_left = -285; paper.offset_right = -14; paper.offset_top = 70
	paper.theme = editor.theme
	body = VBoxContainer.new(); paper.add_child(body)
	Editor.label(body,"地塊即時測試 · 無批次")
	Editor.label(body,"補助：60 Gold／免費補牌／無敗北")
	Editor.label(body,"測試組合（切換會重開）")
	combination_picker = OptionButton.new(); body.add_child(combination_picker)
	combination_picker.item_selected.connect(_switch_combination)
	tower_picker = OptionButton.new(); body.add_child(tower_picker)
	for key in Catalog.KEYS: tower_picker.add_item(Catalog.tower(key).localized_name())
	tower_picker.item_selected.connect(func(_index): _choices())
	preset_picker = OptionButton.new(); body.add_child(preset_picker)
	edit_button = Editor.button(body,"開啟地塊編輯器",show_editor)
	add_button = Editor.button(body,"補入選定塔＋配置",add_selected)
	clear_button = Editor.button(body,"清空測試手牌",clear_cards)
	draw_button = Editor.button(body,"依候選權重重抽 6 張",redraw)
	reset_button = Editor.button(body,"重開直線關卡",reset)
	status = Editor.label(body,"準備期可編輯；R／右鍵旋轉，拖牌或點地圖放置。")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.x = 260
	await reset()
	if open_editor: show_editor()

func editable() -> bool:
	return not busy and is_instance_valid(session) and not session.finished and not session._wave_starting and not session._wave.active and not session.choosing_relic and not session.choosing_start and not get_tree().paused

func _process(_delta: float) -> void:
	for control in [edit_button,add_button,clear_button,draw_button]:
		if is_instance_valid(control): control.disabled = not editable()
	if is_instance_valid(reset_button): reset_button.disabled = busy or get_tree().paused
	if is_instance_valid(combination_picker): combination_picker.disabled = not editable()
	if is_instance_valid(add_button): add_button.disabled = not editable() or entries.is_empty()

func reset() -> void:
	if busy or get_tree().paused: return
	busy = true
	if is_instance_valid(session):
		remove_child(session); session.queue_free(); await get_tree().process_frame
	Engine.time_scale = 1
	session = Fixture.session(0)
	session.process_mode = Node.PROCESS_MODE_PAUSABLE
	session.level.set_meta("display_title", "Tower Tile Editor · 即時測試（60 Gold／免費補牌／無敗北）")
	session.get_node("CardPlacement").cards.clear()
	session.get_node("TowerMap").card_filter = func(card): return editor.catalog.card_error(card)
	editor.catalog.apply(session.get_node("CardPlacement/Shop"))
	add_child(session)
	var candidate := preload("res://scripts/tower_tile_editor/candidate_preview.gd").new()
	candidate.name = "TileCandidatePreview"; candidate.status = status; session.add_child(candidate)
	session.get_node("TowerMap").placement_feedback.connect(func(message): status.text = message)
	for i in 5: await get_tree().process_frame
	busy = false; needs_reset = false; policy_stamp = _policy_stamp(); _choices(); _combination_choices()

func _choices(preferred := "") -> void:
	var key: String = Catalog.KEYS[tower_picker.selected]
	entries = editor.catalog.playable_rows(key); preset_picker.clear()
	for row in entries:
		preset_picker.add_item(Catalog.title(row)+" · 權重 "+str(row.weight))
		if row.default: preset_picker.select(preset_picker.item_count-1)
	for i in entries.size():
		if entries[i].id == preferred: preset_picker.select(i)

func _apply() -> void:
	if policy_stamp != _policy_stamp(): _policy_changed()
	if is_instance_valid(session): editor.catalog.apply(session.get_node("CardPlacement/Shop"))
	_choices(editor.draft.preset_id)
	_combination_choices()

func show_editor() -> void:
	if not editable(): return
	session.get_node("CardPlacement").select_card(-1)
	session.get_node("CardPlacement/Shop").close_shop()
	editor.key = Catalog.KEYS[tower_picker.selected]; editor._list()
	var selected := preset_picker.selected
	var id: String = entries[selected].id if selected >= 0 and selected < entries.size() else ""
	var editor_index := 0
	for i in editor.entries.size():
		if editor.entries[i].id == id: editor_index = i
	editor._load_row(editor_index)
	session.get_node("Camera3D")._stop_orbit()
	input_states.clear()
	_suspend_input(session)
	editor.show(); get_tree().paused = true

func close_editor() -> void:
	editor.hide(); get_tree().paused = false
	for state in input_states:
		if not is_instance_valid(state.node): continue
		state.node.set_process_input(state.input)
		state.node.set_process_unhandled_input(state.unhandled)
		state.node.set_process_unhandled_key_input(state.keys)
	input_states.clear()
	tower_picker.select(Catalog.KEYS.find(editor.key)); _choices(editor.draft.preset_id)
	if needs_reset: await reset()

func _suspend_input(node: Node) -> void:
	input_states.append({"node":node,"input":node.is_processing_input(),"unhandled":node.is_processing_unhandled_input(),"keys":node.is_processing_unhandled_key_input()})
	node.set_process_input(false); node.set_process_unhandled_input(false); node.set_process_unhandled_key_input(false)
	for child in node.get_children(): _suspend_input(child)

func _add(card: BuildCard) -> void:
	if not editable(): return
	var denied: String = editor.catalog.card_error(card)
	if not denied.is_empty(): status.text = denied; return
	if session.get_node("CardPlacement").add_card(card): status.text = "已免費補牌："+card.localized_name()

func add_selected() -> void:
	if not editable() or entries.is_empty(): return
	_add(BuildCard.from_parts(Catalog.tower(Catalog.KEYS[tower_picker.selected]),entries[preset_picker.selected].preset))

func clear_cards() -> void:
	if not editable(): return
	var cards: Node = session.get_node("CardPlacement")
	cards.select_card(-1); cards.cards.clear(); cards.hand.setup(cards.cards); cards.cards_changed.emit()
	status.text = "已清空手牌；已建塔保留。"

func redraw() -> void:
	if not editable(): return
	clear_cards()
	for card in session.get_node("CardPlacement/Shop").roll_cards(6): _add(card)
	status.text = "已使用目前商店候選權重重抽 6 張；未扣金幣。"

func _policy_stamp() -> String:
	return str([editor.catalog.data.active_combination,editor.catalog.data.exclude_builtins,editor.catalog.combination(editor.catalog.data.active_combination).get("members",[])])

func _policy_changed() -> void:
	needs_reset = true
	_combination_choices()
	if not editor.visible and not get_tree().paused: reset()
	else: status.text = "組合已套用；返回測試時會重開，清除上一組手牌／商品／塔。"

func _combination_choices() -> void:
	if combination_picker == null: return
	combination_picker.clear(); combination_picker.add_item("全部可用配置")
	for item in editor.catalog.data.combinations:
		combination_picker.add_item(item.name)
		if item.id == editor.catalog.data.active_combination: combination_picker.select(combination_picker.item_count-1)

func _switch_combination(index: int) -> void:
	if not editable(): return
	var id: String = "" if index == 0 else editor.catalog.data.combinations[index-1].id
	if editor.catalog.activate(id): editor._sync_policy(); _policy_changed()
	else: status.text = editor.catalog.error
