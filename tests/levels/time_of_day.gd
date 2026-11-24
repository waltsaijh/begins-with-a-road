extends SceneTree
## Four fixed time-of-day presets: the level's Sun (colour, energy, angle), a
## duplicated Environment (background, ambient) and the cloud shader globals take
## each preset; shadows, the shared environment and the warmup key stay unchanged;
## leaving restores default clouds; noon equals the authored look; the real renders
## differ. Screenshots in .godot/test-results/levels/time_of_day/.
const Artifacts = preload("res://tests/fixtures/test_artifacts.gd")
const Signatures = preload("res://scripts/enemies/rendering/enemy_render_signatures.gd")
const SharedEnvironment = preload("res://assets/data/rendering/level_environment.tres")
const NAMES := ["morning", "noon", "dusk", "night"]
var failures := 0
var checks := 0

func _initialize() -> void:
	verify.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func open(preset: TimeOfDayPreset) -> Node:
	var definition := (load("res://assets/data/levels/frontier.tres") as LevelDefinition).duplicate()
	definition.time_of_day = preset
	var scene: Node = load("res://scenes/level.tscn").instantiate()
	scene.level = definition
	root.add_child(scene)
	current_scene = scene
	for i in 30: await process_frame
	return scene

func close(scene: Node) -> void:
	root.remove_child(scene)
	scene.free()
	await process_frame

## Mean colour of the map area only (centre of the screen, away from the HUD).
func mean(image: Image) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for y in range(160, 440, 4):
		for x in range(360, 800, 4):
			var c := image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			count += 1
	return sum / count

func verify() -> void:
	root.size = Vector2i(1152, 648)
	var headless := DisplayServer.get_name() == "headless"
	var shots := {}
	var defaults := TimeOfDayPreset.default_clouds()
	var shared_before := Signatures.resource_key(SharedEnvironment)
	var warm_key := Signatures.environment_key(SharedEnvironment)
	var baseline := await open(null)
	var authored := baseline.get_node("Sun") as DirectionalLight3D
	var shadow := [authored.shadow_enabled, authored.shadow_opacity, authored.shadow_blur, authored.directional_shadow_mode]
	var authored_state := [authored.light_color, authored.light_energy, authored.rotation_degrees]
	if not headless: shots["none"] = mean(root.get_texture().get_image())
	await close(baseline)
	for name in NAMES:
		var preset := load("res://assets/data/rendering/time_of_day/%s.tres" % name) as TimeOfDayPreset
		check(preset != null, name+" preset loads")
		var scene := await open(preset)
		var sun := scene.get_node("Sun") as DirectionalLight3D
		check(sun.light_color == preset.sun_color and is_equal_approx(sun.light_energy, preset.sun_energy), name+" sun colour/energy")
		check(sun.rotation_degrees.is_equal_approx(preset.sun_rotation_degrees), name+" sun angle")
		check([sun.shadow_enabled, sun.shadow_opacity, sun.shadow_blur, sun.directional_shadow_mode] == shadow, name+" keeps the authored shadow settings")
		var world := scene.get_node("WorldEnvironment") as WorldEnvironment
		check(world.environment != SharedEnvironment and world.environment.background_color == preset.background_color and world.environment.ambient_light_color == preset.ambient_color and is_equal_approx(world.environment.ambient_light_energy, preset.ambient_energy), name+" environment duplicated and recoloured")
		check(Signatures.environment_key(world.environment) == warm_key, name+" keeps the Boot warmup environment key")
		check(TimeOfDayPreset.current_clouds == ([preset.cloud_low, preset.cloud_high] as Array[Color]), name+" cloud globals applied")
		var timeline := scene.get_node("LevelHUD/Header/WaveTimeline") as WaveTimeline
		var amount := scene.get_node("LevelHUD/Header/Balance/Amount") as Label
		check(scene.get_node_or_null("HudBackdrop") == null, name+" has no top-bar backdrop")
		if preset.hud_light_text:
			check(timeline.label_color == HudTextPalette.TEXT and timeline.current_color == HudTextPalette.TEXT and amount.get_theme_color("font_color") == HudTextPalette.TEXT, name+" switches the top HUD to light text")
			check((scene.get_node("RunStatus/Integrity") as Button).get_theme_color("icon_normal_color") == HudTextPalette.INTEGRITY_ICON, name+" brightens the integrity icon")
		else:
			check(timeline.label_color == Color("244c52") and timeline.current_color == Color("202c2d"), name+" keeps the authored dark HUD text")
		if name == "noon":
			check(preset.cloud_low == defaults[0] and preset.cloud_high == defaults[1] and preset.background_color == SharedEnvironment.background_color and preset.ambient_color == SharedEnvironment.ambient_light_color and is_equal_approx(preset.ambient_energy, SharedEnvironment.ambient_light_energy), "Noon clouds/environment equal the project defaults")
			check(sun.light_color == authored_state[0] and is_equal_approx(sun.light_energy, authored_state[1]) and sun.rotation_degrees.is_equal_approx(authored_state[2]), "Noon equals the Sun authored in main.tscn")
		if not headless:
			var image := root.get_texture().get_image()
			shots[name] = mean(image)
			image.save_png(Artifacts.path("levels/time_of_day/%s.png" % name))
		await close(scene)
		check(TimeOfDayPreset.current_clouds == defaults, name+" leaving restores default clouds")
	check(Signatures.resource_key(SharedEnvironment) == shared_before, "Shared level_environment.tres never mutated")
	# Overlapping scene swap: the earlier level exiting must not reset the newer one.
	var night := load("res://assets/data/rendering/time_of_day/night.tres") as TimeOfDayPreset
	var first := await open(load("res://assets/data/rendering/time_of_day/dusk.tres"))
	var second := await open(night)
	await close(first)
	check(TimeOfDayPreset.current_clouds == ([night.cloud_low, night.cloud_high] as Array[Color]), "Stale level exit keeps the newer level's clouds")
	await close(second)
	check(TimeOfDayPreset.current_clouds == defaults, "Last level exit restores default clouds")
	if not headless:
		check((shots["none"]-shots["noon"]).length() < 0.005, "Noon renders like an unset level")
		for i in NAMES.size():
			for j in range(i+1, NAMES.size()):
				var d: float = (shots[NAMES[i]]-shots[NAMES[j]]).length()
				check(d > 0.03, "%s and %s render differently (%.3f)" % [NAMES[i], NAMES[j], d])
		print("TIME_OF_DAY_MEANS ", shots)
	print("TIME_OF_DAY %s %d/%d" % ["PASS" if failures == 0 else "FAIL", checks-failures, checks])
	quit(1 if failures else 0)
