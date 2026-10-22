@tool
class_name BuildCard
extends Resource
## Shared, editable construction recipe. Offsets are relative to the tower anchor.
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
	result.tile_preset = preset
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

func tower_cells(anchor: Vector2i, turns := 0) -> Array[Vector2i]:
	return tower.cells_at(anchor, turns) if tower != null else []

func ground_cells(anchor: Vector2i, turns := 0) -> Array[Vector2i]:
	if traffic != null: return [anchor]
	var result := tower_cells(anchor, turns)
	if tile_preset == null: return result
	for offset in tile_preset.road_offsets:
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
	return tower.configuration_error()
