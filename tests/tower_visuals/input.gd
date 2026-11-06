extends "res://tests/tower_tile_editor/input.gd"
## Read-only production catalog. Real selectors, cards, rotation, placement and upgrades.
func run() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	viewport = TestViewport.new(); viewport.size = Vector2i(1440,900); viewport.gui_embed_subwindows = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(viewport)
	game = Playground.instantiate(); viewport.add_child(game); await frames(20); viewport.mouse_entered.emit()
	for tower_index in Catalog.KEYS.size():
		var key_name: String = Catalog.KEYS[tower_index]
		var count := 1 if key_name == "barracks" else 4
		for preset_index in count:
			await game.reset(); await frames(6)
			if key_name == "barracks":
				# Barracks requires existing road plus a connected garrison. Give this
				# input fixture a small road plaza; do not weaken the game's guard.
				var roads: Array[Vector3i] = []
				for x in range(5,12): roads.append(Vector3i(x,0,-1)); roads.append(Vector3i(x,0,1))
				game.session.get_node("TilePlacement").add_cells(roads)
				await frames(5)
			await choose(game.tower_picker,tower_index); await choose(game.preset_picker,preset_index)
			await click(center(game.add_button))
			var cards: Node = game.session.get_node("CardPlacement")
			var towers: Node = game.session.get_node("TowerMap")
			check(cards.cards.size() == 1,key_name+" selected saved preset enters hand")
			if cards.cards.is_empty(): continue
			cards.hand.finish_animation(); await click(center(cards.hand.views[0]))
			for i in preset_index: await key(KEY_R)
			var anchor := Vector3i(2147483647,0,0)
			for z in range(-3,4):
				for x in range(5,12):
					var at := Vector3i(x,0,z)
					var screen := point(at)
					if screen.x < 250 or screen.x > 1050 or screen.y < 160 or screen.y > 680: continue
					if towers.validate_card(cards.cards[0],at,cards.turns).is_empty(): anchor = at; break
				if anchor.x != 2147483647: break
			check(anchor.x != 2147483647,key_name+" has visible legal placement")
			if anchor.x == 2147483647: continue
			motion(point(anchor)); await frames(5)
			check(cards.preview.visible and not cards.preview.range_cells.is_empty(),key_name+" selected recipe exposes coverage")
			if preset_index == 0:
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(Artifacts.path("tower_visuals/"+key_name+"_placement.png"))
			await click(point(anchor)); await frames(6)
			check(towers.towers.size() == 1 and cards.cards.is_empty(),key_name+" real click consumes exactly one card")
			if towers.towers.is_empty(): continue
			var tower: DefenseTower = towers.towers.values()[0]
			check(tower.rotation_steps == preset_index,key_name+" R rotation matches saved tower")
			if preset_index == 0:
				var revision: int = game.session.get_node("PortalMap").revision
				for level in [2,3]:
					await click(center(game.add_button)); cards.hand.finish_animation(); await click(center(cards.hand.views[0]))
					await click(point(Vector3i(tower.grid_cell.x,0,tower.grid_cell.y))); await frames(5)
					check(tower.level == level and cards.cards.is_empty() and game.session.get_node("PortalMap").revision == revision,key_name+" real stacking changes level without roads")
	await click(center(game.session.get_node("LevelHUD/WorldActions/EarlyStart")))
	await get_tree().create_timer(2.0,true,false,true).timeout
	check(game.session.get_node("EnemyWave").active and game.edit_button.disabled,"Base group starts actual wave and locks editing")
	game.queue_free(); await frames()
	var report := {"checks":checks,"failures":failures,"rendered":true,"recipes":21,"human_playtest":"NOT RUN"}
	FileAccess.open(Artifacts.path("tower_visuals/input.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("BASE_RECIPE_INPUT:"+JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
