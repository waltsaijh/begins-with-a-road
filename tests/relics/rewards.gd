extends Node3D
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Fixture = preload("res://tests/fixtures/portal_fixture.gd")
var failures: Array[String] = []
class CountMap extends Node3D:
	var towers := {}
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void: run.call_deferred()
func run() -> void:
	var manager := RunRelics.new()
	add_child(manager)
	check(manager.catalog.entries.size() == 21, "Exactly 17 exclusive and 4 generic relics")
	var unique := {}
	for relic in manager.catalog.entries:
		check(relic.configuration_error().is_empty() and not unique.has(relic.id), "Valid unique relic: "+str(relic.id))
		unique[relic.id] = true
	for i in 200:
		var options := manager.options()
		check(options.size() == 3 and options[0].tower == null and options[0] != options[1] and options[1] != options[2] and options[0] != options[2], "Generic guarantee and no duplicate options")
	for relic in manager.catalog.entries:
		if relic.tower != null:
			check(manager.acquire(relic) and not manager.acquire(relic), "Exclusive acquisition once: "+str(relic.id))
	for relic in manager.options(): check(relic.tower == null, "Owned exclusives excluded")
	var cells: Array[Vector2i] = []
	for y in 12:
		for x in 12: cells.append(Vector2i(x,y))
	var scene := Fixture.scene_for(cells,Vector2i(0,0),Vector2i(11,11))
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
		if not scene.get_node("PortalMap").computing: break
	var towers: Node = scene.get_node("TowerMap")
	var relics: RunRelics = towers.relics
	var definition: TowerDefinition = load("res://assets/data/towers/sentry.tres")
	var card := BuildCard.from_parts(definition,definition.first_tile_preset())
	var a: DefenseTower = towers.place_card(card,Vector3i(3,0,3))
	for i in 100: check(relics.options()[1].tower == definition, "Related slot follows present tower")
	# Sparse tower types remain represented; weights grow by sqrt, not linearly.
	var sample := RunRelics.new()
	add_child(sample)
	var count_map := CountMap.new()
	add_child(count_map)
	sample.tower_map = count_map
	var histogram := {}
	var sizes := [6,5,3,1]
	var types := ["sentry","mortar","crossfire","ballista"]
	for i in types.size():
		var other: TowerDefinition = load("res://assets/data/towers/"+types[i]+".tres")
		for j in sizes[i]:
			var instance := DefenseTower.new()
			instance.definition = other
			count_map.towers[count_map.towers.size()] = instance
	for i in 2000:
		var options := sample.options()
		check(options[1].tower != null, "Weak slot draws a present exclusive")
		var key: String = options[1].tower.name_key
		histogram[key] = int(histogram.get(key,0))+1
	check(histogram.size() == 4 and int(histogram.get("tower.ballista.name",0)) > 250, "One-tower type retains substantial weak-pool probability in 6/5/3/1 fixture")
	for instance: DefenseTower in count_map.towers.values(): instance.free()
	sample.tower_map = null
	count_map.queue_free()
	check(is_equal_approx(relics.catalog.weak_base_weight+relics.catalog.weak_count_weight*sqrt(1.0),1.25), "Single-tower weak weight remains meaningful")
	check((relics.catalog.weak_base_weight+relics.catalog.weak_count_weight*sqrt(6.0))/1.25 < 1.3, "Six towers do not get six times the weak weight")
	relics.acquire(relics.catalog.find(&"global_damage"))
	var b: DefenseTower = towers.place_card(card,Vector3i(7,0,7))
	check(is_equal_approx(a.damage,definition.default_damage*1.1) and a.damage == b.damage, "Global effect applies to existing and future towers")
	relics.acquire(relics.catalog.find(&"protagonist"))
	for i in 4: check(a.upgrade(), "Protagonist unlocks real upgrade path")
	check(a.level == 5 and b.unlimited_levels, "Unlimited only affected towers")
	var shop: Node = scene.get_node("CardPlacement/Shop")
	var coins: int = shop.coins
	relics.acquire(relics.catalog.find(&"gold"))
	check(shop.coins == coins+20, "Immediate gold")
	var price: int = shop.reroll_price
	relics.acquire(relics.catalog.find(&"reroll_discount"))
	check(shop.reroll_price == maxi(0,price-1), "Actual reroll cost discounted")
	check(relics.remove(relics.catalog.find(&"reroll_discount")) and shop.reroll_price == price, "Removing discount restores reroll price")
	check(relics.remove(relics.catalog.find(&"global_damage")) and is_equal_approx(b.damage,definition.default_damage), "Removing global damage refreshes existing towers")
	check(relics.remove(relics.catalog.find(&"protagonist")) and a.level == 5 and not a.unlimited_levels and not a.upgrade(), "Removing protagonist preserves level but restores upgrade cap")
	check(not relics.remove(relics.catalog.find(&"protagonist")), "Removing unowned relic is a no-op")
	var ui: CanvasLayer = load("res://scenes/relics/relic_choice.tscn").instantiate()
	add_child(ui)
	ui.setup(relics)
	check(ui.begin() and ui.offers.size() == 3, "Reward UI has three cards")
	check(ui.choose(ui.offers[0]) and not ui.choose(ui.offers[1]), "No double acquisition")
	await get_tree().create_timer(0.3).timeout
	check(not ui.choosing and not ui.modal.visible, "Selection completes")
	ui.queue_free()
	scene.queue_free()
	await get_tree().process_frame
	var fresh := RunRelics.new()
	add_child(fresh)
	check(fresh.held.is_empty(), "Run state is instance local")
	var output := {"stage":"3B","failures":failures}
	FileAccess.open(Artifacts.path("relics/rewards.json"),FileAccess.WRITE).store_string(JSON.stringify(output))
	print("REWARDS:",JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)
