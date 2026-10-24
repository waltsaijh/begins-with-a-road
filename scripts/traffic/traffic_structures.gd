class_name TrafficStructures
extends Node3D
## Owns overlays and their lifetime. Never edits GridMap or navigation obstacles.
signal changed
var instances: Array[TrafficStructure] = []
var occupied := {}
var revision := 0
var tower_map: Node3D
var _participants: Array[TrafficStructure] = []
var _wave_running := false
var _hover_label: Label3D

func _ready() -> void:
	var wave := tower_map.get_node_or_null("../EnemyWave")
	if wave != null:
		wave.wave_started.connect(begin_wave)
		wave.wave_finished.connect(finish_wave)
	_hover_label = Label3D.new()
	_hover_label.font = preload("res://assets/fonts/NotoSansTC-Light.ttf")
	_hover_label.font_size = 32
	_hover_label.pixel_size = 0.01
	_hover_label.outline_size = 4
	_hover_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hover_label.no_depth_test = true
	_hover_label.modulate = Color("f4e8cc")
	_hover_label.outline_modulate = Color("484334")
	_hover_label.hide()
	add_child(_hover_label)

func effects() -> Array:
	var result: Array = []
	for instance in instances:
		if is_instance_valid(instance) and instance.remaining_waves > 0: result.append(instance.effect.duplicate(true))
	return result

func validate(definition: TrafficStructureDefinition, at: Vector2i, turns: int) -> String:
	if definition == null: return "缺少輔助建築"
	var error := definition.configuration_error()
	if not error.is_empty(): return error
	var wave := tower_map.get_node_or_null("../EnemyWave")
	var cards := tower_map.get_node_or_null("../CardPlacement")
	if (wave != null and wave.active) or (cards != null and cards.input_suspended): return "目前不能建造"
	if tower_map.occupied.has(at) or at in tower_map.controller.terminal_cells(): return "不能覆蓋防禦塔或端點"
	for existing: DefenseTower in tower_map.towers.values():
		if existing.definition.deployment != null and at == existing.grid_cell+BuildCard.rotate_cell(Vector2i(0,-1),existing.rotation_steps): return "不能覆蓋兵營駐點"
	for existing: TrafficStructure in occupied.get(at, []):
		if not definition.can_share(existing.definition): return "此處已有互斥設施"
	var map: GridMap = tower_map.map
	var item := map.get_cell_item(Vector3i(at.x,0,at.y))
	if definition.placement == TrafficStructureDefinition.Placement.ON_ROAD:
		if item <= 0: return "必須放在既有道路"
	else:
		if item != GridMap.INVALID_CELL_ITEM: return "旗幟必須放在道路旁空位"
		var near_road := false
		for cell: Vector2i in definition.effect_at(at,turns).cells:
			if map.get_cell_item(Vector3i(cell.x,0,cell.y)) > 0 and not tower_map.occupied.has(cell): near_road = true
		if not near_road: return "影響範圍內沒有道路"
	return ""

func place(definition: TrafficStructureDefinition, at: Vector2i, turns: int) -> TrafficStructure:
	if not validate(definition,at,turns).is_empty(): return null
	var instance := TrafficStructure.new()
	instance.definition = definition
	instance.grid_cell = at
	instance.rotation_steps = posmod(turns,4)
	add_child(instance)
	var map: GridMap = tower_map.map
	instance.global_transform = map.global_transform*Transform3D(Basis(Vector3.UP,-turns*PI/2),map.map_to_local(Vector3i(at.x,0,at.y))+Vector3.UP*TowerConstants.GROUND_OFFSET)
	instances.append(instance)
	if not occupied.has(at): occupied[at] = []
	occupied[at].append(instance)
	instance.tree_exiting.connect(_remove_index.bind(instance))
	_publish()
	return instance

func remove(instance: TrafficStructure) -> bool:
	if not instances.has(instance): return false
	_remove_index(instance)
	instance.queue_free()
	return true

func _remove_index(instance: TrafficStructure) -> void:
	if not instances.has(instance): return
	instances.erase(instance)
	_participants.erase(instance)
	var at := instance.grid_cell
	if occupied.has(at):
		occupied[at].erase(instance)
		if occupied[at].is_empty(): occupied.erase(at)
	_publish()

func _publish() -> void:
	revision += 1
	if not is_inside_tree() or is_queued_for_deletion() or not tower_map.is_inside_tree() or tower_map.get_parent().is_queued_for_deletion(): return
	if is_instance_valid(tower_map.controller) and tower_map.controller.is_inside_tree(): tower_map.controller.set_traffic_effects(effects())
	changed.emit()

func begin_wave() -> void:
	if _wave_running: return
	_wave_running = true
	_participants.assign(instances)

func finish_wave() -> void:
	if not _wave_running or not is_inside_tree() or tower_map.get_parent().is_queued_for_deletion(): return
	_wave_running = false
	for instance in _participants.duplicate():
		if not is_instance_valid(instance) or not instances.has(instance): continue
		instance.remaining_waves -= 1
		if instance.remaining_waves <= 0: remove(instance)
	_participants.clear()

func _process(_delta: float) -> void:
	_hover_label.hide()
	if not is_instance_valid(tower_map.placement) or get_viewport().gui_get_hovered_control() != null: return
	var cards := tower_map.get_node_or_null("../CardPlacement")
	if cards != null and (cards.selected >= 0 or cards.input_suspended): return
	var cell: Vector3i = tower_map.placement.pick_cell(get_viewport().get_mouse_position())
	var at := Vector2i(cell.x,cell.z)
	if not occupied.has(at): return
	var instance: TrafficStructure = occupied[at][0]
	_hover_label.text = tr("traffic.remaining").format({"name": instance.definition.localized_name(), "waves": instance.remaining_waves})
	_hover_label.global_position = instance.global_position+Vector3.UP*1.25
	_hover_label.show()

func _exit_tree() -> void:
	_participants.clear()
	instances.clear()
	occupied.clear()
	if is_instance_valid(tower_map.controller):
		tower_map.controller.traffic_effects.clear()
		tower_map.controller.clear_traffic_preview_cache()
