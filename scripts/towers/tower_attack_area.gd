@tool
class_name TowerAttackArea
extends Resource
## Editable attack tiles relative to the tower anchor. Forward is local -Z.
@export var offsets: Array[Vector2i] = []:
	set(value):
		offsets = value
		emit_changed()

func configuration_error() -> String:
	if offsets.is_empty(): return "防禦塔攻擊區域不可為空"
	for cell in offsets:
		if absi(cell.x) >= 32767 or absi(cell.y) >= 32767:
			return "防禦塔攻擊區域座標超出範圍"
	return ""

func cells_at(anchor: Vector2i, turns := 0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	for offset in offsets:
		for i in posmod(turns, 4): offset = Vector2i(-offset.y, offset.x)
		var cell := anchor+offset
		if not seen.has(cell):
			seen[cell] = true
			result.append(cell)
	return result

static func circle_cells(center: Vector2i, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_finite(radius) or radius < 0: return result
	var extent := floori(radius)
	for y in range(-extent, extent+1):
		for x in range(-extent, extent+1):
			if x*x+y*y <= radius*radius: result.append(center+Vector2i(x, y))
	return result
