@tool
class_name LevelDefinition
extends Resource
const TerrainLayout = preload("res://scripts/map/terrain/terrain_layout.gd")
## One level file references its editable GridMap scene and complete ACT schedule.
@export_group("Map Selection")
## Stable save/requirement key. Empty uses the relative filename under levels/.
@export var level_id := ""
## All these IDs must be completed. IDs avoid cyclic Resource dependencies.
@export var required_to_complete_levels := PackedStringArray()
@export_group("Gameplay")
@export var terrain: PackedScene
@export var acts: Array[ActDefinition] = []

func progress_id() -> String:
	if not level_id.strip_edges().is_empty(): return level_id.strip_edges()
	var directory := "res://assets/data/levels/"
	return resource_path.trim_prefix(directory).get_basename() if resource_path.begins_with(directory) else ""

func title_key() -> String:
	return "ui.maps.title."+progress_id()

func description_key() -> String:
	return "ui.maps.description."+progress_id()

func wave_count() -> int:
	var count := 0
	for act in acts:
		if act != null: count += act.waves.size()
	return count

func configuration_error() -> String:
	repair_missing_defaults()
	if terrain == null: return "Level terrain is missing"
	var layout := endpoint_layout()
	var terrain_error: String = layout.get("error", "無法讀取地形端點")
	if not terrain_error.is_empty(): return terrain_error
	if acts.is_empty(): return "Level needs at least one ACT"
	for act in acts:
		if act == null or act.waves.is_empty(): return "Each ACT needs waves"
		for wave in act.waves:
			if wave == null: return "Missing wave definition"
			var error := wave.configuration_error()
			if not error.is_empty(): return error
			for group in wave.groups:
				if group.start_index >= layout.starts.size(): return "出生群組的入口不在關卡內"
	return ""

func endpoint_layout(source: GridMap = null) -> Dictionary:
	var owned := source == null
	var node: Node = source
	if owned:
		if terrain == null: return TerrainLayout.empty("Level terrain is missing")
		if not terrain.can_instantiate(): return TerrainLayout.empty("無法載入地形場景")
		node = terrain.instantiate()
		if node == null: return TerrainLayout.empty("無法載入地形場景")
	var result := TerrainLayout.empty("Level terrain must have a GridMap root")
	if node is GridMap:
		result = TerrainLayout.read(node)
	if owned: node.free()
	if not result.has("error"): return TerrainLayout.empty("無法讀取地形端點；請重新載入地形場景")
	return result

func repair_missing_defaults() -> void:
	for act in acts:
		if act != null: act.repair_missing_defaults()
