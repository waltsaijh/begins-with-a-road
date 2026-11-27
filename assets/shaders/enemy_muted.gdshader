shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Art Slice G enemies: vertex colours graded toward the tower palette
// (dusty, low contrast, slightly cool). Tweak here to retone every enemy.
uniform float saturation = 0.45;
uniform float contrast = 0.6;
uniform float brighten = 0.13;
uniform vec3 tint = vec3(0.96, 0.98, 1.02);
void fragment() {
	vec3 p = pow(max(COLOR.rgb, vec3(0.0)), vec3(1.0/2.2));
	float l = dot(p, vec3(0.299, 0.587, 0.114));
	p = mix(vec3(l), p, saturation);
	p = mix(vec3(0.5), p, contrast) + brighten;
	p *= tint;
	ALBEDO = pow(clamp(p, 0.0, 1.0), vec3(2.2));
	ROUGHNESS = 0.9;
}
