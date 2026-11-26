extends CanvasLayer

const Picker = preload("res://scripts/levels/presentation/unit_pick.gd")
const OptionCard = preload("res://scripts/events/presentation/event_option_card.gd")
const CardScene = preload("res://scenes/events/components/event_option_card.tscn")
const Art = preload("res://scripts/events/presentation/event_option_art.gd")
const OFFER_SUFFIXES := ["a", "b"]
const CARD_WIDTH := 224.0
const MIN_COLUMN_WIDTH := 156.0
const CARD_GAP := 18.0
const WINDOW_PADDING := 60.0
const ENTER_STAGGER := 0.075

var manager: SpecialEventManager
var buttons: Array[OptionCard] = []
var targeting := ""
var markers: Array[Node3D] = []
var hovered: DefenseTower
var _locale := ""
var _transition: Tween
var _selected := -1
var _closing := false

@onready var root: Control = $Root
@onready var shade: ColorRect = $Root/Shade
@onready var center: Control = $Root/Center
@onready var scroll: ScrollContainer = %Scroll
@onready var panel: PanelContainer = %Panel
@onready var target_hint: Label = $Root/TargetHint
@onready var options: HFlowContainer = %Options
@onready var header: VBoxContainer = %Header

func setup(owner_manager: SpecialEventManager) -> void:
	manager = owner_manager
	center.resized.connect(_layout)
	panel.minimum_size_changed.connect(_layout)
	manager.shop.balance_changed.connect(func(_coins: int): _refresh_availability())

func present() -> void:
	_cancel_transition()
	targeting = ""
	_selected = -1
	_clear_markers()
	_locale = TranslationServer.get_locale()
	root.show()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	shade.show()
	center.show()
	target_hint.hide()
	scroll.modulate.a = 1.0
	scroll.scroll_vertical = 0
	# The rule set still offers A and B. Card creation and layout accept any count.
	_set_card_count(OFFER_SUFFIXES.size())
	for button in buttons:
		button.unlock()
	_refresh_text()
	_layout()
	_focus_first_offer()
	_animate_in()

func _set_card_count(count: int) -> void:
	while buttons.size() > count:
		buttons.pop_back().free()
	while buttons.size() < count:
		var card: OptionCard = CardScene.instantiate()
		card.scroll_area = scroll
		card.pressed.connect(_choose.bind(buttons.size()))
		options.add_child(card)
		card.paper.minimum_size_changed.connect(_fit_card_heights)
		buttons.append(card)

func _layout() -> void:
	if not center.visible or buttons.is_empty():
		return
	var available := maxf(1.0, center.size.x - WINDOW_PADDING)
	var columns := clampi(floori((available + CARD_GAP) / (MIN_COLUMN_WIDTH + CARD_GAP)), 1, buttons.size())
	var width := minf(CARD_WIDTH, floorf((available - CARD_GAP * (columns - 1)) / columns))
	for card in buttons:
		card.custom_minimum_size.x = width
		# Keep the art readable when the cards wrap into a narrower column.
		card.illustration.custom_minimum_size.y = minf(108.0, width * 0.63)
	var dialog_width := minf(center.size.x, width * columns + CARD_GAP * (columns - 1) + WINDOW_PADDING)
	scroll.size = Vector2(dialog_width, minf(center.size.y, panel.get_combined_minimum_size().y))
	scroll.position = (center.size - scroll.size).floor() * 0.5
	_fit_card_heights()

func _fit_card_heights() -> void:
	var footer_height := 0.0
	for card in buttons:
		footer_height = maxf(footer_height, card.footer.get_minimum_size().y)
	var height := 0.0
	for card in buttons:
		card.footer.custom_minimum_size.y = footer_height
		height = maxf(height, card.paper.get_combined_minimum_size().y)
	for card in buttons:
		card.custom_minimum_size.y = height

func _refresh_text() -> void:
	var definition := manager.active
	%Heading.text = tr("event.ui.heading")
	%Title.text = definition.text("title")
	%Description.text = definition.text("description")
	for i in OFFER_SUFFIXES.size():
		var suffix: String = OFFER_SUFFIXES[i]
		var summary := _option_summary(definition.effects(i))
		buttons[i].show_option(
			definition.text(suffix + ".name"), definition.text(suffix + ".effect"),
			Art.illustration(definition.id, i), summary.text, summary.color, Art.mat_color(definition.id, i))
	_refresh_availability()

func _refresh_availability() -> void:
	if manager.active == null or not targeting.is_empty() or _selected >= 0:
		return
	var offered: Array[OptionCard] = []
	var previous_focus := get_viewport().gui_get_focus_owner()
	for i in OFFER_SUFFIXES.size():
		var card := buttons[i]
		card.set_availability(manager.option_error(manager.active, i))
		if not card.disabled:
			offered.append(card)
	for i in offered.size():
		var card := offered[i]
		var previous := offered[posmod(i - 1, offered.size())]
		var next := offered[(i + 1) % offered.size()]
		card.focus_neighbor_left = card.get_path_to(previous)
		card.focus_neighbor_right = card.get_path_to(next)
		card.focus_neighbor_top = card.focus_neighbor_left
		card.focus_neighbor_bottom = card.focus_neighbor_right
		card.focus_previous = card.focus_neighbor_left
		card.focus_next = card.focus_neighbor_right
	if previous_focus in buttons and previous_focus not in offered and root.visible:
		_focus_first_offer()

func _option_summary(effects: Array[Dictionary]) -> Dictionary:
	var costs := PackedStringArray()
	var conditions := PackedStringArray()
	var cost := 0
	var reward := 0
	for effect in effects:
		match String(effect.type):
			"spend": cost += int(effect.amount)
			"gold": reward += int(effect.amount)
			"health": costs.append(GameText.text("event.ui.health_cost", {"amount": effect.amount}))
			"remove": conditions.append(tr("event.ui.tower_remove"))
			"ceasefire": conditions.append(tr("event.ui.tower_pause"))
			"downgrade": conditions.append(tr("event.ui.tower_downgrade"))
			"card":
				if effect.id == "rubble":
					conditions.append(tr("event.ui.rubble_risk"))
	var color := OptionCard.RISK if not costs.is_empty() or not conditions.is_empty() else OptionCard.INK
	if cost > 0:
		costs.append(GameText.text("event.ui.gold_cost", {"amount": cost}))
	if reward > 0:
		costs.append(GameText.text("event.ui.gold_reward", {"amount": reward}))
	if cost > 0 or reward > 0:
		color = OptionCard.GOLD
	costs.append_array(conditions)
	if costs.is_empty():
		costs.append(tr("event.ui.free"))
	return {"text": " · ".join(costs), "color": color}

func _focus_first_offer() -> void:
	for card in buttons:
		if not card.disabled:
			card.grab_focus()
			return

func _choose(index: int) -> void:
	if _selected >= 0 or _closing or not targeting.is_empty() or get_tree().paused or buttons[index].disabled:
		return
	_selected = index
	# Commit in the manager immediately. The exit animation never owns gameplay state.
	if not manager.choose(index):
		_selected = -1
		_refresh_availability()

func _animate_in() -> void:
	shade.modulate.a = 0.0
	header.modulate.a = 0.0
	_transition = _new_transition()
	_transition.tween_property(shade, "modulate:a", 1.0, 0.24)
	_transition.tween_property(header, "modulate:a", 1.0, 0.20)
	for i in buttons.size():
		var card := buttons[i]
		var delay := ENTER_STAGGER * i
		card.modulate.a = 0.0
		card.entry_offset = 16.0
		_transition.tween_property(card, "entry_offset", 0.0, 0.25).set_delay(delay)
		_transition.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(delay)

func _close_dialog() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	if _closing:
		return
	if not center.visible or not root.visible:
		_finish_close()
		return
	_cancel_transition()
	_closing = true
	_transition = _new_transition()
	_transition.tween_property(shade, "modulate:a", 0.0, 0.19)
	_transition.tween_property(scroll, "modulate:a", 0.0, 0.19)
	for i in buttons.size():
		var card := buttons[i]
		var selected := i == _selected
		card.lock_for_exit(selected)
		if selected:
			_transition.tween_property(card, "entry_offset", -4.0, 0.17)
			_transition.tween_property(card.visuals, "scale", Vector2.ONE * 1.03, 0.12)
		else:
			_transition.tween_property(card, "modulate:a", 0.0, 0.12)
			_transition.tween_property(card, "entry_offset", 9.0, 0.15)
	_transition.finished.connect(_finish_close)

func _new_transition() -> Tween:
	var tween := create_tween().set_parallel().set_ignore_time_scale(true)
	return tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _cancel_transition() -> void:
	if _transition != null:
		_transition.kill()
		_transition = null
	_closing = false

func _finish_close() -> void:
	_closing = false
	shade.hide()
	center.hide()
	if targeting.is_empty():
		root.hide()

func select_target(mode: String) -> void:
	targeting = mode
	_close_dialog()
	target_hint.show()
	target_hint.text = tr("event.ui.target")
	highlight_towers(mode)

func highlight_towers(mode: String) -> void:
	_clear_markers()
	for tower in manager.eligible_towers(mode):
		var marker := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.55; ring.outer_radius = 0.64
		ring.rings = 12; ring.ring_segments = 24
		marker.mesh = ring
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("71c8a6")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = material
		tower.add_child(marker)
		marker.position.y = 0.1
		markers.append(marker)

func clear_targets() -> void:
	_clear_markers()

func _clear_markers() -> void:
	for marker in markers:
		if is_instance_valid(marker): marker.queue_free()
	markers.clear()

func dismiss() -> void:
	targeting = ""
	_clear_markers()
	target_hint.hide()
	_close_dialog()

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	for marker in markers:
		if is_instance_valid(marker):
			marker.visible = not paused
	if manager == null or (manager.active == null and not _closing):
		return
	var resuming := not root.visible and not paused
	root.visible = not paused
	if paused or manager.active == null:
		return
	if targeting.is_empty():
		if _locale != TranslationServer.get_locale():
			_locale = TranslationServer.get_locale()
			_refresh_text()
		if resuming:
			_focus_first_offer()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	hovered = Picker.pick(camera, get_viewport().get_mouse_position(), manager.towers, manager.session._wave.visuals) as DefenseTower
	var hint := tr("event.ui.target")
	if is_instance_valid(hovered):
		hint += "\n%s · Lv.%d" % [hovered.definition.localized_name(), hovered.level]
	target_hint.text = hint

func _unhandled_input(event: InputEvent) -> void:
	if targeting.is_empty() or get_tree().paused: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.button_mask & (MOUSE_BUTTON_MASK_RIGHT|MOUSE_BUTTON_MASK_MIDDLE): return
		var camera := get_viewport().get_camera_3d()
		if camera == null: return
		var picked := Picker.pick(camera,event.position,manager.towers,manager.session._wave.visuals) as DefenseTower
		manager.select_target(picked)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_clear_markers()
