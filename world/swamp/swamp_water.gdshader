shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest,repeat_disable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap,repeat_enable;
uniform vec3 observer=vec3(0.0);
varying vec3 world;
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y+=sin(world.x*.39+TIME*.8)*.018+cos(world.z*.51+TIME*.63)*.015;
}
void fragment(){
    vec4 floor_view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,texture(depth_texture,SCREEN_UV).r,1.0);
    float depth=max(0.0,-floor_view.z/floor_view.w+VERTEX.z);
    vec2 uv=world.xz*.07;
    vec3 n1=texture(normal_map,uv+TIME*vec2(.008,-.005)).rgb;
    vec3 n2=texture(normal_map,uv*.7-TIME*vec2(.006,.007)).rgb;
    float ripple=sin(length(world.xz-observer.xz)*13.0-TIME*5.0)*exp(-length(world.xz-observer.xz)*.7);
    NORMAL_MAP=mix(n1,n2,.5);NORMAL_MAP_DEPTH=.18+ripple*.06;
    float film=smoothstep(.64,.88,sin(world.x*.026+sin(world.z*.049))*.5+.5);
    ALBEDO=mix(vec3(.075,.12,.095),vec3(.035,.066,.059),smoothstep(0.0,1.3,depth));
    ALBEDO=mix(ALBEDO,vec3(.16,.22,.09),film*.45);
    ROUGHNESS=mix(.26,.49,film);SPECULAR=.65;METALLIC=0.0;
    ALPHA=clamp(.68+depth*.25,.68,.96);
}
