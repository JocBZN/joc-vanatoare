shader_type canvas_item;
// Soft coloured edges: red when hurt or low on health, grey when downed.
uniform vec4 tint : source_color = vec4(0.75, 0.05, 0.03, 1.0);
uniform float strength = 0.0;

void fragment() {
    vec2 centred = (UV - vec2(0.5)) * vec2(1.25, 1.0);
    float edge = smoothstep(0.32, 0.78, length(centred));
    COLOR = vec4(tint.rgb, tint.a * edge * clamp(strength, 0.0, 1.0));
}
