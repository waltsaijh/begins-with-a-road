extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void: run.call_deferred()
func run() -> void:
	var cells: Array[Vector2i] = []
	for y in 9:
		for x in 9: cells.append(Vector2i(x,y))
	var scene := Fixture.scene_for(cells, Vector2i(0,0), Vector2i(8,8))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
		if not scene.get_node("PortalMap").computing: break
	var cards: Node = scene.get_node("CardPlacement")
	var towers: Node = scene.get_node("TowerMap")
	var map: GridMap = scene.get_node("TileMap")
	var definition: TowerDefinition = load("res://assets/data/towers/sentry.tres")
	var first := BuildCard.from_parts(definition, definition.first_tile_preset())
	var tower: DefenseTower = towers.place_card(first, Vector3i(4,0,4), 1)
	check(tower != null, "Build level 1")
	var grounds := map.get_used_cells()
	var transform_before := tower.global_transform
	tower.next_attack_time = 123.5
	tower.health = tower.max_health*0.4
	var second := BuildCard.from_parts(definition, load("res://assets/data/tile_presets/bridge.tres"))
	second.price = 17
	var shop: Node = cards.get_node("Shop")
	var coins: int = shop.coins
	cards.add_card(second)
	cards.select_card(cards.cards.size()-1)
	var count: int = cards.cards.size()
	var graph_changes := [0]
	scene.get_node("PortalMap").graph_changed.connect(func(): graph_changes[0] += 1)
	check(cards.place_selected(Vector3i(4,0,4)) == tower, "Different preset upgrades same definition")
	check(tower.level == 2 and cards.cards.size() == count-1 and shop.coins == coins and second.price == 17, "Exactly one card, no extra gold")
	check(map.get_used_cells() == grounds and graph_changes[0] == 0 and tower.global_transform == transform_before, "Upgrade leaves roads, topology, position and orientation unchanged")
	check(tower.next_attack_time == 123.5 and is_equal_approx(tower.health/tower.max_health, 0.4), "Preserve cooldown and health ratio")
	check(is_equal_approx(tower.damage, definition.default_damage*1.35), "Data-driven growth")
	var other: TowerDefinition = load("res://assets/data/towers/mortar.tres")
	check(towers.place_card(BuildCard.from_parts(other, other.first_tile_preset()), Vector3i(4,0,4)) == null, "Different tower rejected")
	check(towers.place_card(second, Vector3i(4,0,4)) == tower and tower.level == 3, "Level 3 upgrade")
	check(towers.place_card(second, Vector3i(4,0,4)) == null and tower.level == 3, "Level 3 cap")
	cards.preview.show_upgrade(map, tower, tower.upgrade_error())
	check(cards.preview.ground.mesh == null and cards.preview.upgrade_label.visible, "Upgrade preview has no roads, has level/error")
	tower.unlimited_levels = true
	for i in 97: check(tower.upgrade(), "Finite high level upgrade")
	check(tower.level == 100 and is_finite(tower.damage) and tower.attack_interval > 0, "Level 100 finite values")
	tower.level = 10000
	var old_damage := tower.damage
	check(not tower.upgrade() and tower.level == 10000 and tower.damage == old_damage, "Overflow fails atomically instead of storing infinity")
	var bdef: TowerDefinition = load("res://assets/data/towers/barracks.tres")
	var barracks: DefenseTower = towers.place_card(BuildCard.from_parts(bdef,bdef.first_tile_preset()),Vector3i(6,0,6))
	towers.combat.barracks._process(0)
	var unit: Node = towers.combat.barracks.units[0]
	unit.health = 20
	unit.attack_timer = 0.3
	barracks.upgrade()
	check(barracks.deployment.count == 2 and towers.combat.barracks.units.size() == 2, "Upgrade never increases soldier count")
	check(is_equal_approx(unit.health/unit.settings.health,0.5) and unit.attack_timer == 0.3, "Friendly health ratio and timer preserved")
	scene.queue_free()
	await get_tree().process_frame
	var output := {"failures": failures, "stage": "3A"}
	FileAccess.open(Artifacts.path("relics/stacking.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("STACKING:", JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)
