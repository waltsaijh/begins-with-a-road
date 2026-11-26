extends CPUParticles3D
## Briefly light the visible tower pieces and lift sparks through their footprint.
@export var glow: StandardMaterial3D
var _lit: Array[MeshInstance3D] = []
var _pulse: Tween

func _ready() -> void:
	finished.connect(queue_free)

func play(visual: Node3D) -> void:
	if _pulse != null: _pulse.kill()
	_clear_glow()
	var bounds := preload("res://scripts/towers/body_visual.gd").visible_bounds(visual, get_parent_node_3d())
	for piece: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if piece.mesh == null or not piece.is_visible_in_tree(): continue
		if piece.material_overlay == null:
			_lit.append(piece)
			piece.material_overlay = glow
	position = bounds.get_center()
	emission_box_extents = Vector3(maxf(.35, bounds.size.x * .54), bounds.size.y * .32, maxf(.35, bounds.size.z * .54))
	glow.albedo_color.a = 0.0
	_pulse = create_tween().set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(glow, "albedo_color:a", .42, .13).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(glow, "albedo_color:a", 0.0, .52).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_callback(_clear_glow)
	restart()

func _clear_glow() -> void:
	for piece in _lit:
		if is_instance_valid(piece) and piece.material_overlay == glow:
			piece.material_overlay = null
	_lit.clear()

func _exit_tree() -> void:
	_clear_glow()
