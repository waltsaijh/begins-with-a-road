shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float rejection_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Only the existing red occupancy/invalid paint reacts; other tile colors stay intact.
	float red = step(COLOR.g * 1.5, COLOR.r) * step(COLOR.b * 1.5, COLOR.r);
	float pulse = rejection_flash * red;
	ALBEDO = mix(COLOR.rgb, vec3(1.0, 0.62, 0.50), pulse * 0.5);
	ALPHA = min(1.0, COLOR.a + pulse * 0.18);
}
