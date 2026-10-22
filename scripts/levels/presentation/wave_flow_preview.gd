extends Node3D
## Shared wave forecast, per-entrance callouts, and cached hover filtering.
const Renderer = preload("res://scenes/navigation/road_flow_renderer.tscn")
var forecast := RoadFlowForecast.new()
var rebuild_count := 0
var preparation := false
var selected_origin := -1
var _dirty := true
var _paused := false
@onready var session: Node = get_parent()
@onready var wave: Node = $"../EnemyWave"
@onready var controller: Node = $"../PortalMap"
## First panel remains the scene-authored action used by existing wave controls.
@onready var panel: Control = $"../LevelHUD/WorldActions/EarlyStart/NextWaveIntel"
@onready var hud: CanvasLayer = $"../LevelHUD"
@onready var debug_overlay: Node = $"../PortalOverlay"
var arrows: MeshInstance3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arrows = Renderer.instantiate()
	add_child(arrows)
	controller.graph_changed.connect(invalidate)
	controller.plan_changed.connect(invalidate)
	controller.tile_parameters.costs_changed.connect(func(_id: int): invalidate())
	wave.routes_changed.connect(invalidate)
	session.preparation_changed.connect(set_preparation)
	_sync_callouts()
	_refresh_visibility()

func _panels() -> Array[Control]:
	var result: Array[Control] = []
	for action: Button in hud.start_callouts:
		result.append(action.get_node("NextWaveIntel"))
	return result

func _sync_callouts() -> void:
	var markers: Array[Node3D] = []
	for path: NodePath in controller.start_paths:
		var marker := controller.get_node_or_null(path) as Node3D
		if marker == null: return
		markers.append(marker)
	hud.sync_start_callouts(markers)
	var panels := _panels()
	for i in panels.size():
		var callback := _filter.bind(i)
		if not panels[i].filter_changed.is_connected(callback):
			panels[i].filter_changed.connect(callback)
	if selected_origin >= panels.size(): selected_origin = -1

func _clear_filters() -> void:
	for entry in _panels(): entry.clear_filter()
	selected_origin = -1

func set_preparation(value: bool) -> void:
	preparation = value
	_clear_filters()
	if value:
		invalidate()
	else:
		forecast = RoadFlowForecast.new()
		arrows.mesh = null
	_refresh_visibility()

func invalidate() -> void:
	_dirty = true
	arrows.mesh = null

func _process(_delta: float) -> void:
	var paused: bool = hud.pause_requested or get_tree().paused
	if paused != _paused:
		_paused = paused
		_clear_filters()
	if preparation and not paused and _dirty and not controller.computing:
		_dirty = false
		_sync_callouts()
		var definition: WaveDefinition = wave.definition
		var schedule := WaveSpawnSchedule.build(definition, controller, wave._next_enemy_id, false, wave.additional_start_indices) if definition != null else {}
		forecast = RoadFlowForecast.from_pending(schedule.get("pending", []))
		var counts := forecast.counts_by_origin if not schedule.is_empty() else WaveSpawnSchedule.counts_by_origin(definition,wave.additional_start_indices)
		var panels := _panels()
		for i in panels.size():
			panels[i].display(counts.get(i,{}))
		rebuild_count += 1
		_render_filter()
	if preparation and not paused and DisplayServer.get_name() != "headless":
		_sync_pointer_filter()
	_refresh_visibility()

func _sync_pointer_filter() -> void:
	# Resolve the actual hovered descendant: titles, row gaps and scrollbars still
	# belong to this entrance, rather than falling back to the whole wave.
	var hovered := get_viewport().gui_get_hovered_control()
	var origin := -1
	var profile: Troop
	var panels := _panels()
	for i in hud.start_callouts.size():
		var action: Button = hud.start_callouts[i]
		if hovered == null or not action.is_visible_in_tree() or action.disabled: continue
		if hovered != action and not action.is_ancestor_of(hovered): continue
		origin = i
		for item in panels[i].get_node("Scroll/Items").get_children():
			var body := item.get_node_or_null("Body")
			if body != null and (hovered == body or body.is_ancestor_of(hovered)):
				profile = item.profile
		break
	var previous: Troop = panels[selected_origin].selected if selected_origin >= 0 and selected_origin < panels.size() else null
	if selected_origin == origin and previous == profile: return
	for i in panels.size(): panels[i].selected = profile if i == origin else null
	selected_origin = origin
	_render_filter()

func _filter(profile: Troop, origin: int) -> void:
	if profile == null:
		if selected_origin != origin: return
		selected_origin = -1
	else:
		selected_origin = origin
		var panels := _panels()
		for i in panels.size():
			if i != origin: panels[i].selected = null
	_render_filter()

func _render_filter() -> void:
	if not preparation or _dirty: return
	var segments: Dictionary = forecast.all
	var panels := _panels()
	if selected_origin >= 0 and selected_origin < panels.size():
		var profile: Troop = panels[selected_origin].selected
		segments = forecast.by_origin.get(selected_origin,{}) if profile == null else forecast.by_troop_origin.get(profile,{}).get(selected_origin,{})
	arrows.display(segments,forecast.all,controller.map)

func _refresh_visibility() -> void:
	var available: bool = preparation and not hud.pause_requested and not get_tree().paused
	for entry in _panels(): entry.visible = available
	arrows.visible = available and not debug_overlay.show_routes and not debug_overlay.show_parameters
