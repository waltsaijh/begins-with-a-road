extends Control
## Generic presentation: the caller supplies data and applies changes.
signal option_changed(key: StringName, value: Variant)
signal closed
const Row = preload("res://scenes/settings/components/setting_row.tscn")
const TextButton = preload("res://scenes/settings/components/settings_button.tscn")
const FOCUS_DIRECTIONS := {"ui_left": SIDE_LEFT, "ui_up": SIDE_TOP, "ui_right": SIDE_RIGHT, "ui_down": SIDE_BOTTOM}
var sections: Array[Dictionary] = []
var values: Dictionary = {}
var selected_section := 0
@onready var categories: VBoxContainer = $Panel/Margin/Layout/Body/Sections/Items
@onready var rows: VBoxContainer = $Panel/Margin/Layout/Body/Options/Rows
@onready var scroll: ScrollContainer = $Panel/Margin/Layout/Body/Options

func _ready() -> void:
	hide()
	$Panel/Margin/Layout/Header/Back.pressed.connect(close)
	resized.connect(_fit)
	_fit()
	_rebuild()

func configure(definitions: Array[Dictionary], current_values: Dictionary) -> void:
	sections = definitions.duplicate(true)
	values = current_values.duplicate(true)
	selected_section = clampi(selected_section, 0, maxi(0, sections.size()-1))
	if is_node_ready(): _rebuild()

func open() -> void:
	_fit()
	show()
	if categories.get_child_count(): categories.get_child(selected_section).grab_focus()

func close() -> void:
	hide()
	closed.emit()

func _fit() -> void:
	var panel := $Panel as Control
	panel.size = (size*0.9).min(Vector2(1120, 720)).floor()
	panel.position = ((size-panel.size)*0.5).floor()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		# Let GUI focus/navigation reach this page; consume gameplay shortcuts.
		var focus := get_viewport().gui_get_focus_owner()
		if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
			_cycle_focus(event.is_action_pressed("ui_focus_prev"))
			get_viewport().set_input_as_handled()
			return
		if not (event.is_action("ui_focus_next") or event.is_action("ui_focus_prev") or event.is_action("ui_accept") or event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("ui_left") or event.is_action("ui_right")) or focus == null or not is_ancestor_of(focus):
			get_viewport().set_input_as_handled()
		else:
			# Directional navigation may move within the page, never behind it.
			for action in FOCUS_DIRECTIONS:
				if event.is_action_pressed(action):
					var target := focus.find_valid_focus_neighbor(FOCUS_DIRECTIONS[action])
					if target == null or not is_ancestor_of(target): get_viewport().set_input_as_handled()

func _cycle_focus(backward: bool) -> void:
	var controls: Array[Control] = []
	for child in find_children("*", "Control", true, false):
		if child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree() and not (child is BaseButton and child.disabled):
			controls.append(child)
	if controls.is_empty(): return
	var current := controls.find(get_viewport().gui_get_focus_owner())
	var next := posmod(current+(-1 if backward else 1), controls.size()) if current >= 0 else (controls.size()-1 if backward else 0)
	controls[next].grab_focus()

func _gui_input(_event: InputEvent) -> void:
	# The full-screen transparent root also blocks clicks outside the content.
	accept_event()

func _unhandled_input(_event: InputEvent) -> void:
	if is_visible_in_tree(): get_viewport().set_input_as_handled()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _rebuild() -> void:
	_clear(categories)
	var group := ButtonGroup.new()
	for i in sections.size():
		var button := TextButton.instantiate() as Button
		button.text = sections[i].label
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == selected_section
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.pressed.connect(_select.bind(i))
		categories.add_child(button)
	_show_rows()
	if visible and categories.get_child_count(): categories.get_child(selected_section).grab_focus()

func _select(index: int) -> void:
	selected_section = index
	scroll.scroll_vertical = 0
	_show_rows()

func _show_rows() -> void:
	_clear(rows)
	if sections.is_empty(): return
	for definition: Dictionary in sections[selected_section].options:
		var row := Row.instantiate()
		rows.add_child(row)
		row.configure(definition, values.get(definition.key, definition.get("default")))
		row.changed.connect(_change)

func _change(key: StringName, value: Variant) -> void:
	values[key] = value
	option_changed.emit(key, value)
