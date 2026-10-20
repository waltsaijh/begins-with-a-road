@tool
extends Control
## Keep the two name parts together when inline, or right-align both stacked lines.
var _prefix := "轉角"
var _tower := "哨塔"
var _english := false
var _shop := false

func _ready() -> void:
	resized.connect(_layout)
	_refresh()

func show_name_parts(prefix: String, tower: String, english: bool, shop: bool) -> void:
	_prefix = prefix
	_tower = tower
	_english = english
	_shop = shop
	_refresh()

func _refresh() -> void:
	if not is_node_ready(): return
	$Prefix.text = _prefix
	$Prefix.visible = not _shop and not _prefix.is_empty()
	$Prefix.add_theme_font_size_override("font_size", 12 if _english else 16)
	$TowerName.text = _tower
	$TowerName.add_theme_font_size_override("font_size", 16 if _english else 16)
	$TowerName.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _shop else HORIZONTAL_ALIGNMENT_RIGHT
	var height: float = $TowerName.get_minimum_size().y
	if _english and $Prefix.visible: height += $Prefix.get_minimum_size().y
	custom_minimum_size.y = height
	_layout()

func _layout() -> void:
	if not is_node_ready(): return
	if _english and $Prefix.visible:
		var prefix_height: float = $Prefix.get_minimum_size().y
		$Prefix.position = Vector2.ZERO
		$Prefix.size = Vector2(size.x, prefix_height)
		$TowerName.position = Vector2(0, prefix_height)
		$TowerName.size = Vector2(size.x, size.y-prefix_height)
	else:
		var tower_width := size.x if _shop else minf(_text_width($TowerName), size.x)
		var prefix_width := minf(_text_width($Prefix), maxf(0.0, size.x-tower_width)) if $Prefix.visible else 0.0
		$Prefix.position = Vector2(size.x-tower_width-prefix_width, 0)
		$Prefix.size = Vector2(prefix_width, size.y)
		$TowerName.position = Vector2(size.x-tower_width, 0)
		$TowerName.size = Vector2(tower_width, size.y)

func _text_width(label: Label) -> float:
	return ceilf(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x)
