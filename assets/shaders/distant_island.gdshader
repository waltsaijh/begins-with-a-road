shader_type spatial;
// Art Slice G: far-off floating islands. Lit like the map, then hazed toward the
// cloud colour with depth so they read as silhouettes, and gently bobbing.
render_mode diffuse_lambert, specular_disabled, fog_disabled;
#include "res://assets/shaders/cloud_field.gdshaderinc"
uniform float haze = 0.42;
uniform float bob = 0.07;
varying vec3 world_pos;
void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.21;
	VERTEX.y += sin(TIME * 0.35 + phase) * bob;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float h = clamp(haze + smoothstep(-0.8, -4.0, world_pos.y) * 0.45, 0.0, 0.9);
	ALBEDO = COLOR.rgb * (1.0 - h);
	EMISSION = cloud_color(0.85) * h * 0.92;
	ROUGHNESS = 1.0;
}
