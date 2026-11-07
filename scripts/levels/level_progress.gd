extends Node
## Stable completion and enemy codex IDs only; no mid-run state.
signal changed
signal codex_changed
var save_path := "user://level_completion.cfg"
var _completed := {}
var _encountered := {}
# Canonical IDs changed with the enemy artwork; preserve v1 codex unlocks.
const ENEMY_ALIASES := {"rat_swarm": "rats", "shield_guardian": "rook", "blood_mage": "bloodmage", "winged_beast": "winged", "saboteur": "bomber", "siege_behemoth": "ravager"}

func canonical_enemy_id(id: String) -> String:
	return ENEMY_ALIASES.get(id,id)

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
	var enemies: Variant = config.get_value("codex","encountered",PackedStringArray())
	if not enemies is PackedStringArray: return ERR_INVALID_DATA
	var loaded := {}
	for id: String in ids:
		if not id.is_empty(): loaded[id] = true
	_completed = loaded
	_encountered.clear()
	for id: String in enemies:
		if not id.is_empty(): _encountered[canonical_enemy_id(id)] = true
	changed.emit()
	codex_changed.emit()
	return OK

func mark_completed(id: String) -> int:
	if id.is_empty(): return ERR_INVALID_PARAMETER
	if _completed.has(id): return OK
	_completed[id] = true
	var error := _save()
	if error != OK: push_warning("Could not save level completion: "+error_string(error))
	changed.emit()
	return error

func enemy_unlocked(id: String) -> bool:
	return _encountered.has(canonical_enemy_id(id))

func encounter_enemy(id: String) -> int:
	id = canonical_enemy_id(id)
	if id.is_empty(): return ERR_INVALID_PARAMETER
	if _encountered.has(id): return OK
	_encountered[canonical_enemy_id(id)] = true
	var error := _save()
	if error != OK: push_warning("Could not save enemy codex: "+error_string(error))
	codex_changed.emit()
	return error

func _save() -> int:
	# Preserve other sections and the v1 completion format, including old saves.
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error not in [OK, ERR_FILE_NOT_FOUND]: return error
	config.set_value("progress","version",1)
	config.set_value("progress","completed",PackedStringArray(_completed.keys()))
	config.set_value("codex","encountered",PackedStringArray(_encountered.keys()))
	return config.save(save_path)
