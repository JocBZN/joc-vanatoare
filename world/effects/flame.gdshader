shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float flame_height = 10.0;
uniform float phase = 0.0;
uniform float strength = 0.75;
uniform vec4 bottom_color : source_color = vec4(1.0, 0.54, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.13, 0.01, 1.0);
varying float height_fraction;

void vertex() {
	height_fraction = clamp(VERTEX.y / flame_height + 0.5, 0.0, 1.0);
	float bend = height_fraction * height_fraction;
	VERTEX.x += sin(TIME * 2.2 + height_fraction * 5.0 + phase) * bend * 0.65;
	VERTEX.z += cos(TIME * 1.7 + height_fraction * 3.0 + phase) * bend * 0.4;
	VERTEX.xz *= 1.0 + sin(TIME * 3.6 + phase + VERTEX.y) * 0.075;
}
void fragment() {
	float t = smoothstep(0.05, 0.95, height_fraction);
	float tongues = sin(UV.x * 43.0 + TIME * 3.1 + phase + t * 11.0);
	float ribbon = sin(UV.x * 87.0 - TIME * 4.3 + t * 27.0);
	float heat = 0.76 + tongues * 0.16 + ribbon * 0.08;
	ALBEDO = mix(bottom_color.rgb, tip_color.rgb, t) * (0.9 + heat * 0.25);
	ALPHA = strength * heat * (1.0 - smoothstep(0.68 + tongues * 0.08, 1.0, height_fraction));
}
