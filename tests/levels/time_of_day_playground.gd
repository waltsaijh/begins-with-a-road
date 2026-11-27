extends Node
## Manual check for time-of-day lighting on Art Slice G towers and enemies (no real
## level needed). F6 this scene, then:
##   1 morning   2 noon   3 dusk   4 night (tower torches lit)
##   Space  send another wave   (camera: the level's usual drag / zoom / orbit)
## Rows of display-only towers stand beside the road: Lv.1, Lv.2, Lv.3 for each kind.
const Fixture = preload("res://tests/fixtures/level_fixture.gd")
const Visual = preload("res://scripts/towers/body_visual.gd")
const PRESETS := ["morning", "noon", "dusk", "night"]
const KINDS := ["sentry", "barracks", "mortar", "crossfire", "ballista", "broadside"]
## Body cells per kind (x, z relative to the anchor), matching the shop footprints.
const BODIES := {"sentry": [Vector2i(0, 0)], "barracks": [Vector2i(0, 0)],
	"mortar": [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)],
	"crossfire": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1)],
	"ballista": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)], "broadside": [Vector2i(0, 0), Vector2i(0, 1)]}
const TROOPS := ["soldier", "heavy", "quickfeet", "rook", "bloodmage", "scout", "bomber", "rats", "winged"]
const ROAD_LENGTH := 26
var level: Node3D
var towers := Node3D.new()
var preset_name := "night"
var label := Label.new()

func _ready() -> void:
	var definition := Fixture.level("")
	var terrain := definition.terrain.instantiate() as GridMap
	for x in range(8, ROAD_LENGTH): terrain.set_cell_item(Vector3i(x, 0, 0), 3)
	for k in KINDS.size():   # stone islands under the display towers
		for lv in [1, 2, 3]:
			var anchor := _anchor(k, lv)
			for c: Vector2i in BODIES[KINDS[k]]:
				terrain.set_cell_item(Vector3i(anchor.x+c.x, 0, anchor.z+c.y), 0)
	terrain.get_node("Goal").position.x = terrain.map_to_local(Vector3i(ROAD_LENGTH-1, 0, 0)).x
	definition.terrain = PackedScene.new(); definition.terrain.pack(terrain); terrain.free()
	var wave := definition.acts[0].waves[0]
	wave.groups.clear(); wave.move_speed = 0.6
	for i in TROOPS.size():
		var group := WaveSpawnGroup.new(); group.troop = TroopCatalog.find(TROOPS[i])
		group.enemy_count = group.troop.cohort_size if TROOPS[i] == "rats" else 1
		group.interval_ticks = 0; group.start_tick = i*4
		wave.groups.append(group)
	definition.time_of_day = _preset(preset_name)
	level = load("res://scenes/level.tscn").instantiate()
	level.level = definition
	add_child(level)
	level.add_child(towers)
	var canvas := CanvasLayer.new(); add_child(canvas)
	label.position = Vector2(16, 60)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(label)
	await get_tree().process_frame
	await get_tree().process_frame
	_build_towers()
	_update_label()
	var camera := get_viewport().get_camera_3d()
	if camera != null and "focus" in camera:
		camera.focus = Vector3(12, 0, -2); camera.update_pose()
	level._on_start_requested()

func _anchor(k: int, lv: int) -> Vector3i:
	return Vector3i(2+k*4, 0, [-3, 3, 6][lv-1])

func _preset(id: String) -> TimeOfDayPreset:
	return load("res://assets/data/rendering/time_of_day/%s.tres" % id)

func _build_towers() -> void:
	for child in towers.get_children(): child.free()
	for k in KINDS.size():
		var kind: String = KINDS[k]
		var tower: TowerDefinition = load("res://assets/data/towers/%s.tres" % kind)
		for lv in [1, 2, 3]:
			var body: Array[Vector2i] = []
			body.assign(BODIES[kind])
			var visual := Visual.create(tower, body)
			# Display-only: north of the road for Lv.1, south for Lv.2 / Lv.3 rows.
			var cell := _anchor(k, lv)
			var map: GridMap = level.get_node("TowerMap").map
			visual.position = map.map_to_local(cell)
			visual.position.y = 0.025   # road / ground surface (road_surface.gd GROUND_HEIGHT)
			towers.add_child(visual)
			Visual.set_level(visual, lv)

## Keys are polled: the level's own input (hand hotkeys 1-9, Space) may consume the
## events before an unhandled-input callback here would see them.
var _held := {}
func _process(_delta: float) -> void:
	if level == null: return
	for i in PRESETS.size():
		if _pressed(KEY_1+i): _switch(PRESETS[i])
	if _pressed(KEY_SPACE): level._on_start_requested()

func _pressed(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var fresh: bool = down and not _held.get(key, false)
	_held[key] = down
	return fresh

func _switch(id: String) -> void:
	preset_name = id
	level.level.time_of_day = _preset(preset_name)
	TimeOfDayPreset.claim(level, level.level.time_of_day, level.get_node_or_null("Sun") as DirectionalLight3D,
		level.get_node_or_null("WorldEnvironment") as WorldEnvironment)
	_build_towers()   # torches are lit when a tower is built
	var lamps := level.get_node_or_null("RoadLamps")
	if lamps != null: lamps.build()
	_update_label()

func _update_label() -> void:
	label.text = "時段：%s    1 早上  2 中午  3 黃昏  4 夜晚    Space 再出一波\n塔：上排 Lv.1，下兩排 Lv.2 / Lv.3（哨塔、兵營、迫擊砲、十字火力、弩砲、飛艇）" % {"morning": "早上", "noon": "中午", "dusk": "黃昏", "night": "夜晚"}[preset_name]
