@tool
extends EditorScenePostImport
## Asset-local import preparation, never attached to a gameplay tower.
## Godot normalizes animation tracks across clips. Remove unrelated constant
## reset tracks so independent cannon banks cannot cancel another bank.
func _post_import(scene: Node) -> Object:
	var id := get_source_file().get_file().get_basename()
	for node in scene.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		player.autoplay = ""
		for clip_name in player.get_animation_list():
			if clip_name == "RESET": continue
			var animation := player.get_animation(clip_name)
			animation.loop_mode = Animation.LOOP_NONE
			var required := ""
			if id == "crossfire":
				var index := ["fire_north","fire_east","fire_south","fire_west"].find(clip_name)
				if index >= 0: required = "RecoilAssembly"+str(index)
			elif id == "broadside_airship":
				required = "PortGun" if clip_name == "fire_port" else "StarboardGun"
			if not required.is_empty():
				for track in range(animation.get_track_count()-1,-1,-1):
					if not required in str(animation.track_get_path(track)): animation.remove_track(track)
	return scene
