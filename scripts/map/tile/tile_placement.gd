extends Node3D
## Ground edits and picking for card construction; no standalone mouse tool.

signal cell_placed(cell: Vector3i)

@onready var map: GridMap = $"../TileMap"
@onready var camera: Camera3D = $"../Camera3D"

func _ready() -> void:
	for cell in map.get_used_cells():
		refresh_cell(cell)

func pick_cell(screen_position: Vector2) -> Vector3i:
	# Use the placement plane, so empty space and existing tile tops share one grid.
	var plane := Plane(map.global_basis.y.normalized(), map.global_position)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	if hit == null:
		return TileConstants.INVALID_CELL
	var cell := map.local_to_map(map.to_local(hit))
	cell.y = 0
	return cell if abs(cell.x) < 32767 and abs(cell.z) < 32767 else TileConstants.INVALID_CELL

func place_cell(cell: Vector3i) -> bool:
	if cell == TileConstants.INVALID_CELL or cell.y != 0 or abs(cell.x) >= 32767 or abs(cell.z) >= 32767:
		return false
	if map.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
		return false
	return not add_cells([cell]).is_empty()

## The caller validates first. Set all ground before refreshing any connections.
## Cards delay notifications until their tower occupancy has also been committed.
func add_cells(cells: Array[Vector3i], notify := true) -> Array[Vector3i]:
	var towers := get_node_or_null("../TowerMap")
	for cell in cells:
		if map.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM and towers != null and towers.traffic != null and towers.traffic.occupied.has(Vector2i(cell.x,cell.z)): return []
		if cell.y != 0 or absi(cell.x) >= 32767 or absi(cell.z) >= 32767:
			return []
	var added: Array[Vector3i] = []
	var affected := {}
	for cell in cells:
		if map.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM:
			continue
		map.set_cell_item(cell, 3)
		added.append(cell)
		affected[cell] = true
		for direction in TileConstants.DIRECTIONS:
			affected[cell + direction] = true
	for cell: Vector3i in affected:
		refresh_cell(cell)
	if notify:
		notify_cells(added)
	return added

func notify_cells(cells: Array[Vector3i]) -> void:
	for cell in cells:
		cell_placed.emit(cell)

func neighbor_mask(cell: Vector3i) -> int:
	var mask := 0
	for i in TileConstants.DIRECTIONS.size():
		if map.get_cell_item(cell + TileConstants.DIRECTIONS[i]) > 0:
			mask |= 1 << i
	return mask

func tile_for_mask(mask: int) -> Vector2i:
	var count := 0
	for i in 4:
		if mask & (1 << i):
			count += 1
	var item := 3
	match count:
		1: item = 4
		2: item = 1 if mask in [5, 10] else 2
		3: item = 5
		4: item = 6
	var rotated: int = TileConstants.BASE_MASKS[item]
	for turn in 4:
		if rotated == mask:
			return Vector2i(item, map.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn * PI / 2)))
		rotated = (rotated >> 1) | ((rotated & 1) << 3)
	return Vector2i(3, 0)

func refresh_cell(cell: Vector3i) -> void:
	if map.get_cell_item(cell) <= 0:
		return
	var tile := tile_for_mask(neighbor_mask(cell))
	var appearance := TileConstants.appearance_of(map.get_cell_item(cell))
	map.set_cell_item(cell, TileConstants.item_for(tile.x, appearance), tile.y)

