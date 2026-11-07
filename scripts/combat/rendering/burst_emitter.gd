extends Node3D
## Bounded, reusable scene instances. Lifetime never gates death, rewards or damage.
@export var effect_scene: PackedScene
@export_range(1, 128, 1) var max_active := 48
@export var automatic := true
var active: Array[Node3D] = []
var _pool: Array[Node3D] = []

func _ready() -> void:
	set_process(false)
	_warm_shaders.call_deferred()

## Shaders compile on first draw: a sub-pixel pooled burst pays that under the
## loading veil, because the first kill otherwise stalls WebGL for seconds.
func _warm_shaders() -> void:
	var camera := get_viewport().get_camera_3d()
	if effect_scene == null or camera == null: return
	var burst := _create_burst()
	_pool.append(burst)
	burst.global_transform = camera.global_transform*Transform3D(Basis().scaled(Vector3.ONE*0.00001),Vector3.FORWARD*(camera.near+1.0))
	burst.show()

func _create_burst() -> Node3D:
	var burst := effect_scene.instantiate() as Node3D
	burst.set_meta("authored_basis", burst.basis)
	add_child(burst)
	burst.finished.connect(_release)
	return burst

func emit_at(at: Vector3, reference_basis := Basis.IDENTITY, splash_radius := -1.0) -> Node3D:
	if effect_scene == null or active.size() >= max_active: return null
	var burst: Node3D
	if _pool.is_empty():
		burst = _create_burst()
	else:
		burst = _pool.pop_back()
	burst.global_transform = Transform3D(reference_basis*burst.get_meta("authored_basis"), at)
	active.append(burst)
	burst.play(splash_radius)
	set_process(automatic)
	return burst

func _release(burst: Node3D) -> void:
	var index := active.find(burst)
	if index < 0: return
	active.remove_at(index)
	_pool.append(burst)
	if active.is_empty(): set_process(false)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	for i in range(active.size()-1, -1, -1): active[i].advance(delta)

func clear() -> void:
	for burst in active:
		burst.playing = false
		burst.hide()
		_pool.append(burst)
	active.clear()
	set_process(false)
