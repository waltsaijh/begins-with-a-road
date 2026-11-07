extends SceneTree
## Bake only the legacy ram art. No runtime legacy scripts or project dependency.
func _initialize() -> void:
	var source := "D:/games/card-tower-defense"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prototype="): source = arg.trim_prefix("--prototype=")
	var scratch := "res://.godot/phase5/boss_source/"
	for file: String in ["enemies/skybridge_pawns.gd","enemies/miniature_humanoid.gd","skybridge_kit.gd","materials/skybridge_palette.gd"]:
		var input := source+"/art/"+file
		if not FileAccess.file_exists(input):
			push_error("Missing boss source: "+input)
			quit(1)
			return
		var target := scratch+file
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var handle := FileAccess.open(target,FileAccess.WRITE)
		handle.store_string(FileAccess.get_file_as_string(input).replace("res://art/",scratch))
		handle.close()
	var generator: GDScript = load(scratch+"enemies/skybridge_pawns.gd")
	if generator == null or not generator.can_instantiate():
		quit(1)
		return
	var model := Node3D.new()
	model.name = "Ravager"
	model.set_meta("source","card-tower-defense/art/enemies/skybridge_pawns.gd: Siege Behemoth")
	var parts: Dictionary = generator.create(model,"siege_behemoth")
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	var library := AnimationLibrary.new()
	var walk := Animation.new()
	walk.length = 1.6
	walk.loop_mode = Animation.LOOP_LINEAR
	for i in parts.legs.size():
		var leg: Node3D = parts.legs[i]
		var track := walk.add_track(Animation.TYPE_VALUE)
		walk.track_set_path(track,NodePath(str(model.get_path_to(leg))+":rotation:x"))
		for j in 5: walk.track_insert_key(track,j*0.4,sin(j*PI/2)*(0.25 if i%2==0 else -0.25))
	library.add_animation("Walk",walk)
	player.add_animation_library("",library)
	for child in model.find_children("*","",true,false): child.owner = model
	var scene := PackedScene.new()
	scene.pack(model)
	var error := ResourceSaver.save(scene,"res://assets/models/enemies/ravager.tscn")
	model.free()
	print("BOSS_MODEL ",error_string(error))
	quit(0 if error == OK else 1)
