extends MeshInstance3D
## Non-overlapping cell patches evaluate a union of fixed line pieces in one pass.
const MAX_PIECES := 24
@export var surface_height := 0.075
@export var lane_offset := 0.10
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

func _ready() -> void:
	material_override = material_override.duplicate()
	material_override.set_shader_parameter("highlight_color", highlight_color)
	material_override.set_shader_parameter("highlight_length", highlight_length)
	material_override.set_shader_parameter("flow_speed", flow_speed)

func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell)

func _right(direction: Vector2) -> Vector2:
	return Vector2(-direction.y, direction.x)

func _lane(a: Vector2i, b: Vector2i, all_segments: Dictionary) -> float:
	return lane_offset if all_segments.has(Vector4i(b.x, b.y, a.x, a.y)) else 0.0

func _piece(pieces: Array, a: Vector2, b: Vector2, strength: float, phase_a: float, phase_b: float) -> void:
	if a.distance_squared_to(b) < 0.000001: return
	pieces.append({"a": a, "b": b, "strength": strength, "phase_a": phase_a, "phase_b": phase_b,
		"width": line_width*0.5*lerpf(0.4, 1.0, strength)})

func _animation_phases(segments: Dictionary) -> Dictionary:
	# Presentation-only clocks on the existing directed flow network, no route search.
	var incoming := {}
	var outgoing := {}
	for edge: Vector4i in segments:
		var a := Vector2i(edge.x,edge.y)
		var b := Vector2i(edge.z,edge.w)
		if not incoming.has(b): incoming[b] = []
		if not outgoing.has(a): outgoing[a] = []
		incoming[b].append(edge)
		outgoing[a].append(edge)
	var roots: Array[Vector4i] = []
	for edge: Vector4i in segments:
		var predecessors := 0
		for previous: Vector4i in incoming.get(Vector2i(edge.x,edge.y),[]):
			if previous.x != edge.z or previous.y != edge.w: predecessors += 1
		if predecessors == 0: roots.append(edge)
	var phases := {}
	var queue: Array[Vector4i] = []
	for edge in roots:
		phases[edge] = 0.0
		queue.append(edge)
	var cursor := 0
	var period := 4.0
	# Closed loops have no root; seed only still-unvisited loop components.
	var seeds: Array = [null]
	seeds.append_array(segments.keys())
	for seed_edge in seeds:
		if seed_edge != null and not phases.has(seed_edge):
			phases[seed_edge] = 0.0
			queue.append(seed_edge)
		while cursor < queue.size():
			var edge := queue[cursor]
			cursor += 1
			period = maxf(period,float(phases[edge])+1.0)
			for next: Vector4i in outgoing.get(Vector2i(edge.z,edge.w),[]):
				if (next.z == edge.x and next.w == edge.y) or phases.has(next): continue
				phases[next] = float(phases[edge])+1.0
				queue.append(next)
	return {"phases": phases, "period": period}

func display(segments: Dictionary, all_segments: Dictionary, map: GridMap) -> void:
	mesh = null
	rendered_cells.clear()
	flow_data = null
	material_override.set_shader_parameter("flow_data", null)
	if segments.is_empty(): return
	var animation := _animation_phases(all_segments)
	var phases: Dictionary = animation.phases
	material_override.set_shader_parameter("stroke_period",maxf(animation.period,highlight_length*2.0))
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
	var data := Image.create(1+MAX_PIECES*2, cells.size(), false, Image.FORMAT_RGBAF)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in cells:
		var pieces: Array = []
		var handled := {}
		var adjacent: Array = neighbors[cell]
		# Only the corner cell curves. Neighboring cell halves remain exactly straight.
		if adjacent.size() == 2:
			for previous: Vector2i in adjacent:
				var next: Vector2i = adjacent[1] if previous == adjacent[0] else adjacent[0]
				var entering := Vector4i(previous.x, previous.y, cell.x, cell.y)
				var leaving := Vector4i(cell.x, cell.y, next.x, next.y)
				if not segments.has(entering) or not segments.has(leaving): continue
				var incoming := (_point(cell)-_point(previous)).normalized()
				var outgoing := (_point(next)-_point(cell)).normalized()
				if absf(incoming.dot(outgoing)) > 0.01: continue
				var phase := float(phases[leaving])
				var strength := log(1.0+minf(segments[entering], segments[leaving]))/log(1.0+peak)
				var lane_a := _lane(previous, cell, all_segments)
				var lane_b := _lane(cell, next, all_segments)
				var entry := -incoming*corner_radius+_right(incoming)*lane_a
				var exit := outgoing*corner_radius+_right(outgoing)*lane_b
				var center := -incoming*corner_radius+outgoing*corner_radius
				var start := -incoming*0.5+_right(incoming)*lane_a
				var finish := outgoing*0.5+_right(outgoing)*lane_b
				_piece(pieces, start, entry, strength, float(phases[entering])+0.5, phase-corner_radius)
				var radius_a := entry-center
				var radius_b := exit-center
				var angle := radius_a.angle_to(radius_b)
				for i in 8:
					var u := float(i)/8.0
					var v := float(i+1)/8.0
					var p := center+radius_a.normalized().rotated(angle*u)*lerpf(radius_a.length(), radius_b.length(), u)
					var q := center+radius_a.normalized().rotated(angle*v)*lerpf(radius_a.length(), radius_b.length(), v)
					_piece(pieces, p, q, strength, phase+lerpf(-corner_radius, corner_radius, u), phase+lerpf(-corner_radius, corner_radius, v))
				_piece(pieces, exit, finish, strength, phase+corner_radius, phase+0.5)
				handled[entering] = true
				handled[leaving] = true
		for other: Vector2i in adjacent:
			for entering: bool in [true, false]:
				var a := other if entering else cell
				var b := cell if entering else other
				var edge := Vector4i(a.x, a.y, b.x, b.y)
				if not segments.has(edge) or handled.has(edge): continue
				var strength := log(1.0+int(segments[edge]))/log(1.0+peak)
				var direction := (_point(b)-_point(a)).normalized()
				var offset := _right(direction)*_lane(a, b, all_segments)
				if entering:
					_piece(pieces, -direction*0.5+offset, offset, strength, float(phases[edge])+0.5, float(phases[edge])+1.0)
				else:
					_piece(pieces, offset, direction*0.5+offset, strength, float(phases[edge]), float(phases[edge])+0.5)
		assert(pieces.size() <= MAX_PIECES, "Flow cell exceeds bounded primitive capacity")
		var row := rendered_cells.size()
		rendered_cells.append(cell)
		data.set_pixel(0, row, Color(pieces.size(), 0, 0, 0))
		for i in pieces.size():
			var piece: Dictionary = pieces[i]
			data.set_pixel(1+i*2, row, Color(piece.a.x, piece.a.y, piece.b.x, piece.b.y))
			data.set_pixel(2+i*2, row, Color(piece.strength, piece.phase_a, piece.phase_b, piece.width))
		var center3 := map.map_to_local(Vector3i(cell.x, 0, cell.y))+Vector3.UP*surface_height
		var offsets := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
		for index in [0, 1, 2, 0, 2, 3]:
			var offset: Vector2 = offsets[index]
			surface.set_uv(offset+Vector2(0.5, 0.5))
			surface.set_uv2(Vector2(row, 0))
			surface.add_vertex(to_local(map.to_global(center3+Vector3(offset.x*map.cell_size.x, 0, offset.y*map.cell_size.z))))
	flow_data = ImageTexture.create_from_image(data)
	material_override.set_shader_parameter("flow_data", flow_data)
	mesh = surface.commit()
