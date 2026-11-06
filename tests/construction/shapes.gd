extends Node
## Pure recipe checks; topology commits and input are separate integration tests.
const Sentry = preload("res://assets/data/towers/sentry.tres")
const Fixture = preload("res://tests/fixtures/card_fixture.gd")
const SHAPES := {
	"straight": {"roads": 7, "port_cell": Vector2i(-3, -1), "mask": 10},
	"corner": {"roads": 9, "port_cell": Vector2i(-2, 0), "mask": 5},
	"tee": {"roads": 9, "port_cell": Vector2i(0, -1), "mask": 11},
	"cross": {"roads": 9, "port_cell": Vector2i(1, -1), "mask": 15},
	"pocket": {"roads": 13, "port_cell": Vector2i(-3, -3), "mask": 6},
}
var failures := 0
var checks := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error(message)

func verify() -> void:
	var ids := {}
	var origin := Vector2i(11, -8)
	for shape: String in SHAPES:
		var preset: TilePreset = load("res://assets/data/construction/presets/%s.tres" % shape)
		var card := BuildCard.from_parts(Sentry, preset)
		check(card.configuration_error().is_empty(), "%s rejected: %s" % [shape, card.configuration_error()])
		check(not preset.stable_id().is_empty() and not ids.has(preset.stable_id()), "%s has missing/duplicate stable ID" % shape)
		ids[preset.stable_id()] = true
		check(preset.road_offsets.size() == SHAPES[shape].roads, "%s road count changed" % shape)
		check(preset.explicit_road_ports[SHAPES[shape].port_cell] == SHAPES[shape].mask, "%s authored junction/endpoint mask is wrong" % shape)
		for turn in 4:
			var roads := card.road_ports(origin, turn)
			var occupied := card.ground_cells(origin, turn)
			check(card.allows_rotation(turn) and occupied.size() == SHAPES[shape].roads + 1, "%s rotation %d footprint incomplete" % [shape, turn])
			check(card.tower_anchor(origin, turn) == origin and card.tower_cells(origin, turn) == [origin], "%s tower moved from its declared origin" % shape)
			check(not roads.has(origin), "%s rotation %d overlaps tower and road" % [shape, turn])
			for cell: Vector2i in preset.road_offsets:
				# Direct coordinate formulas form an independent quarter-turn oracle.
				var transformed: Vector2i = [cell, Vector2i(-cell.y, cell.x), -cell, Vector2i(cell.y, -cell.x)][turn]
				check(roads.has(origin + transformed) and origin + transformed in occupied, "%s lost rotated road %s" % [shape, cell])
				var mask: int = preset.explicit_road_ports[cell]
				for direction in 4:
					check(bool(roads.get(origin + transformed, 0) & (1 << ((direction + turn) % 4))) == bool(mask & (1 << direction)), "%s rotated ports disagree with geometry" % shape)
			check(card.road_ports(origin, turn + 4) == roads and card.ground_cells(origin, turn + 4) == occupied, "%s rotations fail wraparound" % shape)
	_verify_errors()
	_verify_legacy()
	_verify_pair()
	var output := "res://.godot/test-results/construction"
	DirAccess.make_dir_recursive_absolute(output)
	var preset: TilePreset = load("res://assets/data/construction/presets/corner.tres")
	var saved := output.path_join("shape-roundtrip.tres")
	check(ResourceSaver.save(preset, saved) == OK, "Could not save compound preset")
	var roundtrip: TilePreset = ResourceLoader.load(saved, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(roundtrip != null and roundtrip.stable_id() == preset.stable_id() and roundtrip.explicit_road_ports == preset.explicit_road_ports and roundtrip.occupied_offsets == preset.occupied_offsets, "Compound data did not survive resource serialization")
	var report := {"checks": checks, "failures": failures, "shapes": SHAPES.keys(), "all_rotations": true, "legacy": true, "pairing": true}
	var file := FileAccess.open(output.path_join("shapes.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CONSTRUCTION_SHAPES_CHECK:" + JSON.stringify(report))
	get_tree().quit(1 if failures else 0)

func _verify_errors() -> void:
	var base: TilePreset = load("res://assets/data/construction/presets/straight.tres")
	var preset: TilePreset = base.duplicate(true)
	preset.explicit_road_ports[Vector2i(0, -1)] = 2
	check(not preset.configuration_error().is_empty(), "One-sided internal port accepted")
	preset = base.duplicate(true)
	preset.explicit_road_ports[Vector2i(0, -1)] = 16
	check(not preset.configuration_error().is_empty(), "Out-of-range port mask accepted")
	preset = base.duplicate(true)
	preset.explicit_road_ports.erase(Vector2i(0, -1))
	check(not preset.configuration_error().is_empty(), "Road without explicit port accepted")
	preset = base.duplicate(true)
	preset.road_offsets.append(preset.road_offsets[0])
	check(not preset.configuration_error().is_empty(), "Duplicate road accepted")
	preset = base.duplicate(true)
	preset.occupied_offsets.erase(Vector2i(0, -1))
	check(not preset.configuration_error().is_empty(), "Road outside footprint accepted")
	preset = base.duplicate(true)
	preset.occupied_offsets.erase(Vector2i.ZERO)
	check(not BuildCard.from_parts(Sentry, preset).configuration_error().is_empty(), "Tower outside declared footprint accepted")
	preset = base.duplicate(true)
	preset.tower_offset = Vector2i(0, -1)
	check(not BuildCard.from_parts(Sentry, preset).configuration_error().is_empty(), "Physical tower-road overlap accepted")
	preset = base.duplicate(true)
	preset.allowed_rotations = [0, 2]
	var card := BuildCard.from_parts(Sentry, preset)
	check(card.allows_rotation(0) and card.allows_rotation(2) and card.allows_rotation(-2) and not card.allows_rotation(1), "Allowed rotations ignored")
	preset.allowed_rotations = []
	check(not card.configuration_error().is_empty(), "Empty rotation set accepted")
	preset = base.duplicate(true)
	preset.tower_offset = Vector2i(1, 1)
	preset.occupied_offsets.erase(Vector2i.ZERO)
	preset.occupied_offsets.append(Vector2i(1, 1))
	card = BuildCard.from_parts(Sentry, preset)
	check(card.configuration_error().is_empty() and card.tower_anchor(Vector2i(8, 9), 1) == Vector2i(7, 10), "Tower offset does not rotate with its recipe")

func _verify_legacy() -> void:
	for name in ["corner", "bridge", "flank"]:
		var card := Fixture.card(name)
		check(card.configuration_error().is_empty() and card.road_ports(Vector2i.ZERO).is_empty(), "Legacy geometry unexpectedly uses explicit ports")
		for turn in 4:
			check(card.ground_cells(Vector2i.ZERO, turn).size() == card.tile_preset.road_offsets.size() + 1, "Legacy geometry changed")
	var card := Fixture.card("bridge")
	card.tile_preset.road_offsets.append(Vector2i.ZERO)
	check(card.configuration_error().is_empty() and card.ground_cells(Vector2i.ZERO).size() == 4, "Legacy tower-road overlap compatibility lost")
	for path in ResourceLoader.list_directory("res://assets/data/tile_presets"):
		if not path.ends_with(".tres"): continue
		var preset: TilePreset = load("res://assets/data/tile_presets/" + path)
		check(preset.configuration_error().is_empty() and not preset.has_explicit_ports() and not preset.stable_id().is_empty(), "Existing preset failed to load unchanged: " + path)
	var custom: TowerDefinition = Sentry.duplicate()
	var candidate := TilePresetCandidate.new()
	candidate.preset_path = "res://assets/data/construction/presets/straight.tres"
	candidate.weight = 1.0
	custom.tile_preset_candidates = [candidate]
	check(custom.roll_tile_preset(RandomNumberGenerator.new()).preset_id == "construction.straight.v1", "Existing weighted candidate pool cannot use compound recipes")

func _verify_pair() -> void:
	var card := BuildCard.from_parts(Sentry, load("res://assets/data/construction/presets/corner.tres"))
	var left := card.road_ports(Vector2i(-2, 0), 0)
	var right := card.road_ports(Vector2i(1, -2), 1)
	check(left.has(Vector2i(-4, 0)) and right.has(Vector2i(5, 0)), "Two-piece bypass misses initial straight road")
	check(bool(left.get(Vector2i(0, -4), 0) & 2) and bool(right.get(Vector2i(1, -4), 0) & 8), "Two-piece bypass has incompatible joining ports")
	check(not right.has(Vector2i(-2, 0)) and not left.has(Vector2i(1, -2)), "Two-piece bypass covers the other tower")
