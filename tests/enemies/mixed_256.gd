extends Node3D
## Manual reproduction of the Web report's load; no automated timing or sampling.
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Layout = preload("res://tests/fixtures/route_loop_fixture.gd")
const COUNTS := [86, 85, 85]
const TROOPS := ["soldier", "quickfeet", "heavy"]
var world: Node3D
var wave: Node
var controller: Node
var ready_to_start := false
var wave_number := 0
var _busy := true
var _last_alive := -1
@onready var start_button: Button = $HUD/Root/Bottom/Buttons/Start
@onready var reload_button: Button = $HUD/Root/Bottom/Buttons/Reload
@onready var status: Label = $HUD/Root/Bottom/Status

func _ready() -> void:
	set_process(false)
	start_button.pressed.connect(start_batch)
	reload_button.pressed.connect(func(): get_tree().reload_current_scene())
	setup.call_deferred()

func setup() -> void:
	seed(602210)
	world = Fixture.scene_for(Layout.cells(), Vector2i(0, 3), Vector2i(31, 27))
	world.name = "World"
	wave = world.get_node("EnemyWave")
	wave.auto_start = false
	wave.show_button = false
	var camera: Camera3D = world.get_node("Camera3D")
	camera.size = 42
	camera.near = 0.1
	camera.far = 150
	camera.distance = Vector3(25, 35, 35).length()
	camera.azimuth = atan2(25.0, 35.0)
	camera.elevation = asin(35.0/camera.distance)
	add_child(world)
	controller = world.get_node("PortalMap")
	while controller.computing: await get_tree().process_frame
	if not _map_ready(): return
	camera.focus = controller.map.transform*Vector3(16, 0, 16)
	camera.update_pose()
	world.get_node("CardPlacement").set_entry_selection(true)
	var towers: Node = world.get_node("TowerMap")
	towers.input_enabled = false
	for y in 4:
		for x in 4:
			if towers.place_tower(Vector3i(x*8+1, 0, y*8+1)) == null:
				fail("無法建立測試防禦塔："+towers.last_error)
				return
	while controller.computing: await get_tree().process_frame
	if not _map_ready(): return
	var definition := WaveDefinition.new()
	definition.move_speed = 2.5
	for i in TROOPS.size():
		var source := TroopCatalog.find(TROOPS[i])
		if source == null:
			fail("找不到兵種："+TROOPS[i])
			return
		var profile := source.duplicate() as Troop
		profile.max_health = 1000000
		profile.speed_multiplier = 0.45
		var plan: Dictionary = controller.plan_for(profile)
		if not plan.get("reachable", false):
			fail("無法建立兵種路線："+TROOPS[i])
			return
		var group := WaveSpawnGroup.new()
		group.troop = profile
		group.enemy_count = COUNTS[i]
		group.interval_ticks = 0
		definition.groups.append(group)
	wave.definition = definition
	wave.enemy_spawned.connect(_on_enemy_spawned)
	if not wave.presentation_ready: await wave.presentation_prepared
	ready_to_start = true
	_busy = false
	start_button.disabled = false
	status.text = "準備完成，按「開始一局」同時生成 256 名敵人。"
	set_process(true)
	print("MIXED_256_READY")

func _map_ready() -> bool:
	if controller.plan.get("reachable", false): return true
	fail("無法建立測試地圖或原生尋路模組尚未載入。")
	return false

func fail(message: String) -> void:
	status.text = message
	push_error(message)

func start_batch() -> void:
	if not ready_to_start or _busy: return
	_busy = true
	start_button.disabled = true
	reload_button.disabled = true
	status.text = "正在清場並生成敵人…"
	# Tree-exiting follows the normal removal path; keep this wave's caches,
	# renderer, atlas and map alive so repeated starts can reuse loaded resources.
	for enemy: Node3D in wave.living_enemies(): enemy.queue_free()
	await get_tree().process_frame
	if not is_inside_tree(): return
	var combat: Node = world.get_node("TowerMap").combat
	combat.projectiles.clear()
	combat.visuals.beams.clear()
	combat.visuals.get_node("ImpactEffects").clear()
	wave.visuals.death_effects.clear()
	for tower: DefenseTower in world.get_node("TowerMap").towers.values():
		tower.next_attack_time = combat.elapsed
	seed(602210)
	if not wave.start_wave():
		fail("無法開始波次，請重新載入場景。")
		reload_button.disabled = false
		return
	wave_number += 1
	_last_alive = -1
	start_button.text = "清場並再次開波"
	print("MIXED_256_STARTED:%d" % wave_number)

func _on_enemy_spawned(_enemy: Node3D) -> void:
	if wave.spawned != wave.total: return
	_busy = false
	start_button.disabled = false
	reload_button.disabled = false
	print("MIXED_256_SPAWNED:%d" % wave_number)

func _process(_delta: float) -> void:
	if wave_number == 0 or _busy or _last_alive == wave.alive: return
	_last_alive = wave.alive
	status.text = "第 %d 次開波 · 已生成 %d / %d · 存活 %d" % [wave_number, wave.spawned, wave.total, wave.alive]
