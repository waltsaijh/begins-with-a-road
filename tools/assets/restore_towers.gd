extends SceneTree
## Generate candidates for review. Resource links use their eventual project paths.

var output_root := "res://.godot/tower-restoration/%s-%s/" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
var scratch := output_root + "source/"
var save_failed := false
func _initialize() -> void:
	var source := "D:/games/card-tower-defense"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prototype="): source = arg.trim_prefix("--prototype=")
	for path: String in ["art/towers/skybridge_towers.gd","art/props/skybridge_props.gd","art/skybridge_kit.gd","art/materials/skybridge_palette.gd","art/enemies/miniature_humanoid.gd","scripts/audio/synth_audio.gd","scripts/card_data.gd"]:
		var original := source.path_join(path)
		if not FileAccess.file_exists(original):
			push_error("Missing source: "+original)
			quit(1)
			return
		var output := scratch+path
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var contents := FileAccess.get_file_as_string(original).replace("res://art/",scratch+"art/").replace("class_name CardData", "# Offline source data")
		FileAccess.open(output,FileAccess.WRITE).store_string(contents)
	var keep: Array = []
	for path: String in ["art/materials/skybridge_palette.gd","art/skybridge_kit.gd","art/props/skybridge_props.gd"]: keep.append(load(scratch+path))
	var art: GDScript = load(scratch+"art/towers/skybridge_towers.gd")
	var cards: GDScript = load(scratch+"scripts/card_data.gd")
	var audio: GDScript = load(scratch+"scripts/audio/synth_audio.gd")
	var synth: Node = audio.new()
	var humanoid: GDScript = load(scratch+"art/enemies/miniature_humanoid.gd")
	var friendly := Node3D.new()
	friendly.name = "FriendlySoldier"
	var parts: Dictionary = humanoid.create(friendly,"soldier")
	parts.skin.set_meta("friendly_skin",true)
	for i in parts.legs.size(): parts.legs[i].set_meta("gait_sign",1.0 if i%2 == 0 else -1.0)
	for i in parts.arms.size(): parts.arms[i].set_meta("arm_sign",1.0 if i%2 == 0 else -1.0)
	var soldier := _save_scene(friendly,"res://assets/models/allies/soldier.tscn")
	for kind in range(1,6):
		var key: String = cards.TYPE_KEYS[kind]
		var data: Dictionary = cards.TOWER_TYPES[kind]
		var model: Node3D = art.create(kind)
		var muzzle_paths: Array[NodePath] = []
		for muzzle: Node3D in model.get_meta("muzzles"): muzzle_paths.append(model.get_path_to(muzzle))
		model.set_meta("muzzle_paths",muzzle_paths)
		# Node references in generator metadata are replaced by scene paths.
		for meta in ["recoil","muzzles"]: model.remove_meta(meta)
		model.set_script(load("res://scripts/towers/restored_tower_visual.gd"))
		model.kind = kind
		if kind < 5:
			var sound: AudioStreamWAV = synth._synthesize(kind)
			var sound_path := "res://assets/audio/towers/"+key+".tres"
			_save_candidate(sound,sound_path)
			model.shot_sound = sound
		var tower_model := _save_scene(model,"res://assets/models/towers/"+key+".tscn")
		var definition := TowerDefinition.new()
		definition.name_key = "tower."+key+".name"
		definition.model = tower_model
		definition.card_price = data.price
		definition.default_damage = data.damage
		definition.attack_interval = data.interval
		definition.attack_radius = data.range
		definition.accent_color = data.color
		var icon_path := "res://assets/sprites/towers/"+key+".png"
		if ResourceLoader.exists(icon_path): definition.icon = load(icon_path)
		if kind == 5:
			definition.deployment = BarracksDeployment.new()
			definition.deployment.unit_model = soldier
			var home_area := TowerAttackArea.new()
			home_area.offsets = TowerAttackArea.circle_cells(Vector2i(0,-1),definition.deployment.engage_radius)
			var home_path := "res://assets/data/towers/ranges/barracks.tres"
			_save_candidate(home_area,home_path)
			definition.attack_area = home_area
		else:
			var attack := VolleyAttack.new()
			attack.color = Color("ffc46d") if kind == 1 else Color("fff3b0")
			attack.mode = VolleyAttack.Mode.SPLASH if kind == 1 else (VolleyAttack.Mode.ALL if kind == 4 else VolleyAttack.Mode.SINGLE)
			attack.mortar_visual = kind == 1
			attack.circular_range = kind in [1,4]
			var attack_path := "res://assets/data/towers/attacks/"+key+".tres"
			_save_candidate(attack,attack_path)
			definition.attack = attack
			if kind in [2,3]:
				var area := TowerAttackArea.new()
				for i in range(1,5 if kind == 2 else 4):
					if kind == 2: area.offsets.append(Vector2i(0,-i))
					else:
						area.offsets.append(Vector2i(-i,0))
						area.offsets.append(Vector2i(i,0))
				var area_path := "res://assets/data/towers/ranges/"+key+".tres"
				_save_candidate(area,area_path)
				definition.attack_area = area
		for variant in (1 if kind == 5 else 4):
			var preset := TilePreset.new()
			preset.prefix_key = "" # Prototype variants had no names; do not invent prefixes.
			if kind != 5:
				for cell: Vector2i in cards.PATTERNS[kind][variant]:
					# Ballista's original +X front becomes the model's -Z front.
					preset.road_offsets.append(Vector2i(cell.y,-cell.x) if kind == 2 else cell)
			var path := "res://assets/data/tile_presets/%s_%02d.tres" % [key,variant+1]
			_save_candidate(preset,path)
			var candidate := TilePresetCandidate.new()
			candidate.preset_path = path
			definition.tile_preset_candidates.append(candidate)
		_save_candidate(definition,"res://assets/data/towers/"+key+".tres")
	synth.free()
	print("Restoration candidates: ", output_root)
	quit(1 if save_failed else 0)

func _save_candidate(resource: Resource, project_path: String) -> void:
	var destination := output_root.path_join(project_path.trim_prefix("res://"))
	var err := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if err == OK: err = ResourceSaver.save(resource, destination)
	if err != OK:
		push_error("Cannot save %s: %s" % [destination, error_string(err)])
		save_failed = true
	# Parent candidates keep canonical dependencies without loading or replacing live assets.
	resource.set_path_cache(project_path)

func _save_scene(model: Node3D,path: String) -> PackedScene:
	_own(model,model)
	var packed := PackedScene.new()
	if packed.pack(model) == OK:
		_save_candidate(packed,path)
	else:
		push_error("Cannot pack " + path)
		save_failed = true
	model.free()
	return packed
func _own(node: Node,root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child,root)
