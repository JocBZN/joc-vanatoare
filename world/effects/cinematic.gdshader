shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.55;

void fragment() {
    vec3 base = texture(scene_texture, SCREEN_UV).rgb;
    vec3 bloom = vec3(0.0);
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 5.0;
            vec3 tap = texture(scene_texture, SCREEN_UV + offset).rgb;
            float brightness = max(tap.r, max(tap.g, tap.b));
            bloom += tap * smoothstep(0.65, 1.0, brightness) / 25.0;
        }
    }
    vec3 color = base * vec3(1.04, 1.015, 0.98) + bloom * glow_strength;
    vec2 center = SCREEN_UV - 0.5;
    float vignette = 1.0 - smoothstep(0.20, 0.72, length(center)) * 0.20;
    COLOR = vec4(color * vignette, 1.0);
}
