@tool
class_name LevelDefinition
extends Resource
const TerrainLayout = preload("res://scripts/map/terrain/terrain_layout.gd")
## One level file references its editable GridMap scene and complete ACT schedule.
@export var title := "Begins With a Road"
@export var terrain: PackedScene
## Prefer draggable Start/Goal nodes in the terrain scene when present.
@export var use_terrain_endpoints := true
## Compatibility for markerless maps, or when Use Terrain Endpoints is disabled.
@export var starts: Array[Vector2i] = [Vector2i.ZERO]
@export var goal := Vector2i(23, 0)
@export var marker_height := 0.0305
@export var acts: Array[ActDefinition] = []
@export var auto_start := false
## Between ACTs, choose a direction and extend the road to one new entrance.
@export var expand_starts_after_act := true
@export_range(1.0, 300.0, 1.0) var preparation_seconds := 60.0
## Maximum extra coins for manually calling a wave at the start of preparation.
## 0 disables the bonus; remaining-time rewards are rounded up to whole coins.
@export_range(0, 1000, 1, "or_greater") var early_start_max_bonus := 10

func early_start_bonus(remaining: float) -> int:
	if remaining <= 0.0 or early_start_max_bonus <= 0: return 0
	return mini(early_start_max_bonus, ceili(early_start_max_bonus*clampf(remaining/preparation_seconds, 0.0, 1.0)))

func wave_count() -> int:
	var count := 0
	for act in acts:
		if act != null: count += act.waves.size()
	return count

func configuration_error() -> String:
	repair_missing_defaults()
	if not is_finite(preparation_seconds) or preparation_seconds <= 0: return "Invalid preparation duration"
	if early_start_max_bonus < 0: return "Early-start bonus cannot be negative"
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
	# Existing resources can retain Nil for newly added exports after a script
	# reload. Read through Variant so the boundary always receives a real bool.
	var prefer_markers := terrain_endpoints_enabled()
	var owned := source == null
	var node: Node = source
	if owned:
		if terrain == null: return TerrainLayout.empty("Level terrain is missing")
		if not terrain.can_instantiate(): return TerrainLayout.empty("無法載入地形場景")
		node = terrain.instantiate()
		if node == null: return TerrainLayout.empty("無法載入地形場景")
	var result := TerrainLayout.empty("Level terrain must have a GridMap root")
	if node is GridMap:
		result = TerrainLayout.read(node, prefer_markers, starts, goal, marker_height)
	if owned: node.free()
	if not result.has("error"): return TerrainLayout.empty("無法讀取地形端點；請重新載入地形場景")
	return result

func terrain_endpoints_enabled() -> bool:
	var value: Variant = get("use_terrain_endpoints")
	return value if value is bool else true

func repair_missing_defaults() -> void:
	# Repair before validation/save, rather than serializing stale Nil fields.
	for property in ["use_terrain_endpoints", "expand_starts_after_act"]:
		if get(property) == null: set(property, true)
