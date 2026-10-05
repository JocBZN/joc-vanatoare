shader_type spatial;
uniform sampler2D mud_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_rough:filter_linear_mipmap,repeat_enable;
uniform sampler2D bank_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D bank_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 uv=world.xz*.36;
    float dry=smoothstep(-.12,.65,world.y);
    vec3 mud=mix(texture(mud_color,uv).rgb,texture(mud_color,uv*.31).rgb,.18);
    float macro=.82+.12*sin(world.x*.07+cos(world.z*.04));
    ALBEDO=mix(mud*vec3(.48,.53,.43),texture(bank_color,uv*.7).rgb*vec3(.57,.63,.46),dry*.68)*macro;
    NORMAL_MAP=mix(texture(mud_normal,uv).rgb,texture(bank_normal,uv*.7).rgb,dry*.5);
    NORMAL_MAP_DEPTH=.7;
    ROUGHNESS=mix(.19,texture(mud_rough,uv).g,dry);
    SPECULAR=.55;
}
