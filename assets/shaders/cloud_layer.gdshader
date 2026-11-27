shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 world_position;
#include "res://assets/shaders/cloud_field.gdshaderinc"
// Night sky (TimeOfDayPreset.stars sets the night_sky global to 1): twinkling stars
// in the cloud gaps; the larger ones carry a small four-point sparkle.
global uniform float night_sky;
float star_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float density = cloud_density(world_position.xz, TIME);
	vec3 color = cloud_color(density);
	if (night_sky > 0.0) {
		vec2 grid = world_position.xz * 1.6;
		vec2 cell = floor(grid);
		float h = star_hash(cell);
		vec2 at = vec2(star_hash(cell + 17.13), star_hash(cell + 31.71)) * 0.7 + 0.15;
		float size = mix(0.09, 0.2, star_hash(cell + 5.3));
		vec2 q = fract(grid) - at;
		float core = smoothstep(size * 0.55, size * 0.15, length(q));
		float rays = smoothstep(size * 0.18, 0.0, abs(q.x)) * smoothstep(size * 1.6, 0.0, abs(q.y))
			+ smoothstep(size * 0.18, 0.0, abs(q.y)) * smoothstep(size * 1.6, 0.0, abs(q.x));
		float star = step(0.84, h) * clamp(core + rays * step(0.16, size) * 0.7, 0.0, 1.0);
		float twinkle = 0.55 + 0.45 * sin(TIME * (1.3 + h * 2.0) + h * 60.0);
		float gap = 1.0 - smoothstep(0.2, 0.6, density);
		color += vec3(0.85, 0.9, 1.0) * star * twinkle * gap * night_sky;
	}
	ALBEDO = color;
}
