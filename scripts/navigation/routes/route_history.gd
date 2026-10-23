extends RefCounted
## Run-local committed topology snapshots; never populated by candidate searches.
var wave := 1
var snapshots: Array[Dictionary] = []
var current := {}
var revision := 0
var _geometry_cache := {}

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
	value.wave = 0 if snapshots.is_empty() else wave
	current = value
	snapshots.append(value)
	revision += 1
	_geometry_cache.clear()

func candidates(origin: int, shortest: bool) -> Dictionary:
	if current.is_empty() or origin < 0 or origin >= current.starts.size(): return {"valid":false,"error":"尚未建立道路歷史"}
	var key := Vector2i(origin, int(shortest))
	if not _geometry_cache.has(key):
		if not ClassDB.class_exists("RoadSpecialRoutes"): return {"valid":false,"error":"請重新建置並重啟 Godot 以載入 Phase 4 尋路擴充"}
		var search: RefCounted = ClassDB.instantiate("RoadSpecialRoutes")
		_geometry_cache[key] = search.plan(current.cells,current.ports,Vector2i(current.starts[origin]),current.goal,snapshots,shortest,200000)
	return _geometry_cache[key]
