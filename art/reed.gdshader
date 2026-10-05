shader_type spatial;
render_mode cull_disabled;
void vertex(){
    vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.x+=sin(TIME*1.4+w.x*.3+w.z*.13)*.06*max(0.0,VERTEX.y);
}
void fragment(){
    float vein=pow(abs(sin(UV.x*22.0)),5.0)*.09;
    ALBEDO=mix(vec3(.12,.21,.07),vec3(.28,.32,.12),UV.y*.5)+vein;
    ROUGHNESS=.83;BACKLIGHT=ALBEDO*.2;
}
