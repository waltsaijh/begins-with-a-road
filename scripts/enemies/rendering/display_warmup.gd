extends Node
## Retain prepared resources across scenes; no wave, routes or gameplay state.
const Signatures = preload("res://scripts/enemies/rendering/enemy_render_signatures.gd")
const Warmup = preload("res://scripts/enemies/rendering/enemy_render_warmup.gd")
var _prepared := {}
var _retained: Array[Troop] = []
var _retained_resources: Array[Resource] = []
var _busy := false

func retain_resources(resources: Array[Resource]) -> void:
	for resource in resources:
		if not _retained_resources.has(resource): _retained_resources.append(resource)

func context_key(renderer: Node3D) -> String:
	var viewport := renderer.get_viewport()
	var environment := renderer.get_world_3d().environment
	var lights: Array[String] = []
	for light: Light3D in viewport.find_children("*", "Light3D", true, false):
		if light.get_world_3d() != renderer.get_world_3d() or not light.is_visible_in_tree(): continue
		var key := light.get_class()+":"+str(light.shadow_enabled)+":"+str(light.light_cull_mask)
		if light is DirectionalLight3D: key += ":"+str(light.directional_shadow_mode)+":"+str(light.directional_shadow_blend_splits)
		lights.append(key)
	lights.sort()
	return str(viewport.get_instance_id())+":"+str(viewport.msaa_3d)+":"+Signatures.resource_key(environment)+":"+str(lights)

func representatives(profiles: Array[Troop], renderer: Node3D) -> Array[Troop]:
	var known: Dictionary = _prepared.get(context_key(renderer), {}).duplicate()
	var selected: Array[Troop] = []
	for profile in profiles:
		var keys := Signatures.profile_keys(profile)
		if keys.all(func(key): return known.has(key)): continue
		selected.append(profile)
		for key in keys: known[key] = true
	return selected

func prepare(renderer: MultiMeshInstance3D, profiles: Array[Troop], completed: Callable) -> int:
	if _busy: return ERR_BUSY
	_busy = true
	var context := context_key(renderer)
	if not _prepared.has(context): _prepared[context] = {}
	var worker := Warmup.new()
	add_child(worker)
	var error: int = await worker.prepare(renderer, profiles, func(profile: Troop):
		for key in Signatures.profile_keys(profile): _prepared[context][key] = true
		if not _retained.has(profile): _retained.append(profile)
		completed.call())
	worker.queue_free()
	_busy = false
	return error
