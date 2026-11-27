extends RefCounted
## Offline GPU meshes, with scene rendering retained for arbitrary imports.
const DefaultScene = preload("res://assets/models/enemies/grunt.tscn")
const DefaultMesh = preload("res://assets/models/enemies/grunt_mesh.res")
const DefaultGpu = preload("res://assets/models/enemies/grunt_gpu.tres")
var batched := true
var gpu_model: EnemyGpuModel
var batch: RefCounted
var clip_phase := 0.0
var instance: Node3D
var animation: AnimationPlayer
var adjustment := Transform3D.IDENTITY
var imported_transform := Transform3D.IDENTITY
var head := Vector3(0, DefaultMesh.get_aabb().end.y+EnemyStatusConstants.HEAD_MARGIN, 0)
var animation_speed := 1.0
var minimum_clip_blend := 0.0
var action: RefCounted

func _init(profile: Troop, parent: Node3D, initial_phase := 0.0) -> void:
	clip_phase = initial_phase
	gpu_model = gpu_for(profile)
	if profile == null: return
	adjustment = Transform3D(Basis.from_euler(profile.model_rotation_degrees*PI/180.0).scaled(profile.model_scale), profile.model_offset)
	if profile.troop_name == "rats":
		adjustment.basis = adjustment.basis.scaled(Vector3.ONE * (1.0 + .09*sin(initial_phase)))
	animation_speed = profile.animation_speed
	if profile.flight_height > 0.0: minimum_clip_blend = 0.4
	batched = gpu_model != null
	if batched:
		imported_transform = gpu_model.root_transform
		var height := gpu_model.rest_height if gpu_model.rest_height > 0 else gpu_model.mesh.get_aabb().end.y
		head = Vector3(0,height+EnemyStatusConstants.HEAD_MARGIN,0)
	if not batched:
		var root := profile.model.instantiate()
		if not root is Node3D:
			root.free()
			batched = true
			gpu_model = DefaultGpu
			return
		instance = root
		parent.add_child(instance)
		imported_transform = instance.transform
		head = Vector3(0, _model_height()+EnemyStatusConstants.HEAD_MARGIN, 0)
		if TimeOfDayPreset.lights_on: _carry_torch(profile.troop_name)
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		for player: AnimationPlayer in players:
			var selected := profile.walk_animation
			if selected.is_empty():
				for title in player.get_animation_list():
					if "walk" in title.to_lower() or "run" in title.to_lower():
						selected = title
						break
			if not selected.is_empty() and player.has_animation(selected):
				animation = player
				animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				animation.play(selected)
				animation.advance(0)
				var clip := animation.get_animation(selected)
				if clip.loop_mode != Animation.LOOP_NONE:
					animation.seek(clip.length * initial_phase / TAU, true)
				break
	if profile.head_height > 0: head.y = profile.head_height+EnemyStatusConstants.HEAD_MARGIN

static func gpu_for(profile: Troop) -> EnemyGpuModel:
	if profile == null or profile.model == null or profile.model == DefaultScene: return DefaultGpu
	if profile.gpu_model != null and profile.gpu_model.matches(profile.model,profile.walk_animation): return profile.gpu_model
	return null

func _model_height() -> float:
	var height := 0.0
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D: meshes.append(instance)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null: continue
		var relative := instance.global_transform.affine_inverse()*mesh.global_transform
		var bounds := relative*mesh.get_aabb()
		height = maxf(height, bounds.end.y)
	return height

func advance(delta: float, walk_blend: float) -> void:
	var clip_blend := maxf(walk_blend, minimum_clip_blend)
	if gpu_model != null and gpu_model.clip_length > 0:
		# The authored clips are time-driven and freeze at their current pose
		# when stationary; Soldier retains its distance-driven pose state.
		clip_phase = fposmod(clip_phase+maxf(0.0,delta)*animation_speed*clip_blend*TAU/gpu_model.clip_length,TAU)
	if is_instance_valid(instance) and instance.has_method("advance_motion"): instance.advance_motion(maxf(0,delta),walk_blend)
	if animation != null and clip_blend > 0:
		# Imported clips need not be marked looping in their import settings.
		if not animation.is_playing(): animation.play(animation.assigned_animation)
		animation.advance(maxf(0.0, delta)*animation_speed*clip_blend)

func custom_data(pose: RefCounted) -> Color:
	return Color(clip_phase,1,0,0) if gpu_model != null and gpu_model.clip_length > 0 else Color(pose.walk_phase,pose.walk_blend,0,0)

func transform_for(display: Transform3D) -> Transform3D:
	var result := display*adjustment*imported_transform
	if instance != null: instance.global_transform = result
	return result

func dispose() -> void:
	if action != null: action.dispose()
	if is_instance_valid(instance):
		instance.hide()
		instance.queue_free()
	instance = null
	animation = null

## Dusk / night fire, placed on each troop's own gear (part name, local point in that
## part, kind): flame = fire on the object, torch = stick + flame, eyes = two glowing
## eyes. The soldier lowers his sword blade for a torch; a troop not listed carries
## a torch at its side. Every second fire also casts a small warm light, which keeps
## the light count bounded on big waves (eyes only glow).
const FIRE := {
	"bloodmage": [["Body", Vector3(-0.32, 1.18, -0.10), "flame"]],       # staff crook
	"soldier": [["Arm-1", Vector3(0.155, 0.06, -0.085), "torch"]],      # in the sword hand
	"rook": [["Arm1", Vector3(-0.09, 0.15, -0.28), "flame"]],           # shield top
	"bomber": [["Body", Vector3(0.23, 0.69, -0.13), "flame"]],          # dynamite fuse
	"quickfeet": [["Body", Vector3(0.29, 1.53, -0.10), "flame"]],       # spear tip
	"heavy": [["Arm-1", Vector3(0.17, 0.52, -0.15), "flame"]],          # war hammer head
	"scout": [["Body", Vector3(0.135, 0.40, 0.06), "flame"]],           # belt pouch
	"rats": [["Body", Vector3(-0.03, 0.178, -0.185), "eye"], ["Body", Vector3(0.03, 0.178, -0.185), "eye"]],
	"winged": [["Body", Vector3(-0.034, 0.325, -0.462), "eye"], ["Body", Vector3(0.034, 0.325, -0.462), "eye"]],
}
## Soldier sword blade and guard (steel pieces above the grip in Arm-1), hidden at night.
const SWORD_PART := "Arm-1"
static var _torch_parts := {}
static var _torch_count := 0
static var _sheathed := {}
func _carry_torch(troop: String) -> void:
	_make_fire_meshes()
	var spots: Array = FIRE.get(troop, [])
	if spots.is_empty():
		var holder: Node3D = instance.get_node_or_null("Rig") as Node3D
		if holder == null: holder = instance
		var height := _model_height()
		var side := 0.0
		for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			var box := (instance.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
			side = maxf(side, box.end.x)
		_fire(holder, Vector3(side*0.95+0.03, height*0.42, 0.0), "torch").rotation.z = -0.25
		return
	if troop == "soldier": _sheath_sword()
	for spot in spots:
		var part := instance.find_child(spot[0], true, false) as Node3D
		if part != null: _fire(part, spot[1], spot[2])

func _fire(holder: Node3D, at: Vector3, kind: String) -> Node3D:
	var fire := Node3D.new(); fire.name = "NightFire"; fire.position = at
	holder.add_child(fire)
	var layout: Array
	match kind:
		"torch": layout = [["stick", Vector3(0, .1, 0)], ["flame", Vector3(0, .25, 0)], ["tip", Vector3(0, .31, 0)], ["halo", Vector3(0, .26, 0)]]
		"flame": layout = [["flame", Vector3.ZERO], ["tip", Vector3(0, .06, 0)], ["halo", Vector3(0, .01, 0)]]
		"eye": layout = [["eye", Vector3.ZERO], ["eye_halo", Vector3.ZERO]]
	for entry in layout:
		var part := MeshInstance3D.new(); part.mesh = _torch_parts[entry[0]]; part.position = entry[1]
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire.add_child(part)
	if kind != "eye":
		_torch_count += 1
		if _torch_count % 2 == 0:
			var light := OmniLight3D.new(); light.light_color = Color(1.0, 0.6, 0.28)
			light.light_energy = 0.8; light.omni_range = 0.9; light.position = Vector3(0, .05, 0)
			fire.add_child(light)
	return fire

## Night swap of the soldier's sword arm for a copy without blade and guard.
func _sheath_sword() -> void:
	var arm := instance.find_child(SWORD_PART, true, false) as MeshInstance3D
	if arm == null or arm.mesh == null: return
	if not _sheathed.has(arm.mesh): _sheathed[arm.mesh] = _without_blade(arm.mesh)
	arm.mesh = _sheathed[arm.mesh]

static func _without_blade(source: Mesh) -> Mesh:
	var arrays := source.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	# Pieces = welded connected components; steel pieces rising above the grip go.
	var root := range(v.size())
	var weld := {}
	for i in v.size():
		var k := str(v[i].snapped(Vector3.ONE*0.0005))
		if weld.has(k): root[i] = weld[k]
		else: weld[k] = i
	var top := func(i: int) -> int:
		while root[i] != i: i = root[i]
		return i
	for t in range(0, idx.size(), 3):
		var r0: int = top.call(idx[t])
		root[top.call(idx[t+1])] = r0
		root[top.call(idx[t+2])] = r0
	var high := {}
	for i in v.size():
		var r: int = top.call(i)
		high[r] = maxf(high.get(r, -9.0), v[i].y)
	var kept := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var r: int = top.call(idx[t])
		var steel := cols.size() > r and cols[r].b > cols[r].r and cols[r].get_luminance() > 0.2
		if steel and float(high[r]) > 0.1: continue
		kept.append_array([idx[t], idx[t+1], idx[t+2]])
	arrays[Mesh.ARRAY_INDEX] = kept
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _custom_flags(source))
	result.surface_set_material(0, source.surface_get_material(0))
	return result

static func _custom_flags(source: Mesh) -> int:
	var format: int = source.surface_get_format(0)
	var flags := 0
	for c in 4:
		var shift: int = Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT + c*Mesh.ARRAY_FORMAT_CUSTOM_BITS
		flags |= format & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
	return flags

static func _make_fire_meshes() -> void:
	if not _torch_parts.is_empty(): return
	var unshaded := func(color: Color, alpha := 1.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(color, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		return m
	var stick := CylinderMesh.new(); stick.top_radius = .014; stick.bottom_radius = .011; stick.height = .22; stick.radial_segments = 5
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("5a3b28"); stick.material = wood
	var flame := SphereMesh.new(); flame.radius = .04; flame.height = .095; flame.radial_segments = 6; flame.rings = 3
	flame.material = unshaded.call(Color(1.0, 0.62, 0.2))
	var tip := CylinderMesh.new(); tip.top_radius = 0.0; tip.bottom_radius = .028; tip.height = .075; tip.radial_segments = 5
	tip.material = unshaded.call(Color(1.0, 0.88, 0.45))
	var halo := SphereMesh.new(); halo.radius = .1; halo.height = .2; halo.radial_segments = 8; halo.rings = 4
	halo.material = unshaded.call(Color(1.0, 0.5, 0.15), 0.28)
	var eye := SphereMesh.new(); eye.radius = .014; eye.height = .028; eye.radial_segments = 6; eye.rings = 3
	eye.material = unshaded.call(Color(1.0, 0.55, 0.15))
	var eye_halo := SphereMesh.new(); eye_halo.radius = .035; eye_halo.height = .07; eye_halo.radial_segments = 6; eye_halo.rings = 3
	eye_halo.material = unshaded.call(Color(1.0, 0.4, 0.1), 0.35)
	_torch_parts = {"stick": stick, "flame": flame, "tip": tip, "halo": halo, "eye": eye, "eye_halo": eye_halo}
