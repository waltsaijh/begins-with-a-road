@tool
extends CardButton
## Scene-authored artwork, layout and tile recipe cells.
enum Presentation { HAND, SHOP }
@export var presentation: Presentation = Presentation.HAND:
	set(value):
		presentation = value
		_refresh()
## -1 previews the resource price; the shop supplies its actual offer price.
@export_range(-1, 100, 1, "or_greater") var price_override := -1:
	set(value):
		price_override = value
		_refresh()
@export var can_afford := true:
	set(value):
		can_afford = value
		_refresh()
@export var coin_texture: Texture2D:
	set(value):
		coin_texture = value
		_refresh()
@export var card: BuildCard:
	set(value):
		if card == value:
			return
		if is_instance_valid(card) and card.changed.is_connected(_refresh):
			card.changed.disconnect(_refresh)
		card = value
		if card != null:
			card.changed.connect(_refresh)
		_refresh()
@export_range(0, 3, 1) var turns := 0:
	set(value):
		turns = posmod(value, 4)
		_refresh()
@export var selected := false:
	set(value):
		selected = value
		_refresh()
@export_range(1, 9, 1) var key_number := 1:
	set(value):
		key_number = value
		_refresh()
@export_group("Default Artwork")
@export var default_background: Texture2D:
	set(value):
		default_background = value
		_refresh()
@export var default_frame: Texture2D:
	set(value):
		default_frame = value
		_refresh()
@export var default_icon: Texture2D:
	set(value):
		default_icon = value
		_refresh()
## Tint alpha-mask icons with a moderately dark shade of the tower accent.
@export_range(0.0, 1.0, 0.01) var icon_darkening := 0.45:
	set(value):
		icon_darkening = value
		_refresh()
var hovered := false
@export var show_shortcut := true:
	set(value):
		show_shortcut = value
		_refresh()
var _tower: TowerDefinition
@export_group("Editor Preview")
@export var preview_tower: TowerDefinition

func _ready() -> void:
	if Engine.is_editor_hint() and card == null and preview_tower != null:
		card = BuildCard.from_parts(preview_tower, preview_tower.first_tile_preset())
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_refresh()

func _on_hover(value: bool) -> void:
	hovered = value
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED: _refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	var definition := card.tower if card != null else null
	if _tower != definition:
		if is_instance_valid(_tower) and _tower.changed.is_connected(_refresh):
			_tower.changed.disconnect(_refresh)
		_tower = definition
		if _tower != null:
			_tower.changed.connect(_refresh)
	var accent := _tower.accent_color if _tower != null else Color.WHITE
	$Background.texture = card.background_texture if card != null and card.background_texture != null else default_background
	$Accent.texture = card.frame_texture if card != null and card.frame_texture != null else default_frame
	$Accent.self_modulate = accent.lightened(0.15) if hovered else accent
	$Selection.texture = $Accent.texture
	$Selection.self_modulate = accent.lightened(0.3)
	$Selection.visible = selected
	%TowerIcon.texture = _tower.icon if _tower != null and _tower.icon != null else default_icon
	%TowerIcon.self_modulate = accent.darkened(icon_darkening)
	%Divider.color = accent
	%Shortcut.text = str(key_number)
	var shop := presentation == Presentation.SHOP
	%Shortcut.visible = not shop and show_shortcut
	var prefix := card.localized_prefix() if card != null and not shop else ""
	var tower_name := _tower.localized_name() if _tower != null else tr("card.unassigned")
	%CardTitle.show_name_parts(prefix, tower_name, TranslationServer.get_locale().get_slice("_", 0) == "en", shop)
	%Price.visible = shop and card != null
	%Price.get_node("Gold").texture = coin_texture
	%Price.get_node("Number").text = str(price_override if price_override >= 0 else (card.price if card != null else 0))
	%Price.get_node("Number").add_theme_color_override("font_color", Color("244c52") if can_afford else Color("c44738"))
	%TileDiagram.show_recipe(card, turns, accent)
	disabled = card == null or (shop and not can_afford)
