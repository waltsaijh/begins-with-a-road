extends Node3D
## Formal-level presentation. Dirty signals coalesce once; hover only reads caches.
const Renderer = preload("res://scenes/navigation/road_flow_renderer.tscn")
var forecast := RoadFlowForecast.new()
var rebuild_count := 0
var preparation := false
var _dirty := true
var _paused := false
@onready var session: Node = get_parent()
@onready var wave: Node = $"../EnemyWave"
@onready var controller: Node = $"../PortalMap"
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
	panel.filter_changed.connect(_filter)
	_refresh_visibility()

func set_preparation(value: bool) -> void:
	preparation = value
	panel.clear_filter()
	if value:
		invalidate()
	else:
		forecast = RoadFlowForecast.new()
		arrows.mesh = null
	_refresh_visibility()

func invalidate() -> void:
	_dirty = true
	# Never retain an old prediction during a pending navigation update.
	arrows.mesh = null

func _process(_delta: float) -> void:
	var paused: bool = hud.pause_requested or get_tree().paused
	if paused != _paused:
		_paused = paused
		panel.clear_filter()
	if preparation and not paused and _dirty and not controller.computing:
		_dirty = false
		var definition: WaveDefinition = wave.definition
		panel.display(RoadFlowForecast.troop_counts(definition))
		var schedule := WaveSpawnSchedule.build(definition, controller, wave._next_enemy_id, false, wave.additional_start_indices) if definition != null else {}
		forecast = RoadFlowForecast.from_pending(schedule.get("pending", []))
		rebuild_count += 1
		_filter(panel.selected)
	_refresh_visibility()

func _filter(profile: Troop) -> void:
	if not preparation or _dirty: return
	arrows.display(forecast.segments(profile), forecast.all, controller.map)

func _refresh_visibility() -> void:
	var available: bool = preparation and not hud.pause_requested and not get_tree().paused
	panel.visible = available
	arrows.visible = available and not debug_overlay.show_routes and not debug_overlay.show_parameters
