extends Control
## Fixed scene-authored controls; data changes labels and the selected preview.
signal map_changed(definition: MenuMapDefinition)
signal launch_requested(definition: MenuMapDefinition, run_options: Dictionary)
signal back_requested
enum Step { MAP, OPTIONS }
var maps: Array[MenuMapDefinition] = []
var selected := 0
var current_step := Step.MAP
@onready var previous_button: Button = $Footer/Column/MapRow/Previous
@onready var next_button: Button = $Footer/Column/MapRow/Next
@onready var start_button: Button = $Footer/Column/Actions/Start
@onready var back_button: Button = $Footer/Column/Actions/Back

func _ready() -> void:
	# Instanced buttons receive separate scene-local resources; bind each row
	# to one local group so radios stay exclusive without sharing across runs.
	for row in ["LeftColumn/Group/Difficulty", "RightColumn/Group/StartingHand"]:
		var choices := $Footer/Column/Details/RunOptions.get_node(row+"/Choices")
		var group: ButtonGroup = choices.get_child(0).button_group
		for button: Button in choices.get_children(): button.button_group = group
	previous_button.pressed.connect(select_map.bind(-1))
	next_button.pressed.connect(select_map.bind(1))
	back_button.pressed.connect(go_back)
	start_button.pressed.connect(advance)
	_align_option_keys()
	_refresh()

func configure(options: Array[MenuMapDefinition]) -> void:
	maps = options.duplicate()
	selected = clampi(selected, 0, maxi(0, maps.size()-1))
	_refresh()

func open() -> void:
	show()
	_set_step(Step.MAP)
	if not maps.is_empty(): map_changed.emit(maps[selected])
	start_button.grab_focus()
	$Entry.play("enter")

func select_map(step: int) -> void:
	if current_step != Step.MAP or maps.size() < 2: return
	selected = posmod(selected+step, maps.size())
	_refresh()
	map_changed.emit(maps[selected])

func advance() -> void:
	if maps.is_empty() or start_button.disabled: return
	if current_step == Step.MAP:
		_set_step(Step.OPTIONS)
	else:
		launch_requested.emit(maps[selected], get_run_options())

func go_back() -> void:
	if back_button.disabled: return
	if current_step == Step.OPTIONS:
		_set_step(Step.MAP)
	else:
		back_requested.emit()

func get_run_options() -> Dictionary:
	# Prototype values are local to this flow, separate from engine settings.
	var rows := $Footer/Column/Details/RunOptions
	return {
		"difficulty": _selected_value(rows.get_node("LeftColumn/Group/Difficulty/Choices")),
		"starting_hand": _selected_value(rows.get_node("RightColumn/Group/StartingHand/Choices")),
		"extra_events": rows.get_node("LeftColumn/Group/ExtraEvents/Enabled").button_pressed,
	}

func _align_option_keys() -> void:
	# Center each complete column, keeping its rows and value starts aligned.
	for column in $Footer/Column/Details/RunOptions.get_children():
		var keys: Array[Label] = []
		var width := 0.0
		for row in column.get_node("Group").get_children():
			var key := row.get_node_or_null("Key") as Label
			if key == null: continue
			keys.append(key)
			width = maxf(width, key.get_theme_font("font").get_string_size(tr(key.text), HORIZONTAL_ALIGNMENT_LEFT, -1, key.get_theme_font_size("font_size")).x+12.0)
		for key in keys: key.custom_minimum_size.x = ceilf(width)

func _selected_value(choices: Node) -> String:
	for button: Button in choices.get_children():
		if button.button_pressed: return button.get_meta("value")
	return ""

func _set_step(step: Step) -> void:
	current_step = step
	var options := current_step == Step.OPTIONS
	$Footer/Column/Details/Info.visible = not options
	$Footer/Column/Details/RunOptions.visible = options
	$Footer/Column/Details/Divider.visible = options
	start_button.text = "ui.maps.launch" if options else "ui.run.next"
	_refresh()
	# Keep focus on the action the player used. Only replace hidden focus,
	# such as Esc returning from an option that is no longer visible.
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not focus.is_visible_in_tree(): start_button.grab_focus()

func _refresh() -> void:
	previous_button.disabled = current_step != Step.MAP or maps.size() < 2
	next_button.disabled = current_step != Step.MAP or maps.size() < 2
	start_button.disabled = maps.is_empty()
	if maps.is_empty(): return
	var definition := maps[selected]
	$Footer/Column/MapRow/Name.text = definition.title_key
	$Footer/Column/Details/Info/Description.text = definition.description_key
	$Footer/Column/Details/Info/Index.text = "%02d / %02d" % [selected+1, maps.size()]
	$Footer/Column/Details/Info/Summary.text = tr("ui.maps.summary") % [definition.level.acts.size(), definition.level.wave_count()]

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_align_option_keys.call_deferred()
		_refresh()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
