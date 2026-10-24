@tool
extends VBoxContainer
## Scene-authored editor surface. Resource edits participate in Godot Undo/Redo.
const VIEW_PATH := "res://addons/wave_editor/wave_editor.tscn"
const VIEW_CONTROLS := [&"ActPicker", &"AddAct", &"DeleteAct", &"AddWave", &"DeleteWave", &"ExpandAfterAct"]
var editor_plugin: EditorPlugin
var level: LevelDefinition
var selected_act := 0
var selected_wave := 0
var selected_group := 0
var preview_tick := 0
var _refreshing := false
var _refresh_frame := -1
var _saved_signatures := {}
var _pending_level: LevelDefinition
var _watched: Array[Resource] = []
var _profiles: Array[Troop] = []
var _local_undo := UndoRedo.new()
var _rebuilding_view := false

func _ready() -> void:
	if _view_ready():
		_bind_view()
	elif not _ensure_view():
		return
	_refresh()

func _view_ready() -> bool:
	for control in VIEW_CONTROLS:
		if get_node_or_null(NodePath("%"+str(control))) == null: return false
	return true

## Tool scripts reload independently of an existing dock's scene tree. Keep the
## panel itself (and Undo/Redo targets), replacing only a stale authored view.
func _ensure_view() -> bool:
	if _view_ready(): return true
	if _rebuilding_view or not is_inside_tree() or is_queued_for_deletion(): return false
	_rebuilding_view = true
	var source := ResourceLoader.load(VIEW_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if source == null:
		_rebuilding_view = false
		return false
	var fresh := source.instantiate()
	if fresh.get_node_or_null("%ActPicker") == null:
		fresh._local_undo.free()
		fresh.free()
		_rebuilding_view = false
		return false
	for previous in get_children():
		var owned: Array[Node] = []
		_collect_view_owners(previous, self, owned)
		for node in owned: node.owner = null
		remove_child(previous)
		previous.queue_free()
	for child in fresh.get_children():
		var owned: Array[Node] = []
		_collect_view_owners(child, fresh, owned)
		for node in owned: node.owner = null
		fresh.remove_child(child)
		add_child(child)
		for node in owned: node.owner = self
	fresh._local_undo.free()
	fresh.free()
	_refreshing = false
	_refresh_frame = -1
	_bind_view()
	_rebuilding_view = false
	return _view_ready()

func _collect_view_owners(node: Node, view: Node, owned: Array[Node]) -> void:
	if node.owner == view: owned.append(node)
	for child in node.get_children(): _collect_view_owners(child, view, owned)

func _bind_view() -> void:
	%Open.pressed.connect(func(): %OpenDialog.popup_centered_ratio(0.65))
	%OpenDialog.file_selected.connect(_open_path)
	%SaveDialog.file_selected.connect(_save_path)
	%SwitchDialog.confirmed.connect(_confirm_switch)
	%Save.pressed.connect(save_current)
	%ActPicker.item_selected.connect(select_act)
	%WavePicker.item_selected.connect(select_wave)
	%AddAct.pressed.connect(add_act)
	%DeleteAct.pressed.connect(delete_act)
	%AddWave.pressed.connect(add_wave)
	%DeleteWave.pressed.connect(delete_wave)
	%ExpandAfterAct.toggled.connect(func(value: bool):
		if not _refreshing and current_act() != null:
			_change(current_act(), "add_start_after_completion", value, "修改 ACT 結束後新增出生點"))
	%Schedule.group_selected.connect(func(index: int): selected_group = index; _refresh())
	%Schedule.group_moved.connect(_move_group)
	%Add.pressed.connect(add_group)
	%Duplicate.pressed.connect(duplicate_group)
	%Delete.pressed.connect(delete_group)
	%TroopPicker.item_selected.connect(_choose_troop)
	%EntrancePicker.item_selected.connect(func(index: int): edit_group_property("start_index", index))
	for entry in [[%StartTick, "start_tick"], [%Count, "enemy_count"], [%Batch, "batch_size"], [%IntervalTicks, "interval_ticks"]]:
		entry[0].value_changed.connect(_number_changed.bind(entry[1]))
	%Reward.value_changed.connect(func(value: float):
		if not _refreshing and current_wave() != null: _change(current_wave(), "reward", roundi(value), "修改波次獎勵"))
	%Speed.value_changed.connect(func(value: float):
		if not _refreshing and current_wave() != null: _change(current_wave(), "move_speed", value, "修改波次移動速度"))
	%PreviewSlider.value_changed.connect(_seek)
	%PreviewTick.value_changed.connect(_seek)

func current_act() -> ActDefinition:
	return level.acts[selected_act] if level != null and selected_act >= 0 and selected_act < level.acts.size() else null

func current_wave() -> WaveDefinition:
	var act := current_act()
	return act.waves[selected_wave] if act != null and selected_wave >= 0 and selected_wave < act.waves.size() else null

func select_act(index: int) -> void:
	selected_act = index
	selected_wave = 0
	selected_group = 0
	preview_tick = 0
	_refresh()

func select_wave(index: int) -> void:
	selected_wave = index
	selected_group = 0
	preview_tick = 0
	_refresh()

func current_group() -> WaveSpawnGroup:
	var wave := current_wave()
	return wave.groups[selected_group] if wave != null and selected_group >= 0 and selected_group < wave.groups.size() else null

func request_level(value: LevelDefinition) -> void:
	if value == level: return
	if level != null and is_dirty(level):
		_pending_level = value
		%SwitchDialog.popup_centered()
	else:
		edit_level(value)

func edit_level(value: LevelDefinition) -> void:
	level = value
	if level != null: level.repair_missing_defaults()
	selected_act = 0
	selected_wave = 0
	selected_group = 0
	preview_tick = 0
	if level != null and not _saved_signatures.has(level): _saved_signatures[level] = _signature(level)
	_refresh()

func _open_path(path: String) -> void:
	var resource := load(path)
	if resource is LevelDefinition:
		request_level(resource)
	else:
		%Status.text = "請選擇 LevelDefinition 關卡資源。"

func _confirm_switch() -> void:
	if level == null: return
	if level.resource_path.is_empty() or "::" in level.resource_path:
		%SaveDialog.popup_centered_ratio(0.65)
	elif _save_document(level, level.resource_path) == OK:
		edit_level(_pending_level)
		_pending_level = null

func _number_changed(value: float, property: String) -> void:
	edit_group_property(property, roundi(value))

func edit_group_property(property: String, value: Variant) -> void:
	if _refreshing or current_group() == null: return
	_change(current_group(), property, value, "修改出生群組")

func _choose_troop(index: int) -> void:
	if _refreshing or index < 0 or index >= _profiles.size(): return
	if current_group() != null and current_group().troop == _profiles[index]: return
	edit_group_property("troop", _profiles[index])

func _move_group(index: int, tick: int) -> void:
	var wave := current_wave()
	if wave == null or index < 0 or index >= wave.groups.size(): return
	selected_group = index
	_change(wave.groups[index], "start_tick", tick, "移動出生群組")

func _new_wave() -> WaveDefinition:
	var group := WaveSpawnGroup.new()
	group.troop = TroopCatalog.default_troop()
	var wave := WaveDefinition.new()
	wave.groups = [group]
	return wave

func add_act() -> void:
	if level == null: return
	var act := ActDefinition.new()
	var number := level.acts.size()+1
	while level.acts.any(func(existing): return existing != null and existing.title == "ACT %d" % number): number += 1
	act.title = "ACT %d" % number
	act.waves = [_new_wave()]
	var next := level.acts.duplicate()
	next.append(act)
	_change(level, "acts", next, "新增 ACT", Vector3i(next.size()-1,0,0))

func delete_act() -> void:
	if level == null or level.acts.is_empty(): return
	var next := level.acts.duplicate()
	next.remove_at(selected_act)
	_change(level, "acts", next, "刪除 ACT", Vector3i(maxi(0,selected_act-1),0,0))

func add_wave() -> void:
	var act := current_act()
	if act == null: return
	var next := act.waves.duplicate()
	var index := mini(selected_wave+1,next.size())
	next.insert(index,_new_wave())
	_change(act, "waves", next, "新增波次", Vector3i(selected_act,index,0))

func delete_wave() -> void:
	var act := current_act()
	if act == null or act.waves.is_empty(): return
	var next := act.waves.duplicate()
	next.remove_at(selected_wave)
	_change(act, "waves", next, "刪除波次", Vector3i(selected_act,maxi(0,selected_wave-1),0))

func add_group() -> void:
	var wave := current_wave()
	if wave == null: return
	var group := WaveSpawnGroup.new()
	group.troop = wave.groups[0].troop if not wave.groups.is_empty() and wave.groups[0] != null else TroopCatalog.default_troop()
	group.start_tick = preview_tick
	var next := wave.groups.duplicate()
	next.append(group)
	_change(wave, "groups", next, "新增出生群組", Vector3i(selected_act,selected_wave,next.size()-1))

func duplicate_group() -> void:
	var wave := current_wave()
	var group := current_group()
	if group == null: return
	var next := wave.groups.duplicate()
	next.insert(selected_group+1, group.duplicate(false))
	_change(wave, "groups", next, "複製出生群組", Vector3i(selected_act,selected_wave,selected_group+1))

func delete_group() -> void:
	var wave := current_wave()
	if current_group() == null or wave.groups.size() < 2: return
	var next := wave.groups.duplicate()
	next.remove_at(selected_group)
	_change(wave, "groups", next, "刪除出生群組", Vector3i(selected_act,selected_wave,maxi(0,selected_group-1)))

func _change(resource: Resource, property: String, value: Variant, title: String, selection := Vector3i(-1,-1,-1)) -> void:
	if resource.get(property) == value: return
	var previous := Vector3i(selected_act,selected_wave,selected_group)
	if selection == Vector3i(-1,-1,-1): selection = previous
	if editor_plugin != null:
		var undo := editor_plugin.get_undo_redo()
		undo.create_action(title, UndoRedo.MERGE_DISABLE, level)
		undo.add_do_method(self, "_apply_value", level, resource, property, value, selection)
		undo.add_undo_method(self, "_apply_value", level, resource, property, resource.get(property), previous)
		undo.commit_action()
	else:
		_local_undo.create_action(title)
		_local_undo.add_do_method(_apply_value.bind(level, resource, property, value, selection))
		_local_undo.add_undo_method(_apply_value.bind(level, resource, property, resource.get(property), previous))
		_local_undo.commit_action()

func _apply_value(document: LevelDefinition, resource: Resource, property: String, value: Variant, selection: Vector3i) -> void:
	if document == level:
		selected_act = selection.x
		selected_wave = selection.y
		selected_group = selection.z
		if property in ["acts","waves"]: preview_tick = 0
	resource.set(property, value)
	resource.emit_changed()
	document.emit_changed()
	_refresh()

func _seek(value: float) -> void:
	if _refreshing: return
	preview_tick = roundi(value)
	_refresh_preview()

func _refresh_preview() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _rebuilding_view: return
	var wave := current_wave()
	var maximum := maxi(120, wave.last_spawn_tick()) if wave != null else 120
	preview_tick = clampi(preview_tick, 0, maximum)
	%PreviewSlider.max_value = maximum
	%PreviewTick.max_value = maximum
	%PreviewSlider.set_value_no_signal(preview_tick)
	%PreviewTick.set_value_no_signal(preview_tick)
	%PreviewLabel.text = "%d 格 = %.2f 秒" % [preview_tick, preview_tick*WaveSpawnGroup.TICK_SECONDS]
	var counts := {}
	if wave != null:
		for group in wave.groups:
			if group == null: continue
			var name := group.troop.troop_name if group.troop != null else "未設定"
			counts[name] = int(counts.get(name, 0))+group.count_at(preview_tick)
	var parts := PackedStringArray()
	for name in counts: parts.append("%s %d 隻" % [name, counts[name]])
	%PreviewCounts.text = "預覽已出生："+" · ".join(parts)
	%Schedule.configure(wave, selected_group, preview_tick)

func _refresh() -> void:
	if not is_inside_tree() or not is_node_ready() or is_queued_for_deletion(): return
	if not _ensure_view(): return
	var frame := Engine.get_process_frames()
	# A script error/hot reload may have interrupted the previous refresh.
	# Guard recursion within this frame without permanently freezing the panel.
	if _refreshing and _refresh_frame == frame: return
	_refresh_frame = frame
	_refreshing = true
	%ActPicker.clear()
	%WavePicker.clear()
	if level != null:
		level.repair_missing_defaults()
		for i in level.acts.size():
			var entry := level.acts[i]
			%ActPicker.add_item(entry.title if entry != null else "ACT %d（未設定）" % (i+1))
	selected_act = clampi(selected_act, 0, maxi(0, level.acts.size()-1)) if level != null else 0
	var act := current_act()
	if level != null and not level.acts.is_empty(): %ActPicker.select(selected_act)
	if act != null:
		for i in act.waves.size(): %WavePicker.add_item("第 %d 波%s" % [i+1,"（未設定）" if act.waves[i] == null else ""])
	selected_wave = clampi(selected_wave, 0, maxi(0, act.waves.size()-1)) if act != null else 0
	if act != null and not act.waves.is_empty(): %WavePicker.select(selected_wave)
	%ActPicker.disabled = level == null or level.acts.is_empty()
	%AddAct.disabled = level == null
	%DeleteAct.disabled = level == null or level.acts.is_empty()
	%WavePicker.disabled = act == null or act.waves.is_empty()
	%AddWave.disabled = act == null
	%DeleteWave.disabled = act == null or act.waves.is_empty()
	%ExpandAfterAct.disabled = act == null
	%ExpandAfterAct.set_pressed_no_signal(act.add_start_after_completion if act != null else true)
	var wave := current_wave()
	selected_group = clampi(selected_group, 0, maxi(0, wave.groups.size()-1)) if wave != null else 0
	var group := current_group()
	%LevelPath.text = ("＊ " if level != null and is_dirty(level) else "")+(level.resource_path if level != null else "請開啟關卡資源")
	%LevelPath.tooltip_text = %LevelPath.text
	%Add.disabled = wave == null
	%Duplicate.disabled = group == null
	%Delete.disabled = wave == null or wave.groups.size() < 2 or group == null
	%Reward.editable = wave != null
	%Speed.editable = wave != null
	if wave != null:
		%Reward.value = wave.reward
		%Speed.value = wave.move_speed
		%Summary.text = "%d 個群組 · 共 %d 隻 · 最後出生 %d 格（%.2f 秒）" % [wave.groups.size(), wave.total_count(), wave.last_spawn_tick(), wave.last_spawn_tick()*0.25]
	else:
		%Summary.text = "請選擇有波次的關卡。"
	%GroupTitle.text = "群組 %d" % (selected_group+1) if group != null else "尚無出生群組"
	for input in [%StartTick, %Count, %Batch, %IntervalTicks]: input.editable = group != null
	%TroopPicker.disabled = group == null
	%EntrancePicker.disabled = group == null
	_profiles = TroopCatalog.all()
	%TroopPicker.clear()
	%TroopPicker.add_theme_constant_override("icon_max_width", 24)
	for profile in _profiles:
		%TroopPicker.add_icon_item(profile.icon, profile.localized_name())
		%TroopPicker.set_item_tooltip(%TroopPicker.item_count-1, profile.resource_path)
	%EntrancePicker.clear()
	if level != null:
		var layout := level.endpoint_layout()
		for i in layout.start_cells.size(): %EntrancePicker.add_item("入口 %d · %s" % [i+1, layout.start_cells[i]])
	if group != null:
		var profile_index := -1
		for i in _profiles.size():
			if group.troop == _profiles[i]: profile_index = i
		if profile_index < 0:
			_profiles.append(group.troop)
			%TroopPicker.add_item(group.troop.localized_name() if group.troop != null else "未設定／檔案已移除")
			profile_index = _profiles.size()-1
		%TroopPicker.select(profile_index)
		%StartTick.value = group.start_tick
		%Count.value = group.enemy_count
		%Batch.value = group.batch_size
		%IntervalTicks.value = group.interval_ticks
		if group.start_index < %EntrancePicker.item_count: %EntrancePicker.select(group.start_index)
		%StartSeconds.text = "%.2f 秒" % (group.start_tick*0.25)
		%IntervalSeconds.text = "%.2f 秒" % (group.interval_ticks*0.25)
		%RangeLabel.text = "出生區間：%.2f–%.2f 秒 · %s" % [group.start_tick*0.25, group.end_tick()*0.25, "Uniform" if group.troop != null and group.troop.route_selection == Troop.RouteSelection.UNIFORM else "Softmax"]
	var error := level.configuration_error() if level != null else ""
	%Save.disabled = level == null or not error.is_empty()
	%Status.text = error if not error.is_empty() else "1 格 = 0.25 秒；間隔 0 為同時出生。所有群組出生並清場後結束本波。"
	_refreshing = false
	_refresh_preview()
	_watch_resources()

func _watch_resources() -> void:
	for resource in _watched:
		if resource.changed.is_connected(_refresh): resource.changed.disconnect(_refresh)
	_watched.clear()
	if level == null: return
	_watch(level)
	if level.terrain != null: _watch(level.terrain)
	for act in level.acts:
		if act == null: continue
		_watch(act)
		for wave in act.waves:
			if wave == null: continue
			_watch(wave)
			for group in wave.groups:
				if group != null:
					_watch(group)
					if group.troop != null: _watch(group.troop)

func _watch(resource: Resource) -> void:
	if resource in _watched: return
	_watched.append(resource)
	resource.changed.connect(_refresh)

func _signature(document: LevelDefinition) -> String:
	var data := [document.level_id, document.required_to_complete_levels, document.terrain.resource_path if document.terrain != null else ""]
	for act in document.acts:
		if act == null: data.append(null); continue
		data.append([act.title, act.add_start_after_completion, act.waves.size()])
		for wave in act.waves:
			if wave == null: data.append(null); continue
			data.append([wave.reward, wave.move_speed, wave.groups.size()])
			for group in wave.groups:
				if group == null: data.append(null); continue
				data.append([_profile_signature(group.troop), group.start_tick, group.enemy_count, group.batch_size, group.interval_ticks, group.start_index])
	return var_to_str(data)

func _profile_signature(profile: Troop) -> Array:
	if profile == null: return []
	var result := [profile.get_script().resource_path, profile.resource_path]
	for property in profile.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
			result.append([property.name, str(profile.get(property.name))])
	return result

func is_dirty(document: LevelDefinition) -> bool:
	return _saved_signatures.get(document, "") != _signature(document)

func has_unsaved_changes() -> bool:
	for document: LevelDefinition in _saved_signatures:
		if is_dirty(document): return true
	return false

func unsaved_names() -> String:
	var names := PackedStringArray()
	for document: LevelDefinition in _saved_signatures:
		if is_dirty(document): names.append(document.resource_path.get_file())
	return "波次編輯器："+", ".join(names) if not names.is_empty() else ""

func save_current() -> void:
	if level == null: return
	if level.resource_path.is_empty() or "::" in level.resource_path:
		%SaveDialog.popup_centered_ratio(0.65)
	else:
		_save_document(level, level.resource_path)

func _save_path(path: String) -> void:
	if level != null and _save_document(level, path) == OK and _pending_level != null:
		edit_level(_pending_level)
		_pending_level = null

func _save_document(document: LevelDefinition, path: String) -> Error:
	document.repair_missing_defaults()
	var error := document.configuration_error()
	if not error.is_empty():
		%Status.text = error
		return ERR_INVALID_DATA
	var result := ResourceSaver.save(document, path, ResourceSaver.FLAG_CHANGE_PATH)
	if result == OK:
		_saved_signatures[document] = _signature(document)
		if editor_plugin != null: editor_plugin.get_editor_interface().get_resource_filesystem().update_file(path)
		_refresh()
		%Status.text = "已儲存："+path
	else:
		%Status.text = "儲存失敗："+error_string(result)
	return result

func save_all() -> void:
	for document: LevelDefinition in _saved_signatures:
		if is_dirty(document) and not document.resource_path.is_empty() and not "::" in document.resource_path:
			_save_document(document, document.resource_path)

func resource_saved(resource: Resource) -> void:
	if resource is LevelDefinition and _saved_signatures.has(resource):
		_saved_signatures[resource] = _signature(resource)
		_refresh()
	elif resource is Troop:
		_refresh()

func _exit_tree() -> void:
	for resource in _watched:
		if resource.changed.is_connected(_refresh): resource.changed.disconnect(_refresh)
	_local_undo.clear_history()
	_local_undo.free()
