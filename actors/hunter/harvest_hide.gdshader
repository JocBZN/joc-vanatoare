shader_type spatial;
render_mode cull_disabled;
uniform vec4 coat_color : source_color = vec4(.55,.4,.27,1);
uniform float progress = 0.0;
uniform float damage = 0.0;
uniform float lift = 0.0;
uniform float cut = 0.0;
uniform bool scales = false;
uniform bool shell = false;
uniform bool finish = false;
// Normalised arc position of the blade along the current incision, and the row
// that incision runs through. Together they open the flap exactly where the
// player actually cut instead of along a fixed seam.
uniform float trace = 0.0;
uniform float seam_row = 0.5;
uniform float peel = 0.0;

varying float flap;

void vertex() {
    // Everything past the incision row hinges away from the carcass, but only
    // as far along the body as the blade has already travelled.
    float opened = step(seam_row, UV.y) * smoothstep(.02, .22, trace + peel);
    float reach = clamp((trace + peel) * 1.15, 0.0, 1.0);
    float along = 1.0 - smoothstep(reach, reach + .18, UV.x);
    flap = opened * along;
    float hinge = smoothstep(.15,.95,1.0-UV.x);
    float open = (lift + peel * .16) * hinge + flap * (.07 + peel * .20);
    VERTEX.z += open;
    VERTEX.y += open * .22 + flap * peel * .05;
    NORMAL = normalize(vec3(open * 4.0, -flap * .6, 1.0));
}

void fragment() {
    float grain = fract(sin(dot(floor(UV*vec2(180.0,65.0)),vec2(17.13,41.73)))*3271.31);
    float fibers = .87 + .20*grain + .08*sin(UV.x*410.0+sin(UV.y*35.0));
    vec2 cell = fract(UV*vec2(15.0,10.0));
    float scale_rim = smoothstep(.36,.49,max(abs(cell.x-.5),abs(cell.y-.5)));
    if (scales) fibers = .98-.23*scale_rim;
    // The incision itself: a dark line along seam_row, revealed up to the blade.
    float wobble = damage*.012*sin(UV.x*74.0);
    float seam = (1.0-smoothstep(.004,.016+damage*.020,abs(UV.y-seam_row-wobble)))
               * step(UV.x, max(trace, cut*.25) + .01);
    float tears = damage * (1.0-smoothstep(.01,.025,abs(UV.y-.24-.12*sin(UV.x*28.0)))) * step(.35,UV.x);
    vec3 meat = mix(vec3(.42,.12,.11), vec3(.62,.24,.19), grain);
    vec3 coat = coat_color.rgb*fibers;
    // Lifted flap shows wet tissue on its underside, not more fur.
    vec3 base = mix(coat, meat*.8, clamp(flap*1.4,0.0,1.0)*float(!shell));
    ALBEDO = mix(base, mix(vec3(.30,.07,.07), coat_color.rgb*.28, float(shell)), clamp(seam+tears,0.0,1.0));
    ROUGHNESS = shell ? .76 : mix(.96, .55, clamp(flap+seam,0.0,1.0));
    SPECULAR = mix(.16, .42, clamp(flap+seam,0.0,1.0));
    if (finish) ALBEDO *= 1.12;
}
