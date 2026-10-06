shader_type spatial;
render_mode cull_disabled, diffuse_toon;
uniform sampler2D coat:source_color,filter_linear_mipmap;
uniform bool has_coat=true;
uniform vec4 tint:source_color=vec4(1.0);
uniform float back_darkening=.12;
// 0 keeps the coat; 1 bleaches it to a pale ghost of its markings (albino).
uniform float lift=0.0;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
    vec4 source=has_coat?texture(coat,UV):vec4(1.0);
    // Retain species markings, remove photographic microdetail.
    vec3 painted=mix(vec3(dot(source.rgb,vec3(.30,.59,.11))),source.rgb,.82);
    painted=mix(painted,vec3(.76+.24*dot(painted,vec3(.30,.59,.11))),lift);
    float back=smoothstep(.3,1.5,local_position.y);
    ALBEDO=painted*tint.rgb*(1.0-back*back_darkening);
    ROUGHNESS=.92;SPECULAR=.15;
    ALPHA=source.a;
    ALPHA_SCISSOR_THRESHOLD=.35;
}
