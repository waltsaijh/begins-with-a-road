shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 world_position;
#include "res://assets/shaders/cloud_field.gdshaderinc"

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float density = cloud_density(world_position.xz, TIME);
	vec3 soft_clouds = mix(vec3(0.86, 0.895, 0.92), vec3(0.995, 0.997, 1.0), density);
	float horizon = smoothstep(55.0, 155.0, distance(world_position.xz, CAMERA_POSITION_WORLD.xz));
	ALBEDO = mix(soft_clouds, vec3(0.9, 0.925, 0.94), horizon);
}
