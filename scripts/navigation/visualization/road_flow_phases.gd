class_name RoadFlowPhases
extends RefCounted
## Presentation clocks taken from complete allocated trips, never from edge-union BFS.
var edges := {}
var turns := {}
var starts := {}
var ends := {}
var steps := 0
var period := 4
var _profiles := {}
var _sets: Array[PackedInt32Array] = []
var _texture: ImageTexture

func add_trip(cells: PackedVector2Array) -> void:
	steps = maxi(steps, cells.size()-1)
	for i in range(cells.size()-1):
		var a := Vector2i(cells[i])
		var b := Vector2i(cells[i+1])
		if absi(a.x-b.x)+absi(a.y-b.y) != 1: continue
		var edge := Vector4i(a.x,a.y,b.x,b.y)
		if not edges.has(edge): edges[edge] = {}
		edges[edge][i] = true
		if i == 0:
			if not starts.has(edge): starts[edge] = {}
			starts[edge][i] = true
		if i == cells.size()-2:
			if not ends.has(edge): ends[edge] = {}
			ends[edge][i+1] = true
		if i+2 >= cells.size(): continue
		var c := Vector2i(cells[i+2])
		if absi(b.x-c.x)+absi(b.y-c.y) != 1: continue
		var next := Vector4i(b.x,b.y,c.x,c.y)
		if not turns.has(edge): turns[edge] = {}
		if not turns[edge].has(next): turns[edge][next] = {}
		turns[edge][next][i+1] = true

func prepare(highlight_length: float) -> void:
	var next := maxi(maxi(4,steps+1),ceili(highlight_length*2.0))
	if next == period: return
	period = next
	_profiles.clear()
	_sets.clear()
	_texture = null

func register(phases: Dictionary) -> Vector2:
	assert(not phases.is_empty(), "Every visible flow piece needs an allocated trip clock")
	var values := PackedInt32Array(phases.keys())
	values.sort()
	var base := values[0]
	for i in values.size(): values[i] -= base
	# Shared suffixes usually have the same arrival gaps; singleton clocks share one row.
	if not _profiles.has(values):
		_profiles[values] = _sets.size()
		_sets.append(values)
		_texture = null
	return Vector2(_profiles[values],base)

func lookup_texture() -> ImageTexture:
	if _texture != null: return _texture
	# Byte channels preserve integer distances on Web, including GPU readback.
	# Each nearest-arrival distance is an unsigned 16-bit value, not a color.
	assert(period <= 65535, "Flow animation period exceeds 16-bit lookup capacity")
	var data := Image.create(period,_sets.size(),false,Image.FORMAT_RGBA8)
	for row in _sets.size():
		var phases := _sets[row]
		var cursor := 0
		for x in period:
			while cursor+1 < phases.size() and phases[cursor+1] <= x: cursor += 1
			var left := x-phases[cursor]
			var right := phases[cursor+1]-x if cursor+1 < phases.size() else phases[0]+period-x
			data.set_pixel(x,row,Color8(left&255,left>>8,right&255,right>>8))
	_texture = ImageTexture.create_from_image(data)
	return _texture
