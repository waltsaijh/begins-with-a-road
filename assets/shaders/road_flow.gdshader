shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 highlight_color : source_color = vec4(0.953, 0.914, 0.804, 0.96);
uniform float highlight_length = 0.50;
uniform float stroke_period = 8.0;
uniform float flow_speed = 0.28;
uniform float phase_offset = 0.0;
uniform sampler2D flow_data : filter_nearest, repeat_disable;

void fragment() {
	vec2 point = UV - vec2(0.5);
	int row = int(UV2.x + 0.5);
	int count = int(texelFetch(flow_data, ivec2(0, row), 0).r + 0.5);
	float best_alpha = 0.0;
	// Derivatives must be outside the variable-count primitive loop.
	float aa = max(length(fwidth(point))*0.55, 0.0001);
	for (int i = 0; i < 24; i++) {
		if (i >= count) { break; }
		vec4 endpoints = texelFetch(flow_data, ivec2(1+i*2, row), 0);
		vec4 info = texelFetch(flow_data, ivec2(2+i*2, row), 0);
		vec2 delta = endpoints.zw - endpoints.xy;
		float t = clamp(dot(point-endpoints.xy, delta) / max(dot(delta,delta), 0.000001), 0.0, 1.0);
		float distance = length(point-mix(endpoints.xy, endpoints.zw, t));
		float coverage = 1.0-smoothstep(max(0.0,info.w-aa), info.w+aa, distance);
		float along = mix(info.y,info.z,t)-TIME*flow_speed-phase_offset;
		float distance_to_light = abs(mod(along+stroke_period*0.5,stroke_period)-stroke_period*0.5);
		// The entire stroke fades at both ends. Outside it, there is no base line.
		float envelope = 1.0-smoothstep(0.0,highlight_length*0.5,distance_to_light);
		float opacity = coverage*highlight_color.a*mix(0.45,1.0,info.x)*envelope;
		// A union, never alpha-over: crossing pieces cannot darken a junction.
		best_alpha = max(best_alpha,opacity);
	}
	ALBEDO = highlight_color.rgb;
	ALPHA = best_alpha;
}
