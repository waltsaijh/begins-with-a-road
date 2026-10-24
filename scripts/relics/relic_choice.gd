extends CanvasLayer
signal selected(relic: RelicDefinition)
const Card = preload("res://scenes/relics/components/relic_card.tscn")
const IconMask = preload("res://assets/shaders/ui_icon_mask.gdshader")
var relics: RunRelics
var offers: Array[RelicDefinition] = []
var choosing := false
var _committing := false
@onready var modal: Control = $Modal
@onready var row: HBoxContainer = $Modal/Center/Layout/Cards

func _process(_delta: float) -> void:
	# Keep the normal HUD pause control reachable; the pause menu owns its overlay.
	visible = not get_tree().paused

func setup(manager: RunRelics) -> void:
	relics = manager
	relics.changed.connect(_refresh_collection)
	$InventoryButton.pressed.connect(func(): $Collection.visible = not $Collection.visible)
	_refresh_collection()

func begin() -> bool:
	if choosing: return true
	offers = relics.options()
	if offers.is_empty(): return false
	for child in row.get_children(): child.free()
	choosing = true
	_committing = false
	$Collection.hide()
	$InventoryButton.disabled = true
	for relic in offers:
		var card: Button = Card.instantiate()
		row.add_child(card)
		card.get_node("Contents/Icon").texture = relic.icon
		card.get_node("Contents/Title").text = tr(relic.name_key)
		card.get_node("Contents/Description").text = tr(relic.description_key)
		_color_card(card,relic)
		card.pressed.connect(choose.bind(relic))
	modal.show()
	return true

func _color_card(card: Button, relic: RelicDefinition) -> void:
	var accent := relic.presentation_color()
	accent.a = 1.0
	var paper: Color = card.get_theme_stylebox("normal").bg_color
	# Each offer owns its StyleBoxes, retaining the scene-authored shape/margins.
	# Also tint disabled, since selection feedback disables all three cards.
	for state: StringName in [&"normal",&"hover",&"pressed",&"disabled"]:
		var style: StyleBoxFlat = card.get_theme_stylebox("hover" if state in [&"hover",&"pressed"] else "normal").duplicate()
		var strength := 0.38 if state == &"pressed" else (0.30 if state == &"hover" else 0.18)
		style.bg_color = paper.lerp(accent,strength)
		style.border_color = accent.darkened(0.18)
		card.add_theme_stylebox_override(state,style)
	var focus: StyleBoxFlat = card.get_theme_stylebox("normal").duplicate()
	focus.bg_color = Color.TRANSPARENT
	card.add_theme_stylebox_override("focus",focus)
	card.get_node("Contents/Title").add_theme_color_override("font_color",accent.darkened(0.65))
	var icon: TextureRect = card.get_node("Contents/Icon")
	if relic.tower != null:
		# Tower art is an alpha mask; use the same tint as hand/shop tower icons.
		var material := ShaderMaterial.new()
		material.shader = IconMask
		icon.material = material
		icon.self_modulate = accent.darkened(0.45)

func choose(relic: RelicDefinition) -> bool:
	if not choosing or _committing or get_tree().paused or not offers.has(relic): return false
	_committing = true
	if not relics.acquire(relic):
		_committing = false
		return false
	for i in row.get_child_count():
		var button: Button = row.get_child(i)
		button.disabled = true
		button.modulate.a = 1.0 if offers[i] == relic else 0.35
	_finish_choice.call_deferred(relic)
	return true

func _finish_choice(relic: RelicDefinition) -> void:
	await get_tree().create_timer(0.25, false).timeout
	if not is_inside_tree(): return
	modal.hide()
	choosing = false
	_committing = false
	$InventoryButton.disabled = false
	selected.emit(relic)

func _refresh_collection() -> void:
	$InventoryButton.text = "%s · %d" % [tr("relic.collection"), relics.held.size()]
	for child in $Collection/Scroll/Items.get_children(): child.free()
	if relics.held.is_empty():
		var empty := Label.new()
		empty.text = tr("relic.empty")
		empty.add_theme_color_override("font_color",Color("34504e"))
		$Collection/Scroll/Items.add_child(empty)
	for id: StringName in relics.held:
		var relic := relics.catalog.find(id)
		var label := Label.new()
		label.add_theme_color_override("font_color",Color("34504e"))
		label.add_theme_font_size_override("font_size",18)
		label.custom_minimum_size.x = 390
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s ×%d\n%s" % [tr(relic.name_key), relics.held[id], tr(relic.description_key)]
		$Collection/Scroll/Items.add_child(label)
