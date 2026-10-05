shader_type spatial;
render_mode diffuse_toon;

uniform vec4 olive : source_color = vec4(0.39, 0.49, 0.20, 1.0);
uniform vec4 moss : source_color = vec4(0.23, 0.35, 0.16, 1.0);
uniform vec4 sand : source_color = vec4(0.70, 0.59, 0.33, 1.0);
uniform vec4 charcoal : source_color = vec4(0.08, 0.11, 0.075, 1.0);
uniform float pattern_scale = 1.3;
uniform sampler2D weave_normal:hint_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D weave_rough:filter_linear_mipmap,repeat_enable;
varying vec3 object_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), f.x),
		mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), f.x),
		mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	object_position = VERTEX;
}
void fragment() {
	vec3 p = object_position * pattern_scale;
	float n = noise(p + vec3(noise(p * 0.7) * 2.0));
	vec3 c = olive.rgb;
	if (n < 0.34) { c = charcoal.rgb; }
	else if (n < 0.48) { c = moss.rgb; }
	else if (n > 0.64) { c = sand.rgb; }
	ALBEDO = c;
	ROUGHNESS=1.0;SPECULAR=.1;
}
