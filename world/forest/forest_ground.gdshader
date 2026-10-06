shader_type spatial;
uniform vec3 grass_light:source_color=vec3(.43,.55,.29);
uniform vec3 grass_mid:source_color=vec3(.36,.47,.26);
uniform vec3 grass_dark:source_color=vec3(.30,.40,.25);
uniform vec3 trail_tone:source_color=vec3(.63,.48,.32);
uniform vec3 rock_tone:source_color=vec3(.42,.40,.38);
uniform vec3 rock_dark:source_color=vec3(.3,.29,.27);
uniform vec3 snow_tone:source_color=vec3(.86,.88,.87);
uniform vec3 sand_light : source_color = vec3(0.82, 0.75, 0.59);
uniform vec3 sand_dark : source_color = vec3(0.62, 0.53, 0.37);
uniform vec2 lake_center = vec2(190.0, 160.0);
uniform float lake_radius = 72.0;
uniform float lake_shore = 26.0;
uniform float lake_level = -3.0;
varying vec3 world;
varying vec3 world_normal;
#include "res://world/effects/sediment_surface.gdshaderinc"
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment(){
    float road_x=sin(world.z*.012)*28.0*smoothstep(35.0,80.0,abs(world.z));
    float road=(1.0-smoothstep(3.5,5.5,abs(world.x-road_x)))*smoothstep(32.0,42.0,length(world.xz));
    float clearing=1.0-smoothstep(10.0,18.0,length(world.xz));
    float blend=max(road,clearing);
    float patches=sin(world.x*.18+sin(world.z*.13)*1.5)+cos(world.z*.21);
    vec3 grass=mix(grass_dark,grass_mid,smoothstep(-.9,-.35,patches));
    grass=mix(grass,grass_light,smoothstep(.55,.85,patches));
    float strokes=smoothstep(.87,.95,sin(world.x*.8+sin(world.z*.55)))*.01;
    vec3 ground_color=mix(grass+strokes,trail_tone+strokes,blend);
    // Mountains: bare rock where the ground steepens, a pale cap once it climbs high enough.
    float steepness=1.0-clamp(world_normal.y,0.0,1.0);
    float rockiness=smoothstep(.32,.62,steepness);
    vec3 rock=mix(rock_dark,rock_tone,smoothstep(-.4,.6,patches));
    vec3 terrain=mix(ground_color,rock,rockiness);
    float altitude=smoothstep(19.0,30.0,world.y-rockiness*4.0);
    terrain=mix(terrain,snow_tone,altitude*smoothstep(.1,.5,steepness+.25));
    float roughness = mix(.95,.78,rockiness);
    float specular = .12;
    // The basin has sand below its nominal water plane and a damp sandy bank.
    // Other forest lowlands keep their grass even if their altitude is below -3.
    float lake_zone = 1.0 - smoothstep(lake_radius + lake_shore,
        lake_radius + lake_shore + 7.0, length(world.xz - lake_center));
    float sand_amount = lake_zone * (1.0 - smoothstep(lake_level + 0.06, lake_level + 0.70, world.y));
    if (sand_amount > 0.001) {
        float broad = sediment_noise(world.xz * 0.38);
        float medium = sediment_noise(world.xz * 2.1);
        float grain = sediment_grain(world.xz, 52.0);
        float wetness = 1.0 - smoothstep(lake_level - 0.10, lake_level + 0.22, world.y);
        vec2 ripple_direction = normalize(vec2(0.83, 0.56));
        float phase = dot(world.xz, ripple_direction) * (TAU / 0.38) + broad * 1.1;
        float ripple_visibility = 1.0 - smoothstep(0.5, 2.0, fwidth(phase));
        float ripple_tone = sin(phase) * 0.028 * ripple_visibility;
        vec3 sand = mix(sand_dark, sand_light, 0.28 + broad * 0.42 + medium * 0.22);
        sand *= 1.0 + (grain - 0.5) * 0.16 + ripple_tone;
        sand *= mix(1.0, 0.78, wetness);
        terrain = mix(terrain, sand, sand_amount);
        roughness = mix(roughness, mix(0.94, 0.66, wetness), sand_amount);
        specular = mix(specular, mix(0.13, 0.25, wetness), sand_amount);
        // Small current-shaped ridges perturb lighting, without moving collision.
        vec2 slope = ripple_direction * cos(phase) * 0.006 * (TAU / 0.38) * ripple_visibility;
        vec3 sand_normal = normalize(world_normal + vec3(-slope.x, 0.0, -slope.y) * sand_amount);
        NORMAL = normalize((VIEW_MATRIX * vec4(sand_normal, 0.0)).xyz);
    }
    ALBEDO=terrain;
    ROUGHNESS=roughness;SPECULAR=specular;
}
