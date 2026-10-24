class_name LevelCatalog
extends RefCounted
## One catalog snapshot. Kahn orders prerequisite layers; siblings sort by ID.
## Build is O(V log V + E); unlock refresh is O(V + E).
const DIRECTORY := "res://assets/data/levels"
var maps: Array[MenuMapDefinition] = []
var by_id := {}
var dependents := {}
var diagnostics := PackedStringArray()

static func discover(directory := DIRECTORY) -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	if not DirAccess.dir_exists_absolute(directory): return result
	for file in ResourceLoader.list_directory(directory):
		if file.ends_with("/"):
			result.append_array(discover(directory.path_join(file.trim_suffix("/"))))
		elif file.get_extension() == "tres":
			var resource := ResourceLoader.load(directory.path_join(file)) as LevelDefinition
			if resource != null: result.append(resource)
	return result

func build(levels: Array[LevelDefinition], completed := {}) -> void:
	maps.clear()
	by_id.clear()
	dependents.clear()
	diagnostics.clear()
	var entries: Array[MenuMapDefinition] = []
	var ordered := levels.duplicate()
	ordered.sort_custom(func(a: LevelDefinition, b: LevelDefinition):
		if a.progress_id() != b.progress_id(): return a.progress_id() < b.progress_id()
		return a.resource_path < b.resource_path)
	for level: LevelDefinition in ordered:
		var entry := MenuMapDefinition.new()
		entry.level = level
		entry.id = level.progress_id()
		entry.title_key = level.title_key()
		entry.description_key = level.description_key()
		var unique := {}
		for required: String in level.required_to_complete_levels:
			var id: String = required.strip_edges()
			if not unique.has(id):
				unique[id] = true
				entry.requirements.append(id)
		entries.append(entry)
		if entry.id.is_empty():
			entry.problem = &"ui.maps.invalid"
			diagnostics.append("Missing level ID: "+level.resource_path)
		elif by_id.has(entry.id):
			entry.problem = &"ui.maps.invalid"
			by_id[entry.id].problem = &"ui.maps.invalid"
			diagnostics.append("Duplicate level ID: "+entry.id)
		else:
			by_id[entry.id] = entry
			dependents[entry.id] = []
		if level.terrain == null or level.acts.is_empty():
			entry.problem = &"ui.maps.invalid"
			diagnostics.append("Missing terrain/ACTs: "+level.resource_path)
	var degree := {}
	var layer: Array[String] = []
	for id: String in by_id:
		var entry: MenuMapDefinition = by_id[id]
		degree[id] = 0
		for required in entry.requirements:
			if not by_id.has(required):
				entry.problem = &"ui.maps.invalid_dependencies"
				diagnostics.append(id+": missing prerequisite "+required)
			else:
				degree[id] += 1
				dependents[required].append(id)
		if degree[id] == 0: layer.append(id)
	while not layer.is_empty():
		# Finish this whole layer before visiting children. A child with a smaller
		# ID must not jump ahead of its parent's remaining siblings.
		layer.sort()
		var next_layer: Array[String] = []
		for id in layer:
			var entry: MenuMapDefinition = by_id[id]
			if entry.problem.is_empty(): maps.append(entry)
			for child: String in dependents[id]:
				if not entry.problem.is_empty(): by_id[child].problem = &"ui.maps.invalid_dependencies"
				degree[child] -= 1
				if degree[child] == 0: next_layer.append(child)
		layer = next_layer
	for id: String in degree:
		if degree[id] > 0:
			by_id[id].problem = &"ui.maps.invalid_dependencies"
			diagnostics.append(id+": cycle or dependent on a cycle")
	# Invalid drafts/cycles stay visible and locked, after the playable DAG.
	# entries already has deterministic ID/path order, including duplicate IDs.
	for entry in entries:
		if not entry.problem.is_empty(): maps.append(entry)
	refresh(completed)

func refresh(completed: Dictionary) -> void:
	for entry in maps:
		entry.completed = completed.has(entry.id)
		entry.missing_titles.clear()
		for required in entry.requirements:
			if not completed.has(required):
				entry.missing_titles.append(by_id[required].title_key if by_id.has(required) else required)
		entry.unlocked = entry.problem.is_empty() and entry.missing_titles.is_empty()
