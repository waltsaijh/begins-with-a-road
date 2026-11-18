extends CanvasLayer
const Picker = preload("res://scripts/levels/presentation/unit_pick.gd")
var manager: SpecialEventManager
var buttons: Array[Button] = []
var details: Array[Label] = []
var titles: Array[Label] = []
var reasons: Array[Label] = []
var targeting := ""
var markers: Array[Node3D] = []
var hovered: DefenseTower
var _locale := ""
@onready var root: Control = $Root
@onready var column: VBoxContainer = $Root/Center/Panel/Margin/Column

func setup(owner_manager: SpecialEventManager) -> void:
	manager = owner_manager
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("f6f8f2")
	panel_style.border_color = Color("b2c5bd")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	$Root/Center/Panel.add_theme_stylebox_override("panel",panel_style)
	for i in 2:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(330,235)
		button.add_to_group("audio_card_hover")
		var style := StyleBoxFlat.new()
		style.bg_color = Color("edf2ec")
		style.border_color = Color("86a5a0")
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override("normal",style)
		var hover := style.duplicate()
		hover.bg_color = Color("dcebe2")
		hover.set_border_width_all(2)
		button.add_theme_stylebox_override("hover",hover)
		button.add_theme_stylebox_override("focus",hover)
		var pressed := hover.duplicate()
		pressed.bg_color = Color("bfd9cc")
		button.add_theme_stylebox_override("pressed",pressed)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left",18)
		margin.add_theme_constant_override("margin_right",18)
		margin.add_theme_constant_override("margin_top",16)
		margin.add_theme_constant_override("margin_bottom",16)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		var text := VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_constant_override("separation",14)
		margin.add_child(text)
		var title := Label.new()
		title.name = "Title"
		title.add_theme_font_size_override("font_size",20)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(title)
		titles.append(title)
		var detail := Label.new()
		detail.add_theme_font_size_override("font_size",16)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text.add_child(detail)
		var reason := Label.new()
		reason.add_theme_font_size_override("font_size",14)
		reason.add_theme_color_override("font_color",Color("a04f44"))
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(reason)
		column.get_node("Options").add_child(button)
		button.pressed.connect(func():
			for other in buttons: other.disabled = true
			manager.choose(i))
		buttons.append(button); details.append(detail); reasons.append(reason)
	get_viewport().size_changed.connect(_layout)
	dismiss()

func _layout() -> void:
	var width := minf(820,get_viewport().get_visible_rect().size.x-32)
	$Root/Center/Panel.custom_minimum_size.x = width
	for button in buttons: button.custom_minimum_size.x = maxf(160,(width-72)/2.0)

func present() -> void:
	targeting = ""
	_clear_markers()
	_locale = TranslationServer.get_locale()
	root.show()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	$Root/Shade.show(); $Root/Center.show(); $Root/TargetHint.hide()
	column.get_node("Heading").text = tr("event.ui.heading")
	column.get_node("Title").text = manager.active.text("title")
	column.get_node("Description").text = manager.active.text("description")
	for i in 2:
		var suffix := "a" if i == 0 else "b"
		titles[i].text = manager.active.text(suffix+".name")
		details[i].text = manager.active.text(suffix+".effect")
		reasons[i].text = manager.option_error(manager.active,i)
		buttons[i].disabled = not reasons[i].text.is_empty()
		buttons[i].modulate.a = 0.5 if buttons[i].disabled else 1.0
	_layout()

func select_target(mode: String) -> void:
	targeting = mode
	$Root/Shade.hide(); $Root/Center.hide(); $Root/TargetHint.show()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root/TargetHint.text = tr("event.ui.target")
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
	root.hide()

func _process(_delta: float) -> void:
	for marker in markers:
		if is_instance_valid(marker): marker.visible = not get_tree().paused
	if manager == null or manager.active == null: return
	root.visible = not get_tree().paused
	if get_tree().paused: return
	if _locale != TranslationServer.get_locale():
		_locale = TranslationServer.get_locale()
		if targeting.is_empty(): present()
	if targeting.is_empty(): return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	hovered = Picker.pick(camera,get_viewport().get_mouse_position(),manager.towers,manager.session._wave.visuals) as DefenseTower
	var text := tr("event.ui.target")
	if is_instance_valid(hovered): text += "\n%s · Lv.%d" % [hovered.definition.localized_name(),hovered.level]
	$Root/TargetHint.text = text

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
