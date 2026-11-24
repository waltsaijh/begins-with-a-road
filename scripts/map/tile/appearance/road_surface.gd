extends RefCounted
## Display-only meshes. Logical GridMap IDs, ports and routes remain untouched.
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const MATERIAL = preload("res://assets/materials/solid_color.tres")
## Art Slice G "sky island": grass tops, carved stone curbs, large weathered
## plain quartz-grey roads and massive grey stone sides.
## Road top: one flat, plain light quartz grey (no flagstones). Only vertex colour on
## the shared solid_color material, so it costs nothing extra on Web.
const ROAD := Color("d6d7d3")
const INACTIVE := Color("a3a8a7") # greyed-out (unreachable) road
## The road floor seen between the pavers is a little darker than the pavers.
const FLOOR_DARKEN := 0.02
## Wooden bridge deck height (from the bridge model) and how far the closed
## bridge-head wedge reaches below the road floor.
const BRIDGE_DECK_HEIGHT := 0.051
const BRIDGE_HEAD_DEPTH := 0.06
const STONE := Color("8fae5c") # grass on island tops
const CURB := Color("b9bbb2")
const SIDE := Color("8e928b")
## Island side: grass lip, then two courses of massive grey stone.
const SIDE_BANDS := [[-0.028, Color("6e8d43")], [-0.175, Color("9a9d95")], [-0.19, Color("666a65")], [-0.37, Color("8b8f88")]]
## Road floor sits a little below the curb top (raised from 0 so it no longer looks
## sunk; equals the enemy/tower GROUND_OFFSET so feet and tower bases stay on it).
## Tower / stone foundation tiles share this height so their joins stay closed.
const ROAD_HEIGHT := 0.025
const GROUND_HEIGHT := ROAD_HEIGHT
const BANK_HEIGHT := 0.065
const BANK_SLOPE := 0.028
## Stronger contact shade makes the recessed edge readable in bright cloud light.
const BANK_SHADOW_STRENGTH := 0.34
## No baked contact band on the road floor (removed 2026-11-24): the bank slope's
## own cel lighting marks the edge, and the floor stays one flat colour.
## Low pavers laid on the road floor, clipped to the road shape. Each cell takes one
## of PAVER_VARIANTS layouts, generated once from a fixed seed (same every run):
## the cell is cut into two 0.5-wide strips (direction random); each strip stays
## whole (0.5x1), splits in half (two 0.5x0.5) or is laid offset (0.25 + 0.5 +
## 0.25); a 0.5x0.5 may split again into two 0.25x0.5. Joints in the two strips
## never line up, so no four pavers meet in a "+". Neighbouring cells avoid the
## same layout, and every piece gets a slight brightness offset.
const PAVER_HEIGHT := 0.015
## Pavers have sloped sides: the foot is inset PAVER_FOOT from its grid piece and
## the top PAVER_TOP (a 0.5 piece: 0.45 at the foot, 0.4 on top).
const PAVER_FOOT := 0.025
const PAVER_TOP := 0.05
const PAVER_SHADE := 0.03
const PAVER_VARIANTS := 16
const PAVER_SEED := 9173
static var _paver_layouts: Array = []
var library := MeshLibrary.new()
var cache := {}
var masks := {}
var ground := {}
var active := {}
var blocked := {}
var _last_snapshot := {}
var _last_terminals: Array[Vector2i] = []
var _support: Mesh
var _reported_old_extension := false
var wood_cells := {}
var foundation_cells := {}

func prepare(map: GridMap, obstacles: Dictionary, terminals: Array[Vector2i]) -> void:
	blocked = obstacles
	ground.clear()
	foundation_cells.clear()
	for cell in map.get_used_cells():
		ground[cell] = true
		var at := Vector2i(cell.x,cell.z)
		if cell.y == 0 and (map.get_cell_item(cell) == 0 or blocked.has(at)): foundation_cells[at] = true
	var snapshot := Snapshot.capture(map,obstacles)
	masks.clear()
	for i in snapshot.ports.size():
		masks[Vector2i(snapshot.cells[i*2],snapshot.cells[i*2+1])] = int(snapshot.ports[i])
	# Re-evaluate even additions ignored by the navigation dead-end guard.
	if snapshot != _last_snapshot or terminals != _last_terminals:
		active.clear()
		if not terminals.is_empty():
			var guard: RefCounted = ClassDB.instantiate("RoadEditGuard")
			var result: Dictionary = guard.prepare(snapshot.cells,snapshot.ports,PackedVector2Array(terminals))
			if result.has("route_cells"):
				var cells: PackedInt32Array = result.route_cells
				for i in range(0,cells.size(),2): active[Vector2i(cells[i],cells[i+1])] = true
			elif result.get("valid",false):
				# An older DLL/wasm cannot classify roads. Preserve neutral artwork
				# instead of incorrectly declaring every legal route a dead end.
				active = masks.duplicate()
				if not _reported_old_extension:
					push_warning("Road membership display requires a rebuilt RoadEditGuard extension; retaining neutral road colors.")
					_reported_old_extension = true
		_last_snapshot = snapshot
		_last_terminals = terminals.duplicate()
	wood_cells.clear()
	for cell in map.get_used_cells():
		if TileConstants.appearance_of(map.get_cell_item(cell)) != TileConstants.Appearance.WOOD: continue
		var at := Vector2i(cell.x,cell.z)
		var road := shape(at)
		if road.y != 0 or not road.x in [5,10] or not active.has(at): continue
		# An authored open bridge cannot replace a complete foundation beside
		# another ground cell. Those locations need the continuous stone surface.
		var sides := [1,3] if road.x == 5 else [0,2]
		var open_sides := true
		for d: int in sides:
			if ground.has(cell+TileConstants.DIRECTIONS[d]): open_sides = false
		if open_sides: wood_cells[cell] = true

func connects(cell: Vector2i, d: int) -> bool:
	var offset: Vector3i = TileConstants.DIRECTIONS[d]
	return (int(masks.get(cell,0)) & (1<<d)) != 0 and (int(masks.get(cell+Vector2i(offset.x,offset.z),0)) & (1<<((d+2)%4))) != 0

func shape(cell: Vector2i) -> Vector2i:
	var exits := 0
	var corners := 0
	for d in 4:
		if connects(cell,d): exits |= 1<<d
		var next := (d+1)%4
		var a: Vector3i = TileConstants.DIRECTIONS[d]
		var b: Vector3i = TileConstants.DIRECTIONS[next]
		# Fill the shared corner only for a reciprocal four-cell square.
		if connects(cell,d) and connects(cell,next) and connects(cell+Vector2i(a.x,a.z),next) and connects(cell+Vector2i(b.x,b.z),d): corners |= 1<<d
	return Vector2i(exits,corners)

func item(map: GridMap, cell: Vector3i, logical: int) -> int:
	var at := Vector2i(cell.x,cell.z)
	var road := shape(at) if cell.y == 0 and logical > 0 and not blocked.has(at) else Vector2i(-1,0)
	var neighbors := 0
	for d in 4:
		var adjacent: Vector3i = cell+TileConstants.DIRECTIONS[d]
		# Open bridge cells are not solid terrain. Keep the real abutment face
		# on the neighboring stone bank instead of leaving its underside open.
		if ground.has(adjacent) and not wood_cells.has(adjacent): neighbors |= 1<<d
	var pillar := TileConstants.appearance_of(logical) == TileConstants.Appearance.PILLAR
	# Keep authored narrow wooden bridges. Junctions/wide streets use stone.
	var wood := wood_cells.has(cell)
	var low := []
	var context := []
	for z in range(-1,2):
		for x in range(-1,2):
			var next := at+Vector2i(x,z)
			var form := shape(next) if masks.has(next) else Vector2i(-1,0)
			context.append([form,foundation_cells.has(next)])
			if foundation_cells.has(next): low.append(Rect2(Vector2(x-0.5,z-0.5),Vector2.ONE))
			else:
				for rect: Rect2 in road_rects(form): low.append(Rect2(rect.position+Vector2(x,z),rect.size))
	var layout := paver_layout(at) if road.x >= 0 and not wood else 0
	var key := str([road,neighbors,active.has(at),pillar,wood,context,map.get_cell_item_orientation(cell) if wood else 0,layout])
	if cache.has(key): return cache[key]
	var id := cache.size()
	var mesh := _mesh(road,neighbors,active.has(at),low,layout)
	if wood:
		var st := _surface()
		var original := map.mesh_library.get_item_mesh(logical)
		for s in original.get_surface_count(): st.append_from(original,s,Transform3D(map.get_cell_item_basis(cell),Vector3.ZERO))
		# append_from retains source indices. New cap vertices must participate
		# in the same primitive stream, not sit unreferenced behind those indices.
		st.deindex()
		# Part of the bridge mesh itself: two structural end transitions join the
		# deck to its stone heads while the normal opening under the span stays open.
		var basis := map.get_cell_item_basis(cell)
		# Bridge head: a short ramp from the paver top at the cell edge up to the deck
		# (nearly level), a small step face down to the road floor on the road side,
		# and closed cheeks / back so no sky shows through beside the curb.
		var floor_color := ROAD.darkened(FLOOR_DARKEN)
		var paver_top := ROAD_HEIGHT+PAVER_HEIGHT
		var bottom := ROAD_HEIGHT-BRIDGE_HEAD_DEPTH
		for sign_z in [-1.0,1.0]:
			# edge -> lip: sloped like a paver bevel (rises from the road floor), so it
			# reads as one more paver edge instead of a dark vertical step.
			var edge: float = sign_z*0.5; var lip: float = sign_z*(0.5-PAVER_FOOT); var deck: float = sign_z*0.44
			_face(st,basis,[Vector3(-0.34,ROAD_HEIGHT,edge),Vector3(0.34,ROAD_HEIGHT,edge),Vector3(0.34,paver_top,lip),Vector3(-0.34,paver_top,lip)],Vector3.UP,floor_color)
			_face(st,basis,[Vector3(-0.34,paver_top,lip),Vector3(0.34,paver_top,lip),Vector3(0.34,BRIDGE_DECK_HEIGHT,deck),Vector3(-0.34,BRIDGE_DECK_HEIGHT,deck)],Vector3.UP,floor_color)
			for side in [-1.0,1.0]:
				var x: float = side*0.34
				_face(st,basis,[Vector3(x,ROAD_HEIGHT,edge),Vector3(x,paver_top,lip),Vector3(x,bottom,lip),Vector3(x,bottom,edge)],Vector3(side,0,0),floor_color.darkened(0.12))
				_face(st,basis,[Vector3(x,paver_top,lip),Vector3(x,BRIDGE_DECK_HEIGHT,deck),Vector3(x,bottom,deck),Vector3(x,bottom,lip)],Vector3(side,0,0),floor_color.darkened(0.12))
			_face(st,basis,[Vector3(-0.34,BRIDGE_DECK_HEIGHT,deck),Vector3(0.34,BRIDGE_DECK_HEIGHT,deck),Vector3(0.34,bottom,deck),Vector3(-0.34,bottom,deck)],Vector3(0,0,-sign_z),floor_color.darkened(0.12))
		mesh = st.commit()
	if pillar:
		if _support == null:
			var source: Node = load("res://assets/models/tiles/variants/pillar_support.tscn").instantiate()
			_support = source.get_child(0).mesh; source.free()
		for s in _support.get_surface_count():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_support.surface_get_arrays(s))
			mesh.surface_set_material(mesh.get_surface_count()-1,_support.surface_get_material(s))
	library.create_item(id); library.set_item_mesh(id,mesh); cache[key] = id
	return id

static func _surface() -> SurfaceTool:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1,SurfaceTool.CUSTOM_RG_FLOAT)
	st.set_material(MATERIAL)
	return st

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, colors := PackedColorArray()) -> void:
	st.set_color(color); st.set_normal((c-a).cross(b-a).normalized())
	st.set_custom(0,Color(0,0,0,0)); st.set_custom(1,Color(0.98,0.12,0,0))
	st.set_uv(Vector2.ZERO); st.set_uv2(Vector2.ZERO)
	var vertices := [a,b,c,d]
	for index in [0,1,2,0,2,3]:
		st.set_color(colors[index] if colors.size() == 4 else color)
		st.add_vertex(vertices[index])

## Quad whose winding/normal faces `outward` (both given in cell space, then rotated).
static func _face(st: SurfaceTool, basis: Basis, points: Array, outward: Vector3, color: Color) -> void:
	var v: Array[Vector3] = []
	for point: Vector3 in points: v.append(basis*point)
	if (v[2]-v[0]).cross(v[1]-v[0]).dot(basis*outward) < 0.0: _quad(st,v[0],v[3],v[2],v[1],color)
	else: _quad(st,v[0],v[1],v[2],v[3],color)

static func _courses(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var top_a := a.y; var top_b := b.y
	for band: Array in SIDE_BANDS:
		var bottom: float = band[0]
		_quad(st,Vector3(a.x,top_a,a.z),Vector3(a.x,bottom,a.z),Vector3(b.x,bottom,b.z),Vector3(b.x,top_b,b.z),band[1])
		top_a = bottom; top_b = bottom

static func _top(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float, y: float, color: Color) -> void:
	_quad(st,Vector3(x0,y,z0),Vector3(x1,y,z0),Vector3(x1,y,z1),Vector3(x0,y,z1),color)

static func road_rects(road: Vector2i) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if road.x < 0: return result
	var values := [-0.5,-0.34,0.34,0.5]
	for z in 3:
		for x in 3:
			var include: bool = x == 1 and z == 1
			if x == 1 and z == 0: include = (road.x & 1) != 0
			if x == 2 and z == 1: include = (road.x & 2) != 0
			if x == 1 and z == 2: include = (road.x & 4) != 0
			if x == 0 and z == 1: include = (road.x & 8) != 0
			if x == 2 and z == 0: include = (road.y & 1) != 0
			if x == 2 and z == 2: include = (road.y & 2) != 0
			if x == 0 and z == 2: include = (road.y & 4) != 0
			if x == 0 and z == 0: include = (road.y & 8) != 0
			if include: result.append(Rect2(Vector2(values[x],values[z]),Vector2(values[x+1]-values[x],values[z+1]-values[z])))
	return result

static func _height(point: Vector2, low: Array) -> float:
	var distance := INF
	for rect: Rect2 in low:
		var nearest := point.clamp(rect.position,rect.end)
		distance = minf(distance,point.distance_to(nearest))
	return lerpf(ROAD_HEIGHT,BANK_HEIGHT,clampf(distance/BANK_SLOPE,0.0,1.0))

## Stable per-cell paver layout index (same cell -> same pattern across rebuilds).
static func paver_layout(at: Vector2i) -> int:
	var pick := _paver_hash(at) % PAVER_VARIANTS
	var left := _paver_hash(at+Vector2i.LEFT) % PAVER_VARIANTS
	var up := _paver_hash(at+Vector2i.UP) % PAVER_VARIANTS
	for step in PAVER_VARIANTS:
		if pick != left and pick != up: break
		pick = (pick+1) % PAVER_VARIANTS
	return pick

static func _paver_hash(at: Vector2i) -> int:
	return absi(((at.x+101)*73856093) ^ ((at.y+211)*19349663))

static func paver_layouts() -> Array:
	if _paver_layouts.is_empty():
		var rng := RandomNumberGenerator.new(); rng.seed = PAVER_SEED
		for i in PAVER_VARIANTS: _paver_layouts.append(_make_paver_layout(rng))
	return _paver_layouts

## Pieces are built in a strip frame (u across the 0.5-wide strip, v along it)
## and transposed when the strips run along X.
static func _make_paver_layout(rng: RandomNumberGenerator) -> Array:
	var along_z := rng.randi() % 2 == 0
	var patterns := [[], [0.0], [-0.25,0.25]]   # cross joints: whole, halves, offset
	var pieces: Array = []
	var first_joints: Array = []
	for strip in 2:
		var u0 := -0.5+0.5*strip
		var allowed: Array = []
		for option in 3:
			var clear := true
			for joint: float in patterns[option]:
				if first_joints.has(joint): clear = false
			if clear: allowed.append(option)
		var pattern: int = allowed[rng.randi() % allowed.size()]
		var joints: Array = patterns[pattern].duplicate()
		var segments: Array = [[-0.5,1.0]] if pattern == 0 else ([[-0.5,0.5],[0.0,0.5]] if pattern == 1 else [[-0.5,0.25],[-0.25,0.5],[0.25,0.25]])
		for segment: Array in segments:
			var v0: float = segment[0]; var length: float = segment[1]
			if is_equal_approx(length,0.5) and rng.randf() < 0.35:
				var joint := v0+0.25
				if rng.randf() < 0.5 and not first_joints.has(joint):
					pieces.append(Rect2(u0,v0,0.5,0.25)); pieces.append(Rect2(u0,joint,0.5,0.25)); joints.append(joint)
				else:
					pieces.append(Rect2(u0,v0,0.25,0.5)); pieces.append(Rect2(u0+0.25,v0,0.25,0.5))
			else:
				pieces.append(Rect2(u0,v0,0.5,length))
		if strip == 0: first_joints = joints
	if not along_z:
		for i in pieces.size():
			var r: Rect2 = pieces[i]
			pieces[i] = Rect2(r.position.y,r.position.x,r.size.y,r.size.x)
	return pieces

static func _pavers(st: SurfaceTool, rectangles: Array[Rect2], valid: bool, layout: int) -> void:
	var base := ROAD if valid else INACTIVE
	var pieces: Array = paver_layouts()[layout]
	var top := ROAD_HEIGHT+PAVER_HEIGHT
	for k in pieces.size():
		var tone := (absi((layout+3)*92821 ^ (k+5)*68917) % 3)-1
		var color := base.lightened(PAVER_SHADE) if tone > 0 else (base.darkened(PAVER_SHADE) if tone < 0 else base)
		var piece: Rect2 = (pieces[k] as Rect2).grow(-PAVER_FOOT)
		var slope := PAVER_TOP-PAVER_FOOT
		# A piece spanning several road rectangles is drawn as touching parts with
		# one shared top height, so it reads as a single paver: only the piece's own
		# outline slopes; edges cut by a road rectangle (inner joins, curb) stay square.
		for rect: Rect2 in rectangles:
			var part := piece.intersection(rect)
			if part.size.x < 0.01 or part.size.y < 0.01: continue
			var lo := part.position; var hi := part.end
			var tlo := lo+Vector2(slope if is_equal_approx(lo.x,piece.position.x) else 0.0,slope if is_equal_approx(lo.y,piece.position.y) else 0.0)
			var thi := hi-Vector2(slope if is_equal_approx(hi.x,piece.end.x) else 0.0,slope if is_equal_approx(hi.y,piece.end.y) else 0.0)
			if thi.x-tlo.x < 0.01 or thi.y-tlo.y < 0.01: continue
			var b := [Vector3(lo.x,ROAD_HEIGHT,lo.y),Vector3(hi.x,ROAD_HEIGHT,lo.y),Vector3(hi.x,ROAD_HEIGHT,hi.y),Vector3(lo.x,ROAD_HEIGHT,hi.y)]
			var t := [Vector3(tlo.x,top,tlo.y),Vector3(thi.x,top,tlo.y),Vector3(thi.x,top,thi.y),Vector3(tlo.x,top,thi.y)]
			_quad(st,t[0],t[1],t[2],t[3],color)
			for i in 4:
				var j := (i+1)%4
				_quad(st,b[i],b[j],t[j],t[i],color)

static func _mesh(road: Vector2i, neighbors: int, valid: bool, low: Array = [], layout := 0) -> ArrayMesh:
	var st := _surface()
	# Exact shared coordinates remove seams. Only the exposed union perimeter
	# receives a shallow stone bevel and side face; foundations remain flush.
	var x0 := -0.5 if neighbors & 8 else -0.47
	var x1 := 0.5 if neighbors & 2 else 0.47
	var z0 := -0.5 if neighbors & 1 else -0.47
	var z1 := 0.5 if neighbors & 4 else 0.47
	if low.is_empty() and road.x >= 0: low.assign(road_rects(road))
	var rectangles := road_rects(road)
	var xs := [x0,-0.34-BANK_SLOPE,-0.34,0.34,0.34+BANK_SLOPE,x1]
	var zs := [z0,-0.34-BANK_SLOPE,-0.34,0.34,0.34+BANK_SLOPE,z1]
	for z in range(zs.size()-1):
		for x in range(xs.size()-1):
			var center := Vector2((xs[x]+xs[x+1])*0.5,(zs[z]+zs[z+1])*0.5)
			var is_road := false
			for rect: Rect2 in rectangles:
				if rect.has_point(center): is_road = true; break
			var color := (ROAD if valid else INACTIVE).darkened(FLOOR_DARKEN) if is_road else STONE
			if not is_road and road.x >= 0 and _height(center,low) < BANK_HEIGHT-0.0001: color = CURB
			var points := [Vector2(xs[x],zs[z]),Vector2(xs[x+1],zs[z]),Vector2(xs[x+1],zs[z+1]),Vector2(xs[x],zs[z+1])]
			var vertices: Array[Vector3] = []
			for point: Vector2 in points:
				var height := GROUND_HEIGHT if road.x < 0 else _height(point,low)
				vertices.append(Vector3(point.x,height,point.y))
			# Cel look: one flat shade per quad (hard step at the quad edge) instead of
			# per-vertex ramps. The bank slope is its own quad.
			var shade := color
			if road.x >= 0:
				if not is_road and color == CURB:
					shade = color.darkened(BANK_SHADOW_STRENGTH*0.6*(1.0-(_height(center,low)-ROAD_HEIGHT)/(BANK_HEIGHT-ROAD_HEIGHT)))
			_quad(st,vertices[0],vertices[1],vertices[2],vertices[3],shade)
	for d in 4:
		if neighbors & (1<<d): continue
		var edge: Array[Vector2] = []
		if d == 0:
			for x: float in xs: edge.append(Vector2(x,z0))
		elif d == 1:
			for z: float in zs: edge.append(Vector2(x1,z))
		elif d == 2:
			for x: float in xs: edge.push_front(Vector2(x,z1))
		else:
			for z: float in zs: edge.push_front(Vector2(x0,z))
		for i in range(edge.size()-1):
			var inside: Array[Vector3] = []; var outside: Array[Vector3] = []
			for point: Vector2 in [edge[i],edge[i+1]]:
				var height := _height(point,low) if road.x >= 0 else GROUND_HEIGHT
				inside.append(Vector3(point.x,height,point.y))
				var boundary := point
				if is_equal_approx(point.x,x0): boundary.x = -0.5
				if is_equal_approx(point.x,x1): boundary.x = 0.5
				if is_equal_approx(point.y,z0): boundary.y = -0.5
				if is_equal_approx(point.y,z1): boundary.y = 0.5
				# Lip drop is measured from the foundation height: flat ground keeps a level
				# lip (no gap at concave island corners); curbs still drop to their old edge.
				outside.append(Vector3(boundary.x,GROUND_HEIGHT+(height-GROUND_HEIGHT)*(1.0-0.035/(BANK_HEIGHT-GROUND_HEIGHT)),boundary.y))
			# Where the road itself reaches an open edge (e.g. a bridge head) the lip is
			# road floor, not a strip of grass.
			var on_road := road.x >= 0 and is_equal_approx(inside[0].y,ROAD_HEIGHT) and is_equal_approx(inside[1].y,ROAD_HEIGHT)
			_quad(st,inside[0],outside[0],outside[1],inside[1],(ROAD if valid else INACTIVE).darkened(FLOOR_DARKEN) if on_road else STONE.darkened(0.12))
			_courses(st,outside[0],outside[1])
	if road.x >= 0: _pavers(st,rectangles,valid,layout)
	st.index()
	return st.commit()
