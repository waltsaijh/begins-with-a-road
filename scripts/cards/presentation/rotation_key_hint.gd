@tool
extends Control
## Screen-sized hint projected above the placement hologram; never captures input.
@export_range(0.0, 2.0, 0.05) var hover_seconds := 0.5
@export_range(0.01, 1.0, 0.01) var reveal_seconds := 0.15
@export var rise_pixels := 6.0
var _elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint(): reset()

func reset() -> void:
	_elapsed = 0.0
	hide()
	modulate.a = 0.0

func follow(camera: Camera3D, anchor: Vector3, delta: float) -> void:
	if camera == null or camera.is_position_behind(anchor):
		reset()
		return
	var point := camera.unproject_position(anchor)
	if not get_viewport_rect().has_point(point):
		reset()
		return
	# Hover timing stays in real seconds even when combat runs at 2x or 4x.
	_elapsed += delta/maxf(Engine.time_scale, 0.001)
	var progress := clampf((_elapsed-hover_seconds)/reveal_seconds, 0.0, 1.0)
	var eased := 1.0-pow(1.0-progress, 2.0)
	position = point-Vector2(size.x*0.5, size.y+rise_pixels*eased)
	modulate.a = eased
	visible = progress > 0.0
