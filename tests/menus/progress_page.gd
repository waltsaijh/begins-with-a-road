extends SceneTree
## Every entry must have real text in both languages, never a raw translation key.
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	verify.call_deferred()

func verify() -> void:
	var shop: Node = load("res://scenes/cards/card_shop.tscn").instantiate()
	check(ProgressCatalog.TOWERS == shop.catalog, "Progress towers must match the shop catalog and its order")
	shop.free()
	for locale in ["zh_TW", "en"]:
		TranslationServer.set_locale(locale)
		var sections := ProgressCatalog.sections()
		check(sections[0].entries.size() == 6, "Progress must list all six towers")
		check(sections[1].entries.size() == TroopCatalog.all().size(), "Progress must list every troop")
		check(sections[2].entries.size() == ProgressCatalog.RELICS.entries.size(), "Progress must list every relic")
		for section in sections:
			for entry: Dictionary in section.entries:
				var text := " ".join([entry.name, entry.description, " ".join(entry.stats), " ".join(entry.traits)])
				check(not entry.name.is_empty() and not entry.description.is_empty(), entry.id+" lacks a name or description in "+locale)
				check(entry.icon != null, entry.id+" lacks an icon")
				check(not text.contains("ui.progress") and not text.contains(".description") and not text.contains(".traits") and not text.contains("{value}"), entry.id+" shows a raw key: "+text)
		for entry: Dictionary in sections[0].entries:
			check(not entry.traits.is_empty(), entry.id+" lists no tower traits")
	for entry: Dictionary in ProgressCatalog.relics():
		check(not entry.usage.is_empty() and not entry.usage.contains("ui.relic"), entry.id+" lacks its usage")
		check(entry.description.right(1) in ["。",".","！","!","？","?"], entry.id+" description lacks closing punctuation")
	var colors := {}
	for profile in TroopCatalog.all():
		check(profile.icon.resource_path == "res://assets/sprites/enemies/%s.png" % profile.troop_name, profile.troop_name+" must use its PNG icon")
		colors[profile.accent_color] = true
	check(colors.size() == TroopCatalog.all().size(), "Every enemy needs its own color")
	TranslationServer.set_locale("zh_TW")
	var page: Control = load("res://scenes/progress/progress_page.tscn").instantiate()
	root.add_child(page)
	page.configure(ProgressCatalog.sections(), {})
	page.open()
	check(page.rows.get_child_count() == 6, "Towers are the first section")
	await page.show_entry("ravager")
	check(page.selected_section == 1 and page.rows.get_child_count() == TroopCatalog.all().size(), "show_entry did not switch to the enemy section")
	page.close()
	check(not page.visible, "Back did not close the page")
	page.free()
	print("PROGRESS_PAGE_CHECK:", JSON.stringify({"failures": failures}))
	quit(1 if not failures.is_empty() else 0)
