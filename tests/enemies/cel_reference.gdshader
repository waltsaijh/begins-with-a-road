shader_type spatial;
// Test-only reference: a uniform colour with the same cel lighting as the
// shared material, so the baked palette can still be compared pixel by pixel.
#include "res://assets/shaders/cel_light.gdshaderinc"
uniform vec3 albedo : source_color;
uniform float roughness = 1.0;
uniform float specular = 0.5;
void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
