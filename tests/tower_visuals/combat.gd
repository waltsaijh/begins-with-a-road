extends Node
const Fixture = preload("res://tests/construction/fixture.gd")
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _ready() -> void: run.call_deferred()

func run() -> void:
	for key in ["ballista","broadside","mortar","crossfire"]:
		for turn in 4:
			var session := Fixture.session(0); add_child(session)
			await get_tree().process_frame
			session.process_mode = Node.PROCESS_MODE_DISABLED
			var map: GridMap = session.get_node("TileMap")
			var towers: Node = session.get_node("TowerMap")
			var definition := Catalog.tower(key)
			var card := BuildCard.from_parts(definition,definition.first_tile_preset())
			var tower: DefenseTower = towers.place_card(card,Vector3i(8,0,7),turn)
			var combat: Node = towers.combat
			var center := TowerBodyGeometry.origin(definition,tower.body_cells())
			var inside := center+Vector2(definition.attack_radius-0.01,0)
			var outside := center+Vector2(definition.attack_radius+0.01,0)
			if key == "ballista": inside = Vector2(0,-3); outside = Vector2(1,-3)
			if key == "broadside": inside = Vector2(2,1); outside = Vector2(2,2)
			var enemies: Array[Node3D] = []
			for point in [inside,outside]:
				var enemy := Enemy.new(); session.add_child(enemy); enemy.health = 100; enemy.max_health = 100; enemy.enemy_id = enemies.size()
				enemy.global_position = tower.to_global(Vector3(point.x,0,point.y)); enemies.append(enemy)
			combat._index.rebuild(enemies,map)
			var targets: Array[Node3D] = combat.targets_for(tower)
			check(targets.size() == 1 and targets[0] == enemies[0],key+" actual targeting respects body boundary at rotation "+str(turn))
			tower.prepare_shot(enemies[0])
			var muzzle := tower.muzzle_position()
			check(muzzle.is_finite(),key+" resolves an actual model muzzle")
			if key == "ballista": check(tower.to_local(muzzle).z < 0 and absf(tower.to_local(muzzle).x) < 0.01,"Ballista muzzle stays on the forward rail")
			if key == "mortar":
				check(absf(tower.to_local(muzzle).x-center.x) < 0.01,"Mortar barrel is centered on the complete platform")
			tower.attack.fire(combat,tower,enemies[0]); tower.present_shot(enemies[0],combat.visuals)
			if key == "mortar":
				check(combat.projectiles.size() == 1 and enemies[0].health == 100,"Mortar retains delayed impact")
				var shot: Dictionary = combat.projectiles[0]
				check(shot.start.is_equal_approx(muzzle) and shot.end.is_equal_approx(enemies[0].global_position),"Mortar snapshots new muzzle and actual target location")
				combat._impact_mortar(shot)
			check(is_equal_approx(enemies[0].health,100-definition.default_damage),key+" fires authored damage")
			if key != "mortar": check(enemies[1].health == 100,key+" does not hit outside coverage")
			check(tower._visual.pulse == 1,key+" retains recoil feedback")
			if key == "broadside":
				tower.relic_effects[&"departure"] = {}; tower.set_patrol_offset(1.0)
				enemies[0].global_position = tower.to_global(Vector3(4,0,1)); combat._index.rebuild(enemies,map)
				check(combat.targets_for(tower).has(enemies[0]),"Departure translates attack anchor once, including second bank row")
				tower.relic_effects[&"crew_concentration"] = {}; tower._invalidate_attack_area()
				enemies[1].global_position = tower.to_global(Vector3(-1,0,1)); combat._index.rebuild(enemies,map)
				check(not combat.targets_for(tower).has(enemies[1]),"Crew relic excludes moving port bank")
				check(tower._visual.get_node("FixedBase").position == Vector3.ZERO,"Departure keeps fixed platform stationary")
			session.free()
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open(Artifacts.path("tower_visuals/combat.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t"))
	print("TOWER_BODY_COMBAT:"+JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
