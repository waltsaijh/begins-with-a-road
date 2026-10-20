shader_type spatial;
// Opaque colour fade from the prototype's cliff_fade shader avoids rock sorting.
render_mode diffuse_lambert, specular_disabled, cull_disabled, fog_disabled;
uniform vec4 stone_color : source_color = vec4(0.431, 0.518, 0.600, 1.0);
uniform float cloud_height = -4.0;
uniform float cloud_top = -2.0;
uniform float support_growth : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_position;
varying float local_height;
#include "res://assets/shaders/cloud_field.gdshaderinc"
void vertex() {
	// Extend/retract below the stationary attachment to the tile foundation.
	VERTEX.y = -0.37 + (VERTEX.y + 0.37) * support_growth;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_height = VERTEX.y;
}
void fragment() {
	float n = cloud_density(world_position.xz, TIME);
	float fade = 1.0 - smoothstep(cloud_height, cloud_top, local_height + (n - 0.5) * 0.3);
	ALBEDO = stone_color.rgb * COLOR.rgb * (1.0 - fade);
	EMISSION = cloud_color(n) * fade;
	ROUGHNESS = 1.0;
}
