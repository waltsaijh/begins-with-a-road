class_name TowerBodyGeometry
extends RefCounted
## All coordinates here are relative to the anchor, in the weapon's facing.
static func local_cells(preset: TilePreset) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if preset != null:
		for cell in preset.tower_footprint:
			result.append(BuildCard.rotate_cell(cell-preset.tower_offset,-preset.facing_steps))
	return result

static func bounds(body: Array[Vector2i]) -> Rect2i:
	if body.is_empty(): return Rect2i(0,0,1,1)
	var lo := body[0]
	var hi := body[0]
	for cell in body:
		lo = lo.min(cell); hi = hi.max(cell)
	return Rect2i(lo,hi-lo+Vector2i.ONE)

static func center(body: Array[Vector2i]) -> Vector2:
	var rect := bounds(body)
	return Vector2(rect.position)+Vector2(rect.size-Vector2i.ONE)*0.5

static func weapon_lane(body: Array[Vector2i]) -> int:
	var counts := {}
	for cell in body: counts[cell.x] = int(counts.get(cell.x,0))+1
	var best := 0
	for x: int in counts:
		if int(counts[x]) > int(counts.get(best,0)) or (counts[x] == counts.get(best,0) and absi(x) < absi(best)): best = x
	return best

static func origin(definition: TowerDefinition, body: Array[Vector2i]) -> Vector2:
	if body.is_empty() or definition.deployment != null or definition.name_key == "tower.sentry.name": return Vector2.ZERO
	if definition.name_key == "tower.ballista.name":
		var lane := weapon_lane(body)
		var front := bounds(body).end.y
		var back := bounds(body).position.y
		for cell in body:
			if cell.x == lane: front = mini(front,cell.y); back = maxi(back,cell.y)
		return Vector2(lane,(front+back)*0.5)
	return center(body)

static func base_cells(definition: TowerDefinition, body: Array[Vector2i], radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rect := bounds(body)
	if definition.name_key == "tower.broadside.name":
		for y in range(rect.position.y,rect.end.y):
			for step in range(1,4):
				result.append(Vector2i(rect.position.x-step,y))
				result.append(Vector2i(rect.end.x-1+step,y))
	elif definition.name_key == "tower.ballista.name" and definition.attack_area != null:
		var lane := weapon_lane(body)
		var front := rect.end.y
		for cell in body:
			if cell.x == lane: front = mini(front,cell.y)
		for offset in definition.attack_area.offsets: result.append(Vector2i(lane,front)+offset)
	elif definition.attack_area == null:
		var c := origin(definition,body)
		for y in range(floori(c.y-radius),ceili(c.y+radius)+1):
			for x in range(floori(c.x-radius),ceili(c.x+radius)+1):
				if Vector2(x,y).distance_squared_to(c) <= radius*radius: result.append(Vector2i(x,y))
	else: result = definition.attack_area.cells_at(Vector2i.ZERO)
	return result
