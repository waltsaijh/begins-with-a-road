extends Node3D
const Fixture = preload("res://tests/construction/fixture.gd")
const Metrics = preload("res://tests/construction/geometry_metrics.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []
var results: Array = []

func _ready() -> void: run.call_deferred()

func settle(session: Node3D) -> void:
	for index in 120:
		await get_tree().process_frame
		if index > 2 and not session.get_node("PortalMap").computing: return

func run() -> void:
	for scenario in ["same_four_cards", "two_card_bypass", "reverse_two_card_bypass"]:
		for mode in 3:
			var session := Fixture.session(mode)
			add_child(session)
			await settle(session)
			var towers: Node = session.get_node("TowerMap")
			var entries: Array = []
			if scenario != "same_four_cards":
				entries = Fixture.batch_pair()
				if mode == 0:
					entries[0].card = Fixture.card("corner", "ballista", true)
					entries[1].card = Fixture.card("bridge", "crossfire", true)
				if scenario == "reverse_two_card_bypass": entries.reverse()
			else:
				for index in 4:
					entries.append({"card":Fixture.card("bridge" if mode == 0 else "pocket", "ballista" if index % 2 == 0 else "crossfire", mode == 0), "anchor":Vector3i(4 if index % 2 == 0 else 12, 0, 1 if index < 2 else -1), "turns":0 if index < 2 else 2})
			var steps: Array = []
			var commits := 0
			var successes := 0
			var before_cells: int = session.get_node("TileMap").get_used_cells().size()
			if mode == 2:
				for index in range(0, entries.size(), 2):
					var pair: Array = entries.slice(index, mini(index+2, entries.size()))
					for partial in pair.size():
						var plan: Dictionary = towers.construction_plan(pair.slice(0, partial+1), false)
						steps.append({"stage":index+partial, "accepted":plan.ok, "connected":bool(towers.construction_plan(pair.slice(0, partial+1), true).ok), "error":plan.error})
					var built: Array = towers.commit_construction(pair)
					commits += 1
					successes += built.size()
					await settle(session)
			else:
				for entry: Dictionary in entries:
					var previous: int = session.get_node("TileMap").get_used_cells().size()
					var error: String = towers.validate_card(entry.card, entry.anchor, entry.turns)
					var built: Node3D = towers.place_card(entry.card, entry.anchor, entry.turns) if error.is_empty() else null
					if built != null: successes += 1
					steps.append({"accepted":built != null, "error":error, "changed_cells":session.get_node("TileMap").get_used_cells().size()-previous})
					await settle(session)
			var result: Dictionary = Metrics.new().measure(session)
			var rotate_operations := 0
			for entry: Dictionary in entries: rotate_operations += posmod(int(entry.turns), 4)
			var added_ground: int = session.get_node("TileMap").get_used_cells().size()-before_cells
			result.merge({"scenario":scenario, "mode":Fixture.MODE_NAMES[mode], "cards_offered":entries.size(), "cards_built":successes, "steps":steps, "explicit_confirmations":commits, "operation_proxy":entries.size()*2+rotate_operations+commits, "rotation_key_presses":rotate_operations, "added_ground_cells":added_ground, "mean_added_ground_per_built_card":float(added_ground)/maxi(1, successes), "economy":"Direct authority placement; no purchasing or hand consumption claims", "human_usability":"NOT RUN"})
			results.append(result)
			if scenario == "same_four_cards" and successes != 4: failures.append("Four-card shape scenario rejected placement in mode %d" % mode)
			if scenario == "two_card_bypass" and mode == 2 and successes != 2: failures.append("Batch bypass failed")
			if scenario == "reverse_two_card_bypass" and mode > 0 and successes != 2: failures.append("Reverse immediate order should reach the same compound bypass")
			if result.route_enumeration_truncated: failures.append("Measurement route enumeration truncated")
			var file_name := "construction/comparison_%s_%d" % [scenario, mode]
			FileAccess.open(Artifacts.path(file_name+".svg"), FileAccess.WRITE).store_string(Metrics.svg(result, scenario+" / "+Fixture.MODE_NAMES[mode]))
			if DisplayServer.get_name() != "headless":
				await get_tree().create_timer(0.8).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(Artifacts.path(file_name+".png"))
			session.queue_free()
			await get_tree().process_frame
	var output := {"failures":failures, "cases":results, "rendered":DisplayServer.get_name() != "headless", "limits":"Scripted placements and operation proxies; human beauty, fun, interaction effort and full economy NOT RUN. Finite simple-path enumeration is independent of enemy candidate search."}
	FileAccess.open(Artifacts.path("construction/comparisons.json"), FileAccess.WRITE).store_string(JSON.stringify(output, "  "))
	print("CONSTRUCTION_COMPARISONS:", JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)
