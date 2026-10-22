extends Node3D
## Scene-authored presentation; only intents, transitions and settings hosting.
const SettingsAdapter = preload("res://scripts/settings/game_settings.gd")
@export_range(0.0, 1.0, 0.01) var settings_veil_alpha := 0.82
var _starting := false
var _selecting := false
var _veil_motion: Tween
@onready var home: Control = $Interface/Home
@onready var start_button: Button = $Interface/Home/Column/Actions/Start
@onready var settings_button: Button = $Interface/Home/Column/Actions/Settings
@onready var exit_button: Button = $Interface/Home/Column/Actions/Exit
@onready var settings_page: Control = $Interface/SettingsPage
@onready var veil: ColorRect = $Interface/SettingsVeil
@onready var map_selection: Control = $Interface/MapSelection
@onready var map_previews: Node3D = $MapPreviews

func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	start_button.pressed.connect(start_game)
	settings_button.pressed.connect(open_settings)
	exit_button.pressed.connect(func(): get_tree().quit())
	exit_button.visible = not OS.has_feature("web")
	settings_page.option_changed.connect(func(key: StringName, value: Variant): SettingsAdapter.apply(key, value, get_viewport()))
	settings_page.visibility_changed.connect(_on_settings_visibility_changed)
	map_selection.back_requested.connect(return_home)
	map_selection.map_changed.connect(_on_map_changed)
	map_selection.launch_requested.connect(_launch_map)
	ScreenTransition.finished.connect(_on_transition_finished)
	var definitions: Array[MenuMapDefinition] = []
	for preview in map_previews.get_children(): definitions.append(preview.definition)
	map_selection.configure(definitions)
	$Interface/Entry.play("enter")
	$Stage/Entry.play("enter")
	start_button.grab_focus()

func start_game() -> void:
	if _starting or settings_page.visible or _selecting: return
	ScreenTransition.run(_show_map_selection)

func _show_map_selection() -> void:
	_selecting = true
	home.hide()
	$Stage/Bridge.hide()
	map_previews.show()
	map_selection.open()

func return_home() -> void:
	if _starting: return
	ScreenTransition.run(_show_home)

func _show_home() -> void:
	_selecting = false
	map_selection.hide()
	map_previews.hide()
	$Stage/Bridge.show()
	$Stage/Camera3D.make_current()
	home.show()
	start_button.grab_focus()

func _on_map_changed(definition: MenuMapDefinition) -> void:
	for preview in map_previews.get_children():
		preview.visible = preview.definition == definition
		if preview.visible: preview.activate()

func _launch_map(definition: MenuMapDefinition, _run_options: Dictionary) -> void:
	# Run options are UI prototypes until their gameplay rules are defined.
	if _starting or settings_page.visible or not _selecting or ScreenTransition.active: return
	if definition == null or definition.level == null or not ResourceLoader.exists(definition.level_scene):
		push_error("Map selection is missing a playable level")
		return
	_starting = true
	if not ScreenTransition.change_scene(definition.level_scene):
		_starting = false

func _on_transition_finished(error: int) -> void:
	if error != OK and _starting:
		_starting = false

func open_settings() -> void:
	if _starting or ScreenTransition.active: return
	settings_page.configure(SettingsAdapter.sections(), SettingsAdapter.read(get_viewport()))
	settings_page.open()

func _on_settings_visibility_changed() -> void:
	if not is_inside_tree(): return
	var active := settings_page.is_visible_in_tree()
	home.visible = not active and not _selecting
	map_selection.visible = not active and _selecting
	if _veil_motion != null: _veil_motion.kill()
	veil.show()
	_veil_motion = create_tween().set_ignore_time_scale(true)
	_veil_motion.tween_property(veil, "color:a", settings_veil_alpha if active else 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if not active:
		if _selecting: map_selection.start_button.grab_focus()
		else: settings_button.grab_focus()
		_veil_motion.tween_callback(veil.hide)

func _exit_tree() -> void:
	if _veil_motion != null: _veil_motion.kill()
