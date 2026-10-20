extends Control
## One recipe shares its tower's name; each presentation chooses its own header.
const CardScene = preload("res://scenes/cards/components/card_view.tscn")
const TestCards = preload("res://tests/fixtures/card_fixture.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func verify() -> void:
	verify_translation_keys()
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var card: BuildCard = TestCards.card("corner").duplicate()
	card.tower = card.tower.duplicate()
	card.tile_preset = card.tile_preset.duplicate()
	var hand: Button = CardScene.instantiate()
	hand.card = card
	hand.key_number = 3
	hand.position = Vector2(24, 24)
	add_child(hand)
	var shop: Button = CardScene.instantiate()
	shop.card = card
	shop.presentation = 1
	shop.position = Vector2(192, 24)
	add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	var hand_prefix: Label = hand.get_node("%CardTitle/Prefix")
	var hand_tower: Label = hand.get_node("%CardTitle/TowerName")
	var shop_prefix: Label = shop.get_node("%CardTitle/Prefix")
	var shop_tower: Label = shop.get_node("%CardTitle/TowerName")
	check(card.localized_name() == "Corner Sentry", "English name did not combine prefix and tower")
	check(hand_prefix.text == "Corner" and hand_tower.text == "Sentry" and hand.get_node("%Shortcut").text == "3", "Hand did not show its number and separate name parts")
	check(shop_tower.text == "Sentry" and not shop_prefix.visible and not shop.get_node("%Shortcut").visible, "Shop included the terrain prefix or hand shortcut")
	check(not hand.get_node("%Price").visible and shop.get_node("%Price/Number").text == str(card.price), "Price appeared in the wrong presentation")
	check(hand_prefix.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and hand_tower.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and hand.get_node("%Shortcut").horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Hand header alignment is incorrect")
	check(hand_prefix.position.y+hand_prefix.size.y <= hand_tower.position.y and is_equal_approx(hand_prefix.size.x, hand_tower.size.x), "English name parts are not stacked above one another")
	check(hand_prefix.get_theme_font_size("font_size") == 12 and hand_tower.get_theme_font_size("font_size") == 16, "English name sizes are not 12/16 px")
	check(shop_tower.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Shop name is not left aligned")
	var price: Control = shop.get_node("%Price")
	var title: Control = shop.get_node("%CardTitle")
	check(is_equal_approx(price.position.x+price.size.x, price.get_parent().size.x) and title.position.x+title.size.x <= price.position.x, "Shop price does not occupy the right edge of the title row")
	check(hand.size == Vector2(144, 208) and shop.size == hand.size, "Header expanded the card dimensions")
	verify_card_font(hand_tower.get_theme_font("font"), "Light")
	verify_card_font(hand_prefix.get_theme_font("font"), "Medium")
	await screenshot("res://.godot/card_names_en.png")
	TranslationServer.set_locale("zh_TW")
	await get_tree().process_frame
	await get_tree().process_frame
	check(card.localized_name() == "轉角哨塔" and hand_prefix.text == "轉角" and hand_tower.text == "哨塔", "Locale change did not refresh both Chinese name parts")
	check(hand_prefix.position.y == hand_tower.position.y and is_equal_approx(hand_prefix.position.x+hand_prefix.size.x, hand_tower.position.x), "Chinese name parts are not joined on the same line")
	check(hand_prefix.get_theme_font_size("font_size") == 16 and hand_tower.get_theme_font_size("font_size") == 16, "Chinese name sizes changed")
	check(shop_tower.text == "哨塔" and not shop_prefix.visible, "Locale change did not refresh the shop tower name")
	await screenshot("res://.godot/card_names_zh.png")
	card.tile_preset.prefix_key = "tile_preset.bridge"
	check(hand_prefix.text == "跨橋" and hand_tower.text == "哨塔" and shop_tower.text == "哨塔", "Prefix edit changed the shop tower name")
	card.tower.name_key = "tower.crossfire.name"
	check(hand_prefix.text == "跨橋" and hand_tower.text == tr("tower.crossfire.name") and shop_tower.text == tr("tower.crossfire.name"), "Shared tower name edit did not refresh both presentations")
	card.tile_preset.prefix_key = ""
	check(card.localized_name() == tr("tower.crossfire.name"), "Empty prefix left unwanted spacing")
	TranslationServer.set_locale("en_US")
	await get_tree().process_frame
	await get_tree().process_frame
	check(not hand_prefix.visible and hand_tower.position.y == 0.0 and hand_tower.get_theme_font_size("font_size") == 16, "Empty English prefix left a blank first line")
	check(hand.size == Vector2(144, 208), "Long tower name expanded its card")
	card.price = 8
	check(shop.get_node("%Price/Number").text == "8", "Resource price edit did not refresh the shop")
	shop.price_override = 12
	card.price = 5
	check(shop.get_node("%Price/Number").text == "12", "Resource price replaced the actual offer price")
	shop.can_afford = false
	check(shop.disabled, "Unaffordable shop card remained enabled")
	shop.presentation = 0
	check(not shop.disabled and not price.visible and shop.get_node("%Shortcut").visible, "Returning to hand retained shop-only state")
	TranslationServer.set_locale(original_locale)
	print("CARD_NAMES_CHECK:"+JSON.stringify({"failures": failures, "separate_names": true, "localized_headers": true, "live_edits": true, "offer_prices": true}))
	get_tree().quit(1 if failures else 0)

func verify_translation_keys() -> void:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")
	var file := FileAccess.open("res://assets/translations/card_names.csv", FileAccess.READ)
	file.get_csv_line()
	var seen := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3: continue
		check(pattern.search(row[0]) != null and not seen.has(row[0]), "Translation key is not unique dot-separated snake_case: "+row[0])
		seen[row[0]] = true
	check(seen.has("card.name_format") and seen.has("tower.sentry.name") and seen.has("tile_preset.corner"), "Required card translation keys are missing")

func verify_card_font(font: Font, weight: String) -> void:
	var server := TextServerManager.get_primary_interface()
	var buffer := server.create_shaped_text()
	var text := "轉角跨橋側翼哨塔ABCabc0123456789"
	server.shaped_text_add_string(buffer, text, font.get_rids(), 16)
	server.shaped_text_shape(buffer)
	var glyphs := server.shaped_text_get_glyphs(buffer)
	check(glyphs.size() == text.length(), "Card font contains missing Chinese/English glyphs")
	for glyph in glyphs:
		check(server.font_get_name(glyph.font_rid).begins_with("Noto Sans TC"), "Card name fell back to a system font")
		check(server.font_get_style_name(glyph.font_rid) == weight, "Card name lost its "+weight+" weight")
	server.free_rid(buffer)

func screenshot(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
