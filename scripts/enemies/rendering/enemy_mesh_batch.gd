extends RefCounted
## Per-geometry dense slots, independent from the overlay's global enemy order.
var view: MultiMeshInstance3D
var units: Array[Node3D] = []
var slots := {}
var _transforms: Array[Transform3D] = []
var _custom: Array[Color] = []

func _init(target: MultiMeshInstance3D, model: EnemyGpuModel) -> void:
	view = target
	view.multimesh = MultiMesh.new()
	view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	view.multimesh.use_colors = true
	view.multimesh.use_custom_data = true
	view.multimesh.mesh = model.mesh
	view.material_override = model.material()
	reserve(EnemyRenderConstants.INITIAL_CAPACITY)

func reserve(count: int) -> void:
	var mesh := view.multimesh
	if count <= mesh.instance_count: return
	mesh.instance_count = maxi(count, mesh.instance_count*2)
	mesh.visible_instance_count = units.size()
	for i in units.size():
		view.multimesh.set_instance_color(i,Color.WHITE)
		_write(i)

func add(enemy: Node3D) -> void:
	reserve(units.size()+1)
	slots[enemy] = units.size()
	units.append(enemy)
	_transforms.append(Transform3D.IDENTITY)
	_custom.append(Color(0,0,0,0))
	view.multimesh.set_instance_color(units.size()-1,Color.WHITE)
	view.multimesh.visible_instance_count = units.size()

func update(enemy: Node3D, transform: Transform3D, custom: Color) -> void:
	var slot: int = slots[enemy]
	_transforms[slot] = transform
	_custom[slot] = custom
	_write(slot)

func _write(slot: int) -> void:
	view.multimesh.set_instance_transform(slot, _transforms[slot])
	view.multimesh.set_instance_custom_data(slot, _custom[slot])

func remove(enemy: Node3D) -> void:
	var slot: int = slots[enemy]
	slots.erase(enemy)
	var last: Node3D = units.pop_back()
	if slot < units.size():
		units[slot] = last
		slots[last] = slot
		_transforms[slot] = _transforms[-1]
		_custom[slot] = _custom[-1]
		_write(slot)
	_transforms.resize(units.size())
	_custom.resize(units.size())
	view.multimesh.visible_instance_count = units.size()
