shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.34, 0.84, 0.82, 0.34);
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
