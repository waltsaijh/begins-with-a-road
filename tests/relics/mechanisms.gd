extends Node3D
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Rules = preload("res://scripts/combat/relic_combat.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class Wave extends Node:
	var alive := 0
	var active := true
	var enemies: Array[Node3D] = []
	func living_enemies() -> Array[Node3D]: return enemies.filter(func(e): return is_instance_valid(e) and e.can_be_targeted())
var failures: Array[String] = []
var checks := 0
var scene: Node3D
var towers: Node
var combat: Node
var map: GridMap
var wave: Wave
var relics: RunRelics
var next_id := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func world(at: Vector2i, height := 0.0) -> Vector3: return map.to_global(map.map_to_local(Vector3i(at.x,0,at.y))+Vector3.UP*height)
func build(key: String, at: Vector2i, turns := 0) -> DefenseTower:
	var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
	var tower: DefenseTower = towers.place_card(BuildCard.from_parts(definition,definition.first_tile_preset()),Vector3i(at.x,0,at.y),turns)
	check(tower != null, "Place "+key)
	return tower
func acquire(id: StringName) -> void: check(relics.acquire(relics.catalog.find(id)), "Acquire "+str(id))
func enemy(at: Vector2i, size := "standard", tags: Array[StringName] = [&"ground"], height := 0.0) -> Node3D:
	var e := Enemy.new()
	e.troop = Troop.new()
	e.troop.body_size = size
	e.troop.tags = tags
	scene.add_child(e)
	e.follow(next_id, {"cells":PackedVector2Array([Vector2(at),Vector2(at+Vector2i(6,0))])}, PackedVector3Array([world(at,height),world(at+Vector2i(6,0),height)]))
	next_id += 1
	e.health = 1000
	e.max_health = 1000
	e.set_process(false)
	wave.enemies.append(e)
	wave.alive += 1
	combat._index.rebuild(wave.living_enemies(),map)
	return e
func clear_enemies() -> void:
	for e in wave.enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion(): e.queue_free()
	wave.enemies.clear()
	wave.alive = 0
	combat.projectiles.clear()
	combat._index.rebuild(wave.enemies,map)
func shoot(tower: DefenseTower, e: Node3D) -> void:
	tower.prepare_shot(e)
	tower.attack.fire(combat,tower,e)
func _ready() -> void: run.call_deferred()
func run() -> void:
	var cells: Array[Vector2i] = []
	for y in 20:
		for x in 24: cells.append(Vector2i(x,y))
	scene = Fixture.scene_for(cells,Vector2i(0,0),Vector2i(23,19))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
		if not scene.get_node("PortalMap").computing: break
	towers = scene.get_node("TowerMap")
	combat = towers.combat
	map = scene.get_node("TileMap")
	relics = towers.relics
	combat.set_process(false)
	combat.barracks.set_process(false)
	combat.enabled = false
	wave = Wave.new()
	add_child(wave)
	combat.wave = wave
	verify_mortar()
	clear_enemies()
	verify_crossfire()
	clear_enemies()
	verify_broadside()
	clear_enemies()
	verify_sentry()
	clear_enemies()
	verify_ballista()
	clear_enemies()
	verify_barracks()
	check(relics.held.size() == 17, "Every exclusive mechanism exercised")
	scene.queue_free()
	await get_tree().process_frame
	var output := {"stage":"3C/3D","checks":checks,"failures":failures}
	FileAccess.open(Artifacts.path("relics/mechanisms.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("MECHANISMS:",JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)

func verify_mortar() -> void:
	var mortar := build("mortar",Vector2i(3,4))
	var moving := enemy(Vector2i(5,4))
	var nearby := enemy(Vector2i(5,4))
	shoot(mortar,moving)
	var flight: float = combat.projectiles[0].duration
	check(moving.health == 1000 and nearby.health == 1000, "Mortar launch does no damage")
	combat._process(flight*0.5)
	check(moving.health == 1000, "No damage in flight")
	moving.global_position = world(Vector2i(8,4))
	combat._process(flight*0.6)
	check(moving.health == 1000 and nearby.health == 992, "Moving target misses, current blast occupant hit")
	combat._process(1)
	check(nearby.health == 992 and combat.projectiles.is_empty(), "Impact damage once")
	clear_enemies()
	var flying := enemy(Vector2i(5,4),"standard",[&"flying"],1.5)
	check(mortar.attack.select_target(combat,mortar) == null, "Mortar excludes flying without relic")
	acquire(&"air_strike")
	check(mortar.attack.select_target(combat,mortar) == flying, "Air Strike allows flying")
	var ground := enemy(Vector2i(5,4))
	shoot(mortar,flying)
	combat._process(combat.projectiles[0].duration+0.01)
	check(flying.health == 992 and ground.health == 1000, "Air blast uses altitude, not ground column")
	shoot(mortar,flying)
	var ordinary_duration: float = combat.projectiles[0].duration
	combat.projectiles.clear()
	acquire(&"assembled_cannon")
	shoot(mortar,flying)
	check(is_equal_approx(combat.projectiles[0].duration,ordinary_duration*2) and mortar.damage == 24 and mortar.attack_interval == 3, "Cannon changes real duration, damage and interval")
	combat.projectiles.clear()
	clear_enemies()
	acquire(&"explosive_shell")
	var victim := build("sentry",Vector2i(5,5))
	victim.health = 1
	var roads := map.get_used_cells()
	var e := enemy(Vector2i(5,4))
	var route: Dictionary = e.route.duplicate(true)
	var waypoints: PackedVector3Array = e.waypoints.duplicate()
	mortar.mortar_shots = 0
	for i in 2:
		shoot(mortar,e)
		check(combat.projectiles[-1].friendly == 0 and combat.projectiles[-1].radius == 1, "Only designated shell is special")
		combat.projectiles.clear()
	shoot(mortar,e)
	check(is_equal_approx(combat.projectiles[0].radius,1.8), "Third shell expands radius")
	var impacts_before: int = combat.visuals.restored_bursts.bursts.size()
	combat._process(combat.projectiles[0].duration+0.01)
	check(combat.visuals.restored_bursts.bursts.size() == impacts_before+1 and combat.visuals.impacts.is_empty(), "Mortar produces one impact effect")
	check(not towers.occupied.has(Vector2i(5,5)) and e.health == 976, "Special shell destroys friendly tower and damages enemy once")
	check(map.get_used_cells() == roads and e.route == route and e.waypoints == waypoints, "Friendly destruction preserves roads and fixed route")
	var last := enemy(Vector2i(5,4))
	shoot(mortar,last)
	last.take_damage(2000)
	check(not combat.projectiles.is_empty(), "Original target death retains shell")
	towers.remove_tower(Vector3i(3,0,4))
	combat._process(combat.projectiles[0].duration+0.01)
	check(e.health == 952, "Shell survives source and target death with launch damage snapshot")

func verify_crossfire() -> void:
	var a := build("crossfire",Vector2i(10,4))
	var b := build("crossfire",Vector2i(12,4))
	acquire(&"fuel_supply")
	check(is_equal_approx(a.damage,4*1.15) and is_equal_approx(b.damage,4*1.15), "Fuel sources never buff themselves or recurse")
	var c := build("crossfire",Vector2i(11,6))
	check(is_equal_approx(a.damage,4*1.3) and is_equal_approx(c.damage,4*1.3), "Multiple fixed fuel bonuses add")
	towers.remove_tower(Vector3i(11,0,6))
	check(is_equal_approx(a.damage,4*1.15), "Removal updates fuel aura")
	acquire(&"frost_ray")
	acquire(&"small_fry")
	var small := enemy(Vector2i(10,3),"small")
	var normal := enemy(Vector2i(11,3))
	shoot(a,small)
	check(is_equal_approx(1000-small.health,a.damage*1.75) and is_equal_approx(1000-normal.health,a.damage), "Small uses body tag and all-hit attack keeps per-target damage")
	var factor: float = small._speed_factor(0)
	shoot(a,small)
	check(small._speed_factor(0) < factor and normal.effect_icons.has(&"frost"), "Frost stacks on every valid victim")
	for i in 30: small.apply_frost(0.18,2,0.6)
	check(small._speed_factor(0) >= 0.4, "Diminishing frost never roots")
	small._speed_factor(2.01)
	check(small._speed_factor(0) == 1 and not small.effect_icons.has(&"frost"), "All frost stacks expire")

func verify_broadside() -> void:
	var ship := build("broadside",Vector2i(17,4),1)
	acquire(&"departure")
	acquire(&"rapid_fire")
	acquire(&"crew_concentration")
	var anchor := ship.global_transform
	var base: Node3D = ship._visual.get_node("FixedBase")
	var base_transform := base.global_transform
	var muzzle_before: Vector3 = ship._visual.muzzle_position()
	var before := map.get_used_cells()
	Rules.advance(combat,ship,1)
	check(ship.patrol_visual().position.x > 0 and ship.global_transform == anchor and base.global_transform == base_transform and map.get_used_cells() == before, "Cruise moves airship while retaining fixed base/anchor/orientation/roads")
	check(ship._visual.muzzle_position() != muzzle_before and ship.combat_origin() == ship.patrol_visual().global_position, "Muzzles and attack origin travel with airship")
	for muzzle in ship._visual.muzzles(): check(ship.patrol_visual().is_ancestor_of(muzzle), "All six barrels are mounted on airship")
	var preview_cells := relics.preview_cells(ship.definition,ship.grid_cell,ship.rotation_steps)
	for offset in ship.influence_offsets(): check(ship.grid_cell+offset in preview_cells, "Patrol preview and threat share the reachable firing footprint")
	for turns in 4:
		ship.rotation_steps = turns
		var right := BuildCard.rotate_cell(Vector2i(2,0),turns)
		var left := -right
		var a := enemy(ship.grid_cell+right)
		var b := enemy(ship.grid_cell+left)
		var valid: Array[Node3D] = combat.targets_for(ship)
		check(a in valid and not b in valid, "Right side follows rotation %d" % turns)
		ship.relic_clocks[&"rapid_fire"] = combat.elapsed
		Rules.advance(combat,ship,0)
		check(a.health < 1000 and b.health == 1000 and ship._visual.shot_count > 0, "Cruise + right-only rapid fire hits correct side")
		combat.elapsed += 0.3
		Rules.advance(combat,ship,0)
		check(ship.rapid_remaining == 0, "Rapid burst completes with multiple muzzle presentation")
		clear_enemies()
	check(is_equal_approx(ship.damage,ship.definition.default_damage*(1+ship.support_bonus)*2.5), "Crew damage multiplier")
	var removal_anchor := ship.global_transform
	ship.rapid_remaining = 2
	check(relics.remove(relics.catalog.find(&"departure")) and relics.remove(relics.catalog.find(&"rapid_fire")), "Cruise and rapid fire can be removed")
	check(is_zero_approx(ship.patrol_visual().position.x) and ship.rapid_remaining == 0 and not ship.relic_clocks.has(&"rapid_fire") and ship.global_transform == removal_anchor, "Removing cruise restores model and cancels burst without moving anchor")
	acquire(&"departure")
	acquire(&"rapid_fire")

func verify_sentry() -> void:
	var sentry := build("sentry",Vector2i(6,12))
	acquire(&"support_attack")
	acquire(&"protagonist")
	acquire(&"hunting")
	var preview: Node = scene.get_node("CardPlacement/Preview")
	preview.show_at(map,BuildCard.from_parts(sentry.definition,sentry.definition.first_tile_preset()),Vector3i(6,0,12),0,true)
	var expected: Array[Vector2i] = []
	for offset in sentry.attack_offsets(): expected.append(sentry.grid_cell+offset)
	check(preview.range_cells == expected, "Triple sentry range matches preview and targeting")
	check(sentry.upgrade() and sentry.upgrade() and sentry.upgrade() and sentry.level == 4, "Protagonist permits Lv4 through original growth")
	var normal := enemy(Vector2i(6,11))
	var large := enemy(Vector2i(6,10),"large")
	var boss := enemy(Vector2i(6,9),"large",[&"ground",&"boss"])
	sentry.relic_clocks[&"hunting"] = combat.elapsed
	Rules.advance(combat,sentry,0)
	check(not large.can_be_targeted() and normal.health == 1000 and boss.health == 1000, "Hunting prioritizes large non-boss")
	combat.elapsed += 8
	Rules.advance(combat,sentry,0)
	check(not normal.can_be_targeted() and boss.health == 1000, "Hunting falls back to ordinary enemy")
	combat.elapsed += 8
	var ready: float = sentry.relic_clocks[&"hunting"]
	Rules.advance(combat,sentry,0)
	check(boss.health == 1000 and sentry.relic_clocks[&"hunting"] == ready, "Boss-only situation does not consume execution")

func verify_ballista() -> void:
	var ballista := build("ballista",Vector2i(15,12))
	acquire(&"secret_mission")
	check(ballista.isolated and is_equal_approx(ballista.damage,30), "Isolated ballista damage")
	var barracks := build("barracks",Vector2i(16,14))
	check(not ballista.isolated and ballista.damage == 15, "Nearby Barracks counts as tower")
	towers.remove_tower(Vector3i(16,0,14))
	check(ballista.isolated and ballista.damage == 30, "Isolation refreshes on removal")
	acquire(&"powerful_shot")
	acquire(&"heavy_bolts")
	var a := enemy(Vector2i(15,11))
	var b := enemy(Vector2i(15,9))
	var off := enemy(Vector2i(16,10))
	# Give each a progressed immutable route so the hit can visibly rewind it.
	for e in [a,b]:
		e.follow(e.enemy_id,{"cells":PackedVector2Array([Vector2(15,7),Vector2(15,12)])},PackedVector3Array([world(Vector2i(15,7)),world(Vector2i(15,12))]))
		e.set_process(false)
	a.global_position = world(Vector2i(15,11))
	b.global_position = world(Vector2i(15,9))
	var a_before: Vector3 = a.global_position
	var route: Dictionary = a.route.duplicate(true)
	var points: PackedVector3Array = a.waypoints.duplicate()
	shoot(ballista,a)
	check(a.health == 1000, "Piercing bolt has real travel")
	combat._process(0.1)
	combat._process(0.1)
	combat._process(0.1)
	check(a.health == 970 and b.health == 970 and off.health == 1000, "Pierce hits collinear enemies once, excludes off-path enemy")
	check(a.global_position.distance_to(a_before) > 0.29 and a.route == route and a.waypoints == points, "Hit rewinds unchanged route")
	a.apply_slow(0.5,2)
	a.knock_back(1)
	check(a._slow_multiplier == 0.5 and a.route == route, "Repeat knockback coexists with slow")
	# Corner traversal is explicitly checked, not only a straight route.
	a.follow(99,route,PackedVector3Array([world(Vector2i(1,1)),world(Vector2i(2,1)),world(Vector2i(2,2))]))
	a.set_process(false)
	a._next = 2
	a.global_position = world(Vector2i(2,1))+Vector3(0,0,0.2)
	a.knock_back(0.5)
	check(a.global_position.is_equal_approx(world(Vector2i(2,1))-Vector3(0.3,0,0)) and a._next == 1, "Knockback follows corners instead of leaving road")

func verify_barracks() -> void:
	var barracks := build("barracks",Vector2i(20,15))
	combat.barracks._process(0)
	check(combat.barracks.units.size() == 2, "Base barracks has two slots")
	acquire(&"reinforcements")
	acquire(&"sharpshooter")
	combat.barracks._process(0)
	check(combat.barracks.units.size() == 3 and combat.barracks.units[2].home == Vector2i(20,14), "Existing barracks gains third legal soldier")
	var third: Node3D = combat.barracks.units[2]
	var foe := enemy(Vector2i(20,12))
	combat.barracks._process(0.01)
	check(foe.health == 988 and third.ranged_timer > 0, "All three soldiers fire ranged shots while unengaged")
	foe.global_position = third.home_position
	third.ranged_timer = 1
	combat._index.rebuild(wave.living_enemies(),map)
	third.advance(0.01)
	check(foe.engaged_by == third, "Third soldier retains interception")
	foe.knock_back(0.3)
	check(foe.engaged_by == null and third.target == null, "Knockback releases both sides of engagement")
	third.take_damage(1000)
	third.advance(5)
	check(not third.dead and third.health == third.settings.health and third.global_position == third.home_position, "Third soldier full death/respawn cycle")
	var fresh := build("barracks",Vector2i(19,18))
	combat.barracks._process(0)
	check(combat.barracks.units.size() == 6 and fresh.deployment.count == 3, "Future barracks inherits both relics")
	foe.engaged_by = third
	third.target = foe
	check(relics.remove(relics.catalog.find(&"reinforcements")), "Reinforcements can be removed")
	combat.barracks._process(0)
	check(combat.barracks.units.size() == 4 and third.is_queued_for_deletion() and third.target == null and foe.engaged_by != third, "Removing reinforcements removes both third slots and releases their engagement")
	check(relics.remove(relics.catalog.find(&"sharpshooter")) and not barracks.has_relic(&"sharpshooter"), "Removing sharpshooter stops future ranged attacks")
	acquire(&"reinforcements")
	combat.barracks._process(0)
	check(combat.barracks.units.size() == 6, "Reacquiring reinforcements restores third slots")
	acquire(&"sharpshooter")
	wave.active = false
	combat.barracks._process(0)
	check(foe.engaged_by == null, "Wave end releases engagement")
