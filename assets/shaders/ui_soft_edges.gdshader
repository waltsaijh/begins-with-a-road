shader_type canvas_item;
render_mode unshaded;

// Fade inside the quad so rotated thin rectangles do not expose hard,
// staircase-shaped geometry edges in the Compatibility renderer.
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	vec2 pixel = max(fwidth(UV), vec2(0.00001));
	vec2 coverage = smoothstep(vec2(0.0), pixel, edge);
	COLOR.a *= coverage.x * coverage.y;
}
