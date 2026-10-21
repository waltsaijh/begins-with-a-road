@tool
class_name CardButton
extends Button
## Retain the original lower hit area while the card lifts above it.
var hover_lift := 0.0

func _enter_tree() -> void:
	add_to_group("camera_drag_blockers")

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size+Vector2(0, hover_lift)).has_point(point)

## Shared by camera gestures and card drops, including disabled cards/backs.
static func has_card_at(viewport: Viewport, point: Vector2) -> bool:
	for card: CardButton in viewport.get_tree().get_nodes_in_group("camera_drag_blockers"):
		if card.get_viewport() != viewport or not card.is_visible_in_tree(): continue
		var local := card.get_global_transform_with_canvas().affine_inverse()*point
		if card._has_point(local): return true
	return false
