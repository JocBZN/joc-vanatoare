shader_type spatial;
uniform vec4 leaf_color : source_color = vec4(0.13, 0.24, 0.16, 1.0);
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    float sway = sin(TIME*0.85 + world.x*0.22 + world.z*0.16);
    VERTEX.x += sway * max(VERTEX.y,0.0) * 0.018;
}
void fragment() { ALBEDO = leaf_color.rgb; ROUGHNESS = 1.0; }
