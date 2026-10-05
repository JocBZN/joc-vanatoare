shader_type spatial;
render_mode cull_disabled, diffuse_toon;
uniform sampler2D color_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap;
uniform sampler2D mask_map : filter_linear_mipmap;
uniform bool use_mask=false;
uniform bool packed_rough=false;
uniform bool solid_leaf=false;
uniform vec3 leaf_light : source_color=vec3(.46,.60,.35);
uniform vec3 leaf_mid : source_color=vec3(.29,.45,.33);
uniform vec3 leaf_dark : source_color=vec3(.18,.32,.28);
uniform float wind_strength=.04;
varying float variation;
void vertex(){
    vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float bend=clamp(VERTEX.y,0.0,3.0);
    float wind=sin(TIME*1.3+world.x*.21+world.z*.13)+sin(TIME*2.4+world.x*.7)*.3;
    VERTEX.x+=wind*wind_strength*bend;VERTEX.z+=cos(TIME+world.z*.3)*wind_strength*bend*.5;
    variation=.94+.06*sin(MODEL_MATRIX[3].x*.37+MODEL_MATRIX[3].z*.81);
}
void fragment(){
    vec4 color=texture(color_map,UV);
    float value=dot(color.rgb,vec3(.3,.5,.2));
    ALBEDO=(solid_leaf?COLOR.rgb:value>.42?leaf_light:value>.22?leaf_mid:leaf_dark)*variation;
    ALPHA=solid_leaf?1.0:use_mask?texture(mask_map,UV).r:color.a;
    ALPHA_SCISSOR_THRESHOLD=.32;

    ROUGHNESS=.95;SPECULAR=.12;
    BACKLIGHT=ALBEDO*.12;
}
