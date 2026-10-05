shader_type spatial;
render_mode cull_disabled, diffuse_toon;
uniform vec3 reed_base : source_color=vec3(.30,.43,.28);
uniform vec3 reed_tip : source_color=vec3(.55,.63,.39);
void vertex(){
    vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.x+=sin(TIME*1.4+w.x*.3+w.z*.13)*.06*max(0.0,VERTEX.y);
}
void fragment(){
    float vein=smoothstep(.76,.90,abs(sin(UV.x*8.0)))*.012;
    ALBEDO=mix(reed_base,reed_tip,clamp(UV.y,0.0,1.0)) + vein;
    ROUGHNESS=.92;SPECULAR=.12;BACKLIGHT=ALBEDO*.12;
}
