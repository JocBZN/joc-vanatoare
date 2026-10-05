shader_type spatial;
uniform vec3 grass_light:source_color=vec3(.43,.55,.29);
uniform vec3 grass_mid:source_color=vec3(.36,.47,.26);
uniform vec3 grass_dark:source_color=vec3(.30,.40,.25);
uniform vec3 trail_tone:source_color=vec3(.63,.48,.32);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    float road_x=sin(world.z*.012)*28.0*smoothstep(35.0,80.0,abs(world.z));
    float road=(1.0-smoothstep(3.5,5.5,abs(world.x-road_x)))*smoothstep(32.0,42.0,length(world.xz));
    float clearing=1.0-smoothstep(10.0,18.0,length(world.xz));
    float blend=max(road,clearing);
    float patches=sin(world.x*.18+sin(world.z*.13)*1.5)+cos(world.z*.21);
    vec3 grass=mix(grass_dark,grass_mid,smoothstep(-.9,-.35,patches));
    grass=mix(grass,grass_light,smoothstep(.55,.85,patches));
    float strokes=smoothstep(.87,.95,sin(world.x*.8+sin(world.z*.55)))*.01;
    ALBEDO=mix(grass+strokes,trail_tone+strokes,blend);
    ROUGHNESS=.95;SPECULAR=.12;
}
