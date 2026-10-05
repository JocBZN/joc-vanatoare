shader_type spatial;
uniform vec4 tint:source_color=vec4(.26,.35,.16,1.0);
uniform float scale_size=24.0;
uniform float wetness=.2;
uniform bool amphibian=false;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
    vec2 p=UV*scale_size;
    p.x+=mod(floor(p.y),2.0)*.5;
    vec2 tile=fract(p);
    float edge=smoothstep(.02,.13,min(min(tile.x,1.0-tile.x),min(tile.y,1.0-tile.y)));
    float mottles=.78+.17*sin(local.x*17.0+cos(local.z*12.0))+.1*cos(local.y*21.0+local.z*10.0);
    float speckle=fract(sin(dot(floor(UV*180.0),vec2(127.1,311.7)))*43758.5453);
    ALBEDO=tint.rgb*mottles*(amphibian?mix(.58,1.05,smoothstep(.08,.18,speckle)):mix(.83,1.0,edge));
    ROUGHNESS=mix(.78,.3,wetness);SPECULAR=.65;
    NORMAL_MAP=vec3(.5+cos(tile.x*6.28)*.035,.5+sin(tile.y*6.28)*.035,1.0);NORMAL_MAP_DEPTH=amphibian?.12:.23;
}
