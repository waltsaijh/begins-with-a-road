@tool
class_name TilePreset
extends Resource
## Named road layout, relative to the tower anchor; independent of tower stats.
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

func localized_prefix() -> String:
	return tr(prefix_key) if not prefix_key.is_empty() else ""
