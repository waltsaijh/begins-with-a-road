extends "res://tests/tower_tile_editor/input.gd"
const Shapes = preload("res://tests/tower_tile_editor/fixture.gd")

func window_point(control: Control) -> Vector2:
	return Vector2(control.get_window().position)+center(control)

func toggle_member(dialog: ConfirmationDialog, id: String) -> void:
	for group in dialog.tree.get_root().get_children():
		for item in group.get_children():
			if item.get_metadata(0) != id: continue
			var rect: Rect2 = dialog.tree.get_item_area_rect(item,0)
			var point: Vector2 = Vector2(dialog.position)+dialog.tree.get_global_transform_with_canvas()*(rect.position+Vector2(12,rect.size.y/2))
			await click(point)
			return
	check(false,"Missing member row: "+id)

func run() -> void:
	if DisplayServer.get_name() == "headless": get_tree().quit(2); return
	var folder := Artifacts.path("tower_tile_editor/combinations_"+str(Time.get_ticks_usec()))
	var catalog := Catalog.new(folder)
	var long := Shapes.long_hull(); var compact := Shapes.compact(); var barracks := Shapes.long_hull()
	barracks.preset_id = "user_barracks"; barracks.display_name = "兵營樣式3"
	check(catalog.save("broadside",long,1,false) and catalog.save("broadside",compact,1,false) and catalog.save("barracks",barracks,1,false),"Independent test designs saved")
	var group_a: Array[String] = [Catalog.member_key("broadside",long.preset_id),Catalog.member_key("barracks",barracks.preset_id)]
	var group_b: Array[String] = [Catalog.member_key("broadside",compact.preset_id)]
	var a: String = catalog.save_combination("","組合一 · 長船與兵營",group_a,true)
	var b: String = catalog.save_combination("","組合二 · 短船",group_b,true)
	check(not a.is_empty() and not b.is_empty() and a != b,"Named combinations have independent stable IDs")
	check(catalog.activate(a),"Activate saved combination")
	var restored := Catalog.new(folder)
	check(restored.data.active_combination == a and restored.combination(a).members == group_a,"Selection and membership persist across reload")
	viewport = TestViewport.new(); viewport.size = Vector2i(1440,900); viewport.gui_embed_subwindows = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(viewport)
	game = Playground.instantiate(); game.catalog_root = folder; viewport.add_child(game); await frames(20); viewport.mouse_entered.emit()
	var cards: Node = game.session.get_node("CardPlacement")
	var towers: Node = game.session.get_node("TowerMap")
	var shop: Node = cards.get_node("Shop")
	var rolled: Array[BuildCard] = shop.roll_cards(60)
	check(rolled.size() == 60 and rolled.all(func(card): return card.tile_preset.preset_id in [long.preset_id,barracks.preset_id]),"Actual shop exclusively draws active cross-tower members")
	check(rolled.any(func(card): return card.tower == Catalog.tower("barracks")),"Second tower kind participates in same saved combination")
	var excluded := BuildCard.from_parts(Catalog.tower("broadside"),compact)
	check(not cards.add_card(excluded),"Direct free-card API rejects a nonmember")
	check(towers.place_card(excluded,Vector3i(12,0,3)) == null and towers.towers.is_empty(),"Authority rejects direct placement outside active combination")
	check(not towers.construction_plan([{"card":excluded,"anchor":Vector3i(12,0,3),"turns":0}]).ok,"Compound commit cannot bypass allowlist")
	await choose(game.tower_picker,2); await click(center(game.add_button))
	cards.hand.finish_animation(); await click(center(cards.hand.views[0])); motion(point(Vector3i(8,0,0))); await frames(6)
	check(cards.preview.ghost.has_node("Airship/RecoilAssembly") and cards.preview.ghost.has_node("FixedBase"),"Preview uses full ship assembly with fixed base")
	await capture("raised_body_preview")
	await click(point(Vector3i(8,0,0))); await frames(12)
	check(towers.towers.size() == 1 and towers.occupied.size() == 3,"Raised body still owns one tower and three blocked cells")
	var tower: DefenseTower = towers.towers.values()[0]
	var body: Node3D = tower.get_node("Visual")
	check(body.has_node("Airship") and body.has_node("FixedBase"),"Placed ship shares preview hierarchy and fixed base")
	await capture("raised_body_placed")
	await choose(game.combination_picker,2); await frames(15)
	check(game.editor.catalog.data.active_combination == b and game.session.get_node("TowerMap").towers.is_empty() and game.session.get_node("CardPlacement").cards.is_empty(),"Real combination switch resets old towers and cards")
	shop = game.session.get_node("CardPlacement/Shop")
	check(shop.roll_cards(24).all(func(card): return card.tile_preset.preset_id == compact.preset_id),"Second saved set entirely replaces actual shop pool")
	check(shop.offers.filter(func(card): return card != null and card.tower != null).all(func(card): return card.tile_preset.preset_id == compact.preset_id),"Opening shop offers belong to newly selected set")
	await click(center(game.edit_button))
	await click(center(game.editor.hide_builtins))
	check(game.editor.entries.all(func(row): return not row.builtin) and game.editor.catalog.data.hide_builtins,"Real hide toggle collapses built-ins without deleting them")
	await click(center(game.editor.combination_button))
	var dialog: ConfirmationDialog = game.editor.combinations
	await frames(6)
	check(viewport.get_visible_rect().has_point(window_point(dialog.save_as)) and viewport.get_visible_rect().has_point(window_point(dialog.get_ok_button())),"Combination dialog actions fit inside the viewport")
	await capture("combination_manager")
	await toggle_member(dialog,group_a[0]); await toggle_member(dialog,group_a[1]); await toggle_member(dialog,group_b[0])
	check(dialog.members.size() == 2 and group_a.all(func(id): return id in dialog.members),"Actual checkboxes edit membership across two tower kinds")
	await click(window_point(dialog.title_edit)); await key(KEY_A,true)
	for c in "Compare C": await key(KEY_NONE,false,c.unicode_at(0))
	await click(window_point(dialog.save_as)); await frames(8)
	check(game.editor.catalog.data.combinations.size() == 3 and game.editor.catalog.combination(game.editor.catalog.data.active_combination).name == "Compare C","Real dialog saves named independent copy")
	await click(center(game.editor.close_button)); await frames(15)
	check(game.combination_picker.get_item_text(game.combination_picker.selected) == "Compare C","Saved copy appears in immediate comparison selector")
	check(game.session.get_node("CardPlacement/Shop").roll_cards(60).all(func(card): return card.tile_preset.preset_id in [long.preset_id,barracks.preset_id]),"Checkbox selection governs actual rebuilt shop")
	# Empty sets stay empty; no silent fallback to built-in recipes.
	var no_members: Array[String] = []
	var empty: String = game.editor.catalog.save_combination("","空白組合",no_members,true)
	game._policy_changed(); await frames(15)
	check(game.session.get_node("CardPlacement/Shop").roll_cards(12).is_empty() and game.editor.catalog.data.active_combination == empty,"Empty combination never falls back to built-ins")
	check(game.editor.catalog.activate(""),"Unrestricted mode remains available")
	check(game.editor.catalog.save_settings(true,true),"Built-in exclusion and visibility are independently persisted")
	game._policy_changed(); await frames(15)
	check(game.session.get_node("CardPlacement/Shop").roll_cards(60).all(func(card): return card.tile_preset.preset_id.begins_with("user_")),"Built-ins excluded even without a named combination")
	check(Catalog.new(folder).data.hide_builtins and Catalog.new(folder).data.exclude_builtins,"Settings survive reopen")
	game.queue_free(); await frames()
	var report := {"checks":checks,"failures":failures,"rendered":true}
	FileAccess.open(Artifacts.path("tower_tile_editor/combinations_input.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TOWER_COMBINATIONS:"+JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
