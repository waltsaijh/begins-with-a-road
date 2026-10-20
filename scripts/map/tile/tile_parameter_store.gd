extends RefCounted
## One collection per map: owns tile records and caches each troop's cost array.
## Pathfinding stays in the native planner; this class only prepares its inputs.
signal costs_changed(profile_id: int)
signal parameters_changed
const TileRecord = preload("res://scripts/map/tile/tile_parameters.gd")
var revision := 0
var ordered: Array[TileRecord] = []
var _tiles := {}
var _ordered_cells := {}
var _cache := {}
## Sparse coverage includes empty cells, so newly added roads inherit it.
var _tower_counts := {}
var _tower_threat := {}
var _update_depth := 0
var _update_dirty := false
var _parameters_dirty := false

func _create_tile(cell: Vector2i) -> TileRecord:
	var tile := TileRecord.new()
	tile.cell = cell
	tile.num_towers_around = _tower_counts.get(cell, 0)
	tile.threat = _tower_threat.get(cell, 0.0)
	tile.changed.connect(_on_tile_changed.bind(cell))
	return tile

func ensure_tile(cell: Vector2i) -> TileRecord:
	if not _tiles.has(cell):
		_tiles[cell] = _create_tile(cell)
		parameters_changed.emit()
	return _tiles[cell]

func all_tiles() -> Array:
	return _tiles.values()

func sync(cells: PackedVector2Array, retained_cells: Dictionary = {}) -> void:
	var kept := {}
	var next: Array[TileRecord] = []
	for value in cells:
		var cell := Vector2i(value)
		var tile: TileRecord = _tiles.get(cell)
		if tile == null:
			tile = _create_tile(cell)
		kept[cell] = tile
		next.append(tile)
	_ordered_cells = kept.duplicate()
	# Obstacles still have physical tile parameters, but no native cost slot.
	for cell: Vector2i in retained_cells:
		if not kept.has(cell):
			kept[cell] = _tiles[cell] if _tiles.has(cell) else _create_tile(cell)
	for cell: Vector2i in _tiles:
		if not kept.has(cell):
			_tiles[cell].changed.disconnect(_on_tile_changed.bind(cell))
	_tiles = kept
	ordered = next
	revision += 1
	_cache.clear()

func get_tile(cell: Vector2i) -> TileRecord:
	return _tiles.get(cell)

func begin_update() -> void:
	_update_depth += 1

func end_update() -> void:
	assert(_update_depth > 0)
	_update_depth -= 1
	if _update_depth == 0 and _update_dirty:
		_update_dirty = false
		revision += 1
		costs_changed.emit(0)
	if _update_depth == 0 and _parameters_dirty:
		_parameters_dirty = false
		parameters_changed.emit()

func change_tower_influence(cell: Vector2i, nearby_delta: int, threat_delta: float) -> void:
	var count: int = _tower_counts.get(cell, 0)+nearby_delta
	var previous: float = _tower_threat.get(cell, 0.0)
	var amount := maxf(0.0, previous+threat_delta)
	# Remove subtraction roundoff after the last fractional contributor leaves.
	if threat_delta < 0 and absf(amount) <= 1e-12*maxf(absf(previous), absf(threat_delta)):
		amount = 0.0
	if count == 0:
		_tower_counts.erase(cell)
	else:
		_tower_counts[cell] = count
	if amount == 0.0:
		_tower_threat.erase(cell)
	else:
		_tower_threat[cell] = amount
	var tile := get_tile(cell)
	if tile != null:
		tile.num_towers_around = count
		tile.threat = amount

func evaluate(profile: Troop) -> Dictionary:
	var id := profile.get_instance_id()
	if not profile.changed.is_connected(_on_profile_changed.bind(id)):
		profile.changed.connect(_on_profile_changed.bind(id))
	if _cache.has(id):
		return {"valid": true, "costs": _cache[id], "cached": true, "evaluation_calls": 0}
	var costs := PackedFloat64Array()
	costs.resize(ordered.size())
	for i in ordered.size():
		var value := profile.evaluation(ordered[i])
		if not is_finite(value):
			return {"valid": false, "error": "地塊 %s 的評分必須為有限數值" % ordered[i].cell, "cached": false, "evaluation_calls": i+1}
		costs[i] = value
	_cache[id] = costs
	return {"valid": true, "costs": costs, "cached": false, "evaluation_calls": ordered.size()}

func _on_tile_changed(cell: Vector2i) -> void:
	if _update_depth > 0:
		_parameters_dirty = true
	else:
		parameters_changed.emit()
	# Deferred dead-end tiles are visible data, but are not native cost slots.
	if not _ordered_cells.has(cell):
		return
	_cache.clear()
	if _update_depth > 0:
		_update_dirty = true
		return
	revision += 1
	costs_changed.emit(0)

func _on_profile_changed(id: int) -> void:
	_cache.erase(id)
	costs_changed.emit(id)
