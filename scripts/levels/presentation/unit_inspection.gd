extends Node3D
## One live selection. Input reaches here only after camera gesture and GUI routing.
const Picker = preload("res://scripts/levels/presentation/unit_pick.gd")
const Data = preload("res://scripts/levels/presentation/unit_inspection_data.gd")
var session: Node3D
var target: Node3D
var _signature: Array = []
var _motion: Tween
var updates := 0
var _layout_signature: Array = []
@onready var panel: Control = $Canvas/Root/Panel
@onready var column: VBoxContainer = $Canvas/Root/Panel/Margin/Column
@onready var range_view: MeshInstance3D = $Range

func setup(host: Node3D) -> void:
	session = host
	process_mode = Node.PROCESS_MODE_ALWAYS
	session.run_finished.connect(func(_won): cancel_selection())
	_layout()
	get_viewport().size_changed.connect(_layout)
	panel.hide()

func has_selection() -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion()

func _blocked() -> bool:
	if not is_instance_valid(session) or session.finished or session._loading or session.choosing_start or session.choosing_relic or ScreenTransition.active: return true
	var cards: Node = session.get_node("CardPlacement")
	if cards.selected >= 0 or cards.hand.is_dragging() or cards._shop_open or cards.entry_selection_active: return true
	if is_instance_valid(session.tutorial) and session.tutorial.stage < session.tutorial.Stage.PRACTICE: return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _blocked(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.button_mask & (MOUSE_BUTTON_MASK_RIGHT|MOUSE_BUTTON_MASK_MIDDLE): return
		var camera := get_viewport().get_camera_3d()
		if camera == null: return
		select_unit(Picker.pick(camera,event.position,session.get_node("TowerMap"),session.get_node("EnemyWave").visuals))
		get_viewport().set_input_as_handled()

func select_unit(unit: Node3D) -> void:
	if unit == target and has_selection(): return
	cancel_selection(false)
	if not is_instance_valid(unit) or unit.is_queued_for_deletion(): return
	target = unit
	target.tree_exiting.connect(_target_exited,CONNECT_ONE_SHOT)
	target.died.connect(_target_exited)
	if target.has_signal("arrived"): target.arrived.connect(_target_exited)
	_signature.clear()
	_refresh()
	_layout()
	panel.modulate.a = 0.0
	panel.show()
	if _motion: _motion.kill()
	_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_motion.tween_property(panel,"modulate:a",1.0,0.18).set_trans(Tween.TRANS_SINE)

func _target_exited(_unit: Node3D = null) -> void:
	cancel_selection()

func cancel_selection(animate := true) -> void:
	if is_instance_valid(target):
		if target.tree_exiting.is_connected(_target_exited): target.tree_exiting.disconnect(_target_exited)
		if target.died.is_connected(_target_exited): target.died.disconnect(_target_exited)
		if target.has_signal("arrived") and target.arrived.is_connected(_target_exited): target.arrived.disconnect(_target_exited)
	target = null
	_signature.clear()
	range_view.clear()
	if _motion: _motion.kill()
	if not animate or not is_inside_tree():
		panel.hide()
		return
	_motion = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_motion.tween_property(panel,"modulate:a",0.0,0.18)
	_motion.tween_callback(panel.hide)

func _refresh() -> void:
	var signature: Array = [TranslationServer.get_locale(),target.health,target.max_health]
	if target is DefenseTower:
		signature.append_array([target.level,target.damage,target.attack_interval,target.attack_radius,target.range_multiplier,target.support_bonus,target.geometry_damage_bonus,target.relic_effects.hash(),target.is_disabled(),target.attack,target.attack.damage_multiplier if target.attack != null else 0.0,target.deployment.damage if target.deployment != null else 0.0,target.deployment.health if target.deployment != null else 0.0,target.deployment.interval if target.deployment != null else 0.0,target.deployment.count if target.deployment != null else 0])
	else: signature.append_array([target.shield,target.max_shield,target.abilities.hash()])
	if signature == _signature: return
	_signature = signature
	updates += 1
	var data: Dictionary = Data.tower(target,session.get_node("TowerMap").relics.catalog) if target is DefenseTower else Data.enemy(target)
	column.get_node("Heading/Name").text = data.name
	column.get_node("Heading/Kind").text = data.kind
	column.get_node("Heading/Kind").visible = not data.kind.is_empty()
	var icon: TextureRect = column.get_node("Heading/Icon")
	icon.texture = data.icon
	icon.modulate = data.color
	var labels := [column.get_node("Stats/First"),column.get_node("Stats/Second"),column.get_node("Stats/Third")]
	for i in labels.size():
		labels[i].visible = i < data.stats.size()
		if labels[i].visible: labels[i].text = data.stats[i]
	var bar: ProgressBar = column.get_node("Health")
	bar.visible = data.health >= 0
	bar.value = maxf(0,data.health)
	var notes: Label = column.get_node("Notes")
	notes.text = data.notes
	notes.visible = not notes.text.is_empty()
	_layout.call_deferred()

func _process(_delta: float) -> void:
	if not is_instance_valid(session): return
	if not has_selection():
		if target != null: cancel_selection()
		return
	if _blocked():
		cancel_selection()
		return
	if target.health <= 0:
		cancel_selection()
		return
	panel.visible = not get_tree().paused
	range_view.visible = not get_tree().paused
	if get_tree().paused: return
	_refresh()
	_layout()
	var map: GridMap = session.get_node("TowerMap").map
	if target is DefenseTower: range_view.update_tower(target,map)
	else: range_view.update_enemy(session.get_node("EnemyWave").visuals.death_position(target),map)

func _layout() -> void:
	if not is_node_ready(): return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(540,viewport_size.x-32)
	var cards: Node = session.get_node("CardPlacement") if is_instance_valid(session) else null
	var hand_visible: bool = cards != null and not cards.hand.stowed and not cards.cards.is_empty()
	var left := (viewport_size.x-width)*0.5
	var bottom := viewport_size.y-20.0
	if hand_visible:
		var hand_right := 0.0
		var hand_top := viewport_size.y
		for view: Control in cards.hand.views:
			var artwork: Control = view.get_node("Visuals")
			var transform := artwork.get_global_transform_with_canvas()
			for point in [Vector2.ZERO,Vector2(artwork.size.x,0),artwork.size,Vector2(0,artwork.size.y)]:
				var at: Vector2 = transform*point
				hand_right = maxf(hand_right,at.x)
				hand_top = minf(hand_top,at.y)
		var right_limit: float = viewport_size.x-(180 if cards.get_node("Shop").available else 16)
		if hand_right+12+width <= right_limit: left = maxf(left,hand_right+12)
		else: bottom = minf(bottom,hand_top-12)
	var minimum_height := panel.get_combined_minimum_size().y
	var signature: Array = [viewport_size,left,bottom,minimum_height]
	if signature == _layout_signature: return
	_layout_signature = signature
	panel.size.x = width
	panel.size.y = minimum_height
	panel.position = Vector2(left,bottom-panel.size.y)

func _exit_tree() -> void:
	cancel_selection(false)
