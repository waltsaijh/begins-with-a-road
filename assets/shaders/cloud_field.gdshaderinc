// Shared, precomputed noise: one filtered lookup per fragment, no live hash/FBM.
uniform sampler2D cloud_noise_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 cloud_drift = vec2(0.012, 0.005);
uniform float cloud_scale = 0.035;
float cloud_density(vec2 world_xz, float clock) {
	vec2 p = world_xz * cloud_scale + vec2(0.27, 0.72) + cloud_drift * clock * 0.195;
	return smoothstep(0.25, 0.75, texture(cloud_noise_texture, p).r);
}
// Sky mood: Project Settings > Shader Globals > cloud_low (gaps/shadows) and cloud_high (cloud tops).
global uniform vec4 cloud_low;
global uniform vec4 cloud_high;
vec3 cloud_color(float density) {
	return mix(cloud_low.rgb, cloud_high.rgb, density);
}
