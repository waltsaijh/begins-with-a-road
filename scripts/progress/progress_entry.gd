extends HBoxContainer
## One tower, enemy or relic on the progress page; choosing it fills the detail column.
signal chosen
const IconMask = preload("res://assets/shaders/ui_icon_mask.gdshader")
const HOVER_TINT := Color(0.2, 0.36, 0.38, 0.1)
const SELECTED_TINT := Color(0.2, 0.36, 0.38, 0.2)
var selected := false
var _hovered := false

func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func configure(definition: Dictionary) -> void:
	$Tile.self_modulate = definition.tile
	$Tile/Icon.texture = definition.icon
	if definition.has("tint"):
		var mask := ShaderMaterial.new()
		mask.shader = IconMask
		$Tile/Icon.material = mask
		$Tile/Icon.self_modulate = definition.tint
	$Text/Name.text = definition.name
	$Text/Usage.text = definition.get("usage", "")
	$Text/Usage.visible = definition.has("usage")
	if definition.has("usage"): $Text/Usage.add_theme_color_override("font_color", definition.usage_color)

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if clicked or event.is_action_pressed("ui_accept"):
		chosen.emit()
		accept_event()

func _draw() -> void:
	if selected: draw_rect(Rect2(Vector2.ZERO, size), SELECTED_TINT)
	elif _hovered or has_focus(): draw_rect(Rect2(Vector2.ZERO, size), HOVER_TINT)
