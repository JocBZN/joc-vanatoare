shader_type canvas_item;
// Paints the terrain from the map's own height grid: elevation colours,
// hillshade from the north-west, 10 m contour lines, water, the road and the
// swamp boardwalks. The radar uses it rotating and round, the big map north-up.
uniform sampler2D heights : filter_nearest;
uniform float cells = 300.0;
uniform float map_size = 2400.0;
// World x/z under the centre of the widget, metres across it, map turn.
uniform vec2 view_center = vec2(0.0);
uniform float view_span = 240.0;
uniform float view_turn = 0.0;
uniform bool circle = true;
uniform float corner = 0.0;
uniform float opacity = 0.96;
uniform float swamp = 0.0;
uniform float ocean = 0.0;
uniform float water_level = 0.0;
uniform vec2 lake_center = vec2(190.0, 160.0);
uniform float lake_reach = 98.0;
uniform float lake_level = -3.0;
uniform float grid = 0.0;
uniform vec4 walks[3];
uniform int walk_count = 0;

float height_at(vec2 world) {
    vec2 cell = clamp((world / map_size + vec2(.5)) * cells, vec2(0.0), vec2(cells - .001));
    ivec2 base = ivec2(floor(cell));
    vec2 f = fract(cell);
    float a = texelFetch(heights, base, 0).r;
    float b = texelFetch(heights, base + ivec2(1, 0), 0).r;
    float c = texelFetch(heights, base + ivec2(0, 1), 0).r;
    float d = texelFetch(heights, base + ivec2(1, 1), 0).r;
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), .0001), 0.0, 1.0);
    return length(p - a - ab * t);
}

// 1 inside a band of half-width `half_width` metres around distance 0, never thinner than a pixel.
float band(float distance_m, float half_width, float pixel) {
    float w = max(half_width, pixel * .8);
    return 1.0 - smoothstep(w - pixel * .5, w + pixel * .5, distance_m);
}

void fragment() {
    vec2 local = UV - vec2(.5);
    float c = cos(view_turn);
    float s = sin(view_turn);
    vec2 world = view_center + vec2(local.x * c + local.y * s, -local.x * s + local.y * c) * view_span;
    float pixel = max(fwidth(world.x) + fwidth(world.y), .001) * .7;
    float h = height_at(world);
    float step_m = max(4.0, pixel * 1.5);
    float hx = height_at(world + vec2(step_m, 0.0)) - height_at(world - vec2(step_m, 0.0));
    float hz = height_at(world + vec2(0.0, step_m)) - height_at(world - vec2(0.0, step_m));
    vec3 normal = normalize(vec3(-hx, 2.0 * step_m, -hz));
    float shade = clamp(dot(normal, normalize(vec3(-.55, .75, -.45))), 0.0, 1.0);
    float steep = 1.0 - normal.y;
    vec3 color;
    if (ocean > .5) {
        color = mix(vec3(.86, .79, .56), vec3(.3, .52, .24), smoothstep(.5, 2.5, h));
        color = mix(color, vec3(.2, .4, .19), smoothstep(3.0, 10.0, h));
        color = mix(color, vec3(.52, .5, .43), smoothstep(14.0, 22.0, h));
    } else if (swamp > .5) {
        color = mix(vec3(.36, .38, .24), vec3(.33, .45, .27), smoothstep(.2, 2.0, h));
        color = mix(color, vec3(.42, .52, .31), smoothstep(4.0, 12.0, h));
        color = mix(color, vec3(.52, .5, .38), smoothstep(16.0, 28.0, h));
    } else {
        color = mix(vec3(.33, .48, .26), vec3(.42, .53, .29), smoothstep(-2.0, 8.0, h));
        color = mix(color, vec3(.55, .52, .36), smoothstep(10.0, 22.0, h));
        color = mix(color, vec3(.58, .56, .52), smoothstep(20.0, 32.0, h));
        color = mix(color, vec3(.9, .91, .9), smoothstep(40.0, 52.0, h));
    }
    color = mix(color, vec3(.55, .53, .5), smoothstep(.35, .6, steep) * .7);
    color *= mix(.6, 1.14, shade);
    // Contour lines every 10 m, fading out where they would crowd together.
    float level = h / 10.0;
    float contour = abs(fract(level + .5) - .5) / max(fwidth(level), .0001);
    float density = 1.0 - smoothstep(.12, .35, fwidth(level));
    color *= 1.0 - (1.0 - clamp(contour, 0.0, 1.0)) * .2 * density;
    // Water: the forest lake, or anything below the swamp's water level.
    float depth = 0.0;
    bool wet = false;
    if (swamp > .5) {
        wet = h < water_level;
        depth = water_level - h;
    } else {
        wet = distance(world, lake_center) < lake_reach && h < lake_level;
        depth = lake_level - h;
    }
    if (wet && ocean > .5) {
        // Lagoon turquoise over the shallows, falling away to deep navy over the canyons.
        color = mix(vec3(.3, .82, .8), vec3(.02, .15, .33), smoothstep(.0, 24.0, depth));
        color = mix(color, vec3(.03, .08, .2), smoothstep(26.0, 50.0, depth));
        color *= mix(.92, 1.05, shade);
    } else if (wet) {
        vec3 shallow = swamp > .5 ? vec3(.33, .52, .49) : vec3(.36, .6, .68);
        vec3 deep = swamp > .5 ? vec3(.18, .33, .35) : vec3(.16, .34, .5);
        color = mix(shallow, deep, smoothstep(.0, 1.6, depth));
        color *= mix(.92, 1.05, shade);
    }
    // The road through the middle of the map, the camp clearing, boardwalks.
    float road_x = swamp > .5 ? sin(world.y * .008) * 28.0 : sin(world.y * .012) * 28.0 * smoothstep(35.0, 80.0, abs(world.y));
    float road = ocean > .5 ? 0.0 : band(abs(world.x - road_x), swamp > .5 ? 4.0 : 3.2, pixel);
    if (swamp < .5 && ocean < .5) road = max(road, 1.0 - smoothstep(12.0, 15.0, length(world)));
    color = mix(color, vec3(.8, .67, .46), road * .85);
    for (int i = 0; i < walk_count; i++) {
        float walk = band(segment_distance(world, walks[i].xy, walks[i].zw), 2.3, pixel);
        color = mix(color, vec3(.66, .48, .3), walk);
    }
    // A light 200 m grid on the big map.
    if (grid > 0.0) {
        vec2 lines = abs(fract(world / grid + .5) - .5) * grid / max(pixel, .001);
        float g = 1.0 - clamp(min(lines.x, lines.y), 0.0, 1.0);
        color = mix(color, vec3(1.0), g * .08);
    }
    // Beyond the edge of the world.
    vec2 outside = abs(world) - vec2(map_size * .5);
    if (max(outside.x, outside.y) > 0.0) color = vec3(.08, .1, .09);
    float alpha = opacity;
    if (circle) {
        float r = length(local);
        float edge = max(fwidth(r), .001);
        alpha *= 1.0 - smoothstep(.5 - edge, .5, r);
        color *= mix(1.0, .78, smoothstep(.32, .5, r));
    } else if (corner > 0.0) {
        vec2 q = abs(local) - vec2(.5 - corner);
        float d = length(max(q, vec2(0.0))) - corner;
        float edge = max(fwidth(d), .001);
        alpha *= 1.0 - smoothstep(-edge, 0.0, d);
    }
    COLOR = vec4(color, alpha);
}
