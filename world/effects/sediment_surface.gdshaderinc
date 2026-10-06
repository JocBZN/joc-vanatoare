// World-space sediment detail, stable across terrain chunks and map reloads.
float sediment_hash(vec2 cell) {
    // Integer hashing gives adjacent cells exactly the same shared corner.
    // Floating sin hashes can disagree after GPU expression reassociation.
    uvec2 key = uvec2(ivec2(cell));
    uint value = key.x * 1597334677u ^ key.y * 3812015801u;
    value = (value ^ (value >> 16u)) * 2246822519u;
    value = (value ^ (value >> 13u)) * 3266489917u;
    value = value ^ (value >> 16u);
    return float(value & 16777215u) / 16777215.0;
}

float sediment_noise(vec2 position) {
    vec2 cell = floor(position);
    vec2 fraction = fract(position);
    vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
    return mix(mix(sediment_hash(cell), sediment_hash(cell + vec2(1.0, 0.0)), blend.x),
        mix(sediment_hash(cell + vec2(0.0, 1.0)), sediment_hash(cell + vec2(1.0)), blend.x), blend.y);
}

// Average fine grains as they become smaller than a pixel, preventing sparkle.
float sediment_grain(vec2 position, float frequency) {
    vec2 coordinate = position * frequency;
    vec2 footprint = fwidth(coordinate);
    float visibility = 1.0 - smoothstep(0.45, 1.6, max(footprint.x, footprint.y));
    return mix(0.5, sediment_noise(coordinate), visibility);
}
