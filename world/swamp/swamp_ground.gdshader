shader_type spatial;
uniform sampler2D mud_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_rough:filter_linear_mipmap,repeat_enable;
uniform sampler2D bank_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D bank_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
uniform vec3 mud_light:source_color=vec3(.43,.34,.26);
uniform vec3 mud_dark:source_color=vec3(.34,.28,.24);
uniform vec3 bank_light:source_color=vec3(.43,.52,.34);
uniform vec3 bank_dark:source_color=vec3(.32,.43,.32);
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    float dry=smoothstep(-.12,.65,world.y);
    float patch=sin(world.x*.23+sin(world.z*.16))+cos(world.z*.19);
    float tone=smoothstep(.2,.65,patch);
    vec3 mud=mix(mud_dark,mud_light,tone);
    vec3 bank=mix(bank_dark,bank_light,tone);
    ALBEDO=mix(mud,bank,dry);
    ROUGHNESS=.95;SPECULAR=.12;
}
