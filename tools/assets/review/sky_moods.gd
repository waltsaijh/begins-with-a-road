extends Node3D
## Renders the Frontier with several sky moods (cloud palette + sun + ambient) to
## .godot/test-results/sky_moods/<name>.png. Run: godot --path . res://tools/assets/review/sky_moods.tscn
const OUT := "res://.godot/test-results/sky_moods/"
const MOODS := {
	"current":  {"low": Color(0.79,0.84,0.88), "high": Color(0.995,0.997,1.0), "sun": Color(1,0.941,0.847), "energy": 0.6, "ambient": Color(0.635,0.722,0.82)},
	"blue_sky": {"low": Color(0.36,0.62,0.86), "high": Color(0.97,0.98,1.0), "sun": Color(1,0.96,0.9), "energy": 0.63, "ambient": Color(0.55,0.70,0.90)},
	"golden":   {"low": Color(0.93,0.66,0.55), "high": Color(1.0,0.93,0.80), "sun": Color(1,0.80,0.58), "energy": 0.67, "ambient": Color(0.78,0.62,0.66)},
	"dusk":     {"low": Color(0.36,0.35,0.62), "high": Color(0.94,0.72,0.74), "sun": Color(1,0.72,0.62), "energy": 0.56, "ambient": Color(0.48,0.45,0.70)},
	"teal_ancient": {"low": Color(0.40,0.70,0.72), "high": Color(0.93,0.97,0.94), "sun": Color(1,0.95,0.84), "energy": 0.62, "ambient": Color(0.55,0.74,0.76)},
}
var level: Node3D
func _ready() -> void: run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	level = load("res://scenes/level.tscn").instantiate(); add_child(level)
	for i in 240:
		await get_tree().process_frame
		if not level.get_node("PortalMap").computing: break
	var manager: Node3D = level.get_node("TowerMap")
	var ids := ["sentry","ballista","mortar","crossfire","broadside","barracks"]
	var placed: Array[Vector2i] = []
	for i in ids.size():
		var definition: TowerDefinition = load("res://assets/data/towers/"+ids[i]+".tres")
		var preferred := Vector2i(2+i*4,1)
		var positions: Array[Vector2i] = []
		for z in range(-5,5):
			for x in range(24): positions.append(Vector2i(x,z))
		positions.sort_custom(func(a,b): return a.distance_squared_to(preferred) < b.distance_squared_to(preferred))
		var done := false
		for candidate in definition.preset_candidates():
			var card := BuildCard.from_parts(definition,candidate.resolve_preset())
			for point in positions:
				if placed.any(func(o): return Vector2(point-o).length() < (1.2 if ids[i]=="barracks" else 2.2)): continue
				if manager.validate_card(card,Vector3i(point.x,0,point.y),0).is_empty():
					manager.place_card(card,Vector3i(point.x,0,point.y),0); placed.append(point); done = true; break
			if done: break
	for i in 90: await get_tree().process_frame
	var sun: DirectionalLight3D = level.find_children("*","DirectionalLight3D",true,false)[0]
	var env: Environment = level.find_children("*","WorldEnvironment",true,false)[0].environment
	for name in MOODS:
		var m: Dictionary = MOODS[name]
		RenderingServer.global_shader_parameter_set("cloud_low", m.low)
		RenderingServer.global_shader_parameter_set("cloud_high", m.high)
		sun.light_color = m.sun; sun.light_energy = m.energy
		env.ambient_light_color = m.ambient; env.background_color = m.low
		for i in 4: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("SKY_MOODS_DONE")
	get_tree().quit()
