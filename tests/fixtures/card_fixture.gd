extends RefCounted
const Sentry = preload("res://assets/data/towers/sentry.tres")

static func card(preset_name: String) -> BuildCard:
	# Geometry tests use fixed layouts so users can freely edit/delete game presets.
	var preset := TilePreset.new()
	match preset_name:
		"corner":
			preset.prefix_key = "tile_preset.corner"
			preset.road_offsets = [Vector2i(0, -1), Vector2i(-1, 0)]
		"bridge":
			preset.prefix_key = "tile_preset.bridge"
			preset.road_offsets = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
		"flank":
			preset.prefix_key = "tile_preset.flank"
			preset.road_offsets = [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	return BuildCard.from_parts(Sentry, preset)

static func starting_hand() -> Array[BuildCard]:
	return [card("corner"), card("bridge"), card("flank")]
