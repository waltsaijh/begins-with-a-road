extends RefCounted
## Projects allocated walks onto reciprocal road bands. No planner/RNG writes.
const Surface = preload("res://scripts/map/tile/appearance/road_surface.gd")
var masks := {}
var bands := {}
var projected_trips: Array = []
var groups := {}
var counts := {}
var peak := 1
var fallback_trips := 0
var _rectangles := {}
var _last_piece := {}
var _corridors: Array[Rect2i] = []
var _members := {}
var _entry_centers := {}

func _prepare_regions() -> void:
	_corridors.clear(); _members.clear(); _entry_centers.clear()
	# Maximal fully reciprocal rectangles describe the actual wide-road arms.
	# Their overlap is a shared junction, not a set of individual lane turns.
	var candidates := {}
	var spans := {}
	for cell: Vector2i in masks:
		var left := cell.x; var right := cell.x
		while connects(Vector2i(left,cell.y),Vector2i(left-1,cell.y)): left -= 1
		while connects(Vector2i(right,cell.y),Vector2i(right+1,cell.y)): right += 1
		if right-left < 1: continue
		var span := Vector3i(left,right,cell.y)
		if spans.has(span): continue
		spans[span] = true
		var top := cell.y; var bottom := cell.y
		for sign_value: int in [-1,1]:
			var y := cell.y
			while true:
				var next := y+sign_value; var complete := true
				for x in range(left,right+1):
					if not connects(Vector2i(x,y),Vector2i(x,next)): complete = false; break
					if x < right and not connects(Vector2i(x,next),Vector2i(x+1,next)): complete = false; break
				if not complete: break
				y = next
			if sign_value < 0: top = y
			else: bottom = y
		if bottom-top >= 1: candidates[Rect2i(left,top,right-left+1,bottom-top+1)] = true
	for rect: Rect2i in candidates:
		var maximal := true
		for other: Rect2i in candidates:
			if other != rect and other.encloses(rect): maximal = false; break
		if maximal: _corridors.append(rect)
	for id in _corridors.size():
		var rect := _corridors[id]
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var cell := Vector2i(x,y)
				if not _members.has(cell): _members[cell] = []
				_members[cell].append(id)

func _entry_center(id: int, axis: int, side: int) -> Variant:
	var key := Vector3i(id,axis,side)
	if _entry_centers.has(key): return _entry_centers[key]
	var rect := _corridors[id]; var gates := {}
	var size: int = rect.size.y if axis == 0 else rect.size.x
	for offset in size:
		var cell := Vector2i(rect.position.x if side < 0 else rect.end.x-1,rect.position.y+offset) if axis == 0 else Vector2i(rect.position.x+offset,rect.position.y if side < 0 else rect.end.y-1)
		var other := cell+(Vector2i(side,0) if axis == 0 else Vector2i(0,side))
		if connects(cell,other):
			var gate := band(cell,other); gates[gate.key] = gate
	var result: Variant = null
	if gates.size() == 1:
		var gate: Dictionary = gates.values()[0]
		if gate.width < size: result = gate.center.y if axis == 0 else gate.center.x
	_entry_centers[key] = result
	return result

func connects(a: Vector2i, b: Vector2i) -> bool:
	var delta := b-a
	var d := TileConstants.DIRECTIONS.find(Vector3i(delta.x,0,delta.y))
	return d >= 0 and (int(masks.get(a,0)) & (1<<d)) != 0 and (int(masks.get(b,0)) & (1<<((d+2)%4))) != 0

func band(a: Vector2i, b: Vector2i) -> Dictionary:
	var key := Vector4i(a.x,a.y,b.x,b.y)
	if bands.has(key): return bands[key]
	var delta := b-a
	var lateral := Vector2i(-delta.y,delta.x)
	var first := 0; var last := 0
	if connects(a,b):
		for sign_value: int in [-1,1]:
			var offset := 0
			while true:
				var p := a+lateral*offset
				var q := b+lateral*offset
				var next := offset+sign_value
				if not connects(p,a+lateral*next) or not connects(q,b+lateral*next) or not connects(a+lateral*next,b+lateral*next): break
				offset = next
			if sign_value < 0: first = offset
			else: last = offset
	var center := (Vector2(a)+Vector2(b))*0.5+Vector2(lateral)*float(first+last)*0.5
	var result := {"center":center,"width":last-first+1,"key":str([center,delta])}
	for offset in range(first,last+1):
		var p := a+lateral*offset; var q := b+lateral*offset
		bands[Vector4i(p.x,p.y,q.x,q.y)] = result
	return result

func cell_band(cell: Vector2i, axis: int) -> Dictionary:
	var delta := Vector2i.RIGHT if axis == 0 else Vector2i.DOWN
	var choices: Array = []
	for other in [cell-delta,cell+delta]:
		if connects(cell,other): choices.append(band(cell,other))
	if choices.is_empty(): return {"center":Vector2(cell),"width":1}
	var width := 2147483647; var center := Vector2.ZERO; var total := 0
	for choice: Dictionary in choices:
		if choice.width < width: width = choice.width; center = Vector2.ZERO; total = 0
		if choice.width == width: center += choice.center; total += 1
	center /= total
	if axis == 0: center.x = cell.x
	else: center.y = cell.y
	return {"center":center,"width":width}

func contains(point: Vector2) -> bool:
	# Test both owners when the centerline lies exactly on a shared boundary.
	var at := Vector2i(floori(point.x+0.5),floori(point.y+0.5))
	for y in range(at.y-1,at.y+2):
		for x in range(at.x-1,at.x+2):
			var cell := Vector2i(x,y)
			if not masks.has(cell): continue
			if _rectangles.has(cell):
				for rect: Rect2 in _rectangles[cell]:
					if rect.grow(0.0001).has_point(point-Vector2(cell)): return true
				continue
			var shape := Vector2i(0,0)
			for d in 4:
				var delta: Vector3i = TileConstants.DIRECTIONS[d]
				if connects(cell,cell+Vector2i(delta.x,delta.z)): shape.x |= 1<<d
				var next: Vector3i = TileConstants.DIRECTIONS[(d+1)%4]
				var a := cell+Vector2i(delta.x,delta.z); var b := cell+Vector2i(next.x,next.z)
				if connects(cell,a) and connects(cell,b) and connects(a,a+Vector2i(next.x,next.z)) and connects(b,b+Vector2i(delta.x,delta.z)): shape.y |= 1<<d
			_rectangles[cell] = Surface.road_rects(shape)
			for rect: Rect2 in _rectangles[cell]:
				if rect.grow(0.0001).has_point(point-Vector2(cell)): return true
	return false

func _safe_link(a: Vector2, b: Vector2) -> bool:
	for sample in 13:
		if not contains(a.lerp(b,sample/12.0)): return false
	return true

func project(cells: PackedVector2Array) -> PackedVector2Array:
	var axes: Array[int] = []
	for id in _corridors.size():
		var rect := _corridors[id]
		var first := Vector2.ZERO; var last := Vector2.ZERO; var found := false
		for cell in cells:
			if not rect.has_point(Vector2i(cell)): continue
			if not found: first = cell; found = true
			last = cell
		var delta := last-first
		var axis := 0 if absf(delta.x) >= absf(delta.y) else 1
		# Multiple intersecting arms retain their common geometric junction.
		if _corridors.size() > 1 and rect.size.x != rect.size.y: axis = 0 if rect.size.x > rect.size.y else 1
		axes.append(axis)
	var result := PackedVector2Array()
	for cell in cells:
		var members: Array = _members.get(Vector2i(cell),[])
		var horizontal: Array[float] = []; var vertical: Array[float] = []
		for id: int in members:
			var rect := _corridors[id]
			var center := Vector2(rect.position)+Vector2(rect.size-Vector2i.ONE)*0.5
			if axes[id] == 0:
				if int(cell.x) == rect.position.x or int(cell.x) == rect.end.x-1:
					var entry: Variant = _entry_center(id,0,-1 if int(cell.x) == rect.position.x else 1)
					if entry != null: center.y = float(entry)
				horizontal.append(center.y)
			else:
				if int(cell.y) == rect.position.y or int(cell.y) == rect.end.y-1:
					var entry: Variant = _entry_center(id,1,-1 if int(cell.y) == rect.position.y else 1)
					if entry != null: center.x = float(entry)
				vertical.append(center.x)
		var point := cell
		if not horizontal.is_empty():
			point.y = 0.0
			for value in horizontal: point.y += value/horizontal.size()
		if not vertical.is_empty():
			point.x = 0.0
			for value in vertical: point.x += value/vertical.size()
		result.append(point if contains(point) else cell)
	# An entry from a narrow arm retains the real gate before moving toward
	# the wider center. All trips sharing that gate receive the same transition.
	for i in range(result.size()-1):
		if _safe_link(result[i],result[i+1]): continue
		var axis := 0 if cells[i].x != cells[i+1].x else 1
		var a: Vector2 = cell_band(Vector2i(cells[i]),axis).center
		var b: Vector2 = cell_band(Vector2i(cells[i+1]),axis).center
		if _safe_link(a,b): result[i] = a; result[i+1] = b
	return result

func _strength(edge: Vector4i, source: Dictionary) -> float:
	var a := Vector2i(edge.x,edge.y); var b := Vector2i(edge.z,edge.w)
	return log(1.0+int(source.get(band(a,b).key,0)))/log(1.0+peak)

func _at_strength(weights: Array[float], time: float) -> float:
	var at := clampi(floori(time),0,weights.size()-1)
	return lerpf(weights[at],weights[mini(at+1,weights.size()-1)],clampf(time-at,0.0,1.0))

func _add(a: Vector2, b: Vector2, ta: float, tb: float, sa: float, sb: float, raw_edge: Vector4i) -> void:
	var dwell := a.distance_squared_to(b) < 0.000001
	if dwell: b = a+Vector2(0.0001,0)
	var base := floori(ta)
	var pa := ta-base; var pb := tb-base
	var key := str([a.snapped(Vector2.ONE*0.0001),b.snapped(Vector2.ONE*0.0001),snappedf(pa,0.0001),snappedf(pb,0.0001),dwell])
	if not groups.has(key): groups[key] = {"a":a,"b":b,"phase_a":pa,"phase_b":pb,"phases":{},"strength":sa,"end_strength":sb,"dwell":dwell,"arc":false,"clip_a":Vector2.ZERO if dwell else (b-a).normalized(),"clip_b":Vector2.ZERO if dwell else (b-a).normalized(),"sources":{}}
	var piece: Dictionary = groups[key]
	piece.phases[base] = true; piece.sources[raw_edge] = true
	piece.strength = maxf(piece.strength,sa); piece.end_strength = maxf(piece.end_strength,sb)
	if not _last_piece.is_empty() and _last_piece.b.distance_squared_to(a) < 0.00001 and not dwell:
		var normal: Vector2 = ((_last_piece.b-_last_piece.a).normalized()+(b-a).normalized()).normalized()
		if normal.length_squared() > 0.5: _last_piece.clip_b = normal; piece.clip_a = normal
	_last_piece = piece

func build(segments: Dictionary, all_segments: Dictionary, animation: RoadFlowPhases, radius: float) -> Array:
	counts.clear(); groups.clear(); projected_trips.clear(); peak = 1; fallback_trips = 0
	_prepare_regions()
	for edge: Vector4i in all_segments:
		var key: String = band(Vector2i(edge.x,edge.y),Vector2i(edge.z,edge.w)).key
		counts[key] = int(counts.get(key,0))+int(all_segments[edge])
	for count: int in counts.values(): peak = maxi(peak,count)
	var selected := {}
	for edge: Vector4i in segments:
		var key: String = band(Vector2i(edge.x,edge.y),Vector2i(edge.z,edge.w)).key
		selected[key] = int(selected.get(key,0))+int(segments[edge])
	for cells: PackedVector2Array in animation.trips:
		if cells.size() < 2: continue
		_last_piece = {}
		var points := project(cells)
		var safe := true
		for i in range(points.size()-1):
			for sample in 9:
				if not contains(points[i].lerp(points[i+1],sample/8.0)): safe = false
		if not safe: points = cells; fallback_trips += 1
		projected_trips.append({"cells":cells,"points":points})
		var edge_weights: Array[float] = []
		for i in range(cells.size()-1): edge_weights.append(_strength(Vector4i(int(cells[i].x),int(cells[i].y),int(cells[i+1].x),int(cells[i+1].y)),selected))
		var weights: Array[float] = []
		for i in cells.size(): weights.append((edge_weights[maxi(0,i-1)]+edge_weights[mini(i,edge_weights.size()-1)])*0.5)
		var entries := points.duplicate(); var exits := points.duplicate()
		var enter_times: Array[float] = []; var exit_times: Array[float] = []
		for i in points.size(): enter_times.append(float(i)); exit_times.append(float(i))
		for i in range(1,points.size()-1):
			var incoming := points[i]-points[i-1]; var outgoing := points[i+1]-points[i]
			if incoming.length() < 0.001 or outgoing.length() < 0.001 or absf(incoming.normalized().dot(outgoing.normalized())) > 0.999: continue
			var trim := minf(radius,minf(incoming.length(),outgoing.length())*0.3)
			entries[i] = points[i]-incoming.normalized()*trim
			exits[i] = points[i]+outgoing.normalized()*trim
			enter_times[i] -= trim/incoming.length(); exit_times[i] += trim/outgoing.length()
		for i in range(points.size()-1):
			var edge := Vector4i(int(cells[i].x),int(cells[i].y),int(cells[i+1].x),int(cells[i+1].y))
			_add(exits[i],entries[i+1],exit_times[i],enter_times[i+1],_at_strength(weights,exit_times[i]),_at_strength(weights,enter_times[i+1]),edge)
			if i+2 >= points.size() or entries[i+1].is_equal_approx(exits[i+1]): continue
			var last := entries[i+1]
			for step in range(1,7):
				var t := step/6.0
				var a := entries[i+1].lerp(points[i+1],t); var b := points[i+1].lerp(exits[i+1],t)
				var point := a.lerp(b,t)
				var ta := lerpf(enter_times[i+1],exit_times[i+1],(step-1)/6.0)
				var tb := lerpf(enter_times[i+1],exit_times[i+1],t)
				_add(last,point,ta,tb,_at_strength(weights,ta),_at_strength(weights,tb),edge)
				last = point
	return groups.values()
