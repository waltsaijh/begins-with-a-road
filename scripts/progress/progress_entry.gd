extends HBoxContainer
## One tower or enemy on the progress page.
const IconMask = preload("res://assets/shaders/ui_icon_mask.gdshader")

func configure(definition: Dictionary) -> void:
	$Tile.self_modulate = definition.tile
	$Tile/Icon.texture = definition.icon
	if definition.has("tint"):
		var mask := ShaderMaterial.new()
		mask.shader = IconMask
		$Tile/Icon.material = mask
		$Tile/Icon.self_modulate = definition.tint
	$Text/Name.text = definition.name
	$Text/Description.text = definition.description
	$Text/Description.visible = not definition.description.is_empty()
	$Text/Stats.text = "  ·  ".join(definition.stats)
	$Text/Traits.text = "  ·  ".join(definition.traits)
	$Text/Traits.visible = not definition.traits.is_empty()
