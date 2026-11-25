shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#define ENEMY_RIGID_CLIP
uniform sampler2D joint_frames : filter_nearest, repeat_disable;

// Three texels per rigid part contain the affine rows for one sampled pose.
mat4 joint_pose(int frame, int part) {
	ivec2 cell = ivec2(frame, part * 3);
	return transpose(mat4(texelFetch(joint_frames, cell, 0),
		texelFetch(joint_frames, cell + ivec2(0, 1), 0),
		texelFetch(joint_frames, cell + ivec2(0, 2), 0), vec4(0., 0., 0., 1.)));
}
#include "res://assets/shaders/solid_color_body.gdshaderinc"

