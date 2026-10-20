extends SceneTree
func _initialize() -> void:
	var art := {
		"card_back": '<svg xmlns="http://www.w3.org/2000/svg" width="144" height="208" viewBox="0 0 144 208"><rect x="1.5" y="1.5" width="141" height="205" rx="8" fill="#203b43" stroke="#b9d9d8" stroke-width="3"/><rect x="9" y="9" width="126" height="190" rx="4" fill="none" stroke="#698c91"/><path d="M15 28L72 12l57 16M15 180l57 16 57-16M20 48l104 112M20 80l104 112M20 16l104 112M20 160L124 48M20 192L124 80M20 128L124 16" fill="none" stroke="#42616a" stroke-width="1"/><path d="M72 59l37 45-37 45-37-45z" fill="#294a53" stroke="#85cbd4" stroke-width="2"/><path d="M18 18h13M18 18v13M126 18h-13M126 18v13M18 190h13M18 190v-13M126 190h-13M126 190v-13" fill="none" stroke="#d5e8de" stroke-width="2"/></svg>',
		"shop_icon": '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="#f1ebd5" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M12 28v25h40V28M10 27l6-15h32l6 15M9 27c0 9 12 9 12 0 0 9 11 9 11 0 0 9 11 9 11 0 0 9 12 9 12 0M25 53V38h14v15M18 8h28"/><path d="M21 27l3-15M43 27l-3-15M32 27V12" stroke="#85cbd4"/></g></svg>',
		"reroll_icon": '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="#f1ebd5" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><path d="M48 24A18 18 0 0 0 17 19l-5 7M12 14v12h12M16 40a18 18 0 0 0 31 5l5-7M52 50V38H40"/></g></svg>',
		"gold": '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path d="M16 2L28 9v14l-12 7L4 23V9z" fill="#d5a43b" stroke="#765421" stroke-width="2"/><path d="M16 4L26 10v12l-10 6L6 22V10z" fill="#f1c65c"/><path d="M16 4L26 10H6z" fill="#ffe8a0"/></svg>'
	}
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/cards")
	for name: String in art:
		if not OS.get_cmdline_user_args().is_empty() and not name in OS.get_cmdline_user_args(): continue
		var image := Image.new()
		var error := image.load_svg_from_string(art[name])
		if error == OK:
			error = image.save_png("res://assets/sprites/cards/%s.png" % name)
		if error != OK:
			quit(1)
			return
	quit()
