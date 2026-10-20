shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 world_position;
#include "res://assets/shaders/cloud_field.gdshaderinc"
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() { ALBEDO = cloud_color(cloud_density(world_position.xz, TIME)); }
