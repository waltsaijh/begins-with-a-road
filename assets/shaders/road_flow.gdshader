shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 highlight_color : source_color = vec4(0.953, 0.914, 0.804, 0.96);
uniform float highlight_length = 0.50;
uniform float stroke_period = 8.0;
uniform float flow_speed = 0.28;
uniform float line_width = 0.055;
uniform float phase_offset = 0.0;
uniform sampler2D phase_data : filter_nearest, repeat_disable;
uniform sampler2D flow_data : filter_nearest, repeat_disable;

void fragment() {
	vec2 point = UV - vec2(0.5);
	int row = int(UV2.x + 0.5);
	int count = int(texelFetch(flow_data, ivec2(0, row), 0).r + 0.5);
	float best_alpha = 0.0;
	// Derivatives must be outside the variable-count primitive loop.
	float aa = max(length(fwidth(point))*0.55, 0.0001);
	for (int i = 0; i < 48; i++) {
		if (i >= count) { break; }
		vec4 endpoints = texelFetch(flow_data, ivec2(1+i*3, row), 0);
		vec4 info = texelFetch(flow_data, ivec2(2+i*3, row), 0);
		vec2 delta = endpoints.zw - endpoints.xy;
		float segment_length = max(length(delta),0.0001);
		vec2 axis = delta/segment_length;
		vec2 relative = point-endpoints.xy;
		float progress = dot(relative,axis);
		bool arc = info.w < 0.0;
		float end_strength = abs(info.w);
		float maximum_width = line_width*0.5*mix(0.4,1.0,max(info.x,end_strength));
		vec2 center = endpoints.xy+endpoints.zw;
		vec2 radial = point-center;
		vec2 radius_a = endpoints.xy-center;
		float distance = arc ? abs(length(radial)-length(radius_a))
			: abs(relative.x*axis.y-relative.y*axis.x);
		if (distance > maximum_width+aa) { continue; }
		vec4 clips = texelFetch(flow_data, ivec2(3+i*3,row), 0);
		// Partition the shared join without fading its seam. The outer strip
		// silhouette and genuine round termini retain their antialiasing.
		if (dot(clips.xy,clips.xy) > 0.5) {
			if (dot(relative,clips.xy) < -0.00001) { continue; }
		} else if (progress < 0.0) {
			distance = max(distance,length(relative));
		}
		if (dot(clips.zw,clips.zw) > 0.5) {
			if (dot(point-endpoints.zw,clips.zw) > 0.00001) { continue; }
		} else if (progress > segment_length) {
			distance = max(distance,length(point-endpoints.zw));
		}
		float t = clamp(progress/segment_length,0.0,1.0);
		if (arc) {
			vec2 radius_b = endpoints.zw-center;
			float direction = sign(radius_a.x*radius_b.y-radius_a.y*radius_b.x);
			float angle = dot(radial,radial) > 0.00000001
				? atan(radius_a.x*radial.y-radius_a.y*radial.x,dot(radius_a,radial))*direction : 0.0;
			t = clamp(angle/1.57079632679,0.0,1.0);
		}
		// Ease only the style: the complete-trip animation clock stays linear.
		float strength = mix(info.x,end_strength,smoothstep(0.0,1.0,t));
		float width = line_width*0.5*mix(0.4,1.0,strength);
		float coverage = 1.0-smoothstep(width-aa,width+aa,distance);
		if (coverage <= 0.0) { continue; }
		float local_progress = mix(fract(info.y),fract(info.z),t)*4.0-0.5;
		float along = mod(TIME*flow_speed+phase_offset-floor(info.y)-local_progress,stroke_period);
		// Nearest complete-trip arrival, in constant work even after many merges.
		vec4 packed_gap = round(texelFetch(phase_data, ivec2(int(floor(along)),int(floor(info.z))), 0)*255.0);
		vec2 gap = vec2(dot(packed_gap.rg,vec2(1.0,256.0)),dot(packed_gap.ba,vec2(1.0,256.0)));
		float distance_to_light = min(gap.x+fract(along),gap.y-fract(along));
		// The entire stroke fades at both ends. Outside it, there is no base line.
		float envelope = 1.0-smoothstep(0.0,highlight_length*0.5,distance_to_light);
		float opacity = coverage*highlight_color.a*mix(0.45,1.0,strength)*envelope;
		// A union, never alpha-over: crossing pieces cannot darken a junction.
		best_alpha = max(best_alpha,opacity);
	}
	ALBEDO = highlight_color.rgb;
	ALPHA = best_alpha;
}
