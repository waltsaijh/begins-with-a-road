extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class Wave extends Node:
	var active := true
	var alive := 0
	var enemies: Array[Node3D] = []
	func living_enemies() -> Array[Node3D]: return enemies.filter(func(e): return is_instance_valid(e) and e.can_be_targeted())
var failures: Array[String] = []
var checks := 0
var scene: Node3D
var towers: Node
var combat: Node
var wave: Wave
var map: GridMap
var next_id := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func world(at: Vector2i, height := 0.0) -> Vector3: return map.to_global(map.map_to_local(Vector3i(at.x,0,at.y))+Vector3.UP*height)
func build(key: String, at: Vector2i) -> DefenseTower:
	var d: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
	var t: DefenseTower = towers.place_card(BuildCard.from_parts(d,TilePreset.new()),Vector3i(at.x,0,at.y))
	check(t != null,"place "+key)
	return t
func enemy(key: String, at: Vector2i) -> Node3D:
	var e := Enemy.new()
	e.troop = TroopCatalog.find(key)
	e.max_health = e.troop.max_health
	e.health = e.max_health
	scene.add_child(e)
	e.follow(next_id,{"cells":PackedVector2Array([Vector2(at),Vector2(at+Vector2i(8,0))])},PackedVector3Array([world(at,e.troop.flight_height),world(at+Vector2i(8,0),e.troop.flight_height)]))
	next_id += 1
	e.set_process(false)
	wave.enemies.append(e)
	wave.alive += 1
	combat._index.rebuild(wave.living_enemies(),map)
	return e
func clear() -> void:
	combat.enemy_abilities.clear()
	for e in wave.enemies:
		if is_instance_valid(e): e.queue_free()
	wave.enemies.clear()
	wave.alive = 0
	combat.projectiles.clear()
	combat._index.rebuild(wave.enemies,map)
func _ready() -> void: run.call_deferred()
func run() -> void:
	var cells: Array[Vector2i] = []
	for y in 20:
		for x in 24: cells.append(Vector2i(x,y))
	scene = Fixture.scene_for(cells,Vector2i.ZERO,Vector2i(23,19))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
		if not scene.get_node("PortalMap").computing: break
	towers = scene.get_node("TowerMap")
	combat = towers.combat
	map = scene.get_node("TileMap")
	combat.set_process(false)
	combat.barracks.set_process(false)
	combat.enemy_abilities.set_process(false)
	wave = Wave.new()
	add_child(wave)
	combat.wave = wave
	verify_guardian()
	clear()
	verify_heal()
	clear()
	verify_air()
	clear()
	verify_sabotage()
	clear()
	scene.queue_free()
	await get_tree().process_frame
	var output := {"checks":checks,"failures":failures}
	FileAccess.open(Artifacts.path("synergy/combat.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("SYNERGY_COMBAT:",JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)

func verify_guardian() -> void:
	var tower := build("ballista",Vector2i(4,5))
	var rat := enemy("rat_swarm",Vector2i(4,4))
	var guard := enemy("shield_guardian",Vector2i(4,3))
	check(tower.attack.select_target(combat,tower) == guard,"guardian overrides earlier/nearer rat for single target")
	tower.attack.fire(combat,tower,tower.attack.select_target(combat,tower))
	check(rat.health == rat.max_health and guard.health < guard.max_health,"same-lane guardian absorbs a shot that would hit rat")
	guard.global_position = world(Vector2i(5,4))
	combat._index.rebuild(wave.living_enemies(),map)
	check(tower.attack.select_target(combat,tower) == rat,"out-of-shape guardian never taunts")
	tower.attack.fire(combat,tower,tower.attack.select_target(combat,tower))
	check(rat.health < rat.max_health,"separating guardian lets unchanged single-target damage reach rat")
	guard.global_position = world(Vector2i(4,1))
	combat._index.rebuild(wave.living_enemies(),map)
	check(tower.attack.select_target(combat,tower) == rat,"inside attack range but outside taunt radius")
	guard.global_position = world(Vector2i(4,3))
	var second := enemy("shield_guardian",Vector2i(4,3))
	check(tower.attack.select_target(combat,tower) == guard,"equal guardians stable spawn order")
	second.abilities.taunt_priority = 2
	check(tower.attack.select_target(combat,tower) == second,"authored taunt priority wins")
	var armor_before: float = guard.health
	guard.take_damage(40)
	check(is_equal_approx(guard.health,armor_before-30),"guardian data-driven defense")
	var all := build("crossfire",Vector2i(5,4))
	var before_rat: float = rat.health
	var before_guard: float = guard.health
	all.attack.fire(combat,all,rat)
	check(rat.health < before_rat and guard.health < before_guard,"area-all fire still hits protected rat and guardian")
	var barracks := build("barracks",Vector2i(19,6))
	var first := enemy("rat_swarm",Vector2i(19,5))
	var blocked := enemy("shield_guardian",Vector2i(19,5))
	blocked.abilities.taunt_priority = 2
	blocked.engaged_by = scene
	var legal := enemy("shield_guardian",Vector2i(19,5))
	combat.barracks._process(0)
	var unit: Node3D
	for soldier in combat.barracks.units:
		if soldier.tower == barracks:
			soldier.release()
			unit = soldier
	unit.advance(0)
	check(unit.target == legal and first.engaged_by == null,"unavailable high-priority guardian cannot hide a second legal guardian from barracks")
	unit.release()

func verify_heal() -> void:
	var mage := enemy("blood_mage",Vector2i(11,4))
	var ally := enemy("shield_guardian",Vector2i(12,4))
	var far := enemy("heavy",Vector2i(17,4))
	ally.health = 50
	far.health = 50
	combat.enemy_abilities.advance(2.9)
	check(ally.health == 50,"healing waits full period")
	combat.enemy_abilities.advance(0.11)
	check(ally.health == 68 and far.health == 50,"heal only within radius")
	var other := enemy("blood_mage",Vector2i(11,5))
	mage.heal_clock = 0.1
	other.heal_clock = 0.1
	combat.enemy_abilities.advance(0.2)
	check(ally.health == 104,"multiple mages independently heal")
	ally.health = ally.max_health-1
	combat.enemy_abilities.advance(3)
	check(ally.health == ally.max_health,"healing capped at maximum")
	var dead := enemy("rat_swarm",Vector2i(11,4))
	dead.take_damage(100)
	check(dead.heal(100) == 0 and not dead.can_be_targeted(),"cannot resurrect dead enemy")

func verify_air() -> void:
	var mortar := build("mortar",Vector2i(11,11))
	var flying := enemy("winged_beast",Vector2i(11,10))
	var ground := enemy("rat_swarm",Vector2i(11,10))
	check(mortar.attack.select_target(combat,mortar) == ground,"ordinary mortar excludes flying targets")
	var before: float = flying.health
	mortar.attack.fire(combat,mortar,ground)
	combat.enabled = false
	combat._process(5)
	check(flying.health == before,"ordinary mortar splash cannot damage flying")
	towers.relics.acquire(towers.relics.catalog.find(&"air_strike"))
	check(mortar.attack.select_target(combat,mortar) == flying,"Air Strike unlocks flying targeting")
	mortar.attack.fire(combat,mortar,flying)
	combat._process(5)
	check(flying.health < before,"Air Strike sphere hits actual altitude")
	var barracks := build("barracks",Vector2i(16,12))
	flying.global_position = world(Vector2i(16,11),1.2)
	var airborne: Array[Node3D] = [flying]
	combat._index.rebuild(airborne,map)
	combat.barracks._process(0)
	for unit in combat.barracks.units:
		if unit.tower == barracks:
			unit.advance(0.5)
			check(unit.target == null and flying.engaged_by == null,"flying cannot be intercepted")
	for id in ["sentry","ballista","crossfire","broadside"]:
		var t := DefenseTower.new()
		t.definition = load("res://assets/data/towers/"+id+".tres")
		scene.add_child(t)
		check(t.can_attack_target(flying),id+" retains explicit anti-air eligibility")
		t.queue_free()

func verify_sabotage() -> void:
	var tower := build("sentry",Vector2i(3,13))
	tower.upgrade()
	var sab := enemy("saboteur",Vector2i(3,12))
	var route: Dictionary = sab.route.duplicate(true)
	var roads := map.get_used_cells()
	var old_definition := tower.definition
	combat.enemy_abilities.advance(6)
	check(sab.cast_remaining == 1 and not tower.is_disabled(),"visible windup before disabling")
	check(sab.skill_progress == 0 and is_instance_valid(sab.ability_visual),"caster ring and skill progress initialized")
	combat.enemy_abilities.advance(0.5)
	check(not tower.is_disabled() and is_equal_approx(sab.skill_progress,0.5),"windup advances without early disable")
	combat.enemy_abilities.advance(0.5)
	check(tower.is_disabled() and tower._disable_icon.visible,"tower disabled with visible cue")
	check(tower.level == 2 and tower.definition == old_definition and roads == map.get_used_cells() and route == sab.route,"disable preserves upgrade, definition, roads and trip")
	combat.enabled = true
	var shots: int = combat.shots_fired
	combat._process(1)
	check(combat.shots_fired == shots,"disabled tower cannot shoot")
	combat.enemy_abilities.advance(2.4)
	check(tower.is_disabled(),"disabled for authored duration")
	combat.enemy_abilities.advance(0.2)
	check(not tower.is_disabled() and not tower._disable_icon.visible,"duration expires and indicator clears")
	tower.next_attack_time = 0
	for i in 20: combat._process(0.1)
	check(combat.shots_fired > shots,"normal attack resumes")
	var second := enemy("saboteur",Vector2i(3,12))
	var first_source := enemy("saboteur",Vector2i(3,12))
	tower.apply_disable(first_source,2.5)
	tower.apply_disable(second,2.5)
	check(tower._disables.size() == 2,"two live sabotage sources coexist")
	tower.advance_disable(2.6)
	check(not tower.is_disabled(),"multiple disables take maximum, never summed")
	tower.apply_disable(second,2.5)
	second.take_damage(1000)
	check(not tower.is_disabled(),"source death immediately releases its disable")
	var third := enemy("saboteur",Vector2i(3,12))
	tower.apply_disable(third,2.5)
	combat.enemy_abilities.clear()
	check(not tower.is_disabled() and third.cast_target == null,"wave cleanup clears disable and cast")
	third.sabotage_clock = 0
	combat.enemy_abilities.advance(0)
	third.global_position = world(Vector2i(23,18))
	combat.enemy_abilities.advance(1)
	check(third.cast_target == null and not tower.is_disabled(),"moving out of range cancels windup")
	var b := towers.towers[Vector2i(16,12)] as DefenseTower
	b.apply_disable(third,2.5)
	combat.barracks._process(0.1)
	for unit in combat.barracks.units:
		if unit.tower == b: check(unit.target == null,"disabled barracks releases and stops friendly attacks")
