extends RefCounted
## Run-local road ages, never populated by candidate searches. A tile keeps the
## wave it first joined a complete route, the same membership that colors roads.
var wave := 1
var tile_waves := {}
var current := {}
var revision := 0
var _active := {}

func record(snapshot: Dictionary, terminals: Array[Vector2i]) -> void:
	if terminals.size() < 2: return
	var value := snapshot.duplicate(true)
	value.goal = terminals[0]
	value.starts = PackedVector2Array(terminals.slice(1))
	# Canonical physical coordinates make editor ordering/rebuilds irrelevant.
	var sorted := {}
	for i in value.ports.size(): sorted[Vector2i(value.cells[2*i],value.cells[2*i+1])] = value.ports[i]
	var keys := sorted.keys()
	keys.sort_custom(func(a: Vector2i,b: Vector2i): return a.x < b.x if a.x != b.x else a.y < b.y)
	value.cells = PackedInt32Array()
	value.ports = PackedByteArray()
	for cell: Vector2i in keys:
		value.cells.append_array(PackedInt32Array([cell.x,cell.y]))
		value.ports.append(sorted[cell])
	if not current.is_empty() and current.cells == value.cells and current.ports == value.ports and current.starts == value.starts and current.goal == value.goal: return
	_mark_tiles(value,terminals,0 if current.is_empty() else wave)
	current = value
	revision += 1

func _mark_tiles(value: Dictionary, terminals: Array[Vector2i], age: int) -> void:
	var guard: RefCounted = ClassDB.instantiate("RoadEditGuard")
	var routed: PackedInt32Array = guard.prepare(value.cells,value.ports,PackedVector2Array(terminals)).get("route_cells",PackedInt32Array())
	_active.clear()
	for i in range(0,routed.size(),2):
		var cell := Vector2i(routed[i],routed[i+1])
		_active[cell] = true
		if not tile_waves.has(cell): tile_waves[cell] = age

## Waves since each routed tile connected, counted from the newest routed tile.
func tile_ages() -> Dictionary:
	var newest := 0
	for cell: Vector2i in _active: newest = maxi(newest,tile_waves[cell])
	var ages := {}
	for cell: Vector2i in _active: ages[cell] = float(newest-tile_waves[cell])
	return ages
