shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, world_vertex_coords;
// The open-ocean surface. Rolling swells in the vertex stage (three summed sine
// waves, mirrored by OceanMap.wave_height), capillary detail and foam from
// textures in the fragment stage, depth-based colour and refraction, white caps,
// shore foam, and a Snell's-window look for anyone swimming under it. A clipmap
// of rings (OceanMap) carries this material; all coordinates are world metres.
uniform vec3 shallow_color : source_color = vec3(0.14, 0.78, 0.78);
uniform vec3 deep_color : source_color = vec3(0.01, 0.16, 0.34);
uniform vec3 foam_color : source_color = vec3(0.96, 0.99, 1.0);
uniform vec3 under_color : source_color = vec3(0.02, 0.30, 0.38);
uniform vec3 sky_window : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 absorption = vec3(0.34, 0.08, 0.045);
uniform float depth_density : hint_range(0.02, 1.0) = 0.13;
uniform float wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.22;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.035;
uniform float roughness_base : hint_range(0.02, 0.5) = 0.06;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_texture : filter_linear_mipmap, repeat_enable;
uniform float wave_time = 0.0;
// (world x, world z, start time, amplitude): footsteps, strokes and the hull's wake.
uniform vec4 ripple_events[8];

varying vec3 wpos;
varying float crest;

// Height and X/Z gradient of the swell. Keep the constants in sync with OceanMap.
vec3 swell(vec2 p, float t, float detail) {
	vec2 d0 = normalize(vec2(0.93, 0.37));
	vec2 d1 = normalize(vec2(0.42, 0.91));
	vec2 d2 = normalize(vec2(-0.8, 0.6));
	float k0 = TAU / 52.0; float k1 = TAU / 27.0; float k2 = TAU / 13.0;
	float p0 = dot(p, d0) * k0 + t * 1.088;
	float p1 = dot(p, d1) * k1 + t * 1.51;
	float p2 = dot(p, d2) * k2 + t * 2.17;
	float a0 = 0.30; float a1 = 0.16; float a2 = 0.07 * detail;
	float h = sin(p0) * a0 + sin(p1) * a1 + sin(p2) * a2;
	vec2 g = d0 * cos(p0) * k0 * a0 + d1 * cos(p1) * k1 * a1 + d2 * cos(p2) * k2 * a2;
	return vec3(h, g) * wave_strength;
}

vec3 ripple_wave(vec2 position, float time) {
	vec3 result = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 event = ripple_events[i];
		float age = time - event.z;
		if (event.w > 0.0 && age >= 0.0 && age < 5.0) {
			vec2 delta = position - event.xy;
			float radius = length(delta);
			float front = radius - age * 1.5;
			float envelope = exp(-front * front * 1.6 - age * 0.8) * smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(4.0, 5.0, age));
			float phase = radius * 8.0 - age * 12.0;
			float amplitude = event.w * envelope;
			float derivative = amplitude * (8.0 * cos(phase) - 3.2 * front * sin(phase));
			result.x += amplitude * sin(phase);
			result.yz += delta / max(radius, 0.025) * derivative;
		}
	}
	return result;
}

vec3 view_position(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	#endif
	vec4 v = inverse_projection * vec4(ndc, 1.0);
	return v.xyz / max(v.w, 0.00001);
}

void vertex() {
	float dist = length(VERTEX.xz - CAMERA_POSITION_WORLD.xz);
	// Small waves fade out with distance: the far rings are too coarse to carry them.
	float detail = 1.0 - smoothstep(90.0, 240.0, dist);
	vec3 s = swell(VERTEX.xz, wave_time, detail);
	VERTEX.y += s.x;
	NORMAL = normalize(vec3(-s.y, 1.0, -s.z));
	wpos = VERTEX;
	crest = s.x;
}

void fragment() {
	float dist_cam = length(wpos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(90.0, 240.0, dist_cam);
	vec3 s = swell(wpos.xz, wave_time, detail);
	vec2 flow = normalize(vec2(0.93, 0.37));
	vec2 broad_uv = wpos.xz * 0.045 + flow * wave_time * 0.012;
	vec2 detail_uv = vec2(wpos.z, -wpos.x) * 0.31 + vec2(-0.017, 0.012) * wave_time;
	vec2 broad_n = texture(normal_map, broad_uv).rg * 2.0 - 1.0;
	vec2 detail_n = texture(detail_normal, detail_uv).rg * 2.0 - 1.0;
	vec2 tex_n = (broad_n * 0.7 + vec2(-detail_n.y, detail_n.x) * 0.4) * detail;
	vec3 ripples = ripple_wave(wpos.xz, wave_time);
	vec2 gradient = s.yz + ripples.yz;
	vec3 world_normal = normalize(vec3(tex_n.x * normal_strength - gradient.x, 1.0, tex_n.y * normal_strength - gradient.y));

	if (!FRONT_FACING) {
		// Seen from below: a bright window straight up, a mirror of the dark sea beyond.
		vec3 wn = -world_normal;
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - wpos);
		float facing = clamp(dot(-wn, to_cam), 0.0, 1.0);
		float window = smoothstep(0.42, 0.78, facing);
		float shimmer = 0.85 + 0.15 * sin(wpos.x * 0.9 + wave_time * 1.7) * sin(wpos.z * 0.8 - wave_time * 1.3);
		ALBEDO = vec3(0.0);
		EMISSION = mix(under_color * 0.55, sky_window * 1.15 * shimmer, window);
		ROUGHNESS = 0.2;
		SPECULAR = 0.0;
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		ALPHA = 0.97;
	} else {
		vec3 floor_view = view_position(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
		vec3 floor_world = (INV_VIEW_MATRIX * vec4(floor_view, 1.0)).xyz;
		float vertical_depth = max(0.0, wpos.y - floor_world.y);
		float optical_depth = clamp(-floor_view.z + VERTEX.z, 0.0, 70.0);
		vec3 view_normal = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
		NORMAL = view_normal;
		float fresnel = 0.0204 + (1.0 - 0.0204) * pow(1.0 - clamp(dot(view_normal, VIEW), 0.0, 1.0), 5.0);
		vec2 distortion = view_normal.xy * refraction_strength * (1.0 - exp(-vertical_depth * 1.5)) / (1.0 + max(-VERTEX.z, 0.0) * 0.02);
		vec2 refracted_uv = clamp(SCREEN_UV + distortion, vec2(0.002), vec2(0.998));
		vec3 refracted_view = view_position(refracted_uv, texture(depth_texture, refracted_uv).r, INV_PROJECTION_MATRIX);
		vec3 refracted_world = (INV_VIEW_MATRIX * vec4(refracted_view, 1.0)).xyz;
		if (-refracted_view.z < -VERTEX.z + 0.03 || refracted_world.y > wpos.y + 0.04) refracted_uv = SCREEN_UV;
		vec3 below = textureLod(screen_texture, refracted_uv, 0.0).rgb;
		vec3 transmission = exp(-absorption * optical_depth * depth_density);
		vec3 tint = mix(shallow_color, deep_color, 1.0 - exp(-vertical_depth * 0.16));

		vec2 foam_uv = wpos.xz * 0.37 + vec2(0.011, -0.008) * wave_time;
		float foam_noise = texture(foam_texture, foam_uv).r;
		float foam_noise2 = texture(foam_texture, wpos.xz * 0.11 - vec2(0.006, 0.009) * wave_time).r;
		// Surf along every coast and reef, white caps on the highest crests, wake foam from ripples.
		float shore = (1.0 - smoothstep(0.1, 1.6, vertical_depth)) * smoothstep(0.02, 0.2, vertical_depth);
		float shore_foam = shore * smoothstep(0.35, 0.8, foam_noise * 0.65 + foam_noise2 * 0.5 + 0.2 * sin(wave_time * 1.4 + vertical_depth * 6.0));
		float cap = smoothstep(0.34, 0.5, crest) * smoothstep(0.45, 0.8, foam_noise) * detail;
		float splash = smoothstep(0.15, 0.5, length(ripples.yz)) * smoothstep(0.35, 0.8, foam_noise) * 0.4;
		float foam = clamp(shore_foam * 0.9 + cap * 0.7 + splash, 0.0, 0.95);

		ALBEDO = mix(tint * (vec3(1.0) - transmission) * 0.5 * (1.0 - fresnel), foam_color * 0.85, foam);
		EMISSION = below * transmission * (1.0 - fresnel) * (1.0 - foam);
		METALLIC = 0.0;
		SPECULAR = 0.3571;
		ROUGHNESS = clamp(roughness_base + foam * 0.5, 0.03, 0.7);
		ALPHA = smoothstep(0.0, 0.09, vertical_depth) + foam * 0.2;
		ALPHA = clamp(ALPHA, 0.0, 1.0);
	}
}
