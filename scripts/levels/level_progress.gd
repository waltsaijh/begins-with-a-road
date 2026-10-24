extends Node
## Completion IDs only: no mid-run state, scene cache or gameplay dependency.
signal changed
var save_path := "user://level_completion.cfg"
var _completed := {}

func _ready() -> void:
	var error := load_progress(save_path)
	if error != OK: push_warning("Could not load level completion: "+error_string(error))

func snapshot() -> Dictionary:
	return _completed.duplicate()

func load_progress(path: String) -> int:
	save_path = path
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND: return error
	var ids: Variant = config.get_value("progress","completed",PackedStringArray())
	if not ids is PackedStringArray or config.get_value("progress","version",1) != 1: return ERR_INVALID_DATA
	var loaded := {}
	for id: String in ids:
		if not id.is_empty(): loaded[id] = true
	_completed = loaded
	changed.emit()
	return OK

func mark_completed(id: String) -> int:
	if id.is_empty(): return ERR_INVALID_PARAMETER
	if _completed.has(id): return OK
	_completed[id] = true
	var config := ConfigFile.new()
	config.set_value("progress","version",1)
	config.set_value("progress","completed",PackedStringArray(_completed.keys()))
	# ConfigFile uses FileAccess; Web synchronizes these writes to IndexedDB.
	var error := config.save(save_path)
	if error != OK: push_warning("Could not save level completion: "+error_string(error))
	changed.emit()
	return error
