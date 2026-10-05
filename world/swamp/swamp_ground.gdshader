shader_type spatial;
uniform sampler2D mud_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_rough:filter_linear_mipmap,repeat_enable;
uniform sampler2D bank_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D bank_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
varying vec3 world_normal;
uniform vec3 mud_light:source_color=vec3(.43,.34,.26);
uniform vec3 mud_dark:source_color=vec3(.34,.28,.24);
uniform vec3 bank_light:source_color=vec3(.43,.52,.34);
uniform vec3 bank_dark:source_color=vec3(.32,.43,.32);
uniform vec3 rock_tone:source_color=vec3(.39,.38,.37);
uniform vec3 rock_dark:source_color=vec3(.28,.27,.26);
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment(){
    float dry=smoothstep(-.12,.65,world.y);
    float patch=sin(world.x*.23+sin(world.z*.16))+cos(world.z*.19);
    float tone=smoothstep(.2,.65,patch);
    vec3 mud=mix(mud_dark,mud_light,tone);
    vec3 bank=mix(bank_dark,bank_light,tone);
    vec3 terrain=mix(mud,bank,dry);
    // Wooded margin hills rise well above the wetland's own height range; let their steep faces go bare rock.
    float steepness=1.0-clamp(world_normal.y,0.0,1.0);
    float rockiness=smoothstep(.35,.65,steepness)*smoothstep(1.3,3.5,world.y);
    vec3 rock=mix(rock_dark,rock_tone,tone);
    terrain=mix(terrain,rock,rockiness);
    ALBEDO=terrain;
    ROUGHNESS=mix(.95,.8,rockiness);SPECULAR=.12;
}
