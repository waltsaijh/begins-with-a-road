shader_type canvas_item;
render_mode unshaded;

uniform vec4 frame_backgrounds[2] : source_color;
uniform vec4 frame_borders[2] : source_color;
uniform vec4 frame_rects[2];
uniform vec4 frame_widths[2];

varying vec4 atlas_rect;
varying vec4 tint;

void vertex() {
	atlas_rect = INSTANCE_CUSTOM;
	tint = COLOR;
}

void fragment() {
	if (atlas_rect.w < 0.0) {
		int index = int(atlas_rect.x);
		vec2 point = UV * atlas_rect.yz;
		vec4 rect = frame_rects[index];
		vec4 widths = frame_widths[index];
		bool inside = point.x >= rect.x && point.y >= rect.y && point.x < rect.z && point.y < rect.w;
		bool border = point.x < rect.x + widths.x || point.y < rect.y + widths.y || point.x >= rect.z - widths.z || point.y >= rect.w - widths.w;
		COLOR = tint * (inside ? (border ? frame_borders[index] : frame_backgrounds[index]) : vec4(0.0));
	} else {
		// A QuadMesh in canvas coordinates has its first UV row at the bottom.
		vec2 icon_uv = vec2(UV.x, 1.0 - UV.y);
		vec2 atlas_uv = (atlas_rect.xy + icon_uv * atlas_rect.zw) / vec2(textureSize(TEXTURE, 0));
		COLOR = tint * texture(TEXTURE, atlas_uv);
	}
}
