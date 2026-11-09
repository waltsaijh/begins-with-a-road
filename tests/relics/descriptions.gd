extends Node
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Codex = preload("res://scripts/enemies/presentation/enemy_codex_text.gd")
var failures := 0
var checks := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _ready() -> void: verify.call_deferred()
func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Artifacts.path("relics/"+name+".png"))
func verify() -> void:
	var digits := RegEx.create_from_string("[0-9]")
	var manager := RunRelics.new()
	add_child(manager)
	var ui: CanvasLayer = load("res://scenes/relics/relic_choice.tscn").instantiate()
	add_child(ui)
	ui.setup(manager)
	ui.begin()
	for locale in ["zh_TW","en"]:
		TranslationServer.set_locale(locale)
		get_tree().root.size = Vector2i(800,600)
		for relic in manager.catalog.entries:
			var text := relic.localized_description()
			check(not "{" in text and not "}" in text and not text.contains(".description"),"Unresolved relic template: "+str(relic.id))
			check(text.contains("\n\n"),"Relic lacks readable paragraphs")
			if relic.parameters.size() > 0: check(digits.search(text) != null,"Relic lacks effect numbers: "+str(relic.id))
		for batch in range(0,manager.catalog.entries.size(),3):
			ui.offers.assign(manager.catalog.entries.slice(batch,batch+3))
			ui._rebuild_cards()
			await frames(10)
			for card: Button in ui.row.get_children():
				var text: Label = card.get_node("Contents/Description")
				check(text.get_global_rect().end.y <= card.get_global_rect().end.y-10,"Reward description extends below card: "+text.text)
				check(card.get_global_rect().position.y >= 60 and card.get_global_rect().end.y < get_viewport().get_visible_rect().size.y-32,"Reward card escapes viewport")
				check(card.get_global_rect().position.x >= 12 and card.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x-12,"Reward card too wide")
			if batch in [0,3,6,18]: await capture("descriptions_"+locale+"_"+str(batch))
		for profile in TroopCatalog.all():
			var text := Codex.description(profile)
			check(text.contains("Route behavior" if locale == "en" else "行進路線"),"Enemy lacks route behavior: "+profile.troop_name)
			check(not text.contains("Softmax") and not text.contains("threshold") and not text.contains("演算法"),"Enemy leaks implementation")
	TranslationServer.set_locale("zh_TW")
	check(manager.catalog.find(&"crew_concentration").localized_description().contains("2.5") and manager.catalog.find(&"crew_concentration").localized_description().contains("150%"),"Crew bonus is inaccurate")
	check(manager.catalog.find(&"frost_ray").localized_description().contains("15.55%"),"Frost single-hit slow is inaccurate")
	var changed: RelicDefinition = manager.catalog.find(&"global_damage").duplicate()
	changed.parameters = {"bonus":0.23}
	check(changed.localized_description().contains("23%"),"Relic text is not resource-driven")
	check(TroopCatalog.find("bomber").route_description().contains("防禦塔密集"),"Bomber route behavior is missing")
	check(TroopCatalog.find("rats").route_description().contains("5 隻"),"Cohort route behavior is missing")
	check(TroopCatalog.find("bloodmage").route_description().contains("多數"),"Bloodmage route behavior is missing")
	ui.choosing = false
	ui.set_process(false)
	ui.hide()
	var progress := get_node("/root/LevelProgress")
	var encountered: Dictionary = progress._encountered.duplicate()
	for profile in TroopCatalog.all(): progress._encountered[profile.troop_name] = true
	var background := ColorRect.new()
	background.color = Color.WHITE
	background.size = get_viewport().get_visible_rect().size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var page: Control = load("res://scenes/progress/progress_page.tscn").instantiate()
	add_child(page)
	for locale in ["zh_TW","en"]:
		TranslationServer.set_locale(locale)
		page.configure(ProgressCatalog.sections(),{})
		page.open()
		for id in ["heavy","bloodmage","bomber","scout","winged","assembled_cannon"]:
			page.focus_entry(id)
			await frames(8)
			check(page.column.get_node("Description").visible,"Progress description not visible")
			await capture("progress_"+locale+"_"+id)
	page.free()
	background.free()
	progress._encountered = encountered
	ui.queue_free()
	manager.queue_free()
	await frames()
	print("DESCRIPTIONS_CHECK: checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
