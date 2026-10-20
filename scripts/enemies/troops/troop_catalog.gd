@tool
class_name TroopCatalog
extends RefCounted
## Discover shared troop resources, including additions/removals, in editor and exports.
const DIRECTORY := "res://assets/data/troops"
static var _loaded: Dictionary[String, Troop] = {}

static func load_path(path: String) -> Troop:
	if path.is_empty(): return null
	var directory := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		_loaded.erase(path)
		return null
	# ResourceLoader's cache may outlive a deleted file.
	if not ResourceLoader.list_directory(directory).has(path.get_file()):
		_loaded.erase(path)
		return null
	if _loaded.has(path): return _loaded[path]
	var profile := ResourceLoader.load(path) as Troop
	if profile != null: _loaded[path] = profile
	return profile

static func all(directory := DIRECTORY) -> Array[Troop]:
	var result: Array[Troop] = []
	if not DirAccess.dir_exists_absolute(directory): return result
	for file in ResourceLoader.list_directory(directory):
		if file.ends_with("/"):
			result.append_array(all(directory.path_join(file.trim_suffix("/"))))
		elif file.get_extension() == "tres":
			var profile := load_path(directory.path_join(file))
			if profile != null: result.append(profile)
	result.sort_custom(func(a: Troop, b: Troop) -> bool:
		if a.sort_order != b.sort_order: return a.sort_order < b.sort_order
		return a.resource_path < b.resource_path)
	return result

static func find(id: String) -> Troop:
	for profile in all():
		if profile.troop_name == id: return profile
	return null

static func default_troop() -> Troop:
	var profiles := all()
	for profile in profiles:
		if profile.troop_name == "soldier": return profile
	return profiles[0] if not profiles.is_empty() else null
