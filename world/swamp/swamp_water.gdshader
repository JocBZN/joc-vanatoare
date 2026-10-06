shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, world_vertex_coords;

// Organic sediment gives the marsh a denser olive/teal tint and a calmer surface.
uniform vec3 deep_color : source_color = vec3(0.07, 0.15, 0.12);
uniform vec3 shallow_color : source_color = vec3(0.28, 0.36, 0.25);
uniform vec3 foam_color : source_color = vec3(0.72, 0.78, 0.64);
uniform vec3 absorption = vec3(0.92, 0.68, 0.85);
uniform float depth_density : hint_range(0.1, 4.0) = 1.45;
uniform float wave_strength : hint_range(0.0, 2.0) = 0.55;
uniform float wave_spatial_scale : hint_range(0.1, 2.0) = 0.22;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.18;
uniform float surface_roughness : hint_range(0.04, 0.8) = 0.22;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.27;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.018;

float water_coverage(vec2 position) {
    return 1.0;
}

#include "res://world/effects/natural_water.gdshaderinc"
