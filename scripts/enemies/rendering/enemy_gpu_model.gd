@tool
class_name EnemyGpuModel
extends Resource
## Offline-baked rigid gait. Unmatched/custom scenes retain their scene renderer.
const SharedMaterial = preload("res://assets/materials/solid_color.tres")
@export var source: PackedScene
@export var mesh: ArrayMesh
@export var rest_height := 0.0
@export var root_transform := Transform3D.IDENTITY
## Zero keeps the original distance-driven Soldier gait.
@export var clip_length := 0.0
@export var keyframe_intervals := 0
@export var animation_name: StringName = &"Walk"
@export var leg_swing := EnemyRenderConstants.LEG_SWING
@export var arm_swing := EnemyRenderConstants.ARM_SWING
@export var body_bob := EnemyRenderConstants.BODY_BOB
@export var body_sway := EnemyRenderConstants.BODY_SWAY

func matches(scene: PackedScene, animation: StringName) -> bool:
	return mesh != null and mesh.get_surface_count() == 1 and mesh.surface_get_material(0) == SharedMaterial and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0) != 0 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM1) != 0 and source == scene and (clip_length == 0.0 or animation.is_empty() or animation == animation_name)

func material() -> ShaderMaterial:
	return SharedMaterial
