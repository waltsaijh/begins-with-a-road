extends "res://tests/tower_tile_editor/input.gd"
const LevelFixture = preload("res://tests/construction/fixture.gd")
class Host extends Node3D:
	var session: Node3D

func run() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	viewport = TestViewport.new(); viewport.size = Vector2i(1440,900); viewport.gui_embed_subwindows = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(viewport)
	game = Host.new(); game.session = LevelFixture.session(0)
	game.session.get_node("CardPlacement").cards.clear()
	game.add_child(game.session); viewport.add_child(game); await frames(12); viewport.mouse_entered.emit()
	var towers: Node = game.session.get_node("TowerMap")
	var cards: Node = game.session.get_node("CardPlacement")
	var mortar := BuildCard.from_parts(Catalog.tower("mortar"),load("res://assets/data/tower_tiles/user/user_6657902a4f1b0f4ce0c1b3be3c808484.tres"))
	var old: DefenseTower = towers.place_card(mortar,Vector3i(8,0,1))
	check(old != null,"Existing full mortar body is in the real level")
	await frames(35)
	var incoming := BuildCard.from_parts(Catalog.tower("sentry"),load("res://assets/data/tower_tiles/user/user_b46a4aa7ce037ee15ceb475612745a2a.tres"))
	var coins: int = cards.get_node("Shop").coins
	for row in [0,1]:
		cards.add_card(incoming); cards.hand.finish_animation(); await frames()
		var anchor := Vector3i(8,0,3) if row == 0 else Vector3i(6,0,2)
		if row == 0:
			await click(center(cards.hand.views[0])); motion(point(anchor)); await frames(5)
		else:
			var start := center(cards.hand.views[0]); motion(start); left(start,true); motion(start+Vector2(20,-25),MOUSE_BUTTON_MASK_LEFT); await frames(2); await key(KEY_R); motion(point(anchor),MOUSE_BUTTON_MASK_LEFT); await frames(5)
		check(cards.preview.visible,"Click/drag opens actual placement preview")
		check(not Vector2i(7,2) in cards.preview.displayed_ground and not (Vector2i(8,2) if row == 0 else Vector2i(7,1)) in cards.preview.displayed_ground,"Preview clips both occupied mortar cells")
		check((Vector2i(9,2) if row == 0 else Vector2i(7,3)) in cards.preview.displayed_ground,"Preview keeps remaining new road")
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(Artifacts.path("road_refinement/"+("click_preview" if row == 0 else "drag_preview")+".png"))
		if row == 0: await click(point(anchor))
		else: left(point(anchor),false)
		await frames(35)
		check(towers.towers.size() == row+2 and cards.cards.is_empty(),"Click/drag consumes one card and creates one tower")
		check(cards.get_node("Shop").coins == coins,"Construction never charges additional Gold")
	check(towers.occupied[Vector2i(8,2)] == old and old.level == 1,"Full old footprint remains the same tower")
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(Artifacts.path("road_refinement/committed_level.png"))
	await click(center(game.session.get_node("LevelHUD/WorldActions/EarlyStart")))
	await get_tree().create_timer(2.0,true,false,true).timeout
	check(game.session.get_node("EnemyWave").active,"Actual mixed wave starts after clipped placements")
	game.queue_free(); await frames()
	var report := {"checks":checks,"failures":failures,"rendered":true,"click_and_drag":true}
	FileAccess.open(Artifacts.path("road_refinement/input.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ROAD_REFINEMENT_INPUT:",JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
