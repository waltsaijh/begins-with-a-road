extends MultiMeshInstance3D
## Cosmetic hit sparks, one draw call for every tower: each hit throws a few
## small coloured chips away from the shooter (arrows: pale splinters, ballista:
## more and bigger, broadside: hot sparks and a smoke puff, crossfire: two quick
## sparks). Real-time only; never touches the simulation.
const LIMIT := 384
const GRAVITY := 5.0
const FRONT_OFFSET := 0.18
## kind -> [[count, colour, speed, size, life, lift (negative gravity)], ...]
## The first entry of each style is the impact pop: still, big and very short.
const STYLES := {
	"arrow": [[1, Color("ffd04a"), 0.0, 0.16, 0.08, 0.0], [5, Color("ff9a2e"), 1.6, 0.07, 0.26, 0.0], [2, Color("8a5a32"), 1.1, 0.06, 0.3, 0.0]],
	"bolt": [[1, Color("ffd04a"), 0.0, 0.22, 0.1, 0.0], [7, Color("ff9a2e"), 2.0, 0.085, 0.32, 0.0], [4, Color("7a4e2c"), 1.3, 0.09, 0.4, 0.0]],
	"shell": [[1, Color("ffe07a"), 0.0, 0.26, 0.1, 0.0], [8, Color("ff6a1a"), 2.5, 0.075, 0.26, 0.0], [3, Color("7d766c"), 0.5, 0.15, 0.55, 6.0]],
	"bullet": [[1, Color("ffd04a"), 0.0, 0.1, 0.06, 0.0], [3, Color("ff8a24"), 1.8, 0.05, 0.16, 0.0]],
	# Mortar landing (thrown all around): hot sparks and dark clods of debris.
	"blast": [[10, Color("ffb02e"), 2.6, 0.06, 0.32, 0.0], [8, Color("4a403a"), 2.0, 0.08, 0.6, 0.0]],
}
const ALL_AROUND := ["blast"]
static var current: Node3D
var _position := PackedVector3Array()
var _velocity := PackedVector3Array()
var _color := PackedColorArray()
var _size := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _lift := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	current = self
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	multimesh.mesh = box
	multimesh.instance_count = LIMIT
	multimesh.visible_instance_count = 0
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Brief and small: drawn over the struck body so big enemies never hide them.
	glow.no_depth_test = true
	glow.render_priority = 1
	material_override = glow
	set_process(false)

func _exit_tree() -> void:
	if current == self: current = null

## Static entry for AttackPayload: emits on the live instance, if any.
static func hit(at: Vector3, from: Vector3, kind: String) -> void:
	if is_instance_valid(current) and STYLES.has(kind): current.emit(at, from, kind)

static func kind_for(tower: Node3D) -> String:
	if not tower is DefenseTower or tower.definition == null: return ""
	var key := String(tower.definition.name_key)
	for name in ["ballista", "broadside", "crossfire", "mortar", "sentry"]:
		if name in key: return {"ballista":"bolt", "broadside":"shell", "crossfire":"bullet", "mortar":"", "sentry":"arrow"}[name]
	return "arrow"

func emit(at: Vector3, from: Vector3, kind: String) -> void:
	var away := at-from
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD
	if not kind in ALL_AROUND: at -= away*FRONT_OFFSET   # on the side facing the shooter, not inside the body
	for style: Array in STYLES[kind]:
		for i in int(style[0]):
			if _position.size() >= LIMIT: return
			# A cone thrown back along the shot, opened up and tipped upward.
			var spread := away.rotated(Vector3.UP, _rng.randf_range(-PI, PI) if kind in ALL_AROUND else _rng.randf_range(-1.1, 1.1))
			var velocity: Vector3 = (spread*_rng.randf_range(0.5, 1.0)+Vector3.UP*_rng.randf_range(0.3, 1.0))*float(style[2])
			if float(style[2]) <= 0.0: velocity = Vector3.UP*0.001   # the pop stays put (no gravity drift)
			_position.append(at+Vector3(_rng.randf_range(-.03, .03), _rng.randf_range(-.03, .03), _rng.randf_range(-.03, .03)))
			_velocity.append(velocity)
			_color.append(style[1])
			_size.append(float(style[3])*_rng.randf_range(0.75, 1.25))
			_age.append(0.0)
			_life.append(float(style[4])*_rng.randf_range(0.8, 1.2))
			_lift.append(float(style[5]))
	set_process(true)

func clear() -> void:
	_resize(0)
	multimesh.visible_instance_count = 0
	set_process(false)

func _process(delta: float) -> void:
	var step := maxf(0.0, delta)
	var i := 0
	while i < _position.size():
		_age[i] += step
		if _age[i] >= _life[i]:
			var last := _position.size()-1
			# Packed arrays are values: swap-remove each one explicitly.
			_position[i] = _position[last]; _velocity[i] = _velocity[last]; _color[i] = _color[last]
			_size[i] = _size[last]; _age[i] = _age[last]; _life[i] = _life[last]; _lift[i] = _lift[last]
			_resize(last)
			continue
		var gravity := (GRAVITY if _lift[i] <= 0.0 else -_lift[i]*0.1) if _velocity[i].length_squared() > 0.000002 else 0.0
		_velocity[i] = _velocity[i]*exp(-3.0*step)+Vector3.DOWN*gravity*step
		_position[i] += _velocity[i]*step
		i += 1
	var count := _position.size()
	for j in count:
		var t := _age[j]/_life[j]
		var smoke := _lift[j] > 0.0
		var pop := _velocity[j].length_squared() <= 0.000002
		var scale := _size[j]*((0.6+t*1.2) if smoke else ((0.6+t*0.8) if pop else (1.0-t*0.7)))
		var stretch := Basis.from_scale(Vector3.ONE*scale)
		if not smoke and not pop and _velocity[j].length_squared() > 0.01:
			# Sparks stretch along their motion.
			var forward := _velocity[j].normalized()
			var side := forward.cross(Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT).normalized()
			stretch = Basis(side*scale, side.cross(forward)*scale, forward*scale*2.2)
		multimesh.set_instance_transform(j, Transform3D(stretch, _position[j]))
		multimesh.set_instance_color(j, Color(_color[j], (1.0-t)*(0.55 if smoke else 1.0)))
	multimesh.visible_instance_count = count
	if count == 0: set_process(false)

func _resize(count: int) -> void:
	_position.resize(count); _velocity.resize(count); _color.resize(count)
	_size.resize(count); _age.resize(count); _life.resize(count); _lift.resize(count)
