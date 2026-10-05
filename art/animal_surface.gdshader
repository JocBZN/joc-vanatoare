shader_type spatial;
render_mode cull_disabled;
uniform sampler2D coat:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D detail:hint_normal,filter_linear_mipmap,repeat_enable;
uniform vec4 tint:source_color=vec4(1.0);
uniform float back_darkening=.28;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
    vec4 color=texture(coat,UV);
    float back=smoothstep(.3,1.0,local_position.y);
    float strand=sin(UV.x*390.0+sin(UV.y*95.0)*1.7)*.018;
    ALBEDO=color.rgb*tint.rgb*(1.0-back*back_darkening)*(1.0+strand);
    NORMAL_MAP=texture(detail,UV*12.0).rgb;
    NORMAL_MAP_DEPTH=.13;
    ROUGHNESS=.9;SPECULAR=.22;
}
