class_name SolidMaterials
extends RefCounted
## The two StandardMaterial3D feature sets shared by all flat-colored 3D art.
## Each extra combination compiles about six WebGL programs, stalling for seconds.
## Keep authored scenes on these flags; only colors and numeric values may differ.

static func opaque(color := Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	return material

static func transparent(color := Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
