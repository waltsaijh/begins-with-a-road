shader_type spatial;
// Same depth-tested strata as the prototype; no depth/screen texture reads.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float opacity = 0.065;
uniform float coverage = 0.65;
uniform vec2 noise_offset = vec2(7.0, 19.0);
varying vec3 world_position;
#include "res://assets/shaders/cloud_field.gdshaderinc"
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = cloud_density(world_position.xz + noise_offset, TIME);
	ALBEDO = cloud_color(n) * 0.98 + vec3(0.025);
	ALPHA = smoothstep(coverage, coverage + 0.33, n) * opacity;
}
