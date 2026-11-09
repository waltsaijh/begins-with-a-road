extends Node
const Info = preload("res://scripts/cards/presentation/card_combat_info.gd")
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	verify.call_deferred()
func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame
func hover(view: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = view.get_global_transform_with_canvas()*(view.size*0.5)
	get_viewport().push_input(event,true)
	await get_tree().create_timer(0.3).timeout
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("cards/"+name+".png"))
func verify() -> void:
	TranslationServer.set_locale("zh_TW")
	for definition in ProgressCatalog.TOWERS:
		var info := Info.data(definition)
		check(info.damage is int and not info.description.contains("tower."),"Card data was not resolved")
		if definition.deployment != null:
			check(info.damage == roundi(definition.deployment.damage),"Barracks did not show soldier damage")
		else:
			check(info.damage == roundi(definition.default_damage*definition.attack.damage_multiplier),"Card damage does not match combat resource")
	var sentry: TowerDefinition = load("res://assets/data/towers/sentry.tres")
	check(Info.data(sentry).damage == 12 and Info.data(sentry).speed == "攻速  快" and Info.data(sentry).description.replace("\n","") == "射出箭矢，對單一敵人造成傷害。","Sentry card example is inaccurate")
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	add_child(scene)
	for i in 180:
		if not scene.get_node("PortalMap").computing: break
		await frames(1)
	var cards: Node = scene.get_node("CardPlacement")
	var hand: CanvasLayer = cards.hand
	cards.cards.assign([BuildCard.from_parts(sentry,sentry.first_tile_preset()),BuildCard.from_parts(ProgressCatalog.TOWERS[1],ProgressCatalog.TOWERS[1].first_tile_preset())])
	hand.set_cards(cards.cards)
	hand.finish_animation()
	var note: CanvasLayer = cards.get_node("CardHoverNote")
	await hover(hand.views[0])
	check(note.target == hand.views[0] and note.root.visible and note._reveal == 1.0,"Real hand hover did not reveal paper")
	check(note.get_node("Root/Damage/Paper/Margin/Text").text == "傷害  12","Hand paper has incorrect damage")
	check(note.root.get_child_count() == 3,"Hover does not show exactly three sticky notes")
	check(note.root.position.x > note.card_bounds(hand.views[0]).position.x+note.card_bounds(hand.views[0]).size.x*0.8,"Hand notes did not attach to the right edge")
	check(note.strips[2].get_node("Paper").size.x > note.strips[0].get_node("Paper").size.x,"Description note is not larger")
	check(note.get_node_or_null("Root/Name") == null and note.get_node_or_null("Root/Range") == null and note.get_node_or_null("Root/Base") == null,"Extra headings remain")
	check(note.note_bounds().position.x >= 11.9 and note.note_bounds().end.x <= get_viewport().get_visible_rect().size.x-12,"Paper escaped viewport")
	for node: Control in note.find_children("*","Control",true,false): check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Paper captures card input")
	await capture("hover_note_hand")
	TranslationServer.set_locale("en")
	await frames()
	check(note.get_node("Root/Speed/Paper/Margin/Text").text == "Attack speed  Fast","Visible paper did not update language")
	await capture("hover_note_en")
	TranslationServer.set_locale("zh_TW")
	scene.get_node("LevelHUD").set_paused(true)
	await frames()
	check(not note.root.visible,"Paper survived pause")
	scene.get_node("LevelHUD").set_paused(false)
	await get_tree().create_timer(0.4).timeout
	var shop: Node = cards.get_node("Shop")
	shop.grant_gold(100,"test")
	shop.open_shop()
	shop.view.finish_animation()
	await hover(shop.view.slots[1].get_node("Face/Card"))
	check(note.target == shop.view.slots[1].get_node("Face/Card") and note.root.visible,"Shop hover did not share paper")
	check(note.root.position.x > note.card_bounds(note.target).position.x+note.card_bounds(note.target).size.x*0.8,"Shop notes did not unfold to the right")
	await capture("hover_note_shop")
	shop.coins = 0
	shop._refresh()
	shop.view.finish_animation()
	await hover(shop.view.slots[4].get_node("Face/Card"))
	check(note.root.visible,"Unaffordable card cannot be inspected")
	check(note.opens_left,"Rightmost shop card did not open to the left")
	for strip in note.strips:
		check(is_equal_approx(strip.position.x+strip.size.x,0.0),"Left-opening notes are not attached by their right edges")
	check(note.note_bounds().end.x <= note.card_bounds(note.target).position.x+12,"Rightmost card face is covered")
	await capture("hover_note_rightmost_left")
	TranslationServer.set_locale("en")
	get_tree().root.size = Vector2i(800,600)
	await frames(6)
	shop.view.finish_animation()
	await hover(shop.view.slots[4].get_node("Face/Card"))
	check(note.root.visible and note.note_bounds().position.x >= 11.9 and note.note_bounds().end.x <= get_viewport().get_visible_rect().size.x-12 and note.note_bounds().end.y <= get_viewport().get_visible_rect().size.y-12,"Small English note escaped viewport")
	await capture("hover_note_small_en")
	var face: Control = shop.view.slots[4].get_node("Face/Card")
	for locale in ["zh_TW","en"]:
		TranslationServer.set_locale(locale)
		for definition in ProgressCatalog.TOWERS:
			face.card = BuildCard.from_parts(definition,definition.first_tile_preset())
			await hover(face)
			check(note.opens_left and note.root.visible,"Rightmost direction changed with card content")
			for strip in note.strips:
				var label: Label = strip.get_node("Paper/Margin/Text")
				var font := label.get_theme_font("font")
				var size := label.get_theme_font_size("font_size")
				var width: float = strip.get_node("Paper").size.x-26.0
				for line in label.text.split("\n"):
					check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x <= width+1.0,"Text row overflows sticky note: "+line)
			var description: String = note.get_node("Root/Description/Paper/Margin/Text").text.replace("\n","")
			if locale == "zh_TW":
				if definition.name_key == "tower.mortar.name": check(description == "發射砲彈，對地面敵人造成範圍傷害。","Mortar copy is outdated")
				if definition.name_key == "tower.crossfire.name": check(not description.contains("旋轉"),"Rotation copy remains")
				if definition.name_key == "tower.broadside.name": check(description == "側舷開火，對兩側敵人造成傷害。","Broadside copy is outdated")
				if definition.name_key in ["tower.mortar.name","tower.crossfire.name","tower.broadside.name"]: await capture("note_updated_"+definition.name_key.get_slice(".",1))

	shop.close_shop()
	await frames()
	check(not note.root.visible,"Closed shop left stale paper")
	var preview: Node = cards.preview
	check(preview.range_fill_color == preload("res://scripts/towers/range_appearance.gd").FILL and preview.range_border_color == preload("res://scripts/levels/presentation/unit_range.gd").EDGE,"Preview and unit range styles differ")
	scene.queue_free()
	await frames()
	print("CARD_HOVER_NOTE_CHECK: failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
