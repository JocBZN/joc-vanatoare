shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// A school of small fish drawn from one MultiMesh. Every instance sits at the
// school's centre; INSTANCE_CUSTOM carries (phase, orbit radius, speed, bob) and
// this shader swims it round a lazy loop, banking along the path, with a tail
// that beats. Purely cosmetic and local: nothing is replicated.
uniform float school_scale = 1.0;
varying float wy;
vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float radius = INSTANCE_CUSTOM.y;
	float speed = INSTANCE_CUSTOM.z;
	float bob = INSTANCE_CUSTOM.w;
	float angle = TIME * speed + phase;
	vec3 offset = vec3(cos(angle) * radius, sin(TIME * 0.6 + phase * 3.0) * bob + sin(angle * 2.0) * bob * 0.4, sin(angle * 1.3) * radius * 0.8);
	vec3 tangent = normalize(vec3(-sin(angle) * radius, 0.0, cos(angle * 1.3) * radius * 1.04));
	// The fish points along -Z, so turn -Z onto the direction of travel.
	float yaw = atan(-tangent.x, -tangent.z);
	float c = cos(yaw); float s = sin(yaw);
	vec3 v = VERTEX * school_scale;
	// Tail beat grows toward the tail (+Z).
	v.x += sin(TIME * 11.0 + phase * 6.0 + v.z * 5.0) * 0.1 * clamp(v.z + 0.4, 0.0, 1.0) * school_scale;
	VERTEX = vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z) + offset;
	NORMAL = vec3(c * NORMAL.x + s * NORMAL.z, NORMAL.y, -s * NORMAL.x + c * NORMAL.z);
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float lit = exp(min(wy, 0.0) / 38.0);
	ALBEDO = to_linear(COLOR.rgb) * lit;
	EMISSION = to_linear(COLOR.rgb) * 0.12 * lit;
	ROUGHNESS = 0.35;
	METALLIC = 0.35;
	SPECULAR = 0.7;
	RIM = 0.3;
}
