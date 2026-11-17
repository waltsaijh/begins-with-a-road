// Drifting cloud shadows over the islands (Art Slice G). Tune in
// Project Settings > Shader Globals: cloud_shadow_strength (0 = off),
// cloud_shadow_scale (smaller = bigger clouds), cloud_shadow_wind (texture units/s).
global uniform sampler2D cloud_shadow_noise : repeat_enable, filter_linear_mipmap;
global uniform float cloud_shadow_strength;
global uniform float cloud_shadow_scale;
global uniform vec2 cloud_shadow_wind;
float cloud_shadow(vec3 world, float clock) {
	vec2 p = world.xz * cloud_shadow_scale + cloud_shadow_wind * clock + vec2(0.61, 0.13);
	float n = texture(cloud_shadow_noise, p).r;
	return smoothstep(0.46, 0.72, n) * cloud_shadow_strength;
}
