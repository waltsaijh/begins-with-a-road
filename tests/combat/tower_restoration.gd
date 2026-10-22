extends Node3D
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Combat = preload("res://scripts/combat/combat_system.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
class Towers extends Node3D:
	var towers := {}
class Wave extends Node:
	var alive := 0
	var active := false
	var enemies: Array[Node3D] = []
	func living_enemies() -> Array[Node3D]: return enemies.filter(func(e): return is_instance_valid(e) and e.can_be_targeted())
var failures := 0
var map: GridMap
var wave: Wave
var towers: Towers
var combat: Node
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func enemy(id: int,point: Vector3) -> Node3D:
	var e := Enemy.new()
	add_child(e)
	e.enemy_id = id
	e.global_position = point
	e.health = 100
	e.max_health = 100
	wave.enemies.append(e)
	wave.alive += 1
	return e
func _ready() -> void: verify.call_deferred()
func verify() -> void:
	map = GridMap.new()
	map.cell_size = Vector3.ONE
	add_child(map)
	wave = Wave.new()
	add_child(wave)
	towers = Towers.new()
	add_child(towers)
	combat = Combat.new()
	combat.map = map
	combat.wave = wave
	combat.tower_map = towers
	add_child(combat)
	combat.set_process(false)
	var tower := DefenseTower.new()
	tower.definition = TowerDefinition.new()
	tower.definition.default_damage = 8
	tower.definition.attack_radius = 3
	add_child(tower)
	var a := enemy(0,Vector3(2,0,0))
	var b := enemy(1,Vector3(2.8,0,0))
	var c := enemy(2,Vector3(0.2,0,0))
	combat._index.rebuild(wave.living_enemies(),map)
	var attack := VolleyAttack.new()
	attack.mode = VolleyAttack.Mode.SPLASH
	attack.mortar_visual = true
	check(attack.select_target(combat,tower) == a,"Restored tower did not preserve oldest-spawn target priority")
	attack.fire(combat,tower,a)
	check(a.health == 92 and b.health == 92 and c.health == 100,"Mortar immediate exact-distance splash incorrect")
	combat._process(0.2)
	check(a.health == 92 and b.health == 92,"Mortar visual impact applied damage twice")
	attack.mode = VolleyAttack.Mode.ALL
	attack.mortar_visual = false
	attack.fire(combat,tower,a)
	check(a.health == 84 and b.health == 84 and c.health == 92,"Crossfire did not hit every valid enemy")
	attack.mode = VolleyAttack.Mode.SINGLE
	attack.circular_range = false
	var area := TowerAttackArea.new()
	area.offsets = [Vector2i(2,0)]
	tower.definition.attack_area = area
	check(attack.select_target(combat,tower) == a,"Directional targeting ignored attack offsets")
	for key: String in ["mortar","ballista","broadside","crossfire","barracks"]:
		var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
		check(definition != null and definition.configuration_error().is_empty(),"Restored resource invalid: "+key)
		check(definition.first_tile_preset() != null,"Restored tower has no eligible preset: "+key)
		var visual := definition.model.instantiate()
		add_child(visual)
		check(visual.get_node_or_null("RecoilAssembly") != null,"Original recoil assembly lost: "+key)
		if key != "barracks": check(visual.shot_sound != null,"Original synthesized shot missing: "+key)
		visual.queue_free()
	verify_restored_attacks()
	await verify_card_placement()
	await verify_barracks()
	var output := {"failures":failures,"stage":"B4","rendered":DisplayServer.get_name() != "headless"}
	FileAccess.open(Artifacts.path("combat/tower_restoration.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("TOWER_RESTORATION:"+JSON.stringify(output))
	get_tree().quit(1 if failures else 0)

func verify_restored_attacks() -> void:
	for key: String in ["mortar","ballista","broadside","crossfire"]:
		for old in wave.enemies: old.queue_free()
		wave.enemies.clear()
		var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
		var tower := DefenseTower.new()
		tower.definition = definition
		add_child(tower)
		towers.towers[Vector2i.ZERO] = tower
		var first := enemy(0,Vector3(2,0,0))
		var second := enemy(1,Vector3(2.8,0,0))
		var outside := enemy(2,Vector3(10,0,0))
		if key == "ballista":
			first.position = Vector3(0.5,0,-1.5)
			second.position = Vector3(1.5,0,-1.5)
		if key == "broadside":
			first.position = Vector3(-1.5,0,0.5)
			second.position = Vector3(2.5,0,0.5)
		if key == "crossfire":
			first.position = Vector3(0.5,0,0)
			second.position = Vector3(1.5,0,0)
		var shots: int = combat.shots_fired
		var bursts: int = combat.visuals.restored_bursts.bursts.size()
		combat._process(0.01)
		check(combat.shots_fired == shots+1 and first.health == 100-definition.default_damage,"Actual combat did not fire restored resource: "+key)
		check(second.health == (100-definition.default_damage if key in ["mortar","crossfire"] else 100),"Restored single/all/splash distinction lost: "+key)
		check(outside.health == 100,"Restored attack hit outside range: "+key)
		check(tower._visual.pulse == 1 and tower._visual.shot_sound != null,"Restored recoil/audio event missing: "+key)
		check(not combat.visuals.restored_bursts.bursts.is_empty(),"Original muzzle burst missing: "+key)
		check(tower._visual.muzzles().size() == (6 if key == "broadside" else (4 if key == "crossfire" else 1)),"Original multi-muzzle metadata lost: "+key)
		check(combat.visuals.restored_bursts.bursts.size()-bursts == (3 if key == "broadside" else (4 if key == "crossfire" else 1)),"Original firing-side muzzle flashes incorrect: "+key)
		var before: float = first.health
		combat._process(0.2)
		check(first.health == before,"Visual flight or cooldown inflicted extra damage: "+key)
		towers.towers.clear()
		tower.queue_free()

func verify_card_placement() -> void:
	var cells: Array[Vector2i] = []
	for y in 11:
		for x in 11: cells.append(Vector2i(x,y))
	var scene := Fixture.scene_for(cells,Vector2i(0,0),Vector2i(10,10))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
		if not scene.get_node("PortalMap").computing: break
	var cards: Node = scene.get_node("CardPlacement")
	var tower_map: Node = scene.get_node("TowerMap")
	for key: String in ["mortar","ballista","broadside","crossfire","barracks"]:
		var definition: TowerDefinition = load("res://assets/data/towers/"+key+".tres")
		for candidate in definition.tile_preset_candidates: check(candidate.resolve_preset() != null,"Invalid restored candidate: "+key)
		for turns in 4:
			var card := BuildCard.from_parts(definition,definition.first_tile_preset())
			check(cards.add_card(card),"Restored card could not enter normal hand: "+key)
			cards.select_card(cards.cards.size()-1)
			cards.turns = turns
			var anchor := Vector3i(5,0,5)
			var error: String = tower_map.validate_card(card,anchor,turns)
			check(error.is_empty(),"Restored rotated card placement rejected: "+key+error)
			cards.preview.show_at(scene.get_node("TileMap"),card,anchor,turns,error.is_empty())
			check(cards.preview.ghost != null and cards.preview.range_cells == definition.attack_cells_at(Vector2i(5,5),turns),"Restored model/range preview differs from definition: "+key)
			var before: int = cards.cards.size()
			var placed: DefenseTower = cards.place_selected(anchor)
			check(placed != null and placed.rotation_steps == turns and cards.cards.size() == before-1,"Restored normal hand commit failed: "+key)
			tower_map.remove_tower(anchor)
			await get_tree().process_frame
	scene.queue_free()
	await get_tree().process_frame

func verify_barracks() -> void:
	var cells: Array[Vector2i] = []
	for y in 6:
		for x in 9: cells.append(Vector2i(x,y))
	var scene := Fixture.scene_for(cells,Vector2i(0,2),Vector2i(8,2))
	var actual_wave: Node = scene.get_node("EnemyWave")
	actual_wave.auto_start = false
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
		if not scene.get_node("PortalMap").computing: break
	actual_wave.set_process(false)
	var tower_map: Node = scene.get_node("TowerMap")
	tower_map.combat.set_process(false)
	var allies: Node = tower_map.combat.barracks
	allies.set_process(false)
	var definition: TowerDefinition = load("res://assets/data/towers/barracks.tres")
	var card := BuildCard.from_parts(definition,definition.first_tile_preset())
	check(not tower_map.validate_card(card,Vector3i(30,0,30)).is_empty(),"Barracks could create land instead of requiring road")
	for turns in 4:
		check(tower_map.validate_card(card,Vector3i(4,0,3),turns).is_empty(),"Barracks rotation lost its legal home")
	var owner: DefenseTower = tower_map.place_card(card,Vector3i(4,0,3))
	check(owner != null,"Barracks could not be placed through normal card commit")
	if owner == null: return
	allies._process(0)
	check(allies.units.size() == 2,"Barracks did not deploy exactly two friendly slots")
	var unit: Node3D = allies.units[0]
	check(unit.home == Vector2i(4,2) and not tower_map.occupied.has(unit.home),"Friendly home became a navigation obstacle")
	check(not tower_map.validate_card(card,Vector3i(4,0,2)).is_empty(),"New tower could cover an existing soldier home")
	var foe := Enemy.new()
	foe.troop = load("res://assets/data/troops/soldier.tres")
	scene.add_child(foe)
	foe.max_health = 100
	foe.health = 100
	var start: Vector3 = allies.world(Vector2i(4,2))
	var route := {"cells":PackedVector2Array([Vector2(4,2),Vector2(5,2),Vector2(6,2)])}
	foe.follow(123,route,PackedVector3Array([start,allies.world(Vector2i(5,2)),allies.world(Vector2i(6,2))]))
	foe.set_process(false)
	actual_wave._living[foe] = true
	actual_wave.active = true
	var original: Dictionary = foe.route.duplicate(true)
	var points: PackedVector3Array = foe.waypoints.duplicate()
	allies._process(0.01)
	check(foe.engaged_by == unit,"Friendly failed to intercept nearby enemy")
	var position := foe.global_position
	var next: int = foe._next
	foe._process(0.5)
	check(foe.global_position == position and foe._next == next and foe.route == original and foe.waypoints == points,"Engagement mutated or advanced fixed trip")
	var paused_health: float = unit.health
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	check(unit.health == paused_health and foe.global_position == position,"Pause advanced friendly contact combat")
	allies._process(1.0)
	check(foe.health == 96 and unit.health == 35,"Friendly attack or enemy counterattack values incorrect")
	unit.take_damage(100)
	check(unit.dead and foe.engaged_by == null,"Friendly death did not release enemy")
	foe._process(0.1)
	check(foe.global_position != position and foe.route == original,"Released enemy did not resume original route")
	unit.advance(4.9)
	check(unit.dead,"Friendly respawned too soon")
	unit.advance(0.1)
	check(not unit.dead and unit.health == 40 and unit.global_position == unit.home_position,"Friendly failed 5-second full-health respawn")
	foe.global_position = start
	allies._process(0.01)
	check(foe.engaged_by == unit,"Respawned friendly failed to re-engage")
	foe.take_damage(1000)
	check(unit.target == null and foe.engaged_by == null,"Enemy death left a friendly engagement lock")
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var seen := {}
	for rolled: BuildCard in shop.roll_cards(6): seen[rolled.tower.name_key] = true
	check(seen.size() == 6,"Equal tower shuffle bag omitted a restored type")
	var weighted := definition.duplicate(true) as TowerDefinition
	var disabled := weighted.tile_preset_candidates[0].duplicate()
	disabled.weight = 0
	var enabled := TilePresetCandidate.new()
	enabled.preset_path = "res://assets/data/tile_presets/bridge.tres"
	enabled.weight = 9
	weighted.tile_preset_candidates.assign([disabled,enabled])
	var rng := RandomNumberGenerator.new()
	for i in 10: check(weighted.roll_tile_preset(rng) == load(enabled.preset_path),"Per-tower candidate weights were ignored")
	tower_map.remove_tower(Vector3i(4,0,3))
	var unit_ref: WeakRef = weakref(unit)
	allies._process(0)
	check(allies.units.is_empty() and foe.engaged_by == null,"Tower removal left friendly state or blocked enemy")
	actual_wave.active = false
	scene.queue_free()
	await get_tree().process_frame
	check(unit_ref.get_ref() == null,"Unload retained a friendly instance")
