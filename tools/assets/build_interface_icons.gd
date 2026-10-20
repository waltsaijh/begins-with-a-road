extends SceneTree
## Offline monochrome controls; no SVG parsing or drawing during play.
func _initialize() -> void:
	var shapes := {
		"play": '<path d="M10 5l17 11-17 11z" fill="#e8efea"/>',
		"pause": '<path d="M8 6h6v20H8zm10 0h6v20h-6z" fill="#e8efea"/>',
		"speed_1x": '<path d="m11 6 10 10-10 10" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
		"speed_2x": '<path d="m5 7 9 9-9 9m13-18 9 9-9 9" fill="none" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
		"speed_4x": '<path d="m3 8 7 8-7 8m10-16 7 8-7 8m10-16 7 8-7 8" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
		"soldier": '<path d="M6 5h20v12c0 6-10 12-10 12S6 23 6 17z" fill="none" stroke="#e8efea" stroke-width="2.5"/><path d="M16 8v15M11 14h10" stroke="#85cbd4" stroke-width="3"/>',
		"quickfeet": '<path d="M12 4h9v13l7 6v5H7V17l5-4z" fill="none" stroke="#e8efea" stroke-width="2.5" stroke-linejoin="round"/><path d="M3 8h9M5 13h5M4 23h8" stroke="#85cbd4" stroke-width="2.5"/>',
		"heavy": '<path d="M5 25V15a11 11 0 0122 0v10l-8 4v-9h-6v9z" fill="none" stroke="#e8efea" stroke-width="2.5" stroke-linejoin="round"/><path d="M5 15h22M16 4v11" stroke="#85cbd4" stroke-width="2.5"/>'
	}
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/interface")
	for name: String in shapes:
		if "--pause-only" in OS.get_cmdline_user_args() and name != "pause": continue
		if "--speed-only" in OS.get_cmdline_user_args() and not name.begins_with("speed_"): continue
		var image := Image.new()
		var error := image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">'+shapes[name]+'</svg>')
		if error == OK: error = image.save_png("res://assets/sprites/interface/%s.png" % name)
		if error != OK:
			quit(1)
			return
	quit()
