shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float leg_swing = 0.3;
uniform float arm_swing = 0.2;
uniform float body_bob = 0.026;
uniform float body_sway = 0.025;

// UV.x: signed limb ID (legs +/-1, arms +/-2). UV.y/UV2: local pivot.
// Instance data: distance-driven phase, movement blend; no per-enemy skeleton.
void vertex() {
	float stride = sin(INSTANCE_CUSTOM.x) * INSTANCE_CUSTOM.y;
	float amplitude = abs(UV.x) > 1.5 ? -arm_swing : leg_swing;
	float angle = stride * sign(UV.x) * amplitude;
	float c = cos(angle);
	float s = sin(angle);
	vec3 pivot = vec3(UV2.x, UV2.y, UV.y);
	vec3 p = VERTEX - pivot;
	p.yz = mat2(vec2(c, s), vec2(-s, c)) * p.yz;
	VERTEX = p + pivot;
	NORMAL.yz = mat2(vec2(c, s), vec2(-s, c)) * NORMAL.yz;
	float roll = stride * body_sway;
	c = cos(roll);
	s = sin(roll);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	NORMAL.xy = mat2(vec2(c, s), vec2(-s, c)) * NORMAL.xy;
	VERTEX.y += abs(stride) * body_bob;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.98;
	SPECULAR = 0.12;
}
