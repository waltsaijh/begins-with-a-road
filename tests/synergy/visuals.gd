extends Node3D
## 偵查兵痕跡、被癱瘓的塔變暗、兵營友軍血條的同畫面檢查，可匯出至 Web 目視比對。
## 邏輯結果印成 SYNERGY_VISUALS:{...}；畫面保持開啟供截圖。
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const RoadTrail = preload("res://scripts/enemies/abilities/road_trail.gd")
class Wave extends Node:
	var active := true
	var alive := 0
	var enemies: Array[Node3D] = []
	func living_enemies() -> Array[Node3D]: return enemies.filter(func(e): return is_instance_valid(e) and e.can_be_targeted())
var failures: Array[String] = []
var scene: Node3D
var map: GridMap
var wave: Wave
var combat: Node

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func world(at: Vector2i) -> Vector3: return map.to_global(map.map_to_local(Vector3i(at.x,0,at.y)))

func enemy(key: String, at: Vector2i) -> Node3D:
	var e := Enemy.new()
	e.troop = TroopCatalog.find(key)
	e.max_health = e.troop.max_health
	e.health = e.max_health
	scene.add_child(e)
	e.follow(wave.enemies.size(),{"cells":PackedVector2Array([Vector2(at),Vector2(at+Vector2i(1,0))])},PackedVector3Array([world(at),world(at+Vector2i(1,0))]))
	e.set_process(false)
	wave.enemies.append(e)
	return e

func _ready() -> void: run.call_deferred()

func run() -> void:
	var cells: Array[Vector2i] = []
	for y in 8:
		for x in 10: cells.append(Vector2i(x,y))
	scene = Fixture.scene_for(cells,Vector2i.ZERO,Vector2i(9,7))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	for i in 30: await get_tree().process_frame
	var towers: Node = scene.get_node("TowerMap")
	map = scene.get_node("TileMap")
	combat = towers.combat
	combat.set_process(false)
	combat.barracks.set_process(false)
	combat.enemy_abilities.set_process(false)
	wave = Wave.new()
	add_child(wave)
	combat.wave = wave
	var place := func(key: String, at: Vector2i) -> DefenseTower:
		return towers.place_card(BuildCard.from_parts(load("res://assets/data/towers/"+key+".tres"),TilePreset.new()),Vector3i(at.x,0,at.y))
	var normal: DefenseTower = place.call("sentry",Vector2i(2,2))
	var disabled: DefenseTower = place.call("sentry",Vector2i(4,2))
	place.call("barracks",Vector2i(7,2))
	# 偵查兵沿第 5 列走出一條 L 形痕跡。
	var scout := enemy("scout",Vector2i(1,5))
	var path := [Vector2i(1,5),Vector2i(2,5),Vector2i(3,5),Vector2i(4,5),Vector2i(5,5),Vector2i(5,6),Vector2i(6,6),Vector2i(7,6)]
	for at: Vector2i in path:
		scout.global_position = world(at)
		combat.enemy_abilities.advance(0)
	var rat := enemy("rats",Vector2i(3,5))
	combat.enemy_abilities.advance(0)
	var bonus: float = scout.ability(TrailAbility).speed_bonus
	check(is_equal_approx(rat._speed_factor(0),1.0+bonus) and rat.effect_icons.has(&"haste"),"痕跡上的地面敵人依設定加速並顯示圖示")
	check(is_equal_approx(scout._speed_factor(0),1.0),"偵查兵不吃自己的痕跡")
	var trail: Node = combat.enemy_abilities.service(RoadTrail)
	check(trail.buffs.size() == path.size(),"痕跡標記了走過的每一格")
	# 癱瘓右邊的哨塔。
	disabled.apply_disable(scout,60.0)
	for i in 20: await get_tree().process_frame
	var mesh: MeshInstance3D = disabled.find_children("*","MeshInstance3D",true,false)[0]
	check(mesh.material_override == disabled._dim_material and is_equal_approx(float(disabled._dim_material.get_shader_parameter(&"dim")),0.45),"被癱瘓的塔改用自己的材質副本並變暗")
	check(normal._dim_material == null,"正常的塔不變暗")
	# 兵營友軍受傷並轉向。
	combat.barracks._process(0)
	var units: Array = combat.barracks.units
	check(units.size() == 2,"兵營部署兩名友軍")
	for i in units.size():
		units[i].take_damage(units[i].settings.health*(0.7 if i == 0 else 0.25))
		units[i].rotation.y = 1.2*i
	check(units.size() == 2 and is_equal_approx(units[0].health_fill.mesh.size.x,0.35*0.3),"友軍血條依比例縮短")
	var camera := Camera3D.new()
	add_child(camera)
	var focus := world(Vector2i(4,4))
	camera.global_position = focus+Vector3(0.6,6.0,5.2)
	camera.look_at(focus)
	camera.current = true
	# 5 秒後切到兵營友軍特寫（總覽視角中友軍被兵營擋住）。
	get_tree().create_timer(5.0).timeout.connect(func():
		if units.is_empty(): return
		var soldier: Vector3 = units[0].global_position
		camera.global_position = soldier+Vector3(1.1,1.2,1.5)
		camera.look_at(soldier+Vector3.UP*0.5))
	var output := {"failures":failures,"web":OS.has_feature("web")}
	print("SYNERGY_VISUALS:",JSON.stringify(output))
	if not OS.has_feature("web") and DisplayServer.get_name() == "headless": get_tree().quit(0 if failures.is_empty() else 1)
