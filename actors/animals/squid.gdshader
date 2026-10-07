shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// The colossal squid's skin: a deep burgundy hide freckled with chromatophores that
// flicker and spread (orange, then angry red) as `agitation` rises, a few bioluminescent
// freckles that glow in the dark, a wet sheen, and the same depth fade as the water
// (about 1/e every 38 m).
uniform float agitation : hint_range(0.0, 1.0) = 0.0;
uniform vec3 glow_color : source_color = vec3(0.35, 0.9, 1.0);
uniform float glow_amount : hint_range(0.0, 3.0) = 0.6;

varying vec3 opos;
varying float wy;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	opos = VERTEX;
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float lit = exp(min(wy, 0.0) / 38.0);
	vec3 base = to_linear(COLOR.rgb);
	float speed = 0.25 + agitation * 3.0;
	float cells = vnoise(opos.xz * 2.4 + opos.y * 1.3 + vec2(TIME * 0.12, 0.0));
	float spots = smoothstep(0.58, 0.72, cells);
	float flick = vnoise(opos.xy * 4.0 + vec2(TIME * speed, opos.z * 0.5));
	vec3 chroma = mix(vec3(0.55, 0.09, 0.12), vec3(1.0, 0.5, 0.22), flick);
	base = mix(base, base * chroma * 2.2, spots * (0.45 + 0.35 * agitation));
	base = mix(base, base * vec3(1.9, 0.42, 0.38), agitation * 0.65);
	// A few freckles are bioluminescent; they brighten when the animal is excited.
	float photo = smoothstep(0.78, 0.9, vnoise(opos.xz * 5.5 + opos.y * 2.0 + 11.0));
	ALBEDO = base * lit;
	EMISSION = to_linear(glow_color) * photo * glow_amount * (0.35 + agitation * 1.4) + base * 0.04 * lit;
	ROUGHNESS = 0.3;
	SPECULAR = 0.75;
	RIM = 0.55;
	RIM_TINT = 0.5;
}
