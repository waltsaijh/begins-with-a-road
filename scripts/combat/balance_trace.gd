class_name BalanceTrace
extends RefCounted
## Opt-in measurement of the real game. No file, timer or events in normal play.
static var enabled := false
static var detailed := false
static var file: FileAccess
static var context := {}
static var time := 0.0
static var wave := 0
static var totals := {}
static var tower_times := {}
static var configuration_hash := ""
static func begin(path: String, metadata: Dictionary, detail := true) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	file = FileAccess.open(path,FileAccess.WRITE)
	enabled = file != null
	detailed = detail
	context = metadata.duplicate(true)
	context["detailed"] = detail
	if configuration_hash.is_empty(): configuration_hash = hash_folder("res://assets/data")+hash_folder("res://scripts")
	context["configuration_hash"] = configuration_hash.sha256_text()
	if metadata.get("kind","") != "interactive": context["driver_hash"] = hash_folder("res://tests/balance")
	time = 0.0
	wave = 0
	totals = {}
	tower_times = {}
	event("run_start", "run",metadata)
static func event(type: String, entity: String = "", payload: Dictionary = {}, stream := "deterministic") -> void:
	if not enabled: return
	totals[type] = int(totals.get(type,0))+1
	if not detailed and type in ["damage","heal","attack","hit","miss","intercept"]: return
	var row := context.duplicate()
	row.merge({"event":type,"entity":entity,"payload":payload,"time":time,"wave":wave,"act":ceili(wave/3.0),"stream":stream},true)
	file.store_line(JSON.stringify(row))
static func tower_id(tower: Node3D) -> String:
	return "%s@%s" % [tower.definition.name_key, str(tower.grid_cell)] if tower is DefenseTower else str(tower.name)
static func sample(tower: DefenseTower, state: String, seconds: float) -> void:
	if not enabled: return
	var key := tower_id(tower)
	if not tower_times.has(key): tower_times[key] = {}
	tower_times[key][state] = float(tower_times[key].get(state,0))+seconds
static func end(state: Dictionary) -> void:
	if not enabled: return
	event("run_end","run",state.merged({"event_counts":totals.duplicate(),"tower_seconds":tower_times.duplicate(true)}))
	file.flush()
	file = null
	enabled = false

static func hash_folder(path: String) -> String:
	var text := ""
	for name in DirAccess.get_files_at(path):
		if name.ends_with(".gd") or name.ends_with(".tres"): text += path+"/"+name+FileAccess.get_sha256(path+"/"+name)
	for name in DirAccess.get_directories_at(path): text += hash_folder(path+"/"+name)
	return text.sha256_text()
