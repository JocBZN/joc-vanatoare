shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Corals, rocks and palms: flat low-poly colours baked into the mesh as sRGB
// vertex colours. A little emission keeps reef colours vivid through the fog.
uniform float glow : hint_range(0.0, 1.0) = 0.3;
uniform float saturation : hint_range(0.0, 2.0) = 1.15;

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }

void fragment() {
	float lit = exp(min(wy, 0.0) / 38.0);
	vec3 base = to_linear(COLOR.rgb);
	float l = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(vec3(l), base, saturation);
	ALBEDO = base * lit;
	EMISSION = base * glow * mix(0.35, 1.0, lit);
	ROUGHNESS = 0.78;
	SPECULAR = 0.3;
}
