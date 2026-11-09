extends CanvasLayer
signal selected(relic: RelicDefinition)
const Card = preload("res://scenes/relics/components/relic_card.tscn")
const IconMask = preload("res://assets/shaders/ui_icon_mask.gdshader")
var relics: RunRelics
var offers: Array[RelicDefinition] = []
var choosing := false
var _committing := false
var _inspected: RelicDefinition
var _inspection_hud: Node
@onready var modal: Control = $Modal
@onready var row: HBoxContainer = $Modal/Center/Layout/Cards
@onready var debug_reroll_button: Button = $Modal/DebugReroll

func _ready() -> void:
	debug_reroll_button.visible = OS.is_debug_build()
	debug_reroll_button.pressed.connect(debug_reroll)

func _process(_delta: float) -> void:
	# Keep the normal HUD pause control reachable; the pause menu owns its overlay.
	visible = not get_tree().paused or $Collection.visible
	if choosing: _layout_cards()

func setup(manager: RunRelics) -> void:
	relics = manager
	relics.changed.connect(_refresh_collection)
	$Collection.close_requested.connect(close_collection)
	$Collection/Paper/Details/Close.pressed.connect(close_collection)
	_refresh_collection()

func begin() -> bool:
	if choosing: return true
	offers = relics.options()
	if offers.is_empty(): return false
	choosing = true
	_committing = false
	$Collection.hide()
	$RelicBar.hide()
	_rebuild_cards()
	modal.show()
	return true

func debug_reroll() -> bool:
	if not OS.is_debug_build() or not choosing or _committing or get_tree().paused: return false
	var next_offers := relics.options()
	if next_offers.is_empty(): return false
	offers = next_offers
	_rebuild_cards()
	return true

func _rebuild_cards() -> void:
	for child in row.get_children(): child.free()
	debug_reroll_button.disabled = false
	for relic in offers:
		var card: Button = Card.instantiate()
		row.add_child(card)
		card.get_node("Contents/Icon").texture = relic.icon
		card.get_node("Contents/Heading/Title").text = tr(relic.name_key)
		card.get_node("Contents/Heading/Usage").text = relic.usage_text()
		card.get_node("Contents/Description").text = relic.localized_description()
		_color_card(card,relic)
		card.pressed.connect(choose.bind(relic))
	_layout_cards.call_deferred()

func _refresh_card_text() -> void:
	for i in mini(offers.size(),row.get_child_count()):
		var card: Button = row.get_child(i)
		card.get_node("Contents/Heading/Title").text = tr(offers[i].name_key)
		card.get_node("Contents/Heading/Usage").text = offers[i].usage_text()
		card.get_node("Contents/Description").text = offers[i].localized_description()
	_layout_cards.call_deferred()

func _layout_cards() -> void:
	if not choosing or row.get_child_count() == 0: return
	var viewport := get_viewport().get_visible_rect().size
	var width := minf(232.0,(viewport.x-64.0-20.0*(row.get_child_count()-1))/row.get_child_count())
	for card: Button in row.get_children():
		card.custom_minimum_size = Vector2(width,400)
		var description: Label = card.get_node("Contents/Description")
		var font_size := 14
		var font := description.get_theme_font("font")
		var available := minf(400.0,viewport.y-150.0)-170.0
		while font_size > 12:
			var measured := font.get_multiline_string_size(description.text,HORIZONTAL_ALIGNMENT_LEFT,width-32,font_size,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE)
			if measured.y+description.text.count("\n")*3 <= available: break
			font_size -= 1
		if description.get_theme_font_size("font_size") != font_size: description.add_theme_font_size_override("font_size",font_size)
	# Keep the debug action below the real card bottoms as text grows.
	var bottom := row.get_global_rect().end.y
	debug_reroll_button.position.y = minf(viewport.y-44,bottom+10)

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
	card.get_node("Contents/Heading/Title").add_theme_color_override("font_color",accent.darkened(0.65))
	card.get_node("Contents/Heading/Usage").add_theme_color_override("font_color",relic.icon_color())
	var icon: TextureRect = card.get_node("Contents/Icon")
	if relic.tower != null:
		# Tower art is an alpha mask; use the same tint as hand/shop tower icons.
		var material := ShaderMaterial.new()
		material.shader = IconMask
		icon.material = material
		icon.self_modulate = relic.icon_color()

func choose(relic: RelicDefinition) -> bool:
	if not choosing or _committing or get_tree().paused or not offers.has(relic): return false
	_committing = true
	if not relics.acquire(relic):
		_committing = false
		return false
	debug_reroll_button.disabled = true
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
	$RelicBar.visible = not relics.held.is_empty()
	selected.emit(relic)

func _refresh_collection() -> void:
	for child in $RelicBar/Items.get_children(): child.free()
	$RelicBar.visible = not choosing and not relics.held.is_empty()
	for id: StringName in relics.held:
		var relic := relics.catalog.find(id)
		var button := Button.new()
		button.custom_minimum_size = Vector2(38,38)
		button.set_meta("relic_id",id)
		button.tooltip_text = "%s ×%d\n%s" % [tr(relic.name_key),relics.held[id],relic.localized_description()]
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(relic.presentation_color(),0.12)
		normal.border_color = Color(relic.presentation_color().darkened(0.2),0.65)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(3)
		button.add_theme_stylebox_override("normal",normal)
		var hover := normal.duplicate()
		hover.bg_color.a = 0.28
		for state in ["hover","pressed","focus"]: button.add_theme_stylebox_override(state,hover)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = relic.icon
		icon.position = Vector2(5,5)
		icon.size = Vector2(28,28)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if relic.tower != null:
			var material := ShaderMaterial.new()
			material.shader = IconMask
			icon.material = material
			icon.self_modulate = relic.icon_color()
		button.add_child(icon)
		if relics.held[id] > 1:
			var count := Label.new()
			count.text = "×%d" % relics.held[id]
			count.position = Vector2(18,20)
			count.add_theme_font_size_override("font_size",12)
			count.add_theme_color_override("font_color",Color("244c52"))
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(count)
		button.pressed.connect(open_collection.bind(relic))
		$RelicBar/Items.add_child(button)
	if $Collection.visible and _inspected != null: _show_relic()

func open_collection(relic: RelicDefinition) -> void:
	if choosing or relic == null or not relics.held.has(relic.id): return
	_inspection_hud = get_parent().get_node_or_null("LevelHUD")
	if _inspection_hud == null or not _inspection_hud.begin_inspection(self): return
	_inspected = relic
	_show_relic()
	$Collection.show()
	$Collection/Paper/Details/Close.grab_focus()

func _show_relic() -> void:
	$Collection/Paper/Details/Title.text = "%s ×%d" % [tr(_inspected.name_key),relics.held.get(_inspected.id,0)]
	var icon: TextureRect = $Collection/Paper/Details/Icon
	icon.texture = _inspected.icon
	icon.material = null
	icon.self_modulate = Color.WHITE
	if _inspected.tower != null:
		var material := ShaderMaterial.new()
		material.shader = IconMask
		icon.material = material
		icon.self_modulate = _inspected.icon_color()
	$Collection/Paper/Details/Description.text = _inspected.usage_text()+"\n\n"+_inspected.localized_description()
	$Collection/Paper/Details/Close.text = GameText.text("text.relic_choice.global_1")

func close_collection() -> void:
	$Collection.hide()
	if is_instance_valid(_inspection_hud): _inspection_hud.end_inspection(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and relics != null:
		_refresh_collection()
		if choosing: _refresh_card_text()

func _exit_tree() -> void:
	if is_instance_valid(_inspection_hud) and _inspection_hud.is_inside_tree(): _inspection_hud.end_inspection(self)
