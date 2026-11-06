extends Node3D
const Calc = preload("res://scripts/construction/geometry_bonus_calculator.gd")
const Rules = preload("res://assets/data/construction/geometry_bonuses.tres")
const Manager = preload("res://scripts/construction/geometry_bonuses.gd")
const Fixture = preload("res://tests/construction/fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var checks := 0
var failures: Array[String] = []

func _ready() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func snapshot(ports: Dictionary) -> Dictionary:
	var cells := PackedInt32Array()
	var masks := PackedByteArray()
	for cell: Vector2i in ports:
		cells.append_array(PackedInt32Array([cell.x,cell.y]))
		masks.append(ports[cell])
	return {"cells":cells,"ports":masks}

func settle(scene: Node) -> void:
	for i in 8: await get_tree().process_frame
	check(not scene.get_node("PortalMap").computing,"Geometry topology settles")

func run() -> void:
	for turns in 4:
		var ports := {}
		for length in range(1,7):
			ports[BuildCard.rotate_cell(Vector2i(0,-length),turns)] = TilePreset.rotate_ports(5,turns)
			var bonus := Calc.evaluate(snapshot(ports),Rules.straight_tower,Vector2i.ZERO,turns,Rules)
			check(bonus.range_extension == (1 if length >= 5 else 0),"Straight threshold rotates with physical roads")
		ports[BuildCard.rotate_cell(Vector2i(0,-3),turns)] = 0
		check(Calc.evaluate(snapshot(ports),Rules.straight_tower,Vector2i.ZERO,turns,Rules).range_extension == 0,"Broken reciprocal edge removes straight bonus")
	var junction := {Vector2i(0,-1):15,Vector2i(0,-2):4,Vector2i(-1,-1):2,Vector2i(1,-1):8}
	check(Calc.evaluate(snapshot(junction),Rules.junction_tower,Vector2i.ZERO,0,Rules).damage_bonus == 0.1,"Three real branches enable junction bonus")
	check(Calc.evaluate(snapshot(junction),Rules.straight_tower,Vector2i.ZERO,0,Rules).damage_bonus == 0,"Bonus targets the configured tower only")
	junction[Vector2i(1,-1)] = 0
	check(Calc.evaluate(snapshot(junction),Rules.junction_tower,Vector2i.ZERO,0,Rules).damage_bonus == 0,"One-sided apparent branch is not a junction")
	var scene := Fixture.session()
	add_child(scene)
	await settle(scene)
	var towers: Node = scene.get_node("TowerMap")
	var placement: Node = scene.get_node("TilePlacement")
	var roads: Array[Vector3i] = []
	for depth in range(-5,1): roads.append(Vector3i(8,0,depth))
	placement.add_cells(roads)
	var plain := BuildCard.from_parts(Rules.straight_tower,TilePreset.new())
	var tower: DefenseTower = towers.place_card(plain,Vector3i(8,0,1),0)
	check(tower != null,"Ballista can use legacy base on straight road")
	await settle(scene)
	check(tower.geometry_range_extension == 0 and not tower.covers_cell(Vector2i(8,-4)),"Without opt-in the same topology has no bonus")
	var manager := Manager.new()
	manager.name = "GeometryBonuses"
	scene.add_child(manager)
	check(tower.geometry_range_extension == 1 and tower.covers_cell(Vector2i(8,-4)),"Opt-in changes actual attack geometry by one tile")
	check(is_equal_approx(towers.controller.tile_parameters.get_tile(Vector2i(8,-4)).threat,tower.threat),"Extended real range updates threat")
	var bonus: Dictionary = manager.preview(plain,Vector3i(8,0,1),0)
	check(Vector2i(8,-4) in bonus.cells,"Preview and real extended range agree")
	var enemy: Node3D = load("res://scenes/enemies/enemy.tscn").instantiate()
	scene.add_child(enemy)
	enemy.troop = TroopCatalog.find("soldier")
	enemy.global_position = towers.map.to_global(towers.map.map_to_local(Vector3i(8,0,-4)))
	enemy.health = 100
	enemy.max_health = 100
	var targets: Array[Node3D] = [enemy]
	towers.combat._index.rebuild(targets,towers.map)
	check(enemy in towers.combat.targets_for(tower),"Extra tile is included by the actual combat spatial query")
	tower.attack.fire(towers.combat,tower,enemy)
	check(is_equal_approx(enemy.health,100.0-tower.damage*tower.attack.damage_multiplier),"Attack at extended range resolves a real damage payload")
	enemy.queue_free()
	var cross: DefenseTower = towers.place_card(BuildCard.from_parts(Rules.junction_tower,TilePreset.new()),Vector3i(7,0,1),0)
	check(cross != null and is_equal_approx(cross.damage,Rules.junction_tower.default_damage*1.1),"Real junction changes effective crossfire damage")
	var original_damage := cross.damage
	manager.refresh()
	manager.refresh()
	check(is_equal_approx(cross.damage,original_damage),"Repeated refresh does not stack geometry")
	cross.upgrade()
	towers.relics.refresh_towers()
	check(is_equal_approx(cross.damage,cross.definition.default_damage*cross.definition.growth.multiplier(cross.definition.growth.damage,2)*1.1),"Upgrade and relic refresh preserve independent geometry effect")
	# Remove the distant straight segment, leaving the original main road valid.
	var map: GridMap = scene.get_node("TileMap")
	map.set_cell_item(Vector3i(8,0,-3),GridMap.INVALID_CELL_ITEM)
	placement.refresh_cell(Vector3i(8,0,-2))
	placement.refresh_cell(Vector3i(8,0,-4))
	towers.controller.rebuild()
	manager.refresh()
	check(tower.geometry_range_extension == 0 and not tower.covers_cell(Vector2i(8,-4)),"Road removal retracts actual bonus range")
	check(is_zero_approx(towers.controller.tile_parameters.get_tile(Vector2i(8,-4)).threat),"Range retraction removes sparse threat")
	for cell in [Vector3i(8,0,-1),Vector3i(8,0,-2)]: map.set_cell_item(cell,GridMap.INVALID_CELL_ITEM)
	placement.refresh_cell(Vector3i(8,0,0))
	towers.controller.rebuild()
	manager.refresh()
	check(cross.geometry_damage_bonus == 0,"Removing the branch retracts junction damage")
	scene.queue_free()
	await get_tree().process_frame
	# A reproducible in-game recipe uses only the five authored shapes.
	scene = Fixture.session()
	add_child(scene)
	await settle(scene)
	towers = scene.get_node("TowerMap")
	manager = Manager.new()
	manager.name = "GeometryBonuses"
	scene.add_child(manager)
	tower = towers.place_card(Fixture.card("tee","ballista"),Vector3i(8,0,1),0)
	check(tower != null and tower.geometry_range_extension == 0,"A three-cell T alone does not reach the long-line threshold")
	var extension: DefenseTower = towers.place_card(Fixture.card("straight","sentry"),Vector3i(7,0,-4),1)
	await settle(scene)
	check(extension != null and tower.geometry_range_extension == 1,"Authored T plus rotated corridor trigger the long-line bonus through normal placement")
	cross = towers.place_card(Fixture.card("tee","crossfire"),Vector3i(7,0,1),0)
	check(cross != null and is_equal_approx(cross.geometry_damage_bonus,0.1),"Authored junction next to the original road triggers the second bonus")
	scene.queue_free()
	await get_tree().process_frame
	var output := {"checks":checks,"failures":failures}
	FileAccess.open(Artifacts.path("construction/geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("CONSTRUCTION_GEOMETRY:",JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)
