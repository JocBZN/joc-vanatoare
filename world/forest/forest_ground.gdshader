shader_type spatial;
uniform sampler2D forest_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D forest_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D forest_rough:filter_linear_mipmap,repeat_enable;
uniform sampler2D trail_color:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D trail_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D trail_rough:filter_linear_mipmap,repeat_enable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 uv=world.xz*.24;
    float road_x=sin(world.z*.012)*28.0*smoothstep(35.0,80.0,abs(world.z));
    float road=(1.0-smoothstep(3.5,5.5,abs(world.x-road_x)))*smoothstep(32.0,42.0,length(world.xz));
    float clearing=1.0-smoothstep(10.0,18.0,length(world.xz));
    float blend=max(road,clearing);
    float macro=.87+.08*sin(world.x*.039+sin(world.z*.02))+.07*cos(world.z*.055);
    vec3 forest=texture(forest_color,uv).rgb;
    forest=mix(forest,texture(forest_color,uv*.37+vec2(.17,.61)).rgb,.23);
    ALBEDO=mix(forest,texture(trail_color,uv*.8).rgb,blend)*macro;
    NORMAL_MAP=mix(texture(forest_normal,uv).rgb,texture(trail_normal,uv*.8).rgb,blend);
    NORMAL_MAP_DEPTH=.85;
    ROUGHNESS=mix(texture(forest_rough,uv).r,texture(trail_rough,uv*.8).g,blend);
}
