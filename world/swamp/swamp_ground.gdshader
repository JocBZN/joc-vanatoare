shader_type spatial;
uniform sampler2D mud_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D mud_rough:filter_linear_mipmap,repeat_enable;
uniform sampler2D bank_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D bank_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
varying vec3 world_normal;
uniform vec3 mud_light:source_color=vec3(.38,.285,.18);
uniform vec3 mud_dark:source_color=vec3(.22,.16,.105);
uniform vec3 bank_light:source_color=vec3(.43,.52,.34);
uniform vec3 bank_dark:source_color=vec3(.32,.43,.32);
uniform vec3 rock_tone:source_color=vec3(.39,.38,.37);
uniform vec3 rock_dark:source_color=vec3(.28,.27,.26);
uniform float water_level = 0.0;
#include "res://world/effects/sediment_surface.gdshaderinc"
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment(){
    // Fully brown below the waterline; grass starts gradually on the higher bank.
    float dry=smoothstep(water_level + .06,water_level + .65,world.y);
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
    float roughness=mix(.95,.8,rockiness);
    float specular=.12;
    float sediment_amount=1.0-dry;
    if (sediment_amount > 0.001) {
        vec2 mud_uv=world.xz*.20;
        vec3 mud_sample=texture(mud_color,mud_uv).rgb;
        float silt=sediment_noise(world.xz*.65)*.65+sediment_noise(world.xz*2.2)*.35;
        vec3 silt_color=mix(mud_dark,mud_light,silt);
        // Reuse the licensed soil scan for clumps/pebbles with an earthy brown tint.
        vec3 sediment=mix(silt_color,mud_sample*vec3(1.10,.88,.65),.65);
        sediment*=1.0+(sediment_grain(world.xz,36.0)-.5)*.09;
        float wetness=1.0-smoothstep(water_level-.08,water_level+.24,world.y);
        sediment*=mix(1.0,.81,wetness);
        terrain=mix(terrain,sediment,sediment_amount);
        float scan_roughness=texture(mud_rough,mud_uv).g;
        roughness=mix(roughness,mix(.89,.48+scan_roughness*.12,wetness),sediment_amount);
        specular=mix(specular,mix(.13,.26,wetness),sediment_amount);
        vec2 bump=(texture(mud_normal,mud_uv).rg*2.0-1.0)*.16;
        vec3 sediment_normal=normalize(world_normal+vec3(bump.x,0.0,bump.y)*sediment_amount);
        NORMAL=normalize((VIEW_MATRIX*vec4(sediment_normal,0.0)).xyz);
    }
    ALBEDO=terrain;
    ROUGHNESS=roughness;SPECULAR=specular;
}
