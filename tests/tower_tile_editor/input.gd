extends Node
const Playground = preload("res://tests/tower_tile_editor/playground.tscn")
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
class TestViewport extends SubViewport:
	signal mouse_entered
	signal mouse_exited
var viewport: SubViewport
var game: Node3D
var checks := 0
var failures: Array[String] = []
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func frames(n := 4) -> void:
	for i in n: await get_tree().process_frame
func center(control: Control) -> Vector2: return control.get_global_transform_with_canvas()*(control.size*0.5)
func motion(point: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new(); event.position = point; event.button_mask = mask; viewport.push_input(event,true)
func left(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0; viewport.push_input(event,true)
func click(point: Vector2) -> void:
	motion(point); left(point,true); left(point,false); await frames()
func key(code: Key, ctrl := false, unicode := 0) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.ctrl_pressed = ctrl; event.unicode = unicode; event.pressed = true; viewport.push_input(event,true)
	event = event.duplicate(); event.pressed = false; viewport.push_input(event,true); await frames(1)
func choose(control: OptionButton, index: int) -> void:
	await click(center(control)); await key(KEY_HOME)
	for i in index+1: await key(KEY_DOWN)
	await key(KEY_ENTER); await frames()
func draw(cell: Vector2i) -> Vector2: return game.editor.grid.get_global_transform_with_canvas()*game.editor.grid.center(cell)
func paint(cell: Vector2i) -> void: await click(draw(cell))
func point(cell: Vector3i) -> Vector2:
	var map: GridMap = game.session.get_node("TileMap")
	return game.session.get_node("Camera3D").unproject_position(map.to_global(map.map_to_local(cell)))
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	check(image != null and image.get_size() == viewport.size,"Rendered viewport available: "+name)
	image.save_png(Artifacts.path("tower_tile_editor/"+name+".png"))
func run() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	viewport = TestViewport.new(); viewport.size = Vector2i(1440,900); viewport.gui_embed_subwindows = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(viewport)
	game = Playground.instantiate(); game.catalog_root = Artifacts.path("tower_tile_editor/ui_catalog_"+str(Time.get_ticks_usec())); viewport.add_child(game); await frames(20); viewport.mouse_entered.emit()
	await click(center(game.edit_button))
	check(game.editor.visible and get_tree().paused,"Editor opens from real button and freezes test world")
	await choose(game.editor.tower_picker,2)
	check(game.editor.key == "broadside","Real dropdown selects existing Broadside definition")
	await click(center(game.editor.new_button))
	var draft_id: String = game.editor.draft.preset_id
	await choose(game.editor.tower_picker,0); await key(KEY_ESCAPE)
	check(game.editor.key == "broadside" and game.editor.tower_picker.selected == 2 and game.editor.draft.preset_id == draft_id,"Cancel discard keeps draft and restores the correct tower selector")
	await click(center(game.editor.name_edit)); await key(KEY_A,true)
	for c in "Long Hull": await key(KEY_NONE,false,c.unicode_at(0))
	await click(draw(Vector2i(-1,0)))
	motion(draw(Vector2i(-1,0))); left(draw(Vector2i(-1,0)),true); await frames(2); motion(draw(Vector2i(1,0)),MOUSE_BUTTON_MASK_LEFT); await frames(2); left(draw(Vector2i(1,0)),false); await frames()
	check(game.editor.draft.tower_footprint.size() == 3,"Fast real drag paints connected 1x3 hull")
	await click(center(game.editor.undo_button)); check(game.editor.draft.tower_footprint.size() == 2,"Undo restores whole stroke")
	await click(center(game.editor.redo_button)); check(game.editor.draft.tower_footprint.size() == 3,"Redo restores complete hull")
	await choose(game.editor.brush_picker,1)
	motion(draw(Vector2i(-2,-1))); left(draw(Vector2i(-2,-1)),true); await frames(2); motion(draw(Vector2i(2,-1)),MOUSE_BUTTON_MASK_LEFT); await frames(2); left(draw(Vector2i(2,-1)),false); await frames()
	await paint(Vector2i(-2,0)); await paint(Vector2i(2,0))
	await choose(game.editor.facing,3)
	check(game.editor.draft.road_offsets.size() == 7 and game.editor.draft.facing_steps == 3 and not game.editor.save_button.disabled,"One-sided authored bypass validates without an automatic ring")
	await click(center(game.editor.manual))
	await click(center(game.editor.port_checks[0])); await click(center(game.editor.port_checks[2]))
	await choose(game.editor.brush_picker,4); await paint(Vector2i(0,-1))
	check(game.editor.draft.explicit_road_ports[Vector2i(0,-1)] == 10 and game.editor.draft.explicit_road_ports[Vector2i(-2,0)] == 15,"Real interface brush changes local ports and preserves unused outward ports")
	await choose(game.editor.rotation_picker,1)
	check(game.editor.grid.turns == 1 and game.editor.draft.tower_footprint.size() == 3,"Grid rotates preview without altering authored geometry")
	await choose(game.editor.rotation_picker,0)
	await click(center(game.editor.weight.get_line_edit())); await key(KEY_A,true); await key(KEY_3,false,51); await key(KEY_ENTER)
	await click(center(game.editor.default_check))
	await click(center(game.editor.save_button)); await click(center(game.editor.reload_button))
	check(game.editor.weight.value == 3 and game.editor.default_check.button_pressed and game.editor.draft.explicit_road_ports[Vector2i(0,-1)] == 10,"UI save/reload preserves weight, default, ID and interfaces")
	await capture("editor_long_hull")
	await click(center(game.editor.add_button)); await frames(12)
	var cards: Node = game.session.get_node("CardPlacement")
	var towers: Node = game.session.get_node("TowerMap")
	var portal: Node = game.session.get_node("PortalMap")
	var shop: Node = cards.get_node("Shop")
	check(not game.editor.visible and cards.cards.size() == 1 and not get_tree().paused,"Save/add button persists and immediately supplies a real hand card")
	check(cards.cards[0].tile_preset.display_name == "Long Hull","Typed name persists to playable card")
	var id: String = cards.cards[0].tile_preset.preset_id
	check(Catalog.new(game.editor.catalog.root).rows("broadside").any(func(row): return row.id == id),"Fresh catalog finds saved UI preset")
	check(shop.tile_preset_overrides[Catalog.tower("broadside")].any(func(option): return option.preset_path.ends_with(id+".tres")),"Saved preset is an actual weighted shop candidate")
	cards.hand.finish_animation(); await frames()
	var coins: int = shop.coins
	await click(center(cards.hand.views[0])); await key(KEY_R)
	check(cards.turns == 1,"R rotates selected authored card")
	await click(point(Vector3i.ZERO))
	check(cards.cards.size() == 1 and towers.towers.is_empty() and shop.coins == coins,"Illegal rotated placement preserves cards and gold")
	await key(KEY_R); await key(KEY_R); await key(KEY_R)
	var revision: int = portal.route_history.revision
	var spawn_rng: int = game.session.get_node("EnemyWave").spawn_rng.state
	var shop_rng: int = shop._rng.state
	cards.hand.finish_animation()
	var start := center(cards.hand.views[0]); var destination := point(Vector3i(8,0,0))
	motion(start); left(start,true); motion(destination,MOUSE_BUTTON_MASK_LEFT); await frames()
	check(cards.hand.is_dragging() and cards.preview.visible,"Actual hand drag shows multi-cell placement preview")
	check(portal.route_history.revision == revision,"Hover preview does not publish route history")
	var candidate: Node = game.session.get_node("TileCandidatePreview")
	check(candidate.pending.size() == 12 and game.session.get_node("WaveFlowPreview").construction_pending != null,"Placement previews a complete future mixed-wave route")
	check(game.session.get_node("EnemyWave").spawn_rng.state == spawn_rng and shop._rng.state == shop_rng,"Future route preview consumes neither departure nor shop RNG")
	var rebuilds: int = candidate.rebuild_count
	await frames(12)
	check(candidate.rebuild_count == rebuilds,"Stationary hover does not rebuild path candidates every frame")
	var expected_flow: Dictionary = RoadFlowForecast.from_pending(candidate.pending).all
	await capture("drag_preview")
	left(destination,false); await frames(12)
	check(towers.towers.size() == 1 and cards.cards.is_empty() and towers.occupied.size() == 3,"Real release immediately commits exactly one 3-cell tower and consumes one card")
	check(portal.route_history.revision == revision+1,"One successful placement records one topology revision")
	var actual_schedule := WaveSpawnSchedule.build(game.session.get_node("EnemyWave").definition,portal,1,false)
	check(RoadFlowForecast.from_pending(actual_schedule.pending).all == expected_flow,"Previewed routes equal actual committed Soldier/Scout/Winged allocation")
	await capture("placed_long_hull")
	# Create a second body for the same tower through the editor, without restarting.
	await click(center(game.edit_button)); await click(center(game.editor.clone_button))
	await choose(game.editor.brush_picker,2); await paint(Vector2i(-1,0)); await paint(Vector2i(1,0))
	check(game.editor.draft.tower_footprint.size() == 1,"Duplicate has independently editable body")
	await click(center(game.editor.add_button)); await frames()
	check(cards.cards.size() == 1 and cards.cards[0].tower == Catalog.tower("broadside") and cards.cards[0].tile_preset.preset_id != id,"Second same-tower preset coexists with saved original")
	check(towers.occupied.size() == 3,"Editing does not reshape already placed tower")
	cards.hand.finish_animation(); await click(center(cards.hand.views[0])); await key(KEY_R); await click(point(Vector3i(12,0,4))); await frames()
	check(towers.towers.size() == 2 and towers.occupied.size() == 4,"Second rotated body builds one distinct instance of the same tower")
	# Restore original selector and add it alongside a different shape in the same hand.
	await choose(game.preset_picker,0); await click(center(game.add_button))
	await choose(game.preset_picker,game.preset_picker.item_count-1); await click(center(game.add_button))
	check(cards.cards.size() == 2 and cards.cards[0].tower == cards.cards[1].tower and cards.cards[0].tile_preset.stable_id() != cards.cards[1].tile_preset.stable_id(),"Two different configurations of one tower share the same hand")
	await click(center(game.session.get_node("LevelHUD/WorldActions/EarlyStart")))
	await get_tree().create_timer(2.0,true,false,true).timeout
	var wave: Node = game.session.get_node("EnemyWave")
	check(wave.active and cards.input_suspended and game.edit_button.disabled,"Real entrance starts mixed combat and locks editing")
	check(wave.total == 12 and wave._committed_routes.size() == 12,"Complete mixed schedule freezes in actual combat")
	await capture("mixed_combat")
	Engine.time_scale = 4
	var deadline := Time.get_ticks_msec()+25000
	while game.session.current_wave == 0 and Time.get_ticks_msec() < deadline: await frames(2)
	Engine.time_scale = 1
	check(game.session.current_wave == 1 and not wave.active and shop.coins == coins+18,"First real wave finishes with exactly one reward")
	await click(center(game.session.get_node("LevelHUD/WorldActions/EarlyStart")))
	await get_tree().create_timer(2.0,true,false,true).timeout
	check(wave.active and wave.total == 15,"Second round starts its own larger mixed schedule")
	Engine.time_scale = 4; deadline = Time.get_ticks_msec()+25000
	while game.session.current_wave == 1 and Time.get_ticks_msec() < deadline: await frames(2)
	Engine.time_scale = 1
	check(game.session.current_wave == 2 and not wave.active and shop.coins == coins+36,"Repeated round finishes without duplicate reward or stale lock")
	await click(center(game.reset_button)); await frames(20)
	check(game.session.current_wave == 0 and game.session.get_node("TowerMap").towers.is_empty() and game.session.get_node("CardPlacement/Shop").coins == 60,"Reset clears world and restores initial economy")
	check(game.editor.catalog.rows("broadside").any(func(row): return row.id == id),"Reset retains saved designs")
	await capture("reset")
	await click(center(game.edit_button))
	var deleted_id: String = game.editor.draft.preset_id
	await click(center(game.editor.delete_button)); await key(KEY_ENTER); await frames()
	check(game.editor.catalog.rows("broadside").all(func(row): return row.id != deleted_id) and FileAccess.file_exists(game.editor.catalog.root+"/"+deleted_id+".tres"),"Real deletion confirmation safely archives the selected user preset")
	await choose(game.editor.tower_picker,3); await click(center(game.editor.new_button))
	await choose(game.editor.brush_picker,0)
	for cell in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]: await paint(cell)
	await choose(game.editor.brush_picker,3); await paint(Vector2i.RIGHT)
	check(game.editor.draft.tower_offset == Vector2i.RIGHT,"Real anchor tool chooses an outer body cell")
	await choose(game.editor.brush_picker,5); await paint(Vector2i.LEFT)
	check(game.editor.draft.tower_offset == Vector2i(2,0) and Vector2i(2,0) in game.editor.draft.tower_footprint,"Placement origin tool recenters body and logical anchor together")
	await click(center(game.editor.undo_button))
	await choose(game.editor.brush_picker,1); await paint(Vector2i(0,-2)); await paint(Vector2i(-1,-2)); await paint(Vector2i(1,-2))
	check(game.editor.draft.tower_footprint.size() == 5 and not game.editor.save_button.disabled,"Cross body with partial exterior roads is editable and valid")
	await capture("editor_cross_body")
	await click(center(game.editor.add_button)); await frames(8)
	cards = game.session.get_node("CardPlacement"); towers = game.session.get_node("TowerMap")
	cards.hand.finish_animation(); await click(center(cards.hand.views[0])); await key(KEY_R); await click(point(Vector3i(8,0,5))); await frames(8)
	check(towers.towers.size() == 1 and towers.occupied.size() == 5,"Rendered rotated cross creates one real five-cell tower")
	await capture("placed_cross_body")
	game.queue_free(); await frames()
	var report := {"checks":checks,"failures":failures,"rendered":true,"human_playtest":"NOT RUN"}
	FileAccess.open(Artifacts.path("tower_tile_editor/input.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TOWER_TILE_INPUT:"+JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
