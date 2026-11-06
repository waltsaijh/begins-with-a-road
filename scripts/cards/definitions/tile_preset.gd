@tool
class_name TilePreset
extends Resource
## Authored footprint coordinates use the placement origin, independently of tower_offset.
## Empty preserves legacy TowerDefinition geometry.
@export var tower_footprint: Array[Vector2i] = []
@export var display_name := ""
@export var manual_ports := false
@export_range(0, 3) var default_rotation := 0
@export_range(0, 3) var facing_steps := 0
@export var model_offset := Vector3.ZERO
@export var custom_home := false
@export var home_offset := Vector2i(0, -1)
## Named construction geometry, relative to its placement anchor.
## Empty explicit_road_ports preserves the original adjacent-road behavior.
@export var preset_id := "":
	set(value):
		preset_id = value
		emit_changed()
## Stable translation ID, e.g. tile_preset.corner. Empty means no prefix.
@export var prefix_key := "":
	set(value):
		if prefix_key != value:
			prefix_key = value
			emit_changed()
@export var road_offsets: Array[Vector2i] = []:
	set(value):
		road_offsets = value
		emit_changed()
## Empty means the union of roads and the chosen tower's complete footprint.
@export var occupied_offsets: Array[Vector2i] = []:
	set(value):
		occupied_offsets = value
		emit_changed()
@export var tower_offset := Vector2i.ZERO:
	set(value):
		tower_offset = value
		emit_changed()
## Clockwise quarter turns. An empty list is a configuration error.
@export var allowed_rotations: Array[int] = [0, 1, 2, 3]:
	set(value):
		allowed_rotations = value
		emit_changed()
## One mask per road_offsets cell: north/east/south/west = 1/2/4/8.
## Outward ports permit future connections; they are not traversable by themselves.
@export var explicit_road_ports: Dictionary[Vector2i, int] = {}:
	set(value):
		explicit_road_ports = value
		emit_changed()

func stable_id() -> String:
	if not preset_id.is_empty(): return preset_id
	return resource_path if not resource_path.is_empty() else prefix_key

func has_explicit_ports() -> bool:
	return manual_ports or not explicit_road_ports.is_empty()

func allows_rotation(turns: int) -> bool:
	return posmod(turns, 4) in allowed_rotations

static func rotate_ports(mask: int, turns: int) -> int:
	for i in posmod(turns, 4):
		mask = ((mask << 1) & 15) | ((mask >> 3) & 1)
	return mask

func configuration_error() -> String:
	if not tower_footprint.is_empty():
		if preset_id.is_empty(): return "自訂塔體缺少穩定 ID"
		if not tower_offset in tower_footprint: return "塔錨點必須在塔體內"
		if not default_rotation in allowed_rotations: return "預設旋轉必須是允許的方向"
		if facing_steps < 0 or facing_steps > 3: return "塔朝向必須是 0 至 3"
		if not model_offset.is_finite(): return "模型位移必須是有限數值"
		var roads_seen := {}
		for cell in road_offsets:
			if roads_seen.has(cell): return "道路格重複"
			roads_seen[cell] = true
		var remaining := {}
		for cell in tower_footprint:
			if remaining.has(cell): return "塔體格重複"
			if cell in road_offsets: return "道路與塔體不能重疊"
			remaining[cell] = true
		var pending: Array[Vector2i] = [tower_offset]
		remaining.erase(tower_offset)
		while not pending.is_empty():
			var at: Vector2i = pending.pop_back()
			for delta in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if remaining.has(at+delta):
					remaining.erase(at+delta)
					pending.append(at+delta)
		if not remaining.is_empty(): return "塔體必須四向連通"
	if allowed_rotations.is_empty(): return "地塊沒有可用旋轉方向"
	var rotations := {}
	for turn in allowed_rotations:
		if turn < 0 or turn > 3 or rotations.has(turn): return "地塊旋轉方向必須是互異的 0 至 3"
		rotations[turn] = true
	var ground := {}
	for cell in occupied_offsets:
		if ground.has(cell): return "複合地塊占用格重複"
		ground[cell] = true
	for cell in road_offsets:
		if not ground.is_empty() and not ground.has(cell): return "複合地塊占用範圍缺少道路格"
	if not has_explicit_ports(): return ""
	if preset_id.is_empty(): return "複合地塊缺少穩定識別碼"
	var roads := {}
	for cell in road_offsets:
		if roads.has(cell): return "複合地塊道路格重複"
		roads[cell] = true
		if not explicit_road_ports.has(cell): return "複合地塊道路缺少接口設定"
	if roads.size() != explicit_road_ports.size(): return "複合地塊接口包含非道路格"
	for cell: Vector2i in explicit_road_ports:
		var mask: int = explicit_road_ports[cell]
		if mask < 0 or mask > 15: return "道路接口必須是 0 至 15 的四向遮罩"
		if not ground.is_empty() and not ground.has(cell): return "複合地塊占用範圍缺少道路格"
		for direction in 4:
			var offset: Vector3i = TileConstants.DIRECTIONS[direction]
			var neighbor := cell + Vector2i(offset.x, offset.z)
			if not explicit_road_ports.has(neighbor): continue
			var outgoing := bool(mask & (1 << direction))
			var incoming := bool(explicit_road_ports[neighbor] & (1 << ((direction + 2) % 4)))
			if outgoing != incoming: return "複合地塊內部道路接口必須雙向一致"
	return ""

func localized_prefix() -> String:
	if not display_name.is_empty(): return display_name
	return tr(prefix_key) if not prefix_key.is_empty() else ""
