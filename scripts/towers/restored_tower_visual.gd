extends Node3D
## Prototype recoil curves; baked model hierarchy keeps the original assemblies.
@export var kind := 1
@export var shot_sound: AudioStream
var pulse := 0.0
var shot_count := 0
var side := 1
var target_position := Vector3.ZERO
var _rest := Vector3.ZERO
@onready var assembly: Node3D = $RecoilAssembly
func _ready() -> void:
	_rest = assembly.position
func prepare_target(target: Node3D) -> void:
	target_position = to_local(target.global_position)
	side = -1 if target_position.x < 0 else 1
func muzzle_position() -> Vector3:
	var markers := muzzles()
	if kind == 3: markers = markers.filter(func(n): return signf(to_local(n.global_position).x) == side)
	markers.sort_custom(func(a,b): return a.global_position.distance_squared_to(to_global(target_position)) < b.global_position.distance_squared_to(to_global(target_position)))
	if not markers.is_empty(): return markers[0].global_position
	return to_global(Vector3(0,0.7,0))
func muzzles() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for path: NodePath in get_meta("muzzle_paths",[]): result.append(get_node(path))
	return result
func fire(_target: Node3D,effects: Node = null) -> void:
	shot_count += 1
	pulse = 1
	if effects != null:
		effects.play_restored_shot(kind,shot_sound)
		var markers := muzzles()
		for marker in markers:
			if kind == 3 and signf(to_local(marker.global_position).x) != side: continue
			effects.restored_bursts.emit(marker.global_position,["arrow","shell","bolt","broadside","radial"][kind])
func _process(delta: float) -> void:
	pulse = maxf(0,pulse-delta*3)
	match kind:
		2: assembly.position = _rest+Vector3(0,-pulse*0.02,pulse*0.075)
		1: assembly.position = _rest+Vector3(0,-pulse*0.055,pulse*0.025)
		3:
			for bank in assembly.get_children():
				var bank_side: int = bank.get_meta("side")
				bank.position.x = -bank_side*pulse*0.045 if side == bank_side else 0.0
		4:
			assembly.position = _rest+Vector3(0,pulse*0.04,0)
			assembly.scale = Vector3(1.0+pulse*0.035,1,1.0+pulse*0.035)
