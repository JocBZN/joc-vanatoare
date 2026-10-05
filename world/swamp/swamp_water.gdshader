shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled;
uniform sampler2D depth_texture:hint_depth_texture,filter_nearest,repeat_disable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap,repeat_enable;
uniform vec3 observer=vec3(0.0);
uniform vec3 deep_color:source_color=vec3(.16,.37,.38);
uniform vec3 shallow_color:source_color=vec3(.28,.51,.48);
uniform vec3 foam_color:source_color=vec3(.65,.79,.70);
varying vec3 world;
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.y+=sin(world.x*.39+TIME*.8)*.018+cos(world.z*.51+TIME*.63)*.015;
}
void fragment(){
    float sampled_depth=texture(depth_texture,SCREEN_UV).r;
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
        sampled_depth=sampled_depth*2.0-1.0;
    #endif
    vec4 floor_view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,sampled_depth,1.0);
    float depth=max(0.0,-floor_view.z/floor_view.w+VERTEX.z);
    float distance_to_player=length(world.xz-observer.xz);
    float ripple=sin(distance_to_player*8.0-TIME*3.0)*exp(-distance_to_player*.7);
    float waves=sin(world.x*.9+world.z*.5+TIME*.6)+sin(world.z*1.3-TIME*.8)+ripple;
    float strokes=smoothstep(1.35,1.55,waves);
    float shore=1.0-smoothstep(.04,.28,depth);
    ALBEDO=mix(deep_color,shallow_color,1.0-smoothstep(.0,1.3,depth));
    ALBEDO=mix(ALBEDO,foam_color,max(strokes*.32,shore*.55));
    ROUGHNESS=.48;SPECULAR=.25;METALLIC=0.0;
    ALPHA=clamp(.84+depth*.12,.84,.98);
}
