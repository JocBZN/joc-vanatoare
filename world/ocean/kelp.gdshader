shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Kelp and sea grass: ribbons that sway with the current. UV.y is the height
// fraction (0 at the root), so the root stays planted and the tip moves most.
uniform float sway_amount = 1.0;
uniform float sway_speed = 1.0;
uniform float fade_start = 90.0;
uniform float fade_end = 150.0;
varying float fade;
varying float wy;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = origin.x * 0.31 + origin.z * 0.27;
	float t = TIME * sway_speed;
	float bend = UV.y * UV.y;
	VERTEX.x += (sin(t * 0.9 + phase + UV.y * 2.2) * 0.8 + sin(t * 1.9 + phase * 1.7) * 0.25) * sway_amount * bend * (1.0 + VERTEX.y * 0.08);
	VERTEX.z += cos(t * 0.7 + phase * 1.3 + UV.y * 1.7) * 0.6 * sway_amount * bend;
	fade = 0.0;
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void fragment() {
	float lit = exp(min(wy, 0.0) / 38.0);
	vec3 base = to_linear(COLOR.rgb) * lit;
	ALBEDO = base;
	EMISSION = base * 0.2;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	// Light passes through the thin blade.
	BACKLIGHT = base * 0.35;
}
