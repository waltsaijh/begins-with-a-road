@tool
extends Node
## godot --editor --path . -- --test-card-resource-refresh
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func verify() -> void:
	await frames(20)
	while EditorInterface.get_resource_filesystem().is_scanning(): await frames()
	check(Engine.is_editor_hint(), "Card resource regression must run inside the editor")
	var definition := load("res://assets/data/towers/sentry.tres").duplicate(true) as TowerDefinition
	var original_offsets: Array[Vector2i] = definition.attack_area.offsets.duplicate()
	var current: CanvasLayer = load("res://scenes/cards/card_shop_view.tscn").instantiate()
	var legacy: CanvasLayer = load("res://scenes/cards/card_shop_view.tscn").instantiate()
	get_tree().root.add_child(current)
	get_tree().root.add_child(legacy)
	await frames()
	var views: Array[Button] = []
	for shop in [current, legacy]:
		for slot in shop.get_node("Root/Slots").get_children():
			var card: Button = slot.get_node("Face/Card")
			card.card = BuildCard.from_parts(definition, definition.first_tile_preset())
			views.append(card)
	await frames()
	# Retain the previous hierarchy while the current tool script stays loaded.
	for slot in legacy.get_node("Root/Slots").get_children():
		var card: Button = slot.get_node("Face/Card")
		var visuals: Control = card.get_node("Visuals")
		for child in visuals.get_children(): child.reparent(card, false)
		card.remove_child(visuals)
		visuals.free()
	# Real script reload, keeping already instantiated nodes and signal links.
	var script: GDScript = views[0].get_script()
	check(script.reload(true) == OK, "Card script could not hot reload")
	definition.attack_area.offsets = [Vector2i(-1, -4), Vector2i.ZERO, Vector2i(2, 1)]
	await frames()
	definition.accent_color = Color("c28d54")
	await frames()
	for card in views:
		var artwork: Node = card.get_node_or_null("Visuals")
		if artwork == null: artwork = card
		var frame: NinePatchRect = artwork.get_node("Accent")
		check(artwork.get_node("Background").texture != null and frame.self_modulate == definition.accent_color, "Resource edit did not refresh a current or retained card")
		check(not card.is_processing(), "Editor resource updates enabled runtime sway")
	# A resource can change while a child's instance is temporarily absent.
	var visuals: Control = views[0].get_node("Visuals")
	var background: NinePatchRect = visuals.get_node("Background")
	visuals.remove_child(background)
	definition.attack_area.offsets = [Vector2i(0, -1)]
	await frames()
	background.texture = null
	visuals.add_child(background)
	await frames()
	check(background.texture == views[0].default_background, "Reinstating artwork did not resume its queued editor refresh")
	# Off-tree cached scene instances must ignore resource notifications safely.
	get_tree().root.remove_child(legacy)
	definition.attack_area.offsets = original_offsets
	await frames()
	check(definition.attack_area.configuration_error().is_empty(), "Editing offsets invalidated the test resource")
	legacy.free()
	current.queue_free()
	await frames()
	var report := {"failures": failures, "editor_mode": true, "retained_shop_cards": 5, "script_hot_reload": true, "offset_resource_change": true, "partial_reinstantiation": true, "off_tree_notifications": true}
	FileAccess.open(Artifacts.path("editor/card_resource_refresh.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CARD_RESOURCE_EDITOR_CHECK:"+JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
