shader_type spatial;
uniform vec3 grass_light:source_color=vec3(.43,.55,.29);
uniform vec3 grass_mid:source_color=vec3(.36,.47,.26);
uniform vec3 grass_dark:source_color=vec3(.30,.40,.25);
uniform vec3 trail_tone:source_color=vec3(.63,.48,.32);
uniform vec3 rock_tone:source_color=vec3(.42,.40,.38);
uniform vec3 rock_dark:source_color=vec3(.3,.29,.27);
uniform vec3 snow_tone:source_color=vec3(.86,.88,.87);
varying vec3 world;
varying vec3 world_normal;
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
    ALBEDO=terrain;
    ROUGHNESS=mix(.95,.78,rockiness);SPECULAR=.12;
}
