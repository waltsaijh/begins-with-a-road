@tool
class_name TimeOfDayPreset
extends Resource
## One fixed time of day per level: the sun's colour, energy and angle, the
## Environment's background and ambient light, and the two cloud shader globals.
## Only colours, energies and the angle change; light type, shadows and material
## flags stay as authored, so no shader variants or warmup combinations are added.
const CLOUD_LOW := &"cloud_low"
const CLOUD_HIGH := &"cloud_high"
@export_group("Sun")
@export var sun_color := Color(1, 0.9411765, 0.8470588)
@export_range(0.0, 4.0, 0.01) var sun_energy := 0.6
## Euler degrees of the DirectionalLight3D: X is elevation (more negative is
## higher, -90 straight down), Y is the azimuth the light comes from.
@export var sun_rotation_degrees := Vector3(-55, -25, 0)
@export_group("Environment")
@export var background_color := Color(0.9, 0.925, 0.94)
@export var ambient_color := Color(0.6352941, 0.7215686, 0.8196078)
@export_range(0.0, 4.0, 0.01) var ambient_energy := 0.23
@export_group("Clouds")
## Gaps and thin cloud (shader global cloud_low); also tints pillar bottoms.
@export var cloud_low := Color(0.79, 0.84, 0.88)
## Dense cloud tops (shader global cloud_high); also the distant-island haze.
@export var cloud_high := Color(0.995, 0.997, 1.0)
@export_group("HUD")
## Dark clouds: switch the transparent top HUD row to light text and icons
## (HudTextPalette). Daytime presets keep the authored dark-teal text.
@export var hud_light_text := false

@export_group("Towers")
## Light the towers' wall torches and dock lamps (imported_tower_visual.gd).
@export var tower_lights := false
## Stars in the cloud gaps (cloud_layer.gdshader, global night_sky).
@export var stars := false
## Whether the active preset wants tower lamps; read by towers when they are built.
static var lights_on := false

## Applies to the level's Sun and WorldEnvironment. The Environment is duplicated
## so the shared level_environment.tres used by Boot warmup is never mutated.
func apply(sun: DirectionalLight3D, world: WorldEnvironment) -> void:
	lights_on = tower_lights
	RenderingServer.global_shader_parameter_set(&"night_sky", 1.0 if stars else 0.0)
	if sun != null:
		sun.light_color = sun_color
		sun.light_energy = sun_energy
		sun.rotation_degrees = sun_rotation_degrees
	if world != null and world.environment != null:
		var environment := world.environment.duplicate() as Environment
		environment.background_color = background_color
		environment.ambient_light_color = ambient_color
		environment.ambient_light_energy = ambient_energy
		world.environment = environment
	set_clouds(cloud_low, cloud_high)

## Cloud colours are process-wide globals. Scene swaps may add the next level
## before the previous one exits, so only the latest owner restores defaults.
static var _owner_id := 0
## Last values sent (the RenderingServer getter is editor-only).
static var current_clouds: Array[Color] = []

static func claim(owner: Object, preset: TimeOfDayPreset, sun: DirectionalLight3D, world: WorldEnvironment) -> void:
	_owner_id = owner.get_instance_id()
	if preset != null: preset.apply(sun, world)
	else:
		lights_on = false
		RenderingServer.global_shader_parameter_set(&"night_sky", 0.0)
		reset_clouds()

static func release(owner: Object) -> void:
	if _owner_id != owner.get_instance_id(): return
	_owner_id = 0
	lights_on = false
	RenderingServer.global_shader_parameter_set(&"night_sky", 0.0)
	reset_clouds()

static func set_clouds(low: Color, high: Color) -> void:
	current_clouds = [low, high]
	RenderingServer.global_shader_parameter_set(CLOUD_LOW, low)
	RenderingServer.global_shader_parameter_set(CLOUD_HIGH, high)

## Project Settings > Shader Globals values, used by menus and map previews.
static func default_clouds() -> Array[Color]:
	return [ProjectSettings.get_setting("shader_globals/cloud_low").value, ProjectSettings.get_setting("shader_globals/cloud_high").value]

static func reset_clouds() -> void:
	var defaults := default_clouds()
	set_clouds(defaults[0], defaults[1])
