extends Node3D
const Batch = preload("res://scripts/enemies/rendering/enemy_multimesh.gd")
const Enemy = preload("res://scenes/enemies/enemy.tscn")
const Tile = preload("res://scripts/map/tile/tile_parameters.gd")
var failures := 0

func _ready() -> void:
	verify.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func import_model(directory: String) -> PackedScene:
	# Real glTF input: one blue triangle and a one-second translation walk clip.
	var data := PackedFloat32Array([-0.3, 0, 0, 0.3, 0, 0, 0, 1, 0,
		0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0.2, 0]).to_byte_array()
	var gltf := {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
		"nodes": [{"name": "ImportedTroop", "children": [1]}, {"name": "Body", "mesh": 0}],
		"buffers": [{"byteLength": data.size(), "uri": "data:application/octet-stream;base64,"+Marshalls.raw_to_base64(data)}],
		"bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 36}, {"buffer": 0, "byteOffset": 36, "byteLength": 36},
			{"buffer": 0, "byteOffset": 72, "byteLength": 8}, {"buffer": 0, "byteOffset": 80, "byteLength": 24}],
		"accessors": [{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [-0.3, 0, 0], "max": [0.3, 1, 0]},
			{"bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3"},
			{"bufferView": 2, "componentType": 5126, "count": 2, "type": "SCALAR", "min": [0], "max": [1]},
			{"bufferView": 3, "componentType": 5126, "count": 2, "type": "VEC3"}],
		"materials": [{"doubleSided": true, "pbrMetallicRoughness": {"baseColorFactor": [0.2, 0.65, 0.95, 1], "metallicFactor": 0}}],
		"meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "material": 0}]}],
		"animations": [{"name": "walk", "samplers": [{"input": 2, "output": 3}],
			"channels": [{"sampler": 0, "target": {"node": 1, "path": "translation"}}]}]}
	var source := directory.path_join("model.gltf")
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_string(JSON.stringify(gltf))
	file.close()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	check(document.append_from_file(source, state) == OK, "glTF file could not be imported")
	var root := document.generate_scene(state)
	var model := PackedScene.new()
	check(root != null and model.pack(root) == OK, "Imported scene could not be packed")
	root.free()
	check(ResourceSaver.save(model, directory.path_join("model.tscn")) == OK, "Imported model scene could not be saved")
	return model

func verify() -> void:
	var profiles := TroopCatalog.all()
	check(profiles.size() == 3 and profiles[0] == TroopCatalog.default_troop(), "Catalog did not discover/sort shared troop assets")
	var soldier := TroopCatalog.find("soldier")
	var quick := TroopCatalog.find("quickfeet")
	var heavy := TroopCatalog.find("heavy")
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	check(soldier.localized_name() == "Soldier", "English troop name was not imported")
	TranslationServer.set_locale("zh_TW")
	check(soldier.localized_name() == "士兵", "Chinese troop name was not imported")
	TranslationServer.set_locale(locale)
	var tile := Tile.new()
	tile.threat = 8
	check(soldier.evaluation(tile) == 1 and quick.evaluation(tile) == 8 and heavy.evaluation(tile) == -8, "Serialized path costs changed the original troop evaluations")
	check(soldier.route_selection == Troop.RouteSelection.UNIFORM and quick.route_selection == Troop.RouteSelection.SOFTMAX and heavy.route_selection == Troop.RouteSelection.SOFTMAX, "Serialized route selection changed")
	var heavy_path := "user://heavy_roundtrip_%d.tres" % Time.get_ticks_usec()
	check(ResourceSaver.save(heavy.duplicate(true), heavy_path) == OK, "Heavy resource could not be saved")
	var heavy_copy := ResourceLoader.load(heavy_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Troop
	check(heavy_copy != null and heavy_copy.max_health == heavy.max_health and heavy_copy.max_shield == heavy.max_shield and heavy_copy.speed_multiplier == heavy.speed_multiplier, "Heavy health/shield/speed changed during serialization")
	DirAccess.remove_absolute(heavy_path)
	for profile in profiles:
		check(profile.configuration_error().is_empty() and profile.icon != null and profile.model != null, "Troop asset lost its icon/model or is invalid")
	var authored: LevelDefinition = load("res://assets/data/levels/frontier.tres")
	for act in authored.acts:
		for wave in act.waves:
			for group in wave.groups:
				check(group.troop == TroopCatalog.find(group.troop.troop_name) and not group.troop_path.is_empty(), "Level still contains embedded troop classes/overrides")
	var directory := "user://troop_resources_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var model := import_model(directory)
	var custom := Troop.new()
	custom.troop_name = "imported_test"
	custom.icon = soldier.icon
	custom.model = model
	custom.model_scale = Vector3.ONE*0.8
	custom.model_offset = Vector3(0.1, 0.05, -0.1)
	custom.model_rotation_degrees.y = 20
	custom.head_height = 1.4
	custom.path_base_cost = 2
	custom.threat_weight = -0.5
	var changed := [0]
	custom.changed.connect(func(): changed[0] += 1)
	custom.threat_weight = -1
	check(changed[0] == 1 and custom.evaluation(tile) == -6, "Editable path weights did not notify/influence evaluation")
	var path := directory.path_join("custom.tres")
	check(ResourceSaver.save(custom, path) == OK, "New troop could not be saved")
	check(TroopCatalog.all(directory).size() == 1, "New troop file was not discovered")
	var shared_id := TroopCatalog.load_path(path).get_instance_id()
	check(TroopCatalog.load_path(path).get_instance_id() == shared_id, "Catalog did not retain shared resource identity")
	var saved: Troop = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(saved.model != null and saved.icon == soldier.icon and saved.threat_weight == -1 and saved.model_offset == custom.model_offset, "Troop model/icon/weights did not survive saving")
	var inherited_path := directory.path_join("inherited.tscn")
	var inherited_file := FileAccess.open(inherited_path, FileAccess.WRITE)
	inherited_file.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="%s" id="1"]\n[node name="InheritedTroop" instance=ExtResource("1")]\n' % directory.path_join("model.tscn"))
	inherited_file.close()
	var inherited_profile := saved.duplicate() as Troop
	inherited_profile.model = load(inherited_path)
	check(inherited_profile.configuration_error().is_empty(), "Inherited imported model was rejected")
	var group := WaveSpawnGroup.new()
	group.troop = TroopCatalog.load_path(path)
	var wave := WaveDefinition.new()
	wave.groups = [group]
	var wave_path := directory.path_join("wave.tres")
	check(ResourceSaver.save(wave, wave_path) == OK, "Wave troop reference could not be saved")
	var batch := Batch.new()
	add_child(batch)
	batch.set_process(false)
	var units: Array[Node3D] = []
	for i in 3:
		var enemy: Node3D = Enemy.instantiate()
		enemy.troop = saved if i == 1 else soldier
		add_child(enemy)
		enemy.follow(i, {}, PackedVector3Array([Vector3(i*2, 0, 0), Vector3(i*2, 0, -20)]))
		enemy.set_process(false)
		batch.add_enemy(enemy)
		units.append(enemy)
	var appearance: RefCounted = batch._appearances[1]
	check(batch._appearances[0].batched and not appearance.batched and appearance.instance != null, "Imported scene did not coexist with the batched grunt")
	var imported_mesh: MeshInstance3D = appearance.instance.find_children("*", "MeshInstance3D", true, false)[0]
	check(imported_mesh.mesh.surface_get_material(0) is StandardMaterial3D and imported_mesh.material_override == null, "Imported materials were replaced by the baked walking shader")
	check(appearance.animation != null, "Imported walk clip was not found")
	units[1]._process(0.25)
	batch._process(0.25)
	check(appearance.animation.current_animation_position > 0.1, "Imported walk animation did not advance")
	check(appearance.instance.global_position.distance_to(units[1].global_position) > 0.05 and batch.head_positions[1].y > 1, "Imported model adjustment/head position was not applied")
	check(batch.multimesh.visible_instance_count == 2, "Imported enemy also drew a duplicate grunt")
	var moved_appearance: RefCounted = batch._appearances[2]
	units[1].free()
	check(batch._appearances[1] == moved_appearance and batch.units[1] == units[2], "Removing an imported model broke dense slot compaction")
	for i in [0, 2]: units[i].free()
	check(batch.units.is_empty() and batch._appearances.is_empty(), "Model instances remained after all enemies were removed")
	batch.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)
	check(TroopCatalog.all(directory).is_empty() and group.troop == null and not group.configuration_error().is_empty(), "Deleted troop stayed in the catalog or cached group")
	var reloaded: WaveDefinition = ResourceLoader.load(wave_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(reloaded != null and reloaded.groups[0].troop == null and not reloaded.configuration_error().is_empty(), "Deleting a troop made its wave file unloadable")
	for file in ["wave.tres", "inherited.tscn", "model.tscn", "model.gltf"]: DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("TROOP_RESOURCES_CHECK:"+JSON.stringify({"failures": failures, "catalog_discovery": true, "editable_costs": true, "save_reload_delete": true, "level_references": true, "imported_model_animation": true, "mixed_renderers": true, "icons": true, "authored_heavy_stats": true}))
	get_tree().quit(1 if failures else 0)
