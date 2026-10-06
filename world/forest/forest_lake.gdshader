shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, world_vertex_coords;

// Clear lake water: light penetrates the shallows, while depth absorbs red first.
uniform vec3 deep_color : source_color = vec3(0.045, 0.205, 0.235);
uniform vec3 shallow_color : source_color = vec3(0.18, 0.42, 0.36);
uniform vec3 foam_color : source_color = vec3(0.81, 0.89, 0.84);
uniform vec3 absorption = vec3(0.62, 0.28, 0.20);
uniform float depth_density : hint_range(0.1, 4.0) = 0.85;
uniform float wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float wave_spatial_scale : hint_range(0.1, 2.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.24;
uniform float surface_roughness : hint_range(0.04, 0.8) = 0.14;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.46;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.025;
uniform vec2 lake_center = vec2(0.0);
uniform float lake_radius = 70.0;
uniform float lake_shore = 26.0;

float water_coverage(vec2 position) {
    float radius = length(position - lake_center);
    return 1.0 - smoothstep(lake_radius + lake_shore * 0.55, lake_radius + lake_shore, radius);
}

#include "res://world/effects/natural_water.gdshaderinc"
