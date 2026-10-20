extends Node
const Shop = preload("res://scripts/cards/shop/card_shop.gd")
const Sentry = preload("res://assets/data/towers/sentry.tres")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func candidate(path: String, weight: float) -> TilePresetCandidate:
	var option := TilePresetCandidate.new()
	option.preset_path = path
	option.weight = weight
	return option

func verify() -> void:
	var card := TestCards.card("bridge")
	check(card.ground_cells(Vector2i.ZERO).size() == 4 and card.configuration_error().is_empty(), "Composed card lost its original footprint")
	check(not BuildCard.from_parts(Sentry, null).configuration_error().is_empty(), "Missing preset was accepted")
	var custom := TilePreset.new()
	custom.prefix_key = "tile_preset.test_custom.prefix"
	custom.road_offsets = [Vector2i.UP]
	card.tile_preset = custom
	var changed := [0]
	card.changed.connect(func(): changed[0] += 1)
	custom.prefix_key = "tile_preset.test_renamed.prefix"
	custom.road_offsets = [Vector2i.LEFT, Vector2i.UP]
	check(changed[0] == 2 and card.localized_prefix() == tr(custom.prefix_key) and card.ground_cells(Vector2i.ZERO).size() == 3, "Preset edits did not reach existing cards")
	var directory := "user://weighted_presets_check_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var alpha := directory.path_join("alpha.tres")
	var beta := directory.path_join("beta.tres")
	var gamma := directory.path_join("gamma.tres")
	check(ResourceSaver.save(TestCards.card("corner").tile_preset, alpha) == OK, "Could not save alpha preset")
	check(ResourceSaver.save(TestCards.card("bridge").tile_preset, beta) == OK, "Could not save beta preset")
	check(ResourceSaver.save(TestCards.card("flank").tile_preset, gamma) == OK, "Could not save gamma preset")
	var first: TowerDefinition = Sentry.duplicate()
	first.tile_preset_candidates = [candidate(alpha, 1.0), candidate(beta, 3.0), candidate(gamma, 0.0), candidate(alpha, -1.0), candidate(alpha, NAN), candidate(alpha, INF), candidate(directory.path_join("missing.tres"), 1000.0), null]
	var second: TowerDefinition = Sentry.duplicate()
	second.name_key = "tower.crossfire.name"
	second.card_price = 7
	second.tile_preset_candidates = [candidate(gamma, 1.0)]
	var shop := Shop.new()
	var repeat := Shop.new()
	shop.catalog = [first, second]
	repeat.catalog = shop.catalog.duplicate()
	shop._rng.seed = 42
	repeat._rng.seed = 42
	var cards: Array[BuildCard] = shop.roll_cards(1024)
	var repeated: Array[BuildCard] = repeat.roll_cards(1024)
	check(cards.size() == 1024 and repeated.size() == 1024, "Roll did not produce complete cards")
	var first_total := 0
	var beta_total := 0
	for i in cards.size():
		var rolled := cards[i]
		check(rolled.tower == repeated[i].tower and rolled.tile_preset == repeated[i].tile_preset, "Same shop seed changed the weighted rolls")
		check(rolled.price == rolled.tower.card_price, "Card price did not come from the tower")
		if rolled.tower == first:
			first_total += 1
			check(rolled.tile_preset.resource_path in [alpha, beta], "Disabled or missing candidate was rolled")
			if rolled.tile_preset.resource_path == beta: beta_total += 1
		else:
			check(rolled.tile_preset.resource_path == gamma, "A tower rolled another tower's candidate")
		if i % 2 == 1:
			check(cards[i-1].tower != rolled.tower and cards[i-1] != rolled, "Tower bag omitted a type or reused a card instance")
	check(first_total > 0 and absf(float(beta_total)/first_total-0.75) < 0.08, "Weights 1:3 did not produce approximately 25%:75%")
	var held_preset := cards[0].tile_preset
	shop.roll_cards(4)
	check(cards[0].tile_preset == held_preset, "Reroll changed an existing card's preset")
	var tower_path := directory.path_join("tower.tres")
	check(ResourceSaver.save(first, tower_path) == OK, "Could not save weighted tower")
	var loaded: TowerDefinition = ResourceLoader.load(tower_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.tile_preset_candidates[0].preset_path == alpha and loaded.tile_preset_candidates[1].weight == 3.0, "Candidate references/weights did not survive saving")
	check(candidate(tower_path, 1.0).resolve_preset() == null, "Non-preset resource was accepted")
	first.tile_preset_candidates = [candidate(alpha, 1.0e308), candidate(beta, 1.0e308)]
	for i in 16:
		check(first.roll_tile_preset(shop._rng) != null, "Large finite weights overflowed the draw")
	first.tile_preset_candidates = [candidate(alpha, 1.0), candidate(beta, 3.0)]
	DirAccess.remove_absolute(alpha)
	for i in 16:
		check(first.roll_tile_preset(shop._rng).resource_path == beta, "Removed preset was rolled from cache")
	DirAccess.remove_absolute(beta)
	check(first.first_tile_preset() == null and first.roll_tile_preset(shop._rng) == null, "Missing candidate pool remained eligible")
	var remaining: Array[BuildCard] = shop.roll_cards(4)
	check(remaining.size() == 4, "Unavailable tower prevented a valid tower from being drawn")
	for rolled in remaining: check(rolled.tower == second, "Unavailable tower stayed in the bag")
	shop.free()
	repeat.free()
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.get_node("EnemyWave").auto_start = false
	add_child(scene)
	await get_tree().process_frame
	var placement: Node = scene.get_node("CardPlacement")
	var live_shop: Node = placement.get_node("Shop")
	check(placement.cards.size() == 3 and placement.hand.views.size() == 3, "Starting hand was not rolled from tower candidates")
	for rolled: BuildCard in placement.cards:
		var allowed := false
		for option: TilePresetCandidate in rolled.tower.tile_preset_candidates:
			if option != null and option.resolve_preset() == rolled.tile_preset: allowed = true
		check(allowed, "Starting card did not use its tower's candidate pool")
	live_shop.catalog.assign([first])
	live_shop.coins = 20
	live_shop.available = true
	live_shop.view.set_available(true)
	live_shop.open_shop()
	var deals: int = live_shop.deals
	check(not live_shop.reroll() and live_shop.coins == 20 and live_shop.deals == deals and not live_shop.view.rerolling, "Empty candidate pool charged for an impossible reroll")
	scene.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(gamma)
	DirAccess.remove_absolute(tower_path)
	DirAccess.remove_absolute(directory)
	print("TILE_PRESETS_CHECK:"+JSON.stringify({"failures": failures, "tower_candidates": true, "weighted_rolls": true, "save_and_delete": true, "live_edits": true, "starting_hand": true, "empty_pool": true}))
	get_tree().quit(1 if failures else 0)
