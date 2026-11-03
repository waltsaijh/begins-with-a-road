extends RefCounted
const Catalog = preload("res://scripts/tower_tile_editor/catalog.gd")

static func long_hull() -> TilePreset:
	var preset := TilePreset.new()
	preset.preset_id = "user_test_long"
	preset.display_name = "長船體 · 單側繞路"
	preset.tower_footprint = [Vector2i(-1,0),Vector2i.ZERO,Vector2i(1,0)]
	preset.facing_steps = 3
	for x in range(-2,3): preset.road_offsets.append(Vector2i(x,-1))
	preset.road_offsets.append_array([Vector2i(-2,0),Vector2i(2,0)])
	return preset

static func cross_body() -> TilePreset:
	var preset := TilePreset.new()
	preset.preset_id = "user_test_cross"
	preset.display_name = "十字塔體 · 部分外圍道路"
	preset.tower_footprint = [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
	for x in range(-2,3): preset.road_offsets.append(Vector2i(x,-2))
	preset.road_offsets.append_array([Vector2i(-2,-1),Vector2i(-2,0),Vector2i(2,-1),Vector2i(2,0)])
	return preset

static func compact() -> TilePreset:
	var preset := TilePreset.new()
	preset.preset_id = "user_test_compact"
	preset.display_name = "單格 · 兩側道路"
	preset.tower_footprint = [Vector2i.ZERO]
	preset.road_offsets = [Vector2i.LEFT,Vector2i.RIGHT]
	return preset
