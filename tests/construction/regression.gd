extends Node3D
const Fixture = preload("res://tests/construction/fixture.gd")
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []
var checks := 0

func _ready() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle(session: Node3D) -> void:
	for index in 120:
		await get_tree().process_frame
		if index > 2 and not session.get_node("PortalMap").computing: return
	check(false, "Construction topology settled in 120 frames")

func state(session: Node3D) -> Dictionary:
	var portal: Node = session.get_node("PortalMap")
	var towers: Node = session.get_node("TowerMap")
	var cards: Node = session.get_node("CardPlacement")
	return {"ground":session.get_node("TileMap").get_used_cells(), "snapshot":Snapshot.capture(session.get_node("TileMap"), towers.occupied), "occupied":towers.occupied.duplicate(), "towers":towers.towers.duplicate(), "history":portal.route_history.snapshots.duplicate(true), "history_revision":portal.route_history.revision, "cards":cards.cards.duplicate(), "coins":cards.get_node("Shop").coins}

func create_session() -> Node3D:
	var session := Fixture.session(2)
	add_child(session)
	await settle(session)
	var batch: Node3D = load("res://scripts/construction/construction_batch.gd").new()
	batch.name = "ConstructionBatch"
	session.add_child(batch)
	var geometry: Node = load("res://scripts/construction/geometry_bonuses.gd").new()
	geometry.name = "GeometryBonuses"
	session.add_child(geometry)
	return session

func pair_for(session: Node3D) -> Array:
	var pair := Fixture.batch_pair()
	pair[0].card = session.get_node("CardPlacement").cards[0]
	pair[1].card = session.get_node("CardPlacement").cards[1]
	return pair

func run() -> void:
	var session := await create_session()
	var batch: Node3D = session.get_node("ConstructionBatch")
	var cards: Node = session.get_node("CardPlacement")
	var portal: Node = session.get_node("PortalMap")
	var towers: Node = session.get_node("TowerMap")
	var wave: Node = session.get_node("EnemyWave")
	check(session.level.wave_count() == 6 and cards.cards.size() == 6 and cards.get_node("Shop").coins == 60 and cards.get_node("Shop").available, "Fixture has six manual waves, free test cards and complete subsidized opening shop")
	check(not wave.active and not session._wave_starting, "Preparation never auto-starts")
	var shop: Node = cards.get_node("Shop")
	var offers: Array = shop.offers.duplicate()
	session._on_start_requested()
	wave.start_allowed = false
	session._advance_wave_start(2.0)
	check(not session._wave_starting and not cards.input_suspended and shop.available and shop.offers == offers,"Late start failure restores preparation and original shop offers without a redeal")
	wave.start_allowed = true
	var initial := state(session)
	var baseline: Dictionary = WaveSpawnSchedule.build(wave.definition, portal, 23, false)
	check(not baseline.is_empty(), "Initial straight map schedules Soldier, Scout and Winged Beast")
	var pair := pair_for(session)
	var first: Dictionary = batch.stage(pair[0].card, pair[0].anchor, pair[0].turns, 0)
	check(first.ok and batch.entries.size() == 1, "Disconnected intermediate draft is accepted")
	check(not batch.validate().ok, "Disconnected final draft fails whole-batch validation")
	check(state(session) == initial, "Staging preserves cards, gold, official map, occupancy and route history")
	var preview_schedule: Dictionary = WaveSpawnSchedule.build(wave.definition, portal, 23, false)
	check(not preview_schedule.is_empty() and RoadFlowForecast.from_pending(preview_schedule.pending).all == RoadFlowForecast.from_pending(baseline.pending).all, "Draft preview does not alter formal schedule")
	var failed: Dictionary = batch.commit()
	check(not failed.ok and batch.entries.size() == 1 and state(session) == initial, "Failed commit retains editable draft with zero card/resource/world changes")
	session._on_start_requested()
	check(not session._wave_starting and not wave.active and not cards.input_suspended, "Actual start request refuses broken draft and leaves preparation editable")
	check(state(session) == initial, "Failed start cannot leak a partial construction")
	var moved: Dictionary = batch.move_entry(0, Vector3i(6, 0, 1), 0)
	check(moved.ok and batch.entries[0].anchor == Vector3i(6, 0, 1), "Pending tile can move")
	var rotated: Dictionary = batch.move_entry(0, Vector3i(6, 0, 1), 2)
	check(rotated.ok and batch.entries[0].turns == 2, "Pending tile can rotate")
	var pending_before: Array = batch.entries.duplicate(true)
	check(not batch.move_entry(0, Vector3i.ZERO, 0).ok and batch.entries == pending_before, "Illegal move onto entrance is rejected without losing previous draft")
	check(batch.remove_entry(0) and batch.entries.is_empty() and state(session) == initial, "Undo returns reservation and leaves all official state unchanged")
	check(batch.stage(pair[0].card, pair[0].anchor, 0, 0).ok, "First L may be staged again")
	check(not batch.stage(pair[0].card, Vector3i(2, 0, 2), 0, 0).ok and batch.entries.size() == 1, "One hand card cannot be reserved twice")
	check(batch.stage(pair[1].card, pair[1].anchor, 1, 1).ok and batch.validate().ok, "Second L repairs complete entrance-to-goal connectivity")
	check(not wave.start_wave() and not wave.active,"Direct EnemyWave start cannot bypass unconfirmed drafts")
	var predicted: Dictionary = RoadFlowForecast.from_pending(batch.validate().pending).all
	check(state(session) == initial, "Complete staged combination still does not publish topology/history")
	var committed: Dictionary = batch.commit()
	check(committed.ok and batch.entries.is_empty(), "Whole legal batch commits successfully")
	await settle(session)
	check(towers.towers.size() == 2 and cards.cards.size() == initial.cards.size()-2 and cards.get_node("Shop").coins == initial.coins, "Batch creates two towers, consumes exactly two owned cards and charges no extra Gold")
	check(portal.route_history.revision == initial.history_revision+1 and portal.route_history.snapshots.size() == initial.history.size()+1, "Only one final topology snapshot is recorded")
	check(Snapshot.connects_terminals(Snapshot.capture(session.get_node("TileMap"), towers.occupied), portal.terminal_cells()), "Committed reciprocal topology connects all active entrances")
	var canonical: Dictionary = portal.route_history.current.duplicate(true)
	var final_plan: Dictionary = WaveSpawnSchedule.build(wave.definition, portal, 91, true)
	check(RoadFlowForecast.from_pending(final_plan.pending).all == predicted,"Read-only pending forecast equals committed mixed troop quotas including geometry influence")
	check(not final_plan.is_empty() and final_plan.pending.size() == wave.definition.total_count(), "Final topology schedules every mixed troop")
	var shortest: Dictionary = portal.route_history.candidates(0, true)
	for member: Dictionary in final_plan.get("pending", []):
		check(_route_legal(member.route.cells, canonical), "Committed troop route uses reciprocal roads and avoids towers")
		if member.profile == TroopCatalog.find("scout"): check(member.route.birth_wave == 1, "Scout new bypass birth is this preparation wave")
		if member.profile == TroopCatalog.find("winged"): check(member.route.cells.size()-1 == shortest.distance, "Winged Beast uses actual shortest committed path")
	var upgrade_card := Fixture.card("cross", "ballista")
	cards.add_card(upgrade_card)
	var upgrade_index: int = cards.cards.size()-1
	var before_upgrade := state(session)
	var target: DefenseTower = towers.occupied[Vector2i(6, 0)]
	check(batch.stage(upgrade_card, Vector3i(6, 0, 0), 3, upgrade_index).ok and batch.commit().ok, "Same-definition pending card upgrades a confirmed tower")
	await settle(session)
	check(target.level == 2 and towers.towers.size() == 2 and cards.cards.size() == before_upgrade.cards.size()-1, "Upgrade consumes one card and preserves tower identity")
	check(Snapshot.capture(session.get_node("TileMap"), towers.occupied) == before_upgrade.snapshot and portal.route_history.snapshots == before_upgrade.history, "Upgrade ignores new card's roads and does not change route birth history")
	session.queue_free()
	await get_tree().process_frame
	# Reverse stage order must result in the same canonical final route history.
	session = await create_session()
	batch = session.get_node("ConstructionBatch")
	pair = pair_for(session)
	check(batch.stage(pair[1].card, pair[1].anchor, 1, 1).ok and batch.stage(pair[0].card, pair[0].anchor, 0, 0).ok and batch.commit().ok, "Reversed draft order is equally valid")
	await settle(session)
	check(session.get_node("PortalMap").route_history.current == canonical, "Scout history is independent of temporary placement order")
	session.queue_free()
	await get_tree().process_frame
	# One origin is on the far side of the temporary cut: checking only it would be wrong.
	session = Fixture.session(1)
	var terrain := session.level.terrain.instantiate() as GridMap
	Fixture.Endpoints.endpoint(terrain, Fixture.Endpoints.Start, Vector2i(8,0), "Start2")
	session.level.terrain = PackedScene.new()
	session.level.terrain.pack(terrain)
	terrain.free()
	session.level.acts[0].waves[0].groups[1].start_index = 1
	add_child(session)
	await settle(session)
	towers = session.get_node("TowerMap")
	pair = Fixture.batch_pair()
	check(not towers.construction_plan(pair.slice(0, 1), true).ok, "Whole-plan validation checks every entrance, including the severed first entrance")
	check(towers.construction_plan(pair, true).ok and towers.commit_construction(pair).size() == 2, "Repaired batch is legal with multiple active entrances")
	await settle(session)
	var multiple: Dictionary = WaveSpawnSchedule.build(session.get_node("EnemyWave").definition, session.get_node("PortalMap"), 17, false)
	var origins := {}
	for member: Dictionary in multiple.get("pending", []): origins[member.start_index] = true
	check(origins.size() == 2, "Committed multi-entry topology supports both assigned origins")
	session.queue_free()
	await get_tree().process_frame
	var output := {"checks":checks, "failures":failures, "rendered":DisplayServer.get_name() != "headless", "scope":"Batch logic and actual level start boundary. UI mouse/keyboard and rendering use input.tscn separately; geometry has its own tests."}
	FileAccess.open(Artifacts.path("construction/regression.json"), FileAccess.WRITE).store_string(JSON.stringify(output, "  "))
	print("CONSTRUCTION_REGRESSION:", JSON.stringify(output))
	get_tree().quit(0 if failures.is_empty() else 1)

func _route_legal(path: PackedVector2Array, snapshot: Dictionary) -> bool:
	var ports := {}
	for index in snapshot.ports.size(): ports[Vector2i(snapshot.cells[index*2], snapshot.cells[index*2+1])] = int(snapshot.ports[index])
	for index in range(path.size()-1):
		var a := Vector2i(path[index])
		var b := Vector2i(path[index+1])
		var delta := b-a
		var direction: int = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT].find(delta)
		if direction < 0 or not (ports.get(a, 0) & (1 << direction)) or not (ports.get(b, 0) & (1 << ((direction+2)%4))): return false
	return true
