extends SceneTree
## Small neutral status art; production uses the PNG, which may be replaced freely.
func _initialize() -> void:
	var image := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><defs><linearGradient id="ice" x2="0" y2="1"><stop stop-color="#c4efff"/><stop offset=".4" stop-color="#b1e2f7"/><stop offset=".65" stop-color="#498eae"/><stop offset="1" stop-color="#3781a2"/></linearGradient></defs><path fill="none" stroke="url(#ice)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" d="M16 3v26M4.75 9.5l22.5 13M4.75 22.5l22.5-13M12 6l4 4 4-4M12 26l4-4 4 4M5.5 14l5.5-1.5L9.5 7M22.5 25l-1.5-5.5 5.5-1.5M5.5 18l5.5 1.5L9.5 25M22.5 7L21 12.5l5.5 1.5"/></svg>'
	var error := image.load_svg_from_string(svg)
	if error == OK:
		DirAccess.make_dir_recursive_absolute("res://assets/sprites/effects")
	error = image.save_png("res://assets/sprites/effects/slowness.png")
	quit(0 if error == OK else 1)
