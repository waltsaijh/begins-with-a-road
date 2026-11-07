extends Control
## Independent screen-space inventory; acquisitions append from left to right.
const Item = preload("res://scenes/relics/components/relic_inventory_item.tscn")
const IconMask = preload("res://assets/shaders/ui_icon_mask.gdshader")
## Left margin and distance from the bottom of the viewport to the row's bottom.
@export var screen_margin := Vector2(16,216)
var relics: RunRelics
var available := true
var _order: Array[StringName] = []

func setup(manager: RunRelics) -> void:
	relics = manager
	relics.changed.connect(_refresh)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and relics != null: _refresh()

func _refresh() -> void:
	# Preserve acquisition order across changes, including repeatable relics and
	# removal in the playground. Only presentation state is stored here.
	var remaining := relics.held.duplicate()
	var order: Array[StringName] = []
	for id in _order:
		if int(remaining.get(id,0)) <= 0: continue
		order.append(id)
		remaining[id] -= 1
	for id: StringName in remaining:
		for copy in int(remaining[id]): order.append(id)
	_order = order
	for child in $Icons.get_children():
		$Icons.remove_child(child)
		child.queue_free()
	for id in _order:
		var relic := relics.catalog.find(id)
		if relic == null: continue
		var icon: TextureRect = Item.instantiate()
		icon.texture = relic.icon
		icon.tooltip_text = "%s\n%s" % [tr(relic.name_key),tr(relic.description_key)]
		icon.set_meta("relic_id",id)
		if relic.tower != null:
			var mask := ShaderMaterial.new()
			mask.shader = IconMask
			icon.material = mask
			icon.self_modulate = relic.presentation_color().darkened(0.45)
		$Icons.add_child(icon)
	_update_position()

func _process(_delta: float) -> void:
	_update_position()

func _update_position() -> void:
	visible = available and not get_tree().paused and $Icons.get_child_count() > 0
	if not visible: return
	size = $Icons.get_combined_minimum_size()
	$Icons.size = size
	var viewport := get_viewport().get_visible_rect().size
	position = Vector2(screen_margin.x,viewport.y-screen_margin.y-size.y)
