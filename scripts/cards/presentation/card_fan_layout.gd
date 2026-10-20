class_name CardFanLayout
extends RefCounted
## Card top edges follow tangents to one shared arc; hover keeps the spacing.
const CARD_SCALE := 0.82
const OVERLAP := 8.0
const MAX_ANGLE := 4.0
const HOVER_LIFT := 12.0
const HOVER_TIME := 0.14
const INSERT_TIME := 0.28
const SHIFT_TIME := 0.22

static func step_for(card_width: float, count: int, available: float) -> float:
	return minf(card_width-OVERLAP, maxf(0, (available-card_width)/maxi(1, count-1)))

static func width_for(card_width: float, count: int, step: float) -> float:
	return card_width+maxi(0, count-1)*step

static func drop_for(count: int, step: float) -> float:
	return maxi(0, count-1)*step*tan(deg_to_rad(MAX_ANGLE)*0.5)

static func offset(index: int, count: int, step: float, side: int, card_size: Vector2) -> Vector2:
	var rotation := angle(index, count, side)
	var curvature := sin(deg_to_rad(MAX_ANGLE))
	if is_zero_approx(curvature): return Vector2(index*step, 0)
	var radius := maxi(0, count-1)*step/curvature
	# Place top centres on the circle and use its tangent as each card's angle.
	# Compensate for the bottom-centre pivot used by the visual controls.
	return Vector2(index*step-card_size.y*sin(rotation), (radius-card_size.y)*(1.0-cos(rotation)))

static func angle(index: int, count: int, side: int) -> float:
	return -side*asin(_inward(index, count, side)*sin(deg_to_rad(MAX_ANGLE)))

static func _inward(index: int, count: int, side: int) -> float:
	if count <= 1: return 0.0
	var t := float(index)/(count-1)
	return t if side < 0 else 1.0-t

## Pick only on actual pointer motion. Tweening cards cannot trigger a hover loop.
static func pick(items: Array, point: Vector2, extra_top := 0.0, hovered := -1) -> int:
	var picked := -1
	var depth := -2147483648
	for i in items.size():
		var item: Control = items[i]
		if not item.is_visible_in_tree(): continue
		var rect := Rect2(Vector2(0, -extra_top), item.size+Vector2(0, extra_top))
		if i == hovered: rect.size.y += HOVER_LIFT
		if item.z_index >= depth and rect.has_point(item.get_global_transform().affine_inverse()*point):
			picked = i
			depth = item.z_index
	return picked
