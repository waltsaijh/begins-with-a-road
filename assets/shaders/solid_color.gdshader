shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec2 surface_response;

// COLOR: palette. UV.y / UV2: rigid pivot. CUSTOM0: signed limb amplitude,
// body bob, body sway, keyframe intervals + 1. Zero w means static geometry.
// INSTANCE_CUSTOM.xy: phase and movement blend (only animated MultiMeshes).
void vertex() {
	surface_response = CUSTOM1.xy;
	if (CUSTOM0.w > 0.0) {
		float stride = sin(INSTANCE_CUSTOM.x) * INSTANCE_CUSTOM.y;
		float intervals = CUSTOM0.w - 1.0;
		if (intervals > 0.0) {
			float frame = INSTANCE_CUSTOM.x * intervals / TAU;
			float step_angle = TAU / intervals;
			stride = mix(sin(floor(frame)*step_angle), sin((floor(frame)+1.0)*step_angle), fract(frame));
		}
		float angle = stride * CUSTOM0.x;
		float c = cos(angle);
		float s = sin(angle);
		vec3 pivot = vec3(UV2.x, UV2.y, UV.y);
		vec3 p = VERTEX - pivot;
		p.yz = mat2(vec2(c, s), vec2(-s, c)) * p.yz;
		VERTEX = p + pivot;
		NORMAL.yz = mat2(vec2(c, s), vec2(-s, c)) * NORMAL.yz;
		float roll = stride * CUSTOM0.z;
		c = cos(roll);
		s = sin(roll);
		VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
		NORMAL.xy = mat2(vec2(c, s), vec2(-s, c)) * NORMAL.xy;
		VERTEX.y += abs(stride) * CUSTOM0.y;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = surface_response.x;
	SPECULAR = surface_response.y;
}
