// Cel lighting shared by every world shader (solid_color, pillar_fade,
// distant_island). Direct light, including the directional shadow carried in
// ATTENUATION, is quantised into three flat bands instead of a smooth ramp.
// Ambient / emission are untouched. Same code in every including shader, so it
// adds no material variants or WebGL programs; tune all worlds here.
const float CEL_LIT = 0.6;     // NdotL above this: fully lit band
const float CEL_MID = 0.2;     // above this: middle band, below: dark band
const float CEL_MID_LEVEL = 0.5;
const float CEL_EDGE = 0.015;  // half-width of the band boundary anti-aliasing
const float CEL_SPECULAR_CUT = 0.6;
const float CEL_SHADOW = 0.7;  // ATTENUATION below this counts as in shadow
                               // (Sun shadow_opacity 0.62 leaves 0.38 inside)

float cel_band(float value) {
	return mix(0.0, CEL_MID_LEVEL, smoothstep(CEL_MID - CEL_EDGE, CEL_MID + CEL_EDGE, value))
		+ (1.0 - CEL_MID_LEVEL) * smoothstep(CEL_LIT - CEL_EDGE, CEL_LIT + CEL_EDGE, value);
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// Shadow is judged on its own and can only cap a surface at the middle band.
	// Multiplying it into NdotL let shadow-map acne on side faces flip bands and
	// draw sawtooth stripes; side faces already in the middle band now ignore it.
	float shadowed = 1.0 - smoothstep(CEL_SHADOW - CEL_EDGE * 4.0, CEL_SHADOW + CEL_EDGE * 4.0, ATTENUATION);
	float band = min(cel_band(n_dot_l), mix(1.0, CEL_MID_LEVEL, shadowed));
	float lit = n_dot_l * (1.0 - shadowed);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
	// Hard-edged highlight; roughness 1 surfaces (rock, islands) get none.
	float gloss = 1.0 - ROUGHNESS;
	if (gloss > 0.0 && SPECULAR_AMOUNT > 0.0) {
		vec3 half_vector = normalize(VIEW + LIGHT);
		float spec = pow(clamp(dot(NORMAL, half_vector), 0.0, 1.0), mix(8.0, 128.0, gloss)) * lit;
		SPECULAR_LIGHT += smoothstep(CEL_SPECULAR_CUT - CEL_EDGE, CEL_SPECULAR_CUT + CEL_EDGE, spec)
			* SPECULAR_AMOUNT * gloss * LIGHT_COLOR / PI;
	}
}
