extends SceneTree
## Read-only prototype import. Never rebuild Sentry or write into the source tree.
const SCRATCH := "res://.godot/restoration_source/"
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
		var output := SCRATCH+path
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var contents := FileAccess.get_file_as_string(original).replace("res://art/",SCRATCH+"art/").replace("class_name CardData", "# Offline source data")
		FileAccess.open(output,FileAccess.WRITE).store_string(contents)
	var keep: Array = []
	for path: String in ["art/materials/skybridge_palette.gd","art/skybridge_kit.gd","art/props/skybridge_props.gd"]: keep.append(load(SCRATCH+path))
	var art: GDScript = load(SCRATCH+"art/towers/skybridge_towers.gd")
	var cards: GDScript = load(SCRATCH+"scripts/card_data.gd")
	var audio: GDScript = load(SCRATCH+"scripts/audio/synth_audio.gd")
	var synth: Node = audio.new()
	for directory: String in ["res://assets/audio/towers","res://assets/models/towers","res://assets/models/allies","res://assets/data/towers/attacks","res://assets/data/towers/ranges"]: DirAccess.make_dir_recursive_absolute(directory)
	var humanoid: GDScript = load(SCRATCH+"art/enemies/miniature_humanoid.gd")
	var friendly := Node3D.new()
	friendly.name = "FriendlySoldier"
	var parts: Dictionary = humanoid.create(friendly,"soldier")
	parts.skin.set_meta("friendly_skin",true)
	for i in parts.legs.size(): parts.legs[i].set_meta("gait_sign",1.0 if i%2 == 0 else -1.0)
	for i in parts.arms.size(): parts.arms[i].set_meta("arm_sign",1.0 if i%2 == 0 else -1.0)
	_save_scene(friendly,"res://assets/models/allies/soldier.tscn")
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
			assert(ResourceSaver.save(sound,sound_path) == OK)
			model.shot_sound = load(sound_path)
		_save_scene(model,"res://assets/models/towers/"+key+".tscn")
		var definition := TowerDefinition.new()
		definition.name_key = "tower."+key+".name"
		definition.model = load("res://assets/models/towers/"+key+".tscn")
		definition.card_price = data.price
		definition.default_damage = data.damage
		definition.attack_interval = data.interval
		definition.attack_radius = data.range
		definition.accent_color = data.color
		var icon_path := "res://assets/sprites/towers/"+key+".png"
		if ResourceLoader.exists(icon_path): definition.icon = load(icon_path)
		if kind == 5:
			definition.deployment = BarracksDeployment.new()
			definition.deployment.unit_model = load("res://assets/models/allies/soldier.tscn")
			var home_area := TowerAttackArea.new()
			home_area.offsets = TowerAttackArea.circle_cells(Vector2i(0,-1),definition.deployment.engage_radius)
			var home_path := "res://assets/data/towers/ranges/barracks.tres"
			assert(ResourceSaver.save(home_area,home_path) == OK)
			definition.attack_area = load(home_path)
		else:
			var attack := VolleyAttack.new()
			attack.color = Color("ffc46d") if kind == 1 else Color("fff3b0")
			attack.mode = VolleyAttack.Mode.SPLASH if kind == 1 else (VolleyAttack.Mode.ALL if kind == 4 else VolleyAttack.Mode.SINGLE)
			attack.mortar_visual = kind == 1
			attack.circular_range = kind in [1,4]
			var attack_path := "res://assets/data/towers/attacks/"+key+".tres"
			assert(ResourceSaver.save(attack,attack_path) == OK)
			definition.attack = load(attack_path)
			if kind in [2,3]:
				var area := TowerAttackArea.new()
				for i in range(1,5 if kind == 2 else 4):
					if kind == 2: area.offsets.append(Vector2i(0,-i))
					else:
						area.offsets.append(Vector2i(-i,0))
						area.offsets.append(Vector2i(i,0))
				var area_path := "res://assets/data/towers/ranges/"+key+".tres"
				assert(ResourceSaver.save(area,area_path) == OK)
				definition.attack_area = load(area_path)
		for variant in (1 if kind == 5 else 4):
			var preset := TilePreset.new()
			preset.prefix_key = "" # Prototype variants had no names; do not invent prefixes.
			if kind != 5:
				for cell: Vector2i in cards.PATTERNS[kind][variant]:
					# Ballista's original +X front becomes the model's -Z front.
					preset.road_offsets.append(Vector2i(cell.y,-cell.x) if kind == 2 else cell)
			var path := "res://assets/data/tile_presets/%s_%02d.tres" % [key,variant+1]
			assert(ResourceSaver.save(preset,path) == OK)
			var candidate := TilePresetCandidate.new()
			candidate.preset_path = path
			definition.tile_preset_candidates.append(candidate)
		assert(ResourceSaver.save(definition,"res://assets/data/towers/"+key+".tres") == OK)
		print("RESTORED_ASSETS:",key)
	synth.free()
	quit()

func _save_scene(model: Node3D,path: String) -> void:
	_own(model,model)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed,path) == OK)
	model.free()
func _own(node: Node,root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child,root)
