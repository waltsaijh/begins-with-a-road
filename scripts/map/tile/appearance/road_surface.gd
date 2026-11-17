extends RefCounted
## Display-only meshes. Logical GridMap IDs, ports and routes remain untouched.
const Snapshot = preload("res://scripts/navigation/road_graph_snapshot.gd")
const MATERIAL = preload("res://assets/materials/solid_color.tres")
## Art Slice G "sky island": grass tops, carved stone curbs, large weathered
## flagstone roads and massive grey stone sides.
const ROAD := Color("6f736d") # deep joints between slabs
const INACTIVE := Color("6c7272")
const STONE := Color("8fae5c") # grass on island tops
const CURB := Color("b9bbb2")
const SIDE := Color("8e928b")
const SLABS := [Color("cfcdc3"), Color("c2c1b8"), Color("d8d5ca"), Color("b8b8b0"), Color("c9c4b6")]
const SLAB_MOSS := Color("9fae7c")
const SLABS_INACTIVE := [Color("9da3a2"), Color("8f9594"), Color("a8adac")]
const SLAB_PITCH := 0.25
const SLAB_GAP := 0.016
const SLAB_HEIGHT := 0.018
## Island side: grass lip, then two courses of massive grey stone.
const SIDE_BANDS := [[-0.028, Color("6e8d43")], [-0.175, Color("9a9d95")], [-0.19, Color("666a65")], [-0.37, Color("8b8f88")]]
const ROAD_HEIGHT := 0.0
const BANK_HEIGHT := 0.065
const BANK_SLOPE := 0.045
## Stronger contact shade makes the recessed edge readable in bright cloud light.
const BANK_SHADOW_STRENGTH := 0.34
## Baked contact occlusion on the road floor reads on the lit bank as well.
const CONTACT_SHADOW_WIDTH := 0.06
const CONTACT_SHADOW_STRENGTH := 0.46
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
	var key := str([road,neighbors,active.has(at),pillar,wood,context,map.get_cell_item_orientation(cell) if wood else 0])
	if cache.has(key): return cache[key]
	var id := cache.size()
	var mesh := _mesh(road,neighbors,active.has(at),low)
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
		for sign_z in [-1.0,1.0]:
			var a := basis*Vector3(-0.34,ROAD_HEIGHT,sign_z*0.5)
			var b := basis*Vector3(0.34,ROAD_HEIGHT,sign_z*0.5)
			var c := basis*Vector3(0.315,0.051,sign_z*0.44)
			var d := basis*Vector3(-0.315,0.051,sign_z*0.44)
			if sign_z > 0: _quad(st,a,d,c,b,ROAD)
			else: _quad(st,a,b,c,d,ROAD)
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

static func _courses(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var top_a := a.y; var top_b := b.y
	for band: Array in SIDE_BANDS:
		var bottom: float = band[0]
		_quad(st,Vector3(a.x,top_a,a.z),Vector3(a.x,bottom,a.z),Vector3(b.x,bottom,b.z),Vector3(b.x,top_b,b.z),band[1])
		top_a = bottom; top_b = bottom

## Large running-bond flagstones on a cell-aligned grid (stones continue across
## cells). Some slabs span two columns; each has a slightly tilted, worn top.
static func _cobbles(st: SurfaceTool, rectangles: Array[Rect2], low: Array, valid: bool) -> void:
	var palette: Array = SLABS if valid else SLABS_INACTIVE
	for row in 4:
		var z0 := -0.5+row*SLAB_PITCH
		var shift := SLAB_PITCH*0.5 if row % 2 else 0.0
		var column := -1
		while column < 5:
			var hash := absi(((row+3)*73856093) ^ ((column+11)*19349663))
			var span := 2 if hash % 4 == 0 else 1
			var x0 := -0.5+column*SLAB_PITCH+shift
			var stone := Rect2(Vector2(x0,z0),Vector2(SLAB_PITCH*span,SLAB_PITCH))
			column += span
			for rect: Rect2 in rectangles:
				var piece := stone.intersection(rect)
				if piece.size.x < 0.035 or piece.size.y < 0.035: continue
				var color: Color = palette[hash % palette.size()]
				if valid and hash % 7 == 3: color = color.lerp(SLAB_MOSS,0.55)
				color = color.darkened(CONTACT_SHADOW_STRENGTH*0.5*_contact_shadow(piece.get_center(),low))
				var g := SLAB_GAP*0.5
				var lo := piece.position+Vector2(g,g); var hi := piece.end-Vector2(g,g)
				var base := SLAB_HEIGHT*(0.75+0.5*float(hash % 5)/4.0)
				var bevel := minf(0.02,minf(hi.x-lo.x,hi.y-lo.y)*0.25)
				var t0 := lo+Vector2(bevel,bevel); var t1 := hi-Vector2(bevel,bevel)
				var tilt: float = [0.0,0.004,-0.003,0.002][hash % 4]
				var b := [Vector3(lo.x,ROAD_HEIGHT,lo.y),Vector3(hi.x,ROAD_HEIGHT,lo.y),Vector3(hi.x,ROAD_HEIGHT,hi.y),Vector3(lo.x,ROAD_HEIGHT,hi.y)]
				var t := [Vector3(t0.x,base+tilt,t0.y),Vector3(t1.x,base,t0.y),Vector3(t1.x,base-tilt,t1.y),Vector3(t0.x,base,t1.y)]
				_quad(st,t[0],t[1],t[2],t[3],color)
				var side := color.darkened(0.18)
				for i in 4:
					var j := (i+1)%4
					_quad(st,b[i],b[j],t[j],t[i],side)

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

static func _contact_shadow(point: Vector2, low: Array) -> float:
	var amount := 0.0
	for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2(-0.70710678,-0.70710678),Vector2(0.70710678,-0.70710678),Vector2(0.70710678,0.70710678),Vector2(-0.70710678,0.70710678)]:
		amount = maxf(amount,_height(point+direction*CONTACT_SHADOW_WIDTH,low)/BANK_HEIGHT)
	return clampf(amount,0.0,1.0)

static func _mesh(road: Vector2i, neighbors: int, valid: bool, low: Array = []) -> ArrayMesh:
	var st := _surface()
	# Exact shared coordinates remove seams. Only the exposed union perimeter
	# receives a shallow stone bevel and side face; foundations remain flush.
	var x0 := -0.5 if neighbors & 8 else -0.47
	var x1 := 0.5 if neighbors & 2 else 0.47
	var z0 := -0.5 if neighbors & 1 else -0.47
	var z1 := 0.5 if neighbors & 4 else 0.47
	if low.is_empty() and road.x >= 0: low.assign(road_rects(road))
	var rectangles := road_rects(road)
	var shadow_start := 0.34-CONTACT_SHADOW_WIDTH
	var xs := [x0,-0.385,-0.34,-shadow_start,shadow_start,0.34,0.385,x1]
	var zs := [z0,-0.385,-0.34,-shadow_start,shadow_start,0.34,0.385,z1]
	var occlusion := {}
	for z in range(zs.size()-1):
		for x in range(xs.size()-1):
			var center := Vector2((xs[x]+xs[x+1])*0.5,(zs[z]+zs[z+1])*0.5)
			var is_road := false
			for rect: Rect2 in rectangles:
				if rect.has_point(center): is_road = true; break
			var color := (ROAD if valid else INACTIVE) if is_road else STONE
			if not is_road and road.x >= 0 and _height(center,low) < BANK_HEIGHT-0.0001: color = CURB
			var points := [Vector2(xs[x],zs[z]),Vector2(xs[x+1],zs[z]),Vector2(xs[x+1],zs[z+1]),Vector2(xs[x],zs[z+1])]
			var vertices: Array[Vector3] = []
			var colors := PackedColorArray()
			for point: Vector2 in points:
				var height := ROAD_HEIGHT if road.x < 0 else _height(point,low)
				vertices.append(Vector3(point.x,height,point.y))
				var shade := color
				if road.x >= 0:
					if is_road:
						if not occlusion.has(point): occlusion[point] = _contact_shadow(point,low)
						shade = color.darkened(CONTACT_SHADOW_STRENGTH*float(occlusion[point]))
					elif color == CURB:
						shade = color.darkened(BANK_SHADOW_STRENGTH*0.6*(1.0-height/BANK_HEIGHT))
				colors.append(shade)
			_quad(st,vertices[0],vertices[1],vertices[2],vertices[3],color,colors)
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
				var height := _height(point,low) if road.x >= 0 else ROAD_HEIGHT
				inside.append(Vector3(point.x,height,point.y))
				var boundary := point
				if is_equal_approx(point.x,x0): boundary.x = -0.5
				if is_equal_approx(point.x,x1): boundary.x = 0.5
				if is_equal_approx(point.y,z0): boundary.y = -0.5
				if is_equal_approx(point.y,z1): boundary.y = 0.5
				outside.append(Vector3(boundary.x,height*(1.0-0.035/BANK_HEIGHT),boundary.y))
			_quad(st,inside[0],outside[0],outside[1],inside[1],STONE.darkened(0.12))
			_courses(st,outside[0],outside[1])
	if road.x >= 0: _cobbles(st,rectangles,low,valid)
	st.index()
	return st.commit()
