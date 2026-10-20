extends RefCounted
## Pure, deterministic visual selection. Does not mutate a GridMap or navigation.

static func select(roads: Array[Vector3i], straight_cells: Dictionary, entrances: Dictionary, terminals: Array[Vector3i], previous: Dictionary = {}) -> Dictionary:
	var variants := {}
	var pillars: Array[Vector3i] = []
	var wood: Array[Vector3i] = []
	var blocked := {}
	var road_set := {}
	for cell in roads:
		road_set[cell] = true
	# Endpoints always get supports, including endpoints closer than the spacing.
	for cell in terminals:
		if road_set.has(cell) and not variants.has(cell):
			variants[cell] = TileConstants.Appearance.PILLAR
			pillars.append(cell)
			_block_disk(blocked, cell, TileAppearanceConstants.PILLAR_RADIUS)
	var candidates: Array[Vector3i] = []
	for cell: Vector3i in entrances:
		if road_set.has(cell):
			candidates.append(cell)
	candidates.sort_custom(_cell_less)
	# Preserve valid supports before looking for new ones. New nearby entrances
	# must not displace an existing support simply because they are nearer.
	var retained_supports := 0
	for cell: Vector3i in previous.get("pillars", []):
		if road_set.has(cell) and entrances.has(cell) and not blocked.has(cell):
			variants[cell] = TileConstants.Appearance.PILLAR
			pillars.append(cell)
			_block_disk(blocked, cell, TileAppearanceConstants.PILLAR_RADIUS)
			retained_supports += 1
	if not pillars.is_empty():
		var current := pillars[-1] if retained_supports > 0 else pillars[0]
		while true:
			var nearest := Vector3i.ZERO
			var best := INF
			for cell in candidates:
				if blocked.has(cell):
					continue
				var distance := _distance_squared(current, cell)
				if distance < best:
					best = distance
					nearest = cell
			if best == INF:
				break
			current = nearest
			variants[current] = TileConstants.Appearance.PILLAR
			pillars.append(current)
			_block_disk(blocked, current, TileAppearanceConstants.PILLAR_RADIUS)
	var target := floori(float(roads.size()) / TileAppearanceConstants.TILES_PER_WOOD_BRIDGE)
	blocked.clear()
	for cell: Vector3i in previous.get("wood", []):
		if wood.size() >= target:
			break
		if road_set.has(cell) and straight_cells.has(cell) and not entrances.has(cell) and not variants.has(cell) and not blocked.has(cell):
			wood.append(cell)
			variants[cell] = TileConstants.Appearance.WOOD
			_block_disk(blocked, cell, TileAppearanceConstants.WOOD_SPACING)
	# Only fill vacancies; stable existing bridges do not enter the lottery again.
	# Shuffle a sorted list so GridMap iteration/hash order cannot change the seed.
	candidates.clear()
	for cell: Vector3i in straight_cells:
		if not entrances.has(cell) and not variants.has(cell):
			candidates.append(cell)
	candidates.sort_custom(_cell_less)
	var rng := RandomNumberGenerator.new()
	rng.seed = TileAppearanceConstants.SEED_VALUE
	for i in range(candidates.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var swap := candidates[i]
		candidates[i] = candidates[other]
		candidates[other] = swap
	for cell in candidates:
		if wood.size() >= target:
			break
		if blocked.has(cell):
			continue
		wood.append(cell)
		variants[cell] = TileConstants.Appearance.WOOD
		_block_disk(blocked, cell, TileAppearanceConstants.WOOD_SPACING)
	return {"variants": variants, "pillars": pillars, "wood": wood, "wood_target": target}

static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	return a.x < b.x or (a.x == b.x and a.z < b.z)

static func _distance_squared(a: Vector3i, b: Vector3i) -> float:
	var dx := float(a.x - b.x)
	var dz := float(a.z - b.z)
	return dx * dx + dz * dz

static func _block_disk(blocked: Dictionary, center: Vector3i, radius: float) -> void:
	var extent := ceili(radius)
	for z in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			if x * x + z * z <= radius * radius:
				blocked[center + Vector3i(x, 0, z)] = true
