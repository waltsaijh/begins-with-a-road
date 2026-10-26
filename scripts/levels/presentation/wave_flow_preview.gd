extends Node3D
## Shared wave forecast, per-entrance callouts, and cached hover filtering.
const Renderer = preload("res://scenes/navigation/road_flow_renderer.tscn")
var forecast := RoadFlowForecast.new()
var baseline := RoadFlowForecast.new()
var candidate := {}
var candidate_rebuild_count := 0
var _candidate_dirty := false
var _candidate_unavailable := false
var _schedule_error := ""
var _junctions := {}
@export_range(1, 100, 1) var minimum_quota_change := 1
var delta_overlay: Control
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
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	delta_overlay = preload("res://scenes/traffic/components/traffic_delta_overlay.tscn").instantiate()
	layer.add_child(delta_overlay)
	delta_overlay.map = controller.map
	get_node("../CardPlacement").traffic_preview_changed.connect(set_candidate)
	controller.graph_changed.connect(invalidate)
	controller.plan_changed.connect(invalidate)
	controller.tile_parameters.costs_changed.connect(func(_id: int): invalidate())
	wave.routes_changed.connect(invalidate)
	session.preparation_changed.connect(set_preparation)
	_sync_callouts()
	_refresh_visibility()

func set_candidate(effect: Dictionary) -> void:
	if candidate == effect: return
	candidate = effect.duplicate(true)
	controller.clear_traffic_preview_cache()
	_candidate_dirty = true
	if candidate.is_empty():
		forecast = baseline
		delta_overlay.markers = {}
		delta_overlay.hint = ""
		_render_filter()

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
		if not panels[i].info_requested.is_connected(_show_intelligence): panels[i].info_requested.connect(_show_intelligence)
	if selected_origin >= panels.size(): selected_origin = -1

func _show_intelligence(profile: Troop) -> void:
	if session.enemy_intelligence != null: session.enemy_intelligence.show_profile(profile)

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
		baseline = forecast
		set_candidate({})
		arrows.mesh = null
	_refresh_visibility()

func invalidate() -> void:
	_dirty = true
	arrows.mesh = null
	if delta_overlay != null:
		delta_overlay.markers = {}
		delta_overlay.hint = ""

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
		_schedule_error = ""
		if schedule.is_empty() and definition != null:
			for group in definition.groups:
				for origin in WaveSpawnSchedule.origins_for(group,wave.additional_start_indices):
					var plan: Dictionary = controller.plan_for(group.troop,origin)
					if not plan.get("valid",false): _schedule_error = str(plan.get("error","無法建立出兵路線"))
		baseline = RoadFlowForecast.from_pending(schedule.get("pending", []))
		forecast = baseline
		_junctions = TrafficFlowDelta.junctions(controller.map,controller.blocked_cells)
		_candidate_dirty = true
		var counts := forecast.counts_by_origin if not schedule.is_empty() else WaveSpawnSchedule.counts_by_origin(definition,wave.additional_start_indices)
		var panels := _panels()
		for i in panels.size():
			panels[i].display(counts.get(i,{}))
		rebuild_count += 1
		_render_filter()
	if preparation and not paused and not _dirty and _candidate_dirty:
		_candidate_dirty = false
		forecast = baseline
		_candidate_unavailable = false
		if not candidate.is_empty():
			var effects: Array = controller.traffic_effects.duplicate(true)
			effects.append(candidate)
			var predicted := WaveSpawnSchedule.build(wave.definition,controller,wave._next_enemy_id,false,wave.additional_start_indices,effects)
			_candidate_unavailable = predicted.is_empty()
			if not _candidate_unavailable: forecast = RoadFlowForecast.from_pending(predicted.pending)
			candidate_rebuild_count += 1
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
		if not action.is_visible_in_tree() or action.disabled: continue
		# The unpainted bridge is still inside the expanded callout even when GUI
		# hover temporarily has no Control owner while crossing into the panel.
		var owned := hovered != null and (hovered == action or action.is_ancestor_of(hovered))
		if not owned and not (hovered == null and bool(action.get("_hovered"))): continue
		origin = i
		# An expanded bridge without a GUI owner selects only the entrance.
		if hovered == null: break
		for item in panels[i].get_node("Scroll/Items").get_children():
			var body := item.get_node_or_null("Body")
			if body != null and (hovered == item or item.is_ancestor_of(hovered)):
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
	var profile: Troop
	var panels := _panels()
	if selected_origin >= 0 and selected_origin < panels.size():
		profile = panels[selected_origin].selected
		segments = forecast.by_origin.get(selected_origin,{}) if profile == null else forecast.by_troop_origin.get(profile,{}).get(selected_origin,{})
	arrows.display(segments,forecast.all,controller.map,forecast.animation(profile,selected_origin))
	var before: Dictionary = baseline.all
	if selected_origin >= 0 and selected_origin < panels.size():
		before = baseline.by_origin.get(selected_origin,{}) if profile == null else baseline.by_troop_origin.get(profile,{}).get(selected_origin,{})
	delta_overlay.markers = TrafficFlowDelta.compare(before,segments,_junctions,minimum_quota_change) if not candidate.is_empty() else {}
	delta_overlay.hint = tr("traffic.no_change") if not candidate.is_empty() and baseline.all == forecast.all else ""
	if not candidate.is_empty() and _candidate_unavailable: delta_overlay.hint = tr("traffic.unavailable")
	if not _schedule_error.is_empty():
		delta_overlay.hint = ("Unable to confirm the newest route. Simplify the roads and retry." if TranslationServer.get_locale().begins_with("en") else "無法確認最新路線，請簡化道路後重試。") if "Scout history" in _schedule_error else _schedule_error
		delta_overlay.hint_point = controller.get_node(controller.start_paths[0]).global_position+Vector3.UP*0.5
	if not candidate.is_empty():
		var placement: Node = get_node("../CardPlacement")
		delta_overlay.hint_point = placement.preview.hint_anchor

func _refresh_visibility() -> void:
	var available: bool = preparation and not hud.pause_requested and not get_tree().paused
	for action: Button in hud.start_callouts: action.set_intel_available(available)
	arrows.visible = available and not debug_overlay.show_routes and not debug_overlay.show_parameters
	delta_overlay.visible = arrows.visible and (not candidate.is_empty() or not _schedule_error.is_empty())
