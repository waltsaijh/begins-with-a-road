extends Node3D
## Draft reservations never mutate inventory, topology or route history.
signal changed
signal feedback(message: String)
const Schedule = preload("res://scripts/construction/construction_schedule.gd")
const Preview = preload("res://scenes/cards/components/card_preview.tscn")
@export_enum("Legacy immediate","Compound immediate","Compound batch") var mode := 2
var entries: Array[Dictionary] = []
var selected_entry := -1
var moving := false
var last_error := ""
var status := "選牌預擺，再一起確認"
var cards: Node
var towers: Node
var session: Node
var _ghosts: Array[Node3D] = []
var _dirty := true
var _busy := false
var _edit_cell := TileConstants.INVALID_CELL
var edit_preview: Node3D
var pending_forecast: Array = []
var _watched_cards: Array[BuildCard] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = get_parent()
	cards = session.get_node("CardPlacement")
	towers = session.get_node("TowerMap")
	cards.construction = self
	towers.input_enabled = false
	towers.controller.graph_changed.connect(invalidate)
	towers.traffic.changed.connect(invalidate)
	towers.relics.changed.connect(invalidate)
	cards.cards_changed.connect(invalidate)
	session.get_node("EnemyWave").routes_changed.connect(invalidate)
	session.preparation_changed.connect(_on_preparation_changed)
	edit_preview = Preview.instantiate()
	add_child(edit_preview)
	edit_preview.relics = towers.relics
	edit_preview.hide()
	get_viewport().mouse_exited.connect(cancel_move)

func editable() -> bool:
	return not _busy and not get_tree().paused and not cards.pause_locked and not cards.entry_selection_active and not cards._wave_active and not cards._wave_start_pending and not cards._shop_open

func invalidate() -> void:
	_dirty = true
	_edit_cell = TileConstants.INVALID_CELL
	for card in _watched_cards:
		if card.changed.is_connected(invalidate): card.changed.disconnect(invalidate)
	_watched_cards.clear()
	for entry in entries:
		if entry.card in _watched_cards: continue
		_watched_cards.append(entry.card)
		entry.card.changed.connect(invalidate)
	_refresh_reservations()

func is_reserved(index: int) -> bool:
	for entry in entries:
		if entry.card_index == index: return true
	return false

func _result(error := "") -> Dictionary:
	last_error = error
	feedback.emit(error)
	return {"ok":error.is_empty(),"error":error}

func _on_preparation_changed(available: bool) -> void:
	if available: _result()

func validate_candidate(card: BuildCard, anchor: Vector3i, turns: int) -> String:
	if mode != 2: return towers.validate_card(card,anchor,turns)
	if card.traffic != null:
		return towers.validate_card(card,anchor,turns) if entries.is_empty() else "請先確認或撤銷預擺，再放輔助設施"
	var proposed: Array = entries.duplicate()
	proposed.append({"card":card,"anchor":anchor,"turns":turns})
	return towers.construction_plan(proposed,false).error

func stage(card: BuildCard, anchor: Vector3i, turns := 0, card_index := -1) -> Dictionary:
	if mode != 2 or not editable(): return _result("目前不能預擺")
	if card_index < 0:
		for index in cards.cards.size():
			if cards.cards[index] == card and not is_reserved(index):
				card_index = index
				break
	if card_index < 0 or card_index >= cards.cards.size() or cards.cards[card_index] != card or is_reserved(card_index): return _result("這張卡已預擺或不在手牌中")
	var error := validate_candidate(card,anchor,turns)
	if not error.is_empty(): return _result(error)
	if card.traffic != null: return _result("輔助設施使用原本的即時放置")
	entries.append({"card":card,"anchor":anchor,"turns":posmod(turns,4),"card_index":card_index})
	selected_entry = entries.size()-1
	cards.select_card(-1)
	cancel_move()
	invalidate()
	changed.emit()
	return _result()

func stage_selected(anchor: Vector3i) -> Node3D:
	var result := stage(cards.cards[cards.selected],anchor,cards.turns,cards.selected)
	return self if result.ok else null

func select_entry(index: int) -> void:
	if not editable(): return
	selected_entry = index if index >= 0 and index < entries.size() else -1
	cards.select_card(-1)
	cancel_move()
	changed.emit()

func begin_move() -> void:
	if not editable() or selected_entry < 0: return
	cards.select_card(-1)
	moving = true
	_edit_cell = TileConstants.INVALID_CELL
	feedback.emit("點新位置移動；Esc 保留原位置")

func cancel_move() -> void:
	moving = false
	if is_instance_valid(edit_preview): edit_preview.hide()

func move_entry(index: int, anchor: Vector3i, turns: int) -> Dictionary:
	if not editable() or index < 0 or index >= entries.size(): return _result("請先選擇預擺地塊")
	var proposed: Array = entries.duplicate(true)
	proposed[index].anchor = anchor
	proposed[index].turns = posmod(turns,4)
	var plan: Dictionary = towers.construction_plan(proposed,false)
	if not plan.ok: return _result(plan.error)
	entries.assign(proposed)
	cancel_move()
	invalidate()
	changed.emit()
	return _result()

func rotate_entry(index: int) -> Dictionary:
	if index < 0 or index >= entries.size(): return _result("請先選擇預擺地塊")
	var entry: Dictionary = entries[index]
	for step in range(1,5):
		var next: int = posmod(entry.turns+step,4)
		if entry.card.allows_rotation(next): return move_entry(index,entry.anchor,next)
	return _result("地塊沒有可用旋轉方向")

func remove_entry(index: int) -> bool:
	if not editable() or index < 0 or index >= entries.size(): return false
	entries.remove_at(index)
	selected_entry = mini(selected_entry,entries.size()-1)
	cancel_move()
	invalidate()
	changed.emit()
	_result()
	return true

func reorder_entry(from: int, to: int) -> bool:
	if not editable() or from < 0 or from >= entries.size() or to < 0 or to >= entries.size(): return false
	var entry: Dictionary = entries[from]
	entries.remove_at(from)
	entries.insert(to,entry)
	selected_entry = to
	cancel_move()
	invalidate()
	changed.emit()
	return true

func cancel_all() -> void:
	if not editable(): return
	entries.clear()
	selected_entry = -1
	cancel_move()
	invalidate()
	changed.emit()

func validate() -> Dictionary:
	for entry in entries:
		if entry.card_index < 0 or entry.card_index >= cards.cards.size() or cards.cards[entry.card_index] != entry.card:
			return {"ok":false,"error":"預擺卡牌庫存已變更"}
	var plan: Dictionary = towers.construction_plan(entries,true)
	if not plan.ok: return plan
	var schedule := Schedule.build(towers,plan,session.get_node("EnemyWave"))
	if not schedule.ok: return schedule
	plan.pending = schedule.pending
	return plan

func commit() -> Dictionary:
	if not editable(): return _result("目前不能確認建造")
	var plan := validate()
	if not plan.ok: return _result(plan.error)
	if entries.is_empty(): return _result()
	_busy = true
	var built: Array = towers.commit_construction(entries)
	if built.size() != entries.size():
		_busy = false
		return _result(towers.last_error if not towers.last_error.is_empty() else "建造確認失敗")
	var indices: Array[int] = []
	for entry in entries: indices.append(entry.card_index)
	indices.sort()
	indices.reverse()
	cards.select_card(-1)
	for index in indices:
		cards.cards.remove_at(index)
		cards.hand.remove_card(index)
	entries.clear()
	selected_entry = -1
	cancel_move()
	_busy = false
	cards.cards_changed.emit()
	invalidate()
	changed.emit()
	_result()
	feedback.emit("已確認 %d 塊地塊" % built.size())
	return {"ok":true,"error":"","towers":built}

func _refresh_reservations() -> void:
	if not is_instance_valid(cards): return
	for index in cards.hand.views.size():
		var reserved := is_reserved(index)
		cards.hand.views[index].disabled = reserved
		cards.hand.views[index].modulate = Color(0.72,0.72,0.72,0.65) if reserved else Color.WHITE

func _process(_delta: float) -> void:
	if _dirty and not towers.controller.computing and not _busy:
		_dirty = false
		_rebuild()
	var show_drafts: bool = not get_tree().paused and not cards.pause_locked and not cards._wave_active and not cards._wave_start_pending
	for ghost in _ghosts: ghost.visible = show_drafts
	if not editable(): cancel_move()
	if not moving: return
	if get_viewport().gui_get_hovered_control() != null:
		edit_preview.hide()
		return
	var cell: Vector3i = cards.placement.pick_cell(get_viewport().get_mouse_position())
	if cell == _edit_cell:
		edit_preview.show()
		return
	_edit_cell = cell
	var proposed: Array = entries.duplicate(true)
	proposed[selected_entry].anchor = cell
	var plan: Dictionary = towers.construction_plan(proposed,false)
	var entry := entries[selected_entry]
	edit_preview.geometry_cells = null
	var geometry := session.get_node_or_null("GeometryBonuses")
	var bonus := {}
	if geometry != null and plan.ok:
		proposed.remove_at(selected_entry)
		bonus = geometry.preview(entry.card,cell,entry.turns,proposed)
		edit_preview.geometry_cells = bonus.get("cells",null)
	edit_preview.show_at(towers.map,entry.card,cell,entry.turns,plan.ok)
	feedback.emit(plan.error if not plan.ok else "點一下移到此處；Esc 取消移動\n"+"\n".join(bonus.get("messages",[])))

func _rebuild() -> void:
	for ghost in _ghosts: ghost.free()
	_ghosts.clear()
	for index in entries.size():
		var entry := entries[index]
		var ghost: Node3D = Preview.instantiate()
		ghost.valid_color = Color(0.72,0.58,0.27,0.48)
		ghost.range_fill_color = Color(0,0,0,0)
		ghost.range_border_color = Color(0,0,0,0)
		add_child(ghost)
		ghost.relics = towers.relics
		var target: DefenseTower = towers.upgrade_target(entry.anchor, entry.card)
		if target != null: ghost.show_upgrade(towers.map,target,"")
		else: ghost.show_at(towers.map,entry.card,entry.anchor,entry.turns,true)
		ghost.upgrade_label.text = "#%d · 待確認%s" % [index+1," 升級" if target != null else ""]
		ghost.upgrade_label.global_position = ghost.hint_anchor+Vector3.UP*0.15
		ghost.upgrade_label.modulate = Color("49675a")
		ghost.upgrade_label.outline_modulate = Color("f2eee3")
		ghost.upgrade_label.font_size = 30
		ghost.upgrade_label.show()
		_ghosts.append(ghost)
	var plan := validate()
	pending_forecast = plan.get("pending",[])
	var flow := session.get_node_or_null("WaveFlowPreview")
	if flow != null: flow.set_construction_pending(null if entries.is_empty() else pending_forecast,plan.get("snapshot",{}) if not entries.is_empty() else {})
	status = ("預擺 %d 塊 · 可確認／開波\n流量為預擺預測" % entries.size()) if plan.ok and not entries.is_empty() else ("選牌放置；可直接開波" if entries.is_empty() else str(plan.error))
	changed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not editable() or cards.selected >= 0 or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if key == KEY_ESCAPE and moving: cancel_move()
	elif key == KEY_R and selected_entry >= 0: rotate_entry(selected_entry)
	elif key in [KEY_DELETE,KEY_BACKSPACE] and selected_entry >= 0: remove_entry(selected_entry)
	else: return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not editable() or cards.selected >= 0 or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var cell: Vector3i = cards.placement.pick_cell(event.position)
	if moving:
		move_entry(selected_entry,cell,entries[selected_entry].turns)
		get_viewport().set_input_as_handled()
		return
	var at := Vector2i(cell.x,cell.z)
	for index in range(entries.size()-1,-1,-1):
		var entry := entries[index]
		if at in entry.card.ground_cells(Vector2i(entry.anchor.x,entry.anchor.z),entry.turns):
			select_entry(index)
			get_viewport().set_input_as_handled()
			return

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel_move()
