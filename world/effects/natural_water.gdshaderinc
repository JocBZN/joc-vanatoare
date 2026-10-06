// Shared lake/marsh surface. All distances are in world metres.
// Reconstruct depth using Godot's renderer-specific NDC range; screen refraction
// contains opaque geometry only, so depth checks reject foreground silhouettes.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_texture : filter_linear_mipmap, repeat_enable;
uniform vec2 wind_direction = vec2(0.93, 0.37);
uniform float wave_time = 0.0;
// (world x, world z, start time, amplitude). Zero amplitude means unused.
uniform vec4 ripple_events[8];

varying vec3 water_world_position;

// Height and its analytic X/Z derivatives. Fine texture normals add capillary
// detail independently of mesh tessellation, avoiding a faceted or striped lake.
vec3 water_wind_wave(vec2 position, float time, bool fine_detail) {
    vec2 d0 = normalize(wind_direction + vec2(0.0001));
    vec2 d1 = normalize(vec2(0.42, 0.91));
    vec2 d2 = normalize(vec2(-0.8, 0.6));
    float k0 = TAU / 7.0 * wave_spatial_scale;
    float k1 = TAU / 3.7 * wave_spatial_scale;
    float k2 = TAU / 1.65 * wave_spatial_scale;
    float p0 = dot(position, d0) * k0 + time * 1.35;
    float p1 = dot(position, d1) * k1 - time * 1.7;
    float p2 = dot(position, d2) * k2 + time * 2.2;
    // Short capillary waves belong in pixel normals, below mesh grid resolution.
    float detail_amplitude = fine_detail ? 0.007 : 0.0;
    float height = sin(p0) * 0.032 + sin(p1) * 0.018 + sin(p2) * detail_amplitude;
    vec2 gradient = d0 * cos(p0) * k0 * 0.032
        + d1 * cos(p1) * k1 * 0.018 + d2 * cos(p2) * k2 * detail_amplitude;
    return vec3(height, gradient) * wave_strength;
}

vec3 water_interaction_wave(vec2 position, float time) {
    vec3 result = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        vec4 event = ripple_events[i];
        float age = time - event.z;
        if (event.w > 0.0 && age >= 0.0 && age < 5.0) {
            vec2 delta = position - event.xy;
            float radius = length(delta);
            float front_distance = radius - age * 1.35;
            // The ring expands away from its actual contact point and dies out.
            float envelope = exp(-front_distance * front_distance * 1.96 - age * 0.8)
                * smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(4.0, 5.0, age));
            float phase = radius * 9.0 - age * 12.0;
            float amplitude = event.w * envelope;
            float derivative = amplitude * (9.0 * cos(phase) - 3.92 * front_distance * sin(phase));
            result.x += amplitude * sin(phase);
            result.yz += delta / max(radius, 0.025) * derivative;
        }
    }
    return result;
}

vec3 water_view_position(vec2 screen_uv, float raw_depth, mat4 inverse_projection) {
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
        vec3 ndc = vec3(screen_uv, raw_depth) * 2.0 - 1.0;
    #else
        vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
    #endif
    vec4 view_position = inverse_projection * vec4(ndc, 1.0);
    return view_position.xyz / max(view_position.w, 0.00001);
}

void vertex() {
    // Contact rings are smaller than the terrain water grid: evaluate them in
    // fragment normals only, where they stay smooth and independent of geometry.
    vec3 surface = water_wind_wave(VERTEX.xz, wave_time, false);
    VERTEX.y += surface.x;
    NORMAL = normalize(vec3(-surface.y, 1.0, -surface.z));
    water_world_position = VERTEX;
}

void fragment() {
    float coverage = water_coverage(water_world_position.xz);
    if (coverage < 0.001) {
        discard;
    }

    vec3 floor_view = water_view_position(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
    vec3 floor_world = (INV_VIEW_MATRIX * vec4(floor_view, 1.0)).xyz;
    float vertical_depth = max(0.0, water_world_position.y - floor_world.y);
    float optical_depth = clamp(-floor_view.z + VERTEX.z, 0.0, 18.0);

    vec2 flow = normalize(wind_direction + vec2(0.0001));
    vec2 broad_uv = water_world_position.xz * 0.14 + flow * wave_time * 0.014;
    vec2 detail_uv = vec2(water_world_position.z, -water_world_position.x) * 0.43
        + vec2(-0.019, 0.013) * wave_time;
    vec2 broad_normal = texture(normal_map, broad_uv).rg * 2.0 - 1.0;
    vec2 detail_sample = texture(detail_normal, detail_uv).rg * 2.0 - 1.0;
    vec2 texture_normal = broad_normal * 0.72 + vec2(-detail_sample.y, detail_sample.x) * 0.36;
    vec3 wind_wave = water_wind_wave(water_world_position.xz, wave_time, true);
    vec3 interaction_wave = water_interaction_wave(water_world_position.xz, wave_time);
    vec2 gradient = wind_wave.yz + interaction_wave.yz;
    vec3 world_normal = normalize(vec3(texture_normal.x * normal_strength - gradient.x,
        1.0, texture_normal.y * normal_strength - gradient.y));
    vec3 view_normal = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
    NORMAL = view_normal;

    float fresnel = 0.0204 + (1.0 - 0.0204) * pow(1.0 - clamp(dot(view_normal, VIEW), 0.0, 1.0), 5.0);
    vec2 distortion = view_normal.xy * refraction_strength
        * (1.0 - exp(-vertical_depth * 2.0)) / (1.0 + max(-VERTEX.z, 0.0) * 0.025);
    vec2 refracted_uv = clamp(SCREEN_UV + distortion, vec2(0.002), vec2(0.998));
    vec3 refracted_view = water_view_position(refracted_uv, texture(depth_texture, refracted_uv).r, INV_PROJECTION_MATRIX);
    vec3 refracted_world = (INV_VIEW_MATRIX * vec4(refracted_view, 1.0)).xyz;
    // Never smear a bank, hunter or tree that lies in front of/above the water.
    if (-refracted_view.z < -VERTEX.z + 0.03 || refracted_world.y > water_world_position.y + 0.04) {
        refracted_uv = SCREEN_UV;
    }
    vec3 below_water = textureLod(screen_texture, refracted_uv, 0.0).rgb;
    vec3 transmission = exp(-absorption * optical_depth * depth_density);
    vec3 water_tint = mix(shallow_color, deep_color, 1.0 - exp(-vertical_depth * 0.7));

    vec2 foam_uv = water_world_position.xz * 0.61 + vec2(0.011, -0.008) * wave_time;
    float foam_noise = texture(foam_texture, foam_uv).r;
    float shore_band = (1.0 - smoothstep(0.09, 0.38, vertical_depth)) * smoothstep(0.015, 0.07, vertical_depth);
    float shore_foam = shore_band * smoothstep(0.28, 0.77, foam_noise) * foam_amount;
    float splash_foam = smoothstep(0.15, 0.45, length(interaction_wave.yz))
        * smoothstep(0.4, 0.8, foam_noise) * 0.16;
    float foam = clamp(shore_foam + splash_foam, 0.0, 0.8);

    // Refraction is already lit in the screen copy; emitting just its transmitted
    // component avoids lighting the lake bed twice. The engine supplies sky/sun
    // reflections using the actual water IOR (F0 = 0.0204) through its PBR surface.
    ALBEDO = mix(water_tint * (vec3(1.0) - transmission) * 0.55 * (1.0 - fresnel), foam_color, foam);
    EMISSION = below_water * transmission * (1.0 - fresnel) * (1.0 - foam);
    METALLIC = 0.0;
    // Godot maps dielectric F0 to 0.16 * SPECULAR squared.
    SPECULAR = 0.3571;
    ROUGHNESS = clamp(surface_roughness + foam * 0.45, 0.04, 0.75);
    ALPHA = coverage * smoothstep(0.0, 0.065, vertical_depth);
}
