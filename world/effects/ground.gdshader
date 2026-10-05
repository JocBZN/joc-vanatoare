shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float broad = noise(world_pos.xz * 0.35);
    float grain = noise(world_pos.xz * 24.0);
    ALBEDO = mix(vec3(0.09,0.14,0.095),vec3(0.24,0.25,0.14),broad) * (0.83+grain*0.30);
    ROUGHNESS = 0.94;
}
