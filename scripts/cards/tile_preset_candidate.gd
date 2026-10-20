@tool
class_name TilePresetCandidate
extends Resource
## Per-tower weight. A file reference lets removed presets be skipped safely.
@export_file("*.tres") var preset_path := ""
@export_range(0.0, 1000.0, 0.1, "or_greater") var weight := 1.0

func is_enabled() -> bool:
	return is_finite(weight) and weight > 0.0 and not preset_path.is_empty()

func resolve_preset() -> TilePreset:
	if not is_enabled(): return null
	var directory := preset_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory): return null
	# A cached resource may outlive its file; the pool must reflect deletions.
	if not ResourceLoader.list_directory(directory).has(preset_path.get_file()): return null
	return ResourceLoader.load(preset_path) as TilePreset
