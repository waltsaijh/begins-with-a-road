@tool
extends EnemyGpuModel
## Baked Blender transforms. Picking uses the same affine interpolation as the GPU.
@export var part_bounds: Array[AABB] = []
@export var frames: Array[Transform3D] = []
## Optional non-looping GLB gesture played only during its matching real ability.
@export var gesture: StringName

func matches(scene: PackedScene, animation: StringName) -> bool:
	return source == scene and (animation.is_empty() or animation == animation_name) \
		and clip_length > 0 and keyframe_intervals > 0 and not part_bounds.is_empty() \
		and frames.size() == keyframe_intervals * part_bounds.size() \
		and mesh != null and mesh.get_surface_count() == 1 and material() != null

func material() -> ShaderMaterial:
	return mesh.surface_get_material(0) as ShaderMaterial

func inspection_parts(display: Transform3D, phase: float) -> Array[Dictionary]:
	var frame := fposmod(phase / TAU, 1.0) * keyframe_intervals
	var index := floori(frame)
	var weight := frame - index
	var count := part_bounds.size()
	var parts: Array[Dictionary] = []
	for part in count:
		var a := frames[index * count + part]
		var b := frames[((index + 1) % keyframe_intervals) * count + part]
		var basis := Basis(a.basis.x.lerp(b.basis.x, weight), a.basis.y.lerp(b.basis.y, weight), a.basis.z.lerp(b.basis.z, weight))
		parts.append({"transform": display * Transform3D(basis, a.origin.lerp(b.origin, weight)), "bounds": part_bounds[part]})
	return parts

