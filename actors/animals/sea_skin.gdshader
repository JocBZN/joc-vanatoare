shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Skin for sea creatures. The mesh carries sRGB vertex colours (a back-to-belly
// gradient, fin colours) and UV = (angle round the body, position along it), so the
// markings below stay on the animal however it swims. Light fades with depth the way
// the water itself does (about 1/e every 38 m), and a faint scale shimmer breaks up the
// specular highlight like wet skin.
uniform int pattern = 0;           // 0 none, 1 bars, 2 spots, 3 stripes, 4 mottled, 5 scutes, 6 bands
uniform vec3 pattern_color : source_color = vec3(0.1, 0.1, 0.12);
uniform float pattern_scale = 8.0;
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.6;
uniform float sheen : hint_range(0.0, 1.0) = 0.5;
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform vec3 glow_color : source_color = vec3(0.4, 0.9, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;   // attack flush toward flash_color
uniform vec3 flash_color : source_color = vec3(1.0, 0.25, 0.15);

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
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float lit = exp(min(wy, 0.0) / 38.0);
	vec3 base = to_linear(COLOR.rgb);
	vec2 uv = UV;
	float mark = 0.0;
	if (pattern == 1) mark = smoothstep(0.35, 0.5, sin(uv.y * pattern_scale * 3.14159));
	else if (pattern == 2) {
		vec2 g = vec2(uv.x * pattern_scale * 0.7, uv.y * pattern_scale);
		vec2 c = floor(g); float r = hash(c);
		vec2 d = fract(g) - vec2(0.5) + (vec2(hash(c + 3.1), hash(c + 7.7)) - 0.5) * 0.5;
		mark = step(0.4, r) * (1.0 - smoothstep(0.12, 0.26, length(d)));
	}
	else if (pattern == 3) mark = smoothstep(0.55, 0.7, sin(uv.x * 6.28318 * pattern_scale * 0.25 + sin(uv.y * 9.0) * 0.5));
	else if (pattern == 4) mark = smoothstep(0.5, 0.65, vnoise(vec2(uv.x * pattern_scale * 0.8, uv.y * pattern_scale)));
	else if (pattern == 5) {
		vec2 g = vec2(uv.x * pattern_scale * 0.6, uv.y * pattern_scale);
		vec2 f = fract(g) - 0.5;
		mark = smoothstep(0.38, 0.5, max(abs(f.x), abs(f.y)));
	}
	else if (pattern == 6) mark = smoothstep(0.45, 0.55, sin(uv.y * pattern_scale * 6.28318));
	vec3 col = mix(base, to_linear(pattern_color), mark * pattern_strength);
	col = mix(col, col * flash_color * 1.6, flash * 0.55);
	// Scale glints: tiny bright cells that catch the light.
	float scale_cell = vnoise(vec2(uv.x * 64.0, uv.y * 90.0));
	ROUGHNESS = mix(0.55, 0.22, sheen * smoothstep(0.55, 0.9, scale_cell));
	SPECULAR = 0.35 + 0.3 * sheen;
	ALBEDO = col * lit;
	EMISSION = to_linear(glow_color) * glow * mark + col * 0.05 * lit;
	RIM = 0.25 * sheen;
	RIM_TINT = 0.4;
}
