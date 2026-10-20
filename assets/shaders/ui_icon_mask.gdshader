shader_type canvas_item;
render_mode unshaded;

// Only alpha defines the icon: both black and white source art accept tint.
// Vertex color includes CanvasItem modulation, keeping the material shared.
varying vec4 icon_tint;
void vertex() {
	icon_tint = COLOR;
}
void fragment() {
	COLOR = vec4(icon_tint.rgb, icon_tint.a * texture(TEXTURE, UV).a);
}
