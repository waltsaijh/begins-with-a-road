extends MeshInstance3D
## Non-overlapping cell patches evaluate a union of fixed line pieces in one pass.
# Eight perpendicular turns (three pieces), eight straight/reverse turns
# (two pieces), and eight possible termini. Geometry is independent of trip count.
const MAX_PIECES := 48
const PIECE_TEXELS := 3
@export var surface_height := 0.075
@export_range(0.08, 0.35, 0.01) var corner_radius := 0.22
@export_group("Flow Appearance")
## Only this warm, soft-ended moving stroke is visible; there is no base line.
@export var highlight_color := Color(0.953, 0.914, 0.804, 0.96)
@export_range(0.10, 20.0, 0.05, "or_greater") var highlight_length := 0.50
@export_range(0.005, 0.16, 0.005) var line_width := 0.055
## Speed of the short moving stroke along the fixed road geometry.
@export_range(0.0, 10.0, 0.01, "or_greater") var flow_speed := 0.28
var rendered_cells: Array[Vector2i] = []
var flow_data: ImageTexture
var phase_data: ImageTexture
## CPU evidence and geometry cache for the display-only wide projection.
var wide_projection: RefCounted
var projected_pieces: Array = []

func _ready() -> void:
	material_override = material_override.duplicate()
	material_override.set_shader_parameter("highlight_color", highlight_color)
	material_override.set_shader_parameter("highlight_length", highlight_length)
	material_override.set_shader_parameter("flow_speed", flow_speed)
	material_override.set_shader_parameter("line_width", line_width)

func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)

func _piece(pieces: Array, a: Vector2, b: Vector2, strength: float, phase_a: float, phase_b: float, clock: Vector2, end_strength := -1.0) -> void:
	if a.distance_squared_to(b) < 0.000001: return
	if end_strength < 0.0: end_strength = strength
	pieces.append({"a": a, "b": b, "strength": strength, "phase_a": phase_a, "phase_b": phase_b,
		"arc": false, "clock": clock, "end_strength": end_strength,
		"width": line_width*0.5*lerpf(0.4, 1.0, strength),
		"end_width": line_width*0.5*lerpf(0.4, 1.0, end_strength),
		"clip_a": (b-a).normalized(), "clip_b": (b-a).normalized()})

func _join(pieces: Array, first: int) -> void:
	for i in range(first+1,pieces.size()):
		var previous: Dictionary = pieces[i-1]
		var next: Dictionary = pieces[i]
		var incoming: Vector2 = previous.clip_b if previous.arc else (previous.b-previous.a).normalized()
		var outgoing: Vector2 = next.clip_a if next.arc else (next.b-next.a).normalized()
		var normal := (incoming+outgoing).normalized()
		# A literal reversal shares a flat cross-section instead of an unbounded miter.
		if normal.length_squared() < 0.5: continue
		previous.clip_b = normal
		next.clip_a = normal

func _turn(pieces: Array, entering: Vector4i, leaving: Vector4i, phases: Dictionary,
		segments: Dictionary, animation: RoadFlowPhases, peak: int) -> void:
	var previous := Vector2i(entering.x,entering.y)
	var cell := Vector2i(entering.z,entering.w)
	var next := Vector2i(leaving.z,leaving.w)
	var incoming := (_point(cell)-_point(previous)).normalized()
	var outgoing := (_point(next)-_point(cell)).normalized()
	var start := -incoming*0.5
	var finish := outgoing*0.5
	var clock := animation.register(phases)
	var strength_a := log(1.0+int(segments[entering]))/log(1.0+peak)
	var strength_b := log(1.0+int(segments[leaving]))/log(1.0+peak)
	var first := pieces.size()
	if absf(incoming.dot(outgoing)) < 0.01:
		var entry := -incoming*corner_radius
		var exit := outgoing*corner_radius
		_piece(pieces,start,entry,strength_a,-0.5,-corner_radius,clock)
		# One exact quarter-circle replaces eight chords, including at junctions.
		# With centered lanes its center is entry+exit; both directions share it.
		_piece(pieces,entry,exit,strength_a,-corner_radius,corner_radius,clock,strength_b)
		pieces.back().arc = true
		pieces.back().clip_a = incoming
		pieces.back().clip_b = outgoing
		_piece(pieces,exit,finish,strength_b,corner_radius,0.5,clock)
	else:
		var middle_strength := (strength_a+strength_b)*0.5
		_piece(pieces,start,Vector2.ZERO,strength_a,-0.5,0.0,clock,middle_strength)
		_piece(pieces,Vector2.ZERO,finish,middle_strength,0.0,0.5,clock,strength_b)
	_join(pieces,first)

func _cell_pieces(cell: Vector2i, adjacent: Array, connections: Array, segments: Dictionary,
		animation: RoadFlowPhases, peak: int) -> Array:
	var pieces: Array = []
	for connection: Array in connections:
		_turn(pieces,connection[0],connection[1],connection[2],segments,animation,peak)
	# Only complete-trip termini receive round caps; cell boundaries and all
	# internal joins use clipping planes. Termini retain their own phase sets.
	for other: Vector2i in adjacent:
		for entering: bool in [true,false]:
			var a := other if entering else cell
			var b := cell if entering else other
			var edge := Vector4i(a.x,a.y,b.x,b.y)
			var phases: Dictionary = (animation.ends if entering else animation.starts).get(edge,{})
			if phases.is_empty(): continue
			var strength := log(1.0+int(segments[edge]))/log(1.0+peak)
			var direction := (_point(b)-_point(a)).normalized()
			var clock := animation.register(phases)
			if entering:
				_piece(pieces,-direction*0.5,Vector2.ZERO,strength,-0.5,0.0,clock)
				pieces.back().clip_b = Vector2.ZERO
			else:
				_piece(pieces,Vector2.ZERO,direction*0.5,strength,0.0,0.5,clock)
				pieces.back().clip_a = Vector2.ZERO
	assert(pieces.size() <= MAX_PIECES, "Flow cell exceeds bounded primitive capacity")
	return pieces

func display(segments: Dictionary, all_segments: Dictionary, map: GridMap, animation: RoadFlowPhases, snapshot: Dictionary = {}) -> void:
	mesh = null
	rendered_cells.clear()
	flow_data = null
	phase_data = null
	wide_projection = null
	projected_pieces.clear()
	material_override.set_shader_parameter("phase_data", null)
	material_override.set_shader_parameter("flow_data", null)
	if segments.is_empty(): return
	material_override.set_shader_parameter("line_width", line_width)
	animation.prepare(highlight_length)
	material_override.set_shader_parameter("stroke_period",float(animation.period))
	var roads := snapshot
	if roads.is_empty() and map.mesh_library != null:
		var controller := map.get_node_or_null("../PortalMap")
		roads = preload("res://scripts/navigation/road_graph_snapshot.gd").capture(map,controller.blocked_cells if controller != null else {})
	if not roads.is_empty() and not animation.trips.is_empty():
		var projection := preload("res://scripts/navigation/visualization/wide_road_flow.gd").new()
		for i in roads.ports.size(): projection.masks[Vector2i(roads.cells[i*2],roads.cells[i*2+1])] = int(roads.ports[i])
		var wide := false
		for edge: Vector4i in all_segments:
			if projection.band(Vector2i(edge.x,edge.y),Vector2i(edge.z,edge.w)).width > 1: wide = true; break
		if wide:
			# Keep the existing malformed-walk contract: a skipped diagonal or
			# absent edge must not become a new visual shortcut across a plaza.
			for cells: PackedVector2Array in animation.trips:
				for i in range(cells.size()-1):
					var a := Vector2i(cells[i]); var b := Vector2i(cells[i+1])
					if not projection.connects(a,b) or not segments.has(Vector4i(a.x,a.y,b.x,b.y)): wide = false; break
				if not wide: break
		if wide:
			wide_projection = projection
			projected_pieces = projection.build(segments,all_segments,animation,corner_radius)
			_display_wide(map,animation)
			return
	var peak := 1
	for count: int in all_segments.values(): peak = maxi(peak, count)
	var neighbors := {}
	for edge: Vector4i in all_segments:
		var a := Vector2i(edge.x, edge.y)
		var b := Vector2i(edge.z, edge.w)
		if not neighbors.has(a): neighbors[a] = []
		if not neighbors.has(b): neighbors[b] = []
		if not b in neighbors[a]: neighbors[a].append(b)
		if not a in neighbors[b]: neighbors[b].append(a)
	var cells := {}
	for edge: Vector4i in segments:
		cells[Vector2i(edge.x, edge.y)] = true
		cells[Vector2i(edge.z, edge.w)] = true
	var connections := {}
	for entering: Vector4i in animation.turns:
		var cell := Vector2i(entering.z,entering.w)
		if not connections.has(cell): connections[cell] = []
		for leaving: Vector4i in animation.turns[entering]:
			connections[cell].append([entering,leaving,animation.turns[entering][leaving]])
	var data := Image.create(1+MAX_PIECES*PIECE_TEXELS, cells.size(), false, Image.FORMAT_RGBAF)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in cells:
		var pieces := _cell_pieces(cell,neighbors[cell],connections.get(cell,[]),segments,animation,peak)
		var row := rendered_cells.size()
		rendered_cells.append(cell)
		data.set_pixel(0, row, Color(pieces.size(), 0, 0, 0))
		for i in pieces.size():
			var piece: Dictionary = pieces[i]
			data.set_pixel(1+i*PIECE_TEXELS, row, Color(piece.a.x, piece.a.y, piece.b.x, piece.b.y))
			# Integer parts hold the base step / lookup row; fractions hold local
			# progress in [-0.5,1]. The third texel holds the two clipping normals.
			data.set_pixel(2+i*PIECE_TEXELS, row, Color(piece.strength,
				piece.clock.y+(piece.phase_a+0.5)*0.25,
				piece.clock.x+(piece.phase_b+0.5)*0.25, -piece.end_strength if piece.arc else piece.end_strength))
			data.set_pixel(3+i*PIECE_TEXELS,row,Color(piece.clip_a.x,piece.clip_a.y,piece.clip_b.x,piece.clip_b.y))
		var center3 := map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*surface_height
		var offsets := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
		for index in [0, 1, 2, 0, 2, 3]:
			var offset: Vector2 = offsets[index]
			surface.set_uv(offset+Vector2(0.5, 0.5))
			surface.set_uv2(Vector2(row, 0))
			surface.add_vertex(to_local(map.to_global(center3+Vector3(offset.x*map.cell_size.x, 0, offset.y*map.cell_size.z))))
	phase_data = animation.lookup_texture()
	material_override.set_shader_parameter("phase_data", phase_data)
	flow_data = ImageTexture.create_from_image(data)
	material_override.set_shader_parameter("flow_data", flow_data)
	mesh = surface.commit()

func _display_wide(map: GridMap, animation: RoadFlowPhases) -> void:
	var patches := {}
	var padding := line_width*0.5+0.01
	for piece: Dictionary in projected_pieces:
		piece.clock = animation.register(piece.phases)
		var lo: Vector2 = piece.a.min(piece.b)-Vector2.ONE*padding
		var hi: Vector2 = piece.a.max(piece.b)+Vector2.ONE*padding
		for y in range(floori(lo.y+0.5),floori(hi.y+0.5)+1):
			for x in range(floori(lo.x+0.5),floori(hi.x+0.5)+1):
				var cell := Vector2i(x,y)
				if not wide_projection.masks.has(cell): continue
				if not patches.has(cell): patches[cell] = []
				patches[cell].append(piece)
	if patches.is_empty(): return
	var capacity := 1
	for pieces: Array in patches.values(): capacity = maxi(capacity,pieces.size())
	var data := Image.create(1+capacity*PIECE_TEXELS,patches.size(),false,Image.FORMAT_RGBAF)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in patches:
		var row := rendered_cells.size(); rendered_cells.append(cell)
		var pieces: Array = patches[cell]
		data.set_pixel(0,row,Color(pieces.size(),0,0,0))
		for i in pieces.size():
			var piece: Dictionary = pieces[i]
			var a: Vector2 = piece.a-Vector2(cell); var b: Vector2 = piece.b-Vector2(cell)
			data.set_pixel(1+i*PIECE_TEXELS,row,Color(a.x,a.y,b.x,b.y))
			data.set_pixel(2+i*PIECE_TEXELS,row,Color(-piece.strength-1.0 if piece.dwell else piece.strength,piece.clock.y+(piece.phase_a+0.5)*0.25,piece.clock.x+(piece.phase_b+0.5)*0.25,piece.end_strength))
			data.set_pixel(3+i*PIECE_TEXELS,row,Color(piece.clip_a.x,piece.clip_a.y,piece.clip_b.x,piece.clip_b.y))
		var center := map.map_to_local(Vector3i(cell.x,0,cell.y))+Vector3.UP*surface_height
		var offsets := [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]
		for index in [0,1,2,0,2,3]:
			var offset: Vector2 = offsets[index]
			surface.set_uv(offset+Vector2.ONE*0.5); surface.set_uv2(Vector2(row,0))
			surface.add_vertex(to_local(map.to_global(center+Vector3(offset.x*map.cell_size.x,0,offset.y*map.cell_size.z))))
	phase_data = animation.lookup_texture(); flow_data = ImageTexture.create_from_image(data)
	material_override.set_shader_parameter("phase_data",phase_data)
	material_override.set_shader_parameter("flow_data",flow_data)
	mesh = surface.commit()
