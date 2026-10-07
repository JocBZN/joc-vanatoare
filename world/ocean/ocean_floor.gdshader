shader_type spatial;
render_mode cull_back, diffuse_burley;
// Seabed and island ground in one procedural material: ripple-marked sand that
// darkens and turns blue with depth, wet sand along the tide line, beach,
// grass and jungle on the island tops, bare rock on steep faces, and animated
// caustic light on everything below the surface.
uniform float wave_time = 0.0;
uniform vec3 sand_light : source_color = vec3(0.86, 0.74, 0.5);
uniform vec3 sand_deep : source_color = vec3(0.50, 0.55, 0.52);
uniform vec3 rock_color : source_color = vec3(0.38, 0.36, 0.34);
uniform vec3 grass_color : source_color = vec3(0.25, 0.47, 0.17);
uniform vec3 jungle_color : source_color = vec3(0.12, 0.31, 0.12);
uniform float water_level = 0.0;

varying vec3 wpos;
varying vec3 wnormal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += vnoise(p) * a; p = p * 2.03 + 17.1; a *= 0.5; }
	return v;
}
// The classic folded-sine caustic web, cheap enough for every submerged fragment.
float caustic(vec2 uv, float t) {
	vec2 p = mod(uv * TAU, TAU) - 250.0;
	vec2 i = p; float c = 1.0; float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0; c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float h = wpos.y - water_level;
	float slope = 1.0 - clamp(wnormal.y, 0.0, 1.0);
	float broad = fbm(wpos.xz * 0.035);
	float fine = fbm(wpos.xz * 0.6);
	float ripples = sin(dot(wpos.xz, vec2(0.8, 0.6)) * 1.9 + broad * 9.0) * 0.5 + 0.5;
	vec3 sand = mix(sand_light, sand_deep, smoothstep(-1.0, -26.0, h));
	sand *= 0.88 + 0.12 * ripples * smoothstep(0.5, -3.0, h) + (fine - 0.5) * 0.18;
	// Wet sand, a darker band that follows the water line.
	float wet = 1.0 - smoothstep(0.0, 0.9, abs(h - 0.15));
	sand = mix(sand, sand * vec3(0.62, 0.58, 0.5), wet);
	vec3 col = sand;
	// Dry land: beach, then grass, then dense jungle on the heights.
	float dry = smoothstep(1.2, 2.2, h + broad * 1.7 - 0.55 + (fine - 0.5) * 0.6);
	vec3 plant = mix(grass_color, jungle_color, smoothstep(2.5, 9.0, h + (fine - 0.5) * 3.0));
	plant *= 0.85 + fine * 0.35;
	col = mix(col, plant, dry * (1.0 - smoothstep(0.38, 0.62, slope)));
	// Steep faces are bare rock, with sea-green slime where it is wet.
	float rock_mix = smoothstep(0.34, 0.6, slope + (fine - 0.5) * 0.12);
	vec3 rock = rock_color * (0.8 + fine * 0.5);
	rock = mix(rock, rock * vec3(0.55, 0.8, 0.6), smoothstep(0.5, -4.0, h));
	col = mix(col, rock, rock_mix);
	// Depth takes the red out and the light with it.
	float deep = smoothstep(-0.5, -20.0, h);
	col = mix(col, col * vec3(0.32, 0.62, 0.78), deep);
	float below = 1.0 - smoothstep(-0.2, 0.2, h);
	float c = 0.0;
	if (below > 0.01) {
		c = caustic(wpos.xz * 0.12, wave_time * 0.55) * (1.0 - smoothstep(-0.5, -22.0, h)) * below;
		c += caustic(wpos.xz * 0.21 + 3.7, wave_time * 0.4) * 0.5 * (1.0 - smoothstep(-0.5, -15.0, h)) * below;
	}
	// Light is absorbed with depth: about 1/e every 38 m.
	float lit = exp(min(h, 0.0) / 38.0);
	ALBEDO = col * mix(1.0, lit, step(h, 0.0));
	EMISSION = vec3(0.55, 0.85, 0.8) * c * 0.38 * col * lit;
	ROUGHNESS = mix(0.95, 0.75, wet);
	SPECULAR = 0.2;
}
