extends RefCounted
## The editor's marked combination is the production source, not a geometry copy.
const INDEX = preload("res://assets/data/tower_tiles/user/catalog.tres")
static func candidates(tower_key: String) -> Array[TilePresetCandidate]:
	var result: Array[TilePresetCandidate] = []
	var members: Array = []
	for group in INDEX.combinations:
		if group.get("variant_group","") == "base": members = group.members; break
	for entry in INDEX.entries:
		if entry.tower != tower_key or entry.get("archived",false): continue
		if not tower_key+"|"+str(entry.id) in members: continue
		var candidate := TilePresetCandidate.new()
		candidate.preset_path = entry.path
		candidate.weight = entry.weight
		result.append(candidate)
	return result
