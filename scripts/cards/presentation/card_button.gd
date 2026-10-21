@tool
class_name CardButton
extends Button
## Retain the original lower hit area while the card lifts above it.
var hover_lift := 0.0

func _enter_tree() -> void:
	add_to_group("camera_drag_blockers")

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size+Vector2(0, hover_lift)).has_point(point)
