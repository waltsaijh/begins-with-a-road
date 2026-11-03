extends Node
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
const Fixture = preload("res://tests/construction/fixture.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _ready() -> void: run.call_deferred()
func frames(count := 2) -> void:
	for i in count: await get_tree().process_frame

func run() -> void:
	var catalog := Catalog.new()
	var total := 0
	for key in Catalog.KEYS:
		print("TOWER_VISUAL_RULES: checking ",key)
		var definition := Catalog.tower(key)
		var options := definition.preset_candidates()
		check(options.size() == (1 if key == "barracks" else 4),key+" has accepted production count")
		total += options.size()
		for option in options:
			var preset := option.resolve_preset()
			var card := BuildCard.from_parts(definition,preset)
			check(card.configuration_error().is_empty(),key+" valid saved recipe")
			check(catalog.card_error(card).is_empty(),key+" accepted by the base playground group")
			if key == "barracks": continue
			for turn in 4:
				var session := Fixture.session(0); session.get_node("CardPlacement").cards.clear(); add_child(session); await frames()
				var towers: Node3D = session.get_node("TowerMap")
				var tower: DefenseTower = towers.place_card(card,Vector3i(8,0,7),turn)
				check(tower != null,key+" places actual saved recipe at turn "+str(turn))
				if tower == null: session.free(); continue
				var preview: Node3D = session.get_node("CardPlacement/Preview")
				preview.show_at(session.get_node("TileMap"),card,Vector3i(8,0,7),turn,true)
				var expected: Array[Vector2i] = []
				for offset in tower.influence_offsets(): expected.append(tower.grid_cell+offset)
				check(preview.range_cells == expected,key+" preview and threat share body geometry")
				check(tower.occupied_cells.size() == preset.tower_footprint.size(),key+" all body cells are one tower")
				var local := tower.to_local(tower.combat_origin())
				if key in ["mortar","crossfire"]:
					var average := Vector2.ZERO
					for cell in tower.body_cells(): average += Vector2(cell)
					average /= 4.0
					check(Vector2(local.x,local.z).is_equal_approx(average),key+" firing center is the independent four-cell average")
				if key == "broadside":
					check(tower.attack_offsets().size() == 12,"Broadside has exactly twelve tiles")
					for y in 2:
						for x in [-3,-2,-1,1,2,3]: check(tower.covers_cell(tower.grid_cell+BuildCard.rotate_cell(Vector2i(x,y),turn)),"Broadside covers independent 2x3 bank expectation")
					check(not tower.covers_cell(tower.grid_cell+BuildCard.rotate_cell(Vector2i(0,-1),turn)),"Broadside excludes bow")
				if key == "ballista":
					check(tower.attack_offsets().size() == 4,"Ballista retains four forward cells")
					for distance in range(1,5): check(tower.covers_cell(tower.grid_cell+BuildCard.rotate_cell(Vector2i(0,-distance),turn)),"L-body ballista stays on main forward lane")
				var portal: Node = session.get_node("PortalMap")
				var revision: int = portal.revision
				var occupied := tower.occupied_cells.duplicate()
				tower.health *= 0.5; tower.next_attack_time = 9.5
				for level in [2,3]:
					check(tower.upgrade() and tower.level == level,key+" upgrades without replacement")
					check(tower._visual.find_child("Level"+str(level),true,false).visible,key+" exposes level assembly")
					check(tower.occupied_cells == occupied and portal.revision == revision and tower.next_attack_time == 9.5 and is_equal_approx(tower.health/tower.max_health,0.5),key+" upgrade preserves geometry, cooldown and health ratio")
				if key == "sentry":
					tower.unlimited_levels = true; check(tower.upgrade() and tower.level == 4,"Unlimited sentry stats retain Lv3 visual cap")
				session.free(); await frames(1)
	check(total == 21,"Exactly 20+1 production recipes")
	var session := Fixture.session(0); add_child(session); await frames()
	var shop: Node = session.get_node("CardPlacement/Shop")
	var seen := {}
	for card in shop.roll_cards(600):
		check(catalog.card_error(card).is_empty(),"Production random draw belongs to same editor group")
		seen[card.tower.name_key+"|"+card.tile_preset.stable_id()] = true
	check(seen.size() == 21,"Actual weighted shop draw reaches all 21 recipes")
	session.free()
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open(Artifacts.path("tower_visuals/rules.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t"))
	print("TOWER_VISUAL_RULES:"+JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
