extends SceneTree
## Runtime export: resolves inherited defaults, UID presets and subresources.
var rows: Array = []
var seen := {}
func _initialize() -> void:
	var destination := "res://docs/balance/phase5_parameters.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): destination = arg.trim_prefix("--output=")
	for directory in ["towers", "troops", "traffic", "relics"]:
		walk("res://assets/data/"+directory)
	visit(load("res://assets/data/levels/frontier.tres"), "frontier")
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	for path in ["CardPlacement", "CardPlacement/Shop", "EnemyWave"]:
		var node: Node = scene.get_node(path)
		for property in node.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR:
				var value: Variant = node.get(property.name)
				if value is int or value is float or value is bool:
					rows.append({"id":"scene."+path+"."+property.name,"original_value":encode(value),"source":"res://scenes/level.tscn inherited from scenes/main.tscn", "runtime_usage":str(node.get_script().resource_path),"dependencies":[],"domain":"economy/progression","unit_meaning":property.name,"design_role":"scene override or script default"})
	scene.free()
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"engine":Engine.get_version_info().string,"parameters":rows},"\t"))
	print("PARAMETER_EXPORT ", rows.size(), " -> ", destination)
	quit()
func walk(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".tres"): visit(load(path+"/"+file),path+"/"+file)
	for dir in DirAccess.get_directories_at(path): walk(path+"/"+dir)
func visit(resource: Resource, identifier: String) -> void:
	if resource == null or resource.get_script() == null: return
	if seen.has(resource): return
	seen[resource] = true
	var source := resource.resource_path
	var script: String = resource.get_script().resource_path
	for property in resource.get_property_list():
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
		if not property.usage & PROPERTY_USAGE_STORAGE: continue
		var value: Variant = resource.get(property.name)
		var id: String = identifier+"."+property.name
		if value is Resource: visit(value,id)
		if value is Array:
			for i in value.size():
				if value[i] is Resource: visit(value[i],id+"[%d]" % i)
		rows.append({"id":id,"original_value":encode(value),"source":source,"runtime_usage":script,"dependencies":[value.resource_path] if value is Resource else [],"domain":domain(script,property.name),"unit_meaning":meaning(property.name),"design_role":resource.get_class()+" / "+identifier.get_file()})
func encode(value: Variant) -> Variant:
	if value is Resource: return value.resource_path
	if value is Array:
		var result := []
		for entry in value: result.append(encode(entry))
		return result
	if value is float and not is_finite(value): return str(value)
	if typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME,TYPE_DICTIONARY]: return value
	return str(value)
func domain(script: String, key: String) -> String:
	if key.contains("price") or key.contains("reward"): return "economy"
	if key.contains("route") or key.contains("weight") or key.contains("threshold"): return "routing"
	if script.contains("wave") or script.contains("level") or script.contains("act_"): return "progression"
	return "combat/content"
func meaning(key: String) -> String:
	if key.contains("price") or key.contains("reward"): return "Gold"
	if key.contains("tick"): return "quarter-second ticks"
	if key.contains("interval") or key.contains("duration") or key.contains("seconds"): return "simulation seconds unless cohort ticks"
	if key.contains("health") or key.contains("shield") or key.contains("damage") or key.contains("heal_amount"): return "HP / damage; multiplier when named multiplier"
	if key.contains("radius") or key.contains("offset"): return "map cells (model offsets in world units)"
	return key+"; see runtime_usage export declaration"
