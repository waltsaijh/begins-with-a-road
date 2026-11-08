@tool
class_name BuildCard
extends Resource
## Shared, editable construction recipe. Geometry is relative to a placement anchor.
@export_range(0, 100, 1, "or_greater") var price := ShopConstants.DEFAULT_CARD_PRICE:
	set(value):
		price = maxi(0, value)
		emit_changed()
@export var tile_preset: TilePreset:
	set(value):
		if tile_preset == value: return
		if is_instance_valid(tile_preset) and tile_preset.changed.is_connected(emit_changed):
			tile_preset.changed.disconnect(emit_changed)
		tile_preset = value
		if tile_preset != null: tile_preset.changed.connect(emit_changed)
		emit_changed()
@export var traffic: TrafficStructureDefinition:
	set(value):
		if is_instance_valid(traffic) and traffic.changed.is_connected(emit_changed): traffic.changed.disconnect(emit_changed)
		traffic = value
		if traffic != null: traffic.changed.connect(emit_changed)
		emit_changed()
@export var tower: TowerDefinition:
	set(value):
		if tower != value:
			tower = value
			emit_changed()
@export_group("Card Artwork")
## Null keeps the texture authored in card_view.tscn.
@export var background_texture: Texture2D:
	set(value):
		if background_texture != value:
			background_texture = value
			emit_changed()
@export var frame_texture: Texture2D:
	set(value):
		if frame_texture != value:
			frame_texture = value
			emit_changed()

static func from_parts(definition: TowerDefinition, preset: TilePreset) -> BuildCard:
	var result := BuildCard.new()
	result.tower = definition
	result.tile_preset = preset.duplicate(true) if preset != null and not preset.tower_footprint.is_empty() else preset
	if definition != null: result.price = definition.card_price
	return result

static func from_traffic(definition: TrafficStructureDefinition) -> BuildCard:
	var result := BuildCard.new()
	result.traffic = definition
	result.price = definition.card_price
	return result

func visual_definition() -> Resource:
	return traffic if traffic != null else tower

func localized_prefix() -> String:
	return tile_preset.localized_prefix() if tile_preset != null else ""

func localized_name() -> String:
	if traffic != null: return traffic.localized_name()
	if tower == null: return tr("card.unassigned")
	var tower_name := tower.localized_name()
	var prefix := localized_prefix()
	if prefix.is_empty(): return tower_name
	# Translators control the join/order; Chinese does not need an inserted space.
	return tr("card.name_format").format({"prefix": prefix, "tower": tower_name})

static func rotate_cell(cell: Vector2i, turns: int) -> Vector2i:
	for i in posmod(turns, 4):
		cell = Vector2i(-cell.y, cell.x)
	return cell

## Translate the authored origin so pointer rotation pivots around the whole body.
## Compute absolutely from the selection's initial facing: rounding never accumulates.
func rotation_anchor_offset(turns: int, initial_turns := 0) -> Vector2i:
	if traffic != null or tower == null: return Vector2i.ZERO
	var initial_center := TowerBodyGeometry.center(tower_cells(Vector2i.ZERO, initial_turns))
	var rotated_center := TowerBodyGeometry.center(tower_cells(Vector2i.ZERO, turns))
	# Mixed odd/even rectangles need the nearest half-cell snap on a square grid.
	return Vector2i((initial_center-rotated_center).round())

func tower_anchor(anchor: Vector2i, turns := 0) -> Vector2i:
	return anchor + rotate_cell(tile_preset.tower_offset, turns) if tile_preset != null and traffic == null else anchor

func tower_cells(anchor: Vector2i, turns := 0) -> Array[Vector2i]:
	if tile_preset != null and not tile_preset.tower_footprint.is_empty():
		var result: Array[Vector2i] = []
		for cell in tile_preset.tower_footprint: result.append(anchor+rotate_cell(cell,turns))
		return result
	return tower.cells_at(tower_anchor(anchor, turns), turns) if tower != null else []

func tower_facing(turns: int) -> int:
	return posmod(turns+(tile_preset.facing_steps if tile_preset != null else 0),4)

func home_cell(anchor: Vector2i, turns: int) -> Vector2i:
	if tile_preset != null and tile_preset.custom_home:
		return anchor+rotate_cell(tile_preset.home_offset,turns)
	return tower_anchor(anchor,turns)+rotate_cell(Vector2i.UP,tower_facing(turns))

func allows_rotation(turns: int) -> bool:
	return tile_preset == null or traffic != null or tile_preset.allows_rotation(turns)

func road_cells(anchor: Vector2i, turns := 0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if tile_preset == null or traffic != null: return result
	for offset in tile_preset.road_offsets:
		var cell := anchor + rotate_cell(offset, turns)
		if not cell in result: result.append(cell)
	return result

## Empty denotes legacy automatic adjacency, not a disconnected explicit recipe.
func road_ports(anchor: Vector2i, turns := 0) -> Dictionary:
	var result := {}
	if tile_preset == null or traffic != null: return result
	for offset: Vector2i in tile_preset.explicit_road_ports:
		result[anchor + rotate_cell(offset, turns)] = TilePreset.rotate_ports(tile_preset.explicit_road_ports[offset], turns)
	return result

func ground_cells(anchor: Vector2i, turns := 0) -> Array[Vector2i]:
	if traffic != null: return [anchor]
	var result := tower_cells(anchor, turns)
	if tile_preset == null: return result
	var offsets := tile_preset.occupied_offsets if not tile_preset.occupied_offsets.is_empty() else tile_preset.road_offsets
	for offset in offsets:
		var cell := anchor + rotate_cell(offset, turns)
		if not cell in result:
			result.append(cell)
	return result

func configuration_error() -> String:
	if traffic != null:
		if tower != null: return "建造卡不能同時指定塔與輔助設施"
		return traffic.configuration_error()
	if tower == null or tower.model == null or tower.footprint.is_empty():
		return "卡片缺少防禦塔模型或佔格設定"
	if not Vector2i.ZERO in tower.footprint:
		return "防禦塔佔格必須包含中心格"
	if tile_preset == null:
		return "卡片缺少地塊預設"
	var preset_error := tile_preset.configuration_error()
	if not preset_error.is_empty(): return preset_error
	if tower.deployment != null and tile_preset.custom_home and tile_preset.home_offset in tower_cells(Vector2i.ZERO): return "兵營駐點不能位於塔體內"
	for cell in tile_preset.occupied_offsets:
		if not cell in tile_preset.road_offsets and not cell in tower_cells(Vector2i.ZERO):
			return "地塊占用格必須是道路或防禦塔底座"
	if tile_preset.has_explicit_ports():
		var footprint := tower_cells(Vector2i.ZERO)
		for cell in footprint:
			if cell in tile_preset.road_offsets: return "複合地塊道路不能與防禦塔重疊"
			if not tile_preset.occupied_offsets.is_empty() and not cell in tile_preset.occupied_offsets:
				return "複合地塊占用範圍缺少防禦塔底座"
	return tower.configuration_error()
