extends RefCounted
## An authored GLB gesture temporarily occupies this enemy's walking draw slot.
const RELEASE := 31.0 / 48.0
var owner: Node3D
var source: PackedScene
var clip: StringName
var heal: HealAbility
var sabotage: SabotageAbility
var model: Node3D
var player: AnimationPlayer
var crystal_material: StandardMaterial3D
var flask: MeshInstance3D
var airborne: MeshInstance3D
var launch := Transform3D.IDENTITY
var active := false

func _init(enemy: Node3D, renderer: Node3D, name_of_clip: StringName) -> void:
	owner = renderer
	source = enemy.troop.model
	clip = name_of_clip
	if clip == &"Cast": heal = enemy.ability(HealAbility)
	if clip == &"Throw": sabotage = enemy.ability(SabotageAbility)

func prepare() -> void:
	model = source.instantiate() as Node3D
	owner.add_child(model)
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(clip)
	if clip == &"Cast":
		var gem := model.find_child("*StaffCrystal*", true, false) as MeshInstance3D
		crystal_material = gem.get_active_material(0).duplicate() as StandardMaterial3D
		crystal_material.emission_enabled = true
		crystal_material.emission = Color("#cc284d")
		gem.material_override = crystal_material
	else:
		flask = model.find_child("*ClayFlask*", true, false) as MeshInstance3D
		airborne = MeshInstance3D.new()
		airborne.mesh = flask.mesh
		airborne.hide()
		owner.add_child(airborne)

func update(display: Transform3D) -> bool:
	var progress := -1.0
	var tower: DefenseTower
	if heal != null and heal.cast_remaining > 0:
		progress = 1.0 - heal.cast_remaining / heal.cast_seconds
	elif sabotage != null and sabotage.remaining > 0:
		tower = sabotage.target()
		if is_instance_valid(tower):
			progress = 1.0 - sabotage.remaining / sabotage.windup
	if progress < 0:
		if active:
			model.hide()
			if airborne != null: airborne.hide()
		active = false
		return false
	if model == null: prepare()
	model.show()
	model.global_transform = display
	if tower != null:
		var aim := tower.global_position
		aim.y = display.origin.y
		if aim.distance_squared_to(display.origin) > .00001:
			var toward := display.looking_at(aim, Vector3.UP)
			model.global_transform = display.interpolate_with(toward, smoothstep(0,.28,progress))
	var duration := player.get_animation(clip).length
	if flask != null:
		if progress >= RELEASE and not airborne.visible:
			player.seek(duration*RELEASE, true)
			launch = flask.global_transform
			airborne.show()
		flask.visible = progress < RELEASE
		if airborne.visible:
			var flight := clampf((progress-RELEASE)/(1.0-RELEASE),0,1)
			var destination := tower.global_position + Vector3.UP*.65
			airborne.global_transform = launch
			airborne.global_position = launch.origin.lerp(destination,flight) + Vector3.UP * (3.0*flight*(1.0-flight))
			airborne.rotate_object_local(Vector3.RIGHT,flight*TAU)
	if crystal_material != null:
		crystal_material.emission_energy_multiplier = 1.8*smoothstep(.16,.44,progress)*(1.0-smoothstep(.67,.95,progress))
	player.seek(duration*progress, true)
	active = true
	return true

func dispose() -> void:
	for node in [model, airborne]:
		if is_instance_valid(node):
			node.hide()
			node.queue_free()
	active = false

