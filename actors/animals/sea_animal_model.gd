extends Node3D
## Procedural sea creatures, every one with its own swimming animation:
##  - fish, sharks, dolphins, the orca, the swordfish, eels and the sea snake: a lofted body
##    in hinged segments (a travelling S-wave from head to tail), ray-fin fans, gills, eyes
##    with highlights, jaws with teeth, banking in turns and fins that tuck when they race;
##  - the manta ray (a rippling wing), the sea turtle (synchronised flipper strokes), the
##    pufferfish (inflates and bristles), the lionfish (waving fans and spines), the box
##    jellyfish (pulsing bell) and the Portuguese man o' war (floating bladder, trailing
##    stingers).
## The parent WildlifeAnimal supplies the replicated state (speed, behaviour, state, dead),
## so every peer animates the same way. The model faces -Z, centred on the origin.
const Flora:=preload("res://world/ocean/ocean_flora.gd")
const SkinShader:=preload("res://actors/animals/sea_skin.gdshader")
@export var species: String="barracuda"

## kind: fish | eel | snake | ray | turtle | puffer | lion | jelly | siphon
## length, w and h are half-extents in metres; `snout` is how pointed the nose is (0..1 of
## the length); pattern: 0 none, 1 bars, 2 spots, 3 stripes, 4 mottled, 5 scutes, 6 bands.
const SPECS: Dictionary={
    "barracuda":{"kind":"fish","length":1.9,"w":.11,"h":.15,"segments":4,"back":Color("4a5f74"),"belly":Color("eef2f3"),"fin":Color("5b6773"),"pattern":1,"pcolor":Color("1f2a36"),"pscale":7.0,"pstrength":.6,"teeth":8,"dorsal":.3,"pectoral":.22,"pelvic":.12,"anal":.16,"snout":.24,"eye":.03,"gills":3,"jaw":.2,"wave":2.2,"freq":1.15},
    "moray":{"kind":"eel","length":2.4,"w":.15,"h":.19,"segments":8,"back":Color("6b7a2c"),"belly":Color("e0d070"),"fin":Color("4d5b1c"),"pattern":4,"pcolor":Color("3a3410"),"pscale":9.0,"pstrength":.7,"teeth":12,"ridge":.15,"snout":.1,"eye":.03,"gills":0,"jaw":.12,"wave":1.6,"freq":.9,"amp":1.3},
    "electric_eel":{"kind":"eel","length":3.2,"w":.15,"h":.17,"segments":9,"back":Color("4b5a2c"),"belly":Color("e08a3a"),"fin":Color("e08a3a"),"pattern":3,"pcolor":Color("2e3a1a"),"pscale":6.0,"pstrength":.4,"teeth":4,"electrodes":true,"snout":.08,"eye":.03,"gills":0,"jaw":.1,"wave":1.5,"freq":.9,"amp":1.3},
    "sea_snake":{"kind":"snake","length":2.2,"w":.1,"h":.1,"segments":14,"back":Color("d8dbc4"),"belly":Color("f2f0de"),"fin":Color("2a3342"),"pattern":6,"pcolor":Color("1a2330"),"pscale":15.0,"pstrength":.92,"teeth":0,"snout":.06,"eye":.02,"gills":0,"jaw":.06,"wave":1.3,"freq":1.4,"amp":1.7},
    "reef_shark":{"kind":"fish","length":2.6,"w":.3,"h":.34,"segments":5,"back":Color("6f808e"),"belly":Color("eef1f2"),"fin":Color("55606a"),"tips":Color("1d2227"),"pattern":0,"teeth":9,"dorsal":.55,"pectoral":.55,"pelvic":.2,"anal":.2,"second_dorsal":.2,"snout":.2,"eye":.034,"gills":5,"jaw":.16,"wave":2.4,"freq":.85,"amp":.8},
    "tiger_shark":{"kind":"fish","length":4.6,"w":.5,"h":.6,"segments":5,"back":Color("6c7c88"),"belly":Color("e9eceb"),"fin":Color("56626d"),"pattern":6,"pcolor":Color("3c4854"),"pscale":6.0,"pstrength":.55,"teeth":12,"dorsal":.95,"pectoral":.85,"pelvic":.35,"anal":.3,"second_dorsal":.3,"snout":.2,"eye":.045,"gills":5,"jaw":.16,"wave":2.4,"freq":.8,"amp":.75},
    "hammerhead":{"kind":"fish","length":4.2,"w":.42,"h":.5,"segments":5,"back":Color("5f6e7a"),"belly":Color("dde3e6"),"fin":Color("4b5761"),"pattern":0,"teeth":6,"dorsal":.9,"pectoral":.8,"pelvic":.3,"anal":.28,"second_dorsal":.28,"hammer":true,"snout":.2,"eye":.04,"gills":5,"jaw":.12,"wave":2.4,"freq":.8,"amp":.8},
    "great_white":{"kind":"fish","length":5.2,"w":.6,"h":.72,"segments":5,"back":Color("5d6b78"),"belly":Color("f6f7f6"),"fin":Color("46515a"),"pattern":4,"pcolor":Color("46525e"),"pscale":6.0,"pstrength":.25,"teeth":16,"dorsal":1.05,"pectoral":1.0,"pelvic":.4,"anal":.3,"second_dorsal":.32,"snout":.2,"eye":.05,"gills":5,"jaw":.17,"wave":2.4,"freq":.75,"amp":.75},
    "megalodon":{"kind":"fish","length":16.0,"w":1.55,"h":1.85,"segments":6,"back":Color("4a525a"),"belly":Color("cfd5d6"),"fin":Color("373e45"),"pattern":4,"pcolor":Color("2c3238"),"pscale":5.0,"pstrength":.45,"teeth":24,"dorsal":2.6,"pectoral":2.5,"pelvic":.9,"anal":.7,"second_dorsal":.8,"scars":true,"glow":Color("7dffe0"),"snout":.18,"eye":.1,"gills":6,"jaw":.18,"wave":2.6,"freq":.55,"amp":.7},
    "orca":{"kind":"fish","length":7.0,"w":.95,"h":1.0,"segments":5,"back":Color("15181d"),"belly":Color("f2f2ef"),"fin":Color("101317"),"pattern":0,"teeth":10,"dorsal":1.5,"pectoral":1.2,"vertical":true,"patches":true,"snout":.1,"eye":.05,"gills":0,"jaw":.13,"wave":2.0,"freq":.8,"amp":.62},
    "dolphin":{"kind":"fish","length":2.6,"w":.34,"h":.42,"segments":5,"back":Color("6f869c"),"belly":Color("eef2f5"),"fin":Color("5d6f81"),"pattern":0,"teeth":0,"dorsal":.55,"pectoral":.6,"vertical":true,"beak":true,"snout":.22,"eye":.04,"gills":0,"jaw":.1,"wave":2.0,"freq":1.0,"amp":.62},
    "swordfish":{"kind":"fish","length":3.6,"w":.22,"h":.3,"segments":5,"back":Color("2d4a78"),"belly":Color("e1e7eb"),"fin":Color("2a3d5c"),"pattern":3,"pcolor":Color("5f7fb0"),"pscale":6.0,"pstrength":.35,"teeth":0,"dorsal":.75,"pectoral":.42,"anal":.2,"bill":true,"snout":.3,"eye":.05,"gills":3,"jaw":.08,"wave":2.1,"freq":1.1,"amp":.8},
    "grouper":{"kind":"fish","length":1.8,"w":.3,"h":.38,"segments":4,"back":Color("6b6a4a"),"belly":Color("ddd7b4"),"fin":Color("524f36"),"pattern":2,"pcolor":Color("34331f"),"pscale":8.0,"pstrength":.55,"teeth":6,"dorsal":.34,"pectoral":.4,"pelvic":.2,"anal":.24,"round_tail":true,"snout":.14,"eye":.04,"gills":3,"jaw":.22,"wave":2.4,"freq":1.0,"amp":.8},
    "lionfish":{"kind":"lion","length":.9,"w":.17,"h":.21,"segments":3,"back":Color("b5482c"),"belly":Color("e8cfa8"),"fin":Color("a63e28"),"pattern":1,"pcolor":Color("f4ead2"),"pscale":6.0,"pstrength":.8,"teeth":0,"snout":.18,"eye":.03,"gills":2,"jaw":.14,"wave":2.0,"freq":.9,"amp":.6},
    "pufferfish":{"kind":"puffer","length":.8,"w":.28,"h":.3,"segments":2,"back":Color("b69a52"),"belly":Color("f5efd6"),"fin":Color("c9b070"),"pattern":2,"pcolor":Color("5a4524"),"pscale":9.0,"pstrength":.75,"teeth":0,"snout":.12,"eye":.05,"gills":0,"jaw":.06,"wave":2.0,"freq":1.0,"amp":.5},
    "manta_ray":{"kind":"ray","length":3.0,"span":2.7},
    "sea_turtle":{"kind":"turtle","length":1.3},
    "jellyfish":{"kind":"jelly"},
    "man_o_war":{"kind":"siphon"},
}

var animal: WildlifeAnimal
var spec: Dictionary
var kind: String
var segments: Array[Node3D]=[]
var tail: Node3D
var jaw: Node3D
var pectorals: Array[Node3D]=[]
var pelvics: Array[Node3D]=[]
var dorsal_nodes: Array[Node3D]=[]
var wings: Array=[]
var flippers: Array=[]
var chains: Array=[]
var spines: Node3D
var bell: Node3D
var float_node: Node3D
var head_node: Node3D
var glow_parts: Array[MeshInstance3D]=[]
var shock_light: OmniLight3D
var body_mat: ShaderMaterial
var fin_mat: ShaderMaterial
var _roll: float=0.0
var _last_yaw: float=0.0
var _yaw_rate: float=0.0
var _inflate: float=0.0
var _dead_roll: float=0.0
var _flash: float=0.0

func _ready() -> void:
    animal=get_parent() as WildlifeAnimal
    spec=SPECS[species]
    kind=spec.kind
    _make_materials()
    match kind:
        "fish","eel","snake": _build_fish()
        "puffer": _build_puffer()
        "lion": _build_lion()
        "ray": _build_ray()
        "turtle": _build_turtle()
        "jelly": _build_jelly()
        "siphon": _build_siphon()
    for node in find_children("*","MeshInstance3D",true,false):
        node.set_meta("styled",true)
        node.visibility_range_end=170.0 if species!="megalodon" else 420.0
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if is_instance_valid(animal): _last_yaw=animal.rotation.y

# --- Materials ------------------------------------------------------------------------------

func _skin(pattern: int,color: Color,pscale: float,strength: float,sheen: float) -> ShaderMaterial:
    var m:=ShaderMaterial.new();m.shader=SkinShader
    m.set_shader_parameter("pattern",pattern);m.set_shader_parameter("pattern_color",color)
    m.set_shader_parameter("pattern_scale",pscale);m.set_shader_parameter("pattern_strength",strength)
    m.set_shader_parameter("sheen",sheen)
    return m

func _make_materials() -> void:
    body_mat=_skin(int(spec.get("pattern",0)),spec.get("pcolor",Color.BLACK),float(spec.get("pscale",8.0)),float(spec.get("pstrength",.6)),.75)
    fin_mat=_skin(0,Color.BLACK,1.0,0.0,.35)

func _glow_material(color: Color,energy: float=3.0) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new();m.albedo_color=color;m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=energy;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    return m

func _mesh_node(parent: Node3D,mesh: ArrayMesh,point: Vector3=Vector3.ZERO,material: Material=null) -> MeshInstance3D:
    if mesh.get_surface_count()>0: mesh.surface_set_material(0,material if material else fin_mat)
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=point;parent.add_child(node);return node

static func _shade(c: Color,s: float) -> Color:
    return Color(c.r*s,c.g*s,c.b*s,1.0)

## A fin made of rays: a root edge r0..r1 and an outer edge t0..t1, split into strips that
## alternate a little in tone and fade from the root colour to the tip colour.
func _fan(b: Flora.Builder,r0: Vector3,r1: Vector3,t0: Vector3,t1: Vector3,rays: int,c_root: Color,c_tip: Color) -> void:
    for i in rays:
        var f0: float=float(i)/rays;var f1: float=float(i+1)/rays
        var ra: Vector3=r0.lerp(r1,f0);var rb: Vector3=r0.lerp(r1,f1)
        var ta: Vector3=t0.lerp(t1,f0);var tb: Vector3=t0.lerp(t1,f1)
        var s: float=1.0 if i%2==0 else .8
        var cr: Color=_shade(c_root,s);var ct: Color=_shade(c_tip,s)
        b.tri_out_c(ra,ta,tb,cr,ct,ct,Vector3.RIGHT)
        b.tri_out_c(ra,tb,rb,cr,ct,cr,Vector3.RIGHT)

# --- Fish, sharks, cetaceans, eels and the sea snake ----------------------------------------------------

func _profile(t: float) -> Vector2:
    var snout: float=float(spec.get("snout",.2))
    if kind=="eel" or kind=="snake":
        var ends: float=smoothstep(.0,.07,t)*(1.0-.88*smoothstep(.86,1.0,t))
        var head: float=1.0+(.45 if kind=="eel" else .6)*(1.0-smoothstep(.0,.18,t))
        return Vector2(ends*head,ends*head)
    var body: float=pow(sin(PI*clampf(pow(t,.72),0.0,1.0)),.8)
    var nose: float=smoothstep(.0,snout*.55,t)
    var tail_taper: float=1.0-(.72 if not spec.get("round_tail",false) else .5)*smoothstep(.68,1.0,t)
    return Vector2(body*nose*tail_taper,body*nose*tail_taper*(1.0-.1*smoothstep(.7,1.0,t)))

func _build_fish() -> void:
    var length: float=spec.length
    var count: int=spec.segments
    var parent: Node3D=self
    for i in count:
        var node:=Node3D.new();node.name="Seg"+str(i)
        node.position=Vector3(0,0,-length*.5) if i==0 else Vector3(0,0,length/count)
        parent.add_child(node);segments.append(node);parent=node
        _loft(node,float(i)/count,float(i+1)/count,i==count-1)
    head_node=segments[0]
    _head(segments[0],length)
    _fins(length)
    if spec.get("electrodes",false): _electrodes(length)
    if spec.get("patches",false): _orca_patches(length)
    if spec.get("scars",false): _scars(length)
    if spec.get("bill",false): _bill(length)
    if spec.get("beak",false): _beak(length)

## One body segment, lofted between two profile positions; vertices are local to the
## segment's hinge. UV = (angle round the body, position along the whole body).
func _loft(node: Node3D,t0: float,t1: float,close_end: bool) -> void:
    var b:=Flora.Builder.new()
    var length: float=spec.length
    var rings: int=6;var sides: int=16
    var back: Color=spec.back;var belly: Color=spec.belly
    var prev: Array[Vector3]=[];var prev_c: Array[Color]=[];var prev_t: float=t0
    var w_max: float=spec.w;var h_max: float=spec.h
    for k in rings+1:
        var t: float=lerpf(t0,t1,float(k)/rings)
        var p: Vector2=_profile(t)
        var z: float=(t-t0)*length
        var ring: Array[Vector3]=[];var colors: Array[Color]=[]
        for s in sides+1:
            var a: float=TAU*s/sides
            ring.append(Vector3(cos(a)*p.x*w_max,sin(a)*p.y*h_max,z))
            colors.append(belly.lerp(back,smoothstep(-.35,.5,sin(a))))
        if not prev.is_empty():
            for s in sides:
                var o:=Vector3(ring[s].x+ring[s+1].x,ring[s].y+ring[s+1].y,0.0)
                var u0: float=float(s)/sides;var u1: float=float(s+1)/sides
                b.tri_uv(prev[s],prev[s+1],ring[s],prev_c[s],prev_c[s+1],colors[s],Vector2(u0,prev_t),Vector2(u1,prev_t),Vector2(u0,t),o)
                b.tri_uv(prev[s+1],ring[s+1],ring[s],prev_c[s+1],colors[s+1],colors[s],Vector2(u1,prev_t),Vector2(u1,t),Vector2(u0,t),o)
        prev=ring;prev_c=colors;prev_t=t
    if close_end:
        var centre:=Vector3(0,0,(t1-t0)*length)
        for s in sides:
            b.tri_uv(centre,prev[s],prev[s+1],belly,prev_c[s],prev_c[s+1],Vector2(.5,1),Vector2(float(s)/sides,1),Vector2(float(s+1)/sides,1),Vector3(0,0,1))
    _mesh_node(node,b.finish(),Vector3.ZERO,body_mat).name="Body"

func _head(head: Node3D,length: float) -> void:
    var w: float=spec.w;var h: float=spec.h
    var eye_r: float=float(spec.get("eye",.03))
    var p: Vector2=_profile(.1)
    var b:=Flora.Builder.new()
    for side in [-1.0,1.0]:
        var eye_at:=Vector3(side*w*p.x*.86,h*p.y*.25,length*.1)
        if spec.get("hammer",false): eye_at=Vector3(side*w*2.15,0,length*.07)
        # Eye: pale ring, dark iris, black pupil and a small white highlight.
        b.blob(eye_at,Vector3.ONE*eye_r*1.3,Color("d9d3b8"),8,5,0.0,3,Color("d9d3b8"),-1.0)
        b.blob(eye_at+Vector3(side*eye_r*.28,0,-eye_r*.2),Vector3.ONE*eye_r*.95,Color("2a2415"),8,5,0.0,3,Color("2a2415"),-1.0)
        b.blob(eye_at+Vector3(side*eye_r*.58,0,-eye_r*.3),Vector3.ONE*eye_r*.55,Color("050506"),7,4,0.0,3,Color("050506"),-1.0)
        b.blob(eye_at+Vector3(side*eye_r*.72,eye_r*.3,-eye_r*.55),Vector3.ONE*eye_r*.2,Color("ffffff"),5,3,0.0,3,Color("ffffff"),-1.0)
        if spec.has("glow"): b.blob(eye_at+Vector3(side*eye_r*.8,0,-eye_r*.4),Vector3.ONE*eye_r*.6,spec.glow,6,4,0.0,3,spec.glow,-1.0)
    # Gill slits, a dark curve behind the head on each side.
    var gills: int=int(spec.get("gills",0))
    for g in gills:
        var gz: float=length*(.2+g*.018)
        var gp: Vector2=_profile(gz/length)
        for side in [-1.0,1.0]:
            b.box(Vector3(side*w*gp.x*.99,h*gp.y*.05,gz),Vector3(.012,h*gp.y*.72,.018),Vector3(0,0,side*.25),_shade(spec.back,.35))
    if spec.get("hammer",false):
        var span: float=w*4.4
        b.box(Vector3(0,0,length*.05),Vector3(span,h*.18,length*.08),Vector3.ZERO,spec.back)
        b.box(Vector3(0,-h*.06,length*.055),Vector3(span*.92,h*.08,length*.06),Vector3.ZERO,spec.belly)
        for side in [-1.0,1.0]:
            b.blob(Vector3(side*span*.5,0,length*.05),Vector3(h*.17,h*.1,length*.04),spec.back,6,4,0.0,3,spec.back,-1.0)
    _mesh_node(head,b.finish(),Vector3.ZERO,fin_mat)
    # Lower jaw on a hinge, with teeth along both jaws.
    var jaw_len: float=length*float(spec.get("jaw",.15))
    var jaw_w: float=w*p.x*.75
    jaw=Node3D.new();jaw.name="Jaw";jaw.position=Vector3(0,-h*p.y*.34,length*.2);head.add_child(jaw)
    var jb:=Flora.Builder.new()
    jb.box(Vector3(0,-h*.04,-jaw_len*.5),Vector3(jaw_w*1.5,h*.12,jaw_len),Vector3.ZERO,_shade(spec.belly,.8))
    var teeth: int=int(spec.get("teeth",0))
    var big: bool=spec.get("scars",false) or species=="great_white"
    for k in teeth:
        var f: float=float(k)/maxf(1.0,teeth-1.0)
        var side: float=-1.0 if k%2==0 else 1.0
        var tooth_h: float=h*(.22 if big else .13)
        var at:=Vector3(side*jaw_w*(.45+.35*f),h*.03,-jaw_len*(.12+.78*f))
        jb.tube(at,at+Vector3(0,tooth_h,0),tooth_h*.3,.003,4,Color("f7f3e6"))
    _mesh_node(jaw,jb.finish(),Vector3.ZERO,fin_mat)
    var ub:=Flora.Builder.new()
    for k in teeth:
        var f: float=float(k)/maxf(1.0,teeth-1.0)
        var side: float=-1.0 if k%2==0 else 1.0
        var tooth_h: float=h*(.22 if big else .13)
        var at:=Vector3(side*jaw_w*(.45+.35*f),-h*.3,-jaw_len*(.12+.78*f))
        ub.tube(at,at+Vector3(0,-tooth_h,0),tooth_h*.3,.003,4,Color("f7f3e6"))
    _mesh_node(head,ub.finish(),Vector3(0,0,length*.2),fin_mat)

func _fins(length: float) -> void:
    var w: float=spec.w;var h: float=spec.h
    var count: int=segments.size()
    var seg_len: float=length/count
    var fin: Color=spec.fin
    var tip: Color=spec.get("tips",_shade(fin,1.35))
    var vertical: bool=spec.get("vertical",false)
    # Dorsal fin (and a small second one), rooted on the back of the second segment.
    var dorsal: float=float(spec.get("dorsal",0.0))
    if dorsal>0.0 and count>1:
        var top: float=_profile(float(1)/count+.08).y*h*.97
        var b:=Flora.Builder.new()
        var sweep: float=seg_len*(.95 if not vertical else .8)
        _fan(b,Vector3(0,top,0),Vector3(0,top*.98,sweep),Vector3(0,top+dorsal*.98,sweep*.55),Vector3(0,top+dorsal*.08,sweep*1.25),8,fin,tip)
        var holder:=Node3D.new();holder.position=Vector3(0,0,seg_len*.05);segments[1].add_child(holder);dorsal_nodes.append(holder)
        _mesh_node(holder,b.finish())
        var second: float=float(spec.get("second_dorsal",0.0))
        if second>0.0 and count>3:
            var top2: float=_profile(float(3)/count+.04).y*h*.9
            var b2:=Flora.Builder.new()
            _fan(b2,Vector3(0,top2,seg_len*.1),Vector3(0,top2*.96,seg_len*.55),Vector3(0,top2+second*.85,seg_len*.3),Vector3(0,top2+second*.1,seg_len*.7),4,fin,tip)
            _mesh_node(segments[3],b2.finish())
    # Anal and pelvic fins.
    var anal: float=float(spec.get("anal",0.0))
    if anal>0.0 and count>3:
        var b3:=Flora.Builder.new()
        var low: float=-_profile(float(3)/count+.04).y*h*.92
        _fan(b3,Vector3(0,low,seg_len*.1),Vector3(0,low*.96,seg_len*.6),Vector3(0,low-anal*.85,seg_len*.28),Vector3(0,low-anal*.1,seg_len*.75),4,fin,tip)
        _mesh_node(segments[3],b3.finish())
    var pelvic: float=float(spec.get("pelvic",0.0))
    if pelvic>0.0 and count>2:
        for side in [-1.0,1.0]:
            var root:=Node3D.new();root.position=Vector3(side*w*.45,-h*.82,seg_len*.35);segments[2].add_child(root);pelvics.append(root)
            var pb:=Flora.Builder.new()
            _fan(pb,Vector3.ZERO,Vector3(0,0,pelvic*.4),Vector3(side*pelvic*.4,-pelvic*.45,pelvic*.3),Vector3(side*pelvic*.3,-pelvic*.35,pelvic*.8),4,fin,tip)
            _mesh_node(root,pb.finish())
    # Pectoral fins on the front segment, hinged so they can paddle and sweep back.
    var pec: float=float(spec.get("pectoral",0.0))
    if pec>0.0:
        var p: Vector2=_profile(.24)
        for side in [-1.0,1.0]:
            var root:=Node3D.new();root.position=Vector3(side*w*p.x*.9,-h*p.y*.42,length*.24);segments[0].add_child(root);pectorals.append(root)
            var pb:=Flora.Builder.new()
            _fan(pb,Vector3.ZERO,Vector3(0,0,pec*.4),Vector3(side*pec*.95,-pec*.3,pec*.5),Vector3(side*pec*.78,-pec*.28,pec*1.05),8,fin,tip)
            _mesh_node(root,pb.finish())
    # Tail: crescent lobes for fish and sharks, horizontal flukes for cetaceans, a fan for the grouper.
    tail=Node3D.new();tail.name="Tail";segments[count-1].add_child(tail)
    tail.position=Vector3(0,0,seg_len*.96)
    var tb:=Flora.Builder.new()
    var span: float=maxf(h*2.4,.28)
    if spec.kind=="snake":
        _fan(tb,Vector3(0,-.02,0),Vector3(0,.02,.1),Vector3(0,-h*3.0,span*.35),Vector3(0,h*3.0,span*.35),6,spec.fin,spec.fin)
    elif vertical:
        _fan(tb,Vector3(0,0,0),Vector3(0,0,.12*span),Vector3(-span*1.25,0,span*.75),Vector3(-span*.15,0,span*.42),6,fin,tip)
        _fan(tb,Vector3(0,0,0),Vector3(0,0,.12*span),Vector3(span*.15,0,span*.42),Vector3(span*1.25,0,span*.75),6,fin,tip)
    elif spec.get("round_tail",false):
        _fan(tb,Vector3(0,-.05*span,0),Vector3(0,.05*span,.1*span),Vector3(0,-span*.72,span*.7),Vector3(0,span*.72,span*.7),8,fin,tip)
    elif spec.kind=="eel":
        _fan(tb,Vector3(0,-.03,0),Vector3(0,.03,.1),Vector3(0,-h*.7,span*.5),Vector3(0,h*.7,span*.5),5,fin,fin)
    else:
        _fan(tb,Vector3(0,0,0),Vector3(0,.04*span,.1*span),Vector3(0,span*1.05,span*.92),Vector3(0,span*.12,span*.42),7,fin,tip)
        _fan(tb,Vector3(0,0,0),Vector3(0,-.04*span,.1*span),Vector3(0,-span*.78,span*.7),Vector3(0,-span*.1,span*.38),6,fin,tip)
    _mesh_node(tail,tb.finish())
    # A fin ridge down the whole back of an eel, and a ribbon along the belly of the electric one.
    var ridge: float=float(spec.get("ridge",0.0))
    if ridge>0.0:
        for i in range(1,count):
            var rb:=Flora.Builder.new()
            _fan(rb,Vector3(0,h*.92,0),Vector3(0,h*.92,seg_len),Vector3(0,h*.92+ridge,seg_len*.35),Vector3(0,h*.92+ridge*.5,seg_len*.9),3,fin,tip)
            _mesh_node(segments[i],rb.finish())
    if spec.get("electrodes",false):
        for i in range(1,count):
            var rb:=Flora.Builder.new()
            _fan(rb,Vector3(0,-h*.92,0),Vector3(0,-h*.92,seg_len),Vector3(0,-h*.92-.2,seg_len*.35),Vector3(0,-h*.92-.1,seg_len*.9),3,fin,tip)
            _mesh_node(segments[i],rb.finish())

func _electrodes(length: float) -> void:
    shock_light=OmniLight3D.new();shock_light.light_color=Color("8fe4ff");shock_light.light_energy=0.0;shock_light.omni_range=9.0;add_child(shock_light)
    for i in segments.size():
        var holder:=Flora.Builder.new()
        var seg_len: float=length/segments.size()
        for side in [-1.0,1.0]:
            holder.blob(Vector3(side*spec.w*.98,0,seg_len*.5),Vector3(.045,.06,.1),Color("9be8ff"),5,3,0.0,3,Color("9be8ff"),-1.0)
        var mesh: ArrayMesh=holder.finish()
        mesh.surface_set_material(0,_glow_material(Color("7fd8ff"),2.0))
        var node:=MeshInstance3D.new();node.mesh=mesh;segments[i].add_child(node);glow_parts.append(node)

func _orca_patches(length: float) -> void:
    var b:=Flora.Builder.new()
    for side in [-1.0,1.0]:
        b.blob(Vector3(side*spec.w*.8,spec.h*.28,length*.13),Vector3(.1,.34,.5),Color("f4f4f1"),7,4,0.0,3,Color("f4f4f1"),-1.0)
        b.blob(Vector3(side*spec.w*.84,-spec.h*.2,length*.5),Vector3(.1,.4,1.2),Color("f2f2ef"),7,4,0.0,3,Color("f2f2ef"),-1.0)
    _mesh_node(segments[0],b.finish(),Vector3.ZERO,fin_mat)
    var saddle:=Flora.Builder.new()
    saddle.blob(Vector3(0,spec.h*.82,length*.12),Vector3(spec.w*.9,.18,length*.16),Color("5a606a"),8,4,0.0,3,Color("5a606a"),-1.0)
    _mesh_node(segments[1],saddle.finish(),Vector3.ZERO,fin_mat)

func _scars(length: float) -> void:
    for i in range(0,segments.size()-1):
        var b:=Flora.Builder.new()
        var seg_len: float=length/segments.size()
        for k in 3:
            var side: float=-1.0 if (i+k)%2==0 else 1.0
            b.box(Vector3(side*spec.w*.94,spec.h*(.1+.15*k),seg_len*(.25+.25*k)),Vector3(.06,.05,seg_len*.28),Vector3(0,0,.5),Color("2a2f35"))
        _mesh_node(segments[i],b.finish(),Vector3.ZERO,fin_mat)

## The swordfish's long bill.
func _bill(length: float) -> void:
    var b:=Flora.Builder.new()
    var bill_len: float=length*.3
    b.tube(Vector3(0,.02,length*.06),Vector3(0,.02,-bill_len),spec.w*.38,.012,8,_shade(spec.back,.9),_shade(spec.belly,.5))
    b.tube(Vector3(0,-.04,length*.05),Vector3(0,-.04,-bill_len*.2),spec.w*.3,.02,6,spec.belly)
    _mesh_node(segments[0],b.finish(),Vector3.ZERO,body_mat)

## A dolphin's beak and melon.
func _beak(length: float) -> void:
    var b:=Flora.Builder.new()
    b.tube(Vector3(0,-spec.h*.1,length*.04),Vector3(0,-spec.h*.14,-length*.1),spec.w*.3,spec.w*.1,10,spec.back,spec.belly)
    b.blob(Vector3(0,spec.h*.2,length*.07),Vector3(spec.w*.7,spec.h*.4,length*.07),spec.back,10,6,0.0,3,spec.back,-1.0)
    _mesh_node(segments[0],b.finish(),Vector3.ZERO,body_mat)

# --- Pufferfish: a round body that inflates, spines on a holder that grows with it ----------------------------

func _build_puffer() -> void:
    _build_fish()
    spines=Node3D.new();spines.name="Spines";segments[0].add_child(spines)
    var b:=Flora.Builder.new()
    var centre:=Vector3(0,0,spec.length*.3)
    for i in 46:
        var y: float=1.0-2.0*(i+.5)/46.0
        var r: float=sqrt(1.0-y*y);var a: float=i*2.39996
        var dir:=Vector3(cos(a)*r,y,sin(a)*r)
        var at: Vector3=centre+Vector3(dir.x*spec.w,dir.y*spec.h,dir.z*spec.w*1.6)*.95
        b.tube(at,at+dir*.12,.012,.002,3,Color("f1e6bf"))
    _mesh_node(spines,b.finish(),Vector3.ZERO,fin_mat)
    spines.scale=Vector3.ONE*.01

# --- Lionfish: a body with great waving fans and a crown of spines ----------------------------------------------

func _build_lion() -> void:
    _build_fish()
    # Replace the plain pectoral fins with long striped fans made of waving ribbons.
    for node in pectorals: node.queue_free()
    pectorals.clear()
    for side in [-1.0,1.0]:
        var root:=Node3D.new();root.position=Vector3(side*spec.w*.8,-spec.h*.1,spec.length*.26);segments[0].add_child(root)
        var ribbons: Array[Node3D]=[]
        for i in 11:
            var f: float=float(i)/10.0
            var node:=Node3D.new();node.rotation=Vector3(0,side*(.15+f*1.35),side*(-.15+f*.5))
            root.add_child(node);ribbons.append(node)
            var b:=Flora.Builder.new()
            var color: Color=spec.fin.lerp(Color("f2e6cf"),float(i%2)*.65)
            var length: float=.95+.45*sin(f*PI)
            b.tube(Vector3.ZERO,Vector3(0,0,length),.01,.003,3,color)
            _fan(b,Vector3(0,0,.05),Vector3(0,0,length*.8),Vector3(side*.16,-.05,.1),Vector3(side*.16,-.05,length*.98),3,_shade(color,.9),_shade(color,1.25))
            _mesh_node(node,b.finish())
        flippers.append(ribbons)
    # Venomous dorsal spines.
    var holder:=Node3D.new();segments[1].add_child(holder);dorsal_nodes.append(holder)
    var top: float=_profile(.45).y*spec.h*.95
    for i in 13:
        var f: float=float(i)/12.0
        var b:=Flora.Builder.new()
        var base:=Vector3(0,top,spec.length/spec.segments*(.1+f*.9))
        var tip:=base+Vector3(0,.4+.2*sin(f*PI),.12*(f-.3))
        b.tube(base,tip,.008,.002,3,Color("f2e6cf") if i%2==0 else spec.fin)
        _mesh_node(holder,b.finish())

# --- Manta ray: a wing that ripples from the body to the tip ------------------------------------------------------

func _build_ray() -> void:
    var span: float=spec.span
    var b:=Flora.Builder.new()
    var top: Color=Color("1d2330");var bottom: Color=Color("f1f1ee")
    b.blob(Vector3(0,0,0),Vector3(.55,.2,1.0),top,12,6,0.0,3,top.lightened(.1),-1.0)
    b.blob(Vector3(0,-.05,.05),Vector3(.5,.12,.9),bottom,12,5,0.0,3,bottom,-1.0)
    # Head with two unfurled cephalic fins, a wide mouth and side-set eyes.
    for side in [-1.0,1.0]:
        b.tube(Vector3(side*.28,-.02,-.95),Vector3(side*.34,-.04,-1.55),.1,.03,6,top)
        b.blob(Vector3(side*.46,.1,-.55),Vector3(.07,.07,.07),Color("ffd9a0"),6,4,0.0,3,Color("ffd9a0"),-1.0)
        b.blob(Vector3(side*.46,.1,-.55),Vector3(.045,.045,.045),Color("060607"),6,4,0.0,3,Color("060607"),-1.0)
    b.box(Vector3(0,-.12,-.98),Vector3(.7,.04,.05),Vector3.ZERO,Color("1b1015"))
    # White shoulder patches on the back.
    b.blob(Vector3(-.28,.12,-.15),Vector3(.12,.04,.28),Color("f1f1ee"),7,4,0.0,3,Color("f1f1ee"),-1.0)
    b.blob(Vector3(.28,.12,-.15),Vector3(.12,.04,.28),Color("f1f1ee"),7,4,0.0,3,Color("f1f1ee"),-1.0)
    _mesh_node(self,b.finish(),Vector3.ZERO,fin_mat)
    var strips: int=8
    var strip_w: float=(span-.4)/strips
    for side in [-1.0,1.0]:
        var parent: Node3D=self
        var chain: Array[Node3D]=[]
        for i in strips:
            var node:=Node3D.new();node.position=Vector3(side*(.45 if i==0 else strip_w),0,0)
            parent.add_child(node);chain.append(node);parent=node
            var f0: float=float(i)/strips;var f1: float=float(i+1)/strips
            # Chord (front-to-back width) shrinks to the tip, which sweeps back.
            var lead0:=Vector3(0,0,-.75+f0*.5);var lead1:=Vector3(side*strip_w,0,-.75+f1*.5)
            var trail0:=Vector3(0,0,.95-f0*.15);var trail1:=Vector3(side*strip_w,0,.95-f1*.15)
            lead1.z=lerpf(-.75+f1*.5,.1,smoothstep(.75,1.0,f1));trail1.z=lerpf(.95-f1*.15,.3,smoothstep(.75,1.0,f1))
            var wb:=Flora.Builder.new()
            var c0: Color=top.lerp(Color("303a52"),f0);var c1: Color=top.lerp(Color("303a52"),f1)
            wb.tri_out_c(lead0,lead1,trail1,c0,c1,c1,Vector3.UP)
            wb.tri_out_c(lead0,trail1,trail0,c0,c1,c0,Vector3.UP)
            wb.tri_out_c(lead0,trail1,lead1,bottom,bottom,bottom,Vector3.DOWN)
            wb.tri_out_c(lead0,trail0,trail1,bottom,bottom,bottom,Vector3.DOWN)
            _mesh_node(node,wb.finish())
        wings.append(chain)
    # A long whip tail.
    var parent_t: Node3D=self
    for i in 6:
        var node:=Node3D.new();node.position=Vector3(0,0,.95 if i==0 else .55);parent_t.add_child(node);segments.append(node);parent_t=node
        var tb:=Flora.Builder.new()
        tb.tube(Vector3.ZERO,Vector3(0,0,.55),.07*(1.0-i*.14),.07*(1.0-(i+1)*.14),5,top)
        _mesh_node(node,tb.finish())

# --- Sea turtle: domed shell, paddling flippers -------------------------------------------------------------------------

func _build_turtle() -> void:
    var shell:=Color("6e7a3c");var rim:=Color("c2a35a");var skin:=Color("8a9a5a");var belly:=Color("e8dcae")
    var b:=Flora.Builder.new()
    b.blob(Vector3(0,.16,.05),Vector3(.64,.38,.8),shell,16,9,.06,7,shell.lightened(.18),0.0)
    b.blob(Vector3(0,.1,.05),Vector3(.7,.15,.86),rim,16,5,.04,12,rim,0.0)
    for k in 5:
        b.blob(Vector3(0,.42,-.45+k*.28),Vector3(.2,.07,.16),shell.lightened(.1),6,3,0.0,3,shell.lightened(.2),-1.0)
    b.blob(Vector3(0,.0,.05),Vector3(.5,.07,.66),belly,12,5,0.0,3,belly,-1.0)
    _mesh_node(self,b.finish(),Vector3.ZERO,fin_mat)
    # Neck and head.
    var neck:=Node3D.new();neck.position=Vector3(0,.08,-.7);add_child(neck);head_node=neck;segments.append(neck)
    var nb:=Flora.Builder.new()
    nb.tube(Vector3.ZERO,Vector3(0,0,-.3),.17,.15,8,skin)
    nb.blob(Vector3(0,.0,-.42),Vector3(.2,.15,.24),skin,10,6,0.0,3,skin.lightened(.08),-1.0)
    nb.blob(Vector3(0,-.07,-.62),Vector3(.12,.07,.11),Color("c9b36a"),7,4,0.0,3,Color("c9b36a"),-1.0)
    for side in [-1.0,1.0]:
        nb.blob(Vector3(side*.15,.07,-.5),Vector3(.045,.045,.045),Color("0a0a0a"),6,4,0.0,3,Color("0a0a0a"),-1.0)
        nb.blob(Vector3(side*.165,.085,-.52),Vector3(.014,.014,.014),Color("ffffff"),4,3,0.0,3,Color("ffffff"),-1.0)
    _mesh_node(neck,nb.finish(),Vector3.ZERO,fin_mat)
    # Flippers: long front paddles, short rear ones, hinged at the shoulders and hips.
    for flipper in [[Vector3(.5,.02,-.35),.95,.5,true],[Vector3(.42,.02,.55),.42,.28,false]]:
        for side in [-1.0,1.0]:
            var anchor: Vector3=flipper[0]
            var root:=Node3D.new();root.position=Vector3(side*anchor.x,anchor.y,anchor.z);add_child(root)
            var length: float=flipper[1];var chord: float=flipper[2]
            var fb:=Flora.Builder.new()
            _fan(fb,Vector3(0,0,-chord*.5),Vector3(0,0,chord*.5),Vector3(side*length,-.3,-chord*.1),Vector3(side*length*.85,-.32,chord*.55),6,skin,skin.darkened(.15))
            _mesh_node(root,fb.finish())
            flippers.append([root,side,1.0,flipper[3]])
    var tb:=Flora.Builder.new()
    tb.tube(Vector3(0,0,.85),Vector3(0,-.02,1.15),.08,.015,5,skin)
    _mesh_node(self,tb.finish(),Vector3.ZERO,fin_mat)

# --- Box jellyfish -----------------------------------------------------------------------------------------------------------

func _build_jelly() -> void:
    bell=Node3D.new();bell.name="Bell";add_child(bell)
    var b:=Flora.Builder.new()
    var tint:=Color("9fd8ff")
    b.blob(Vector3(0,.25,0),Vector3(.62,.55,.62),tint,14,8,.03,4,tint.lightened(.2),0.0)
    for k in 4:
        var a: float=TAU*k/4.0+PI*.25
        b.tube(Vector3(cos(a)*.5,.2,sin(a)*.5),Vector3(cos(a)*.5,-.15,sin(a)*.5),.05,.04,4,Color("c06aff"))
    var mesh: ArrayMesh=b.finish()
    var glass:=StandardMaterial3D.new();glass.vertex_color_use_as_albedo=true;glass.vertex_color_is_srgb=true;glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.albedo_color=Color(1,1,1,.55);glass.emission_enabled=true;glass.emission=Color("5cc4ff");glass.emission_energy_multiplier=.8;glass.roughness=.2
    mesh.surface_set_material(0,glass)
    var node:=MeshInstance3D.new();node.mesh=mesh;bell.add_child(node)
    for k in 14:
        var a: float=TAU*k/14.0
        var chain:=_hanging_chain(bell,Vector3(cos(a)*.42,0,sin(a)*.42),4,.34,.016,Color("e4b8ff") if k%2==0 else Color("a8e4ff"),Color("c9a0ff"),false)
        chains.append(chain)
    shock_light=OmniLight3D.new();shock_light.light_color=Color("7fd0ff");shock_light.light_energy=.35;shock_light.omni_range=4.0;bell.add_child(shock_light)

## A chain of short tubes hanging down (-Y), each hinged on the one above.
func _hanging_chain(parent: Node3D,at: Vector3,count: int,seg_len: float,radius: float,color: Color,glow: Color,beads: bool) -> Array[Node3D]:
    var result: Array[Node3D]=[]
    var holder: Node3D=parent
    for s in count:
        var piece:=Node3D.new();piece.position=at if s==0 else Vector3(0,-seg_len,0);holder.add_child(piece);result.append(piece);holder=piece
        var tb:=Flora.Builder.new()
        tb.tube(Vector3.ZERO,Vector3(0,-seg_len,0),maxf(.004,radius-.0015*s),maxf(.003,radius-.0015*(s+1)),4,color)
        if beads: tb.blob(Vector3(0,-seg_len*.5,0),Vector3.ONE*radius*1.8,glow,5,3,0.0,3,glow,-1.0)
        var tm: ArrayMesh=tb.finish()
        tm.surface_set_material(0,_glow_material(glow,1.2))
        var m:=MeshInstance3D.new();m.mesh=tm;piece.add_child(m)
    return result

# --- Portuguese man o' war ------------------------------------------------------------------------------------------------------

func _build_siphon() -> void:
    float_node=Node3D.new();float_node.name="Float";add_child(float_node)
    var b:=Flora.Builder.new()
    var gas:=Color("6fa8ff")
    b.blob(Vector3(0,.12,0),Vector3(.3,.2,.62),gas,14,8,.02,3,gas.lightened(.35),0.0)
    # The crest: a pink-violet sail along the top.
    for i in 6:
        var f: float=float(i)/5.0
        b.tri(Vector3(0,.3,-.5+f*.9),Vector3(0,.5+.12*sin(f*PI),-.4+f*.9),Vector3(0,.3,-.2+f*.9),Color("e49bd8"))
        b.tri(Vector3(0,.3,-.5+f*.9),Vector3(0,.3,-.2+f*.9),Vector3(0,.5+.12*sin(f*PI),-.4+f*.9),Color("e49bd8"))
    var mesh: ArrayMesh=b.finish()
    var glass:=StandardMaterial3D.new();glass.vertex_color_use_as_albedo=true;glass.vertex_color_is_srgb=true;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
    glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color=Color(1,1,1,.8);glass.emission_enabled=true;glass.emission=Color("7fb2ff");glass.emission_energy_multiplier=.6;glass.roughness=.1
    mesh.surface_set_material(0,glass)
    var node:=MeshInstance3D.new();node.mesh=mesh;float_node.add_child(node)
    for k in 9:
        var a: float=TAU*k/9.0
        var long: bool=k%3==0
        var chain:=_hanging_chain(float_node,Vector3(cos(a)*.14,-.02,sin(a)*.3),12 if long else 7,.62 if long else .5,.02,Color("5d7cff"),Color("a06bff"),true)
        chains.append(chain)

# --- Animation -----------------------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
    if not is_instance_valid(animal): return
    var t: float=animal.motion_clock
    var speed: float=clampf(animal.movement_speed/maxf(.1,animal.definition.run_speed),0.0,1.0)
    var attacking: bool=animal.state in ["Attack","Leap"]
    var yaw: float=animal.rotation.y
    _yaw_rate=lerpf(_yaw_rate,wrapf(yaw-_last_yaw,-PI,PI)/maxf(delta,.001),1.0-exp(-8.0*delta))
    _last_yaw=yaw
    _flash=lerpf(_flash,1.0 if attacking else 0.0,1.0-exp(-10.0*delta))
    if body_mat: body_mat.set_shader_parameter("flash",_flash*.5)
    match kind:
        "fish","eel","snake","puffer","lion": _animate_fish(delta,t,speed,attacking)
        "ray": _animate_ray(delta,t,speed)
        "turtle": _animate_turtle(delta,t,speed)
        "jelly": _animate_jelly(delta,t,speed,attacking)
        "siphon": _animate_siphon(delta,t,speed,attacking)

func _animate_fish(delta: float,t: float,speed: float,attacking: bool) -> void:
    if animal.dead:
        _dead_roll=lerpf(_dead_roll,PI,1.0-exp(-3.0*delta))
        rotation.z=_dead_roll
        for node in segments: node.rotation=node.rotation.lerp(Vector3.ZERO,1.0-exp(-4.0*delta))
        if is_instance_valid(jaw): jaw.rotation.x=lerpf(jaw.rotation.x,-.35,1.0-exp(-3.0*delta))
        for node in pectorals: node.rotation.y=lerpf(node.rotation.y,0.0,1.0-exp(-3.0*delta))
        if spines: spines.scale=spines.scale.lerp(Vector3.ONE*.01,1.0-exp(-3.0*delta))
        return
    _dead_roll=lerpf(_dead_roll,0.0,1.0-exp(-5.0*delta))
    # Banking: lean into a turn, level out when swimming straight.
    _roll=lerpf(_roll,clampf(-_yaw_rate*.22,-.55,.55),1.0-exp(-6.0*delta))
    rotation.z=_dead_roll+_roll
    var count: int=segments.size()
    var vertical: bool=spec.get("vertical",false)
    var frequency: float=float(spec.get("freq",1.0))*(1.5+speed*5.2+(2.2 if attacking else 0.0))
    var amplitude: float=(.05+.26*speed+(.14 if attacking else 0.0))*float(spec.get("amp",1.0))
    var wave: float=float(spec.get("wave",2.4))
    for i in count:
        var f: float=float(i)/maxf(1.0,count-1.0)
        var bend: float=sin(t*frequency-f*wave*2.0)*amplitude*(.2+.8*f*f)
        if kind=="snake" or kind=="eel": bend=sin(t*frequency-f*wave*3.1)*amplitude*(.3+.7*f)
        if vertical: segments[i].rotation.x=bend*.75
        else: segments[i].rotation.y=bend
    # The head counter-sways a touch, like a real fish's.
    if count>0 and not vertical: segments[0].rotation.y-=sin(t*frequency)*amplitude*.2
    if is_instance_valid(tail):
        var swing: float=sin(t*frequency-wave*2.0-.7)*amplitude*1.7
        if vertical: tail.rotation.x=swing*.7
        else: tail.rotation.y=swing
    # Pectoral fins paddle when slow and sweep back when racing; pelvics and dorsal follow.
    for i in pectorals.size():
        var side: float=-1.0 if i==0 else 1.0
        pectorals[i].rotation.y=side*lerpf(.0,.85,smoothstep(.2,.8,speed))
        pectorals[i].rotation.z=side*(.18+sin(t*(1.6+speed)+i*.8)*.2*(1.0-speed*.7))
    for i in pelvics.size():
        pelvics[i].rotation.z=(-1.0 if i==0 else 1.0)*(.2+sin(t*1.7+i)*.12)
    for node in dorsal_nodes: node.rotation.y=sin(t*frequency-.9)*amplitude*.35
    if is_instance_valid(jaw):
        var open: float=.55 if attacking else (.12+sin(t*1.3)*.1 if kind=="eel" else .04+maxf(0.0,sin(t*(.9+speed*2.0)))*.05)
        jaw.rotation.x=lerpf(jaw.rotation.x,-open,1.0-exp(-14.0*delta))
    if shock_light:
        var zap: float=1.0 if attacking else 0.0
        shock_light.light_energy=lerpf(shock_light.light_energy,zap*(2.5+sin(t*60.0)),1.0-exp(-18.0*delta))
        for part in glow_parts:
            var m: StandardMaterial3D=part.mesh.surface_get_material(0)
            m.emission_energy_multiplier=lerpf(m.emission_energy_multiplier,2.0+zap*9.0*absf(sin(t*40.0)),1.0-exp(-16.0*delta))
    if kind=="puffer":
        var threatened: bool=attacking or animal.behavior in ["Pursue","Attack","Retreat"]
        _inflate=lerpf(_inflate,1.0 if threatened else 0.0,1.0-exp(-(5.0 if threatened else 1.2)*delta))
        scale=Vector3.ONE*(1.0+1.15*_inflate)
        if spines: spines.scale=Vector3.ONE*maxf(.01,_inflate)
        for i in pectorals.size(): pectorals[i].rotation.z=(-1.0 if i==0 else 1.0)*(.3+sin(t*14.0+i*PI)*.35)
    elif kind=="lion":
        for side in flippers.size():
            var ribbons: Array=flippers[side]
            for i in ribbons.size():
                var f: float=float(i)/ribbons.size()
                ribbons[i].rotation.x=sin(t*2.2-f*3.0+side*.6)*.22
        for node in dorsal_nodes: node.rotation.z=sin(t*1.7)*.07

func _animate_ray(delta: float,t: float,speed: float) -> void:
    if animal.dead:
        _dead_roll=lerpf(_dead_roll,PI,1.0-exp(-3.0*delta));rotation.z=_dead_roll
        for chain in wings:
            for node in chain: node.rotation.z=lerpf(node.rotation.z,0.0,1.0-exp(-3.0*delta))
        return
    _dead_roll=lerpf(_dead_roll,0.0,1.0-exp(-5.0*delta))
    _roll=lerpf(_roll,clampf(-_yaw_rate*.3,-.6,.6),1.0-exp(-5.0*delta))
    rotation.z=_dead_roll+_roll
    var freq: float=1.1+speed*2.6
    var amp: float=.2+.2*speed
    for side in wings.size():
        var chain: Array=wings[side]
        var sign: float=-1.0 if side==0 else 1.0
        # Each strip hangs off the last, so set the wing's absolute angle at every strip and
        # rotate by the difference: a smooth ripple from the body out to the tip.
        var previous: float=0.0
        for i in chain.size():
            var f: float=float(i)/chain.size()
            var theta: float=sign*(sin(t*freq-f*2.2)*amp*(.12+f)*.7+.03*f)
            chain[i].rotation.z=theta-previous
            previous=theta
    for i in segments.size(): segments[i].rotation.y=sin(t*freq*1.3-i*.7)*.18*(.5+i*.15)

func _animate_turtle(delta: float,t: float,speed: float) -> void:
    if animal.dead:
        _dead_roll=lerpf(_dead_roll,PI,1.0-exp(-3.0*delta));rotation.z=_dead_roll
        return
    _dead_roll=lerpf(_dead_roll,0.0,1.0-exp(-5.0*delta))
    _roll=lerpf(_roll,clampf(-_yaw_rate*.2,-.4,.4),1.0-exp(-5.0*delta))
    rotation.z=_dead_roll+_roll
    var freq: float=1.0+speed*2.4
    for entry in flippers:
        var root: Node3D=entry[0];var side: float=entry[1];var front: bool=entry[3]
        if front:
            # Both front flippers drive down together, then sweep back up.
            var stroke: float=sin(t*freq)
            root.rotation.z=side*stroke*.7
            root.rotation.y=side*(-.25+cos(t*freq)*.3)
            root.rotation.x=cos(t*freq)*.12
        else:
            root.rotation.z=side*sin(t*freq+1.0)*.3
            root.rotation.y=side*(.2+sin(t*freq*.5)*.2)
    for node in segments:
        node.rotation.x=sin(t*freq*.5)*.05+.06*speed
        node.rotation.y=sin(t*.4)*.12

func _animate_jelly(delta: float,t: float,speed: float,attacking: bool) -> void:
    if animal.dead:
        bell.rotation.z=lerpf(bell.rotation.z,PI,1.0-exp(-3.0*delta))
        return
    bell.rotation.z=lerpf(bell.rotation.z,0.0,1.0-exp(-4.0*delta))
    var pulse: float=sin(t*(2.2+speed*3.0+(3.0 if attacking else 0.0)))
    bell.scale=Vector3(1.0-pulse*.1,1.0+pulse*.22,1.0-pulse*.1)
    for i in chains.size():
        var links: Array=chains[i]
        for s in links.size():
            links[s].rotation.x=sin(t*1.6+i*.7-s*.7)*.28
            links[s].rotation.z=cos(t*1.3+i*.5-s*.6)*.24
    if shock_light: shock_light.light_energy=.35+(1.2 if attacking else 0.0)+pulse*.1

func _animate_siphon(delta: float,t: float,_speed: float,attacking: bool) -> void:
    if animal.dead:
        float_node.rotation.z=lerpf(float_node.rotation.z,PI,1.0-exp(-3.0*delta))
        return
    float_node.rotation.z=lerpf(float_node.rotation.z,sin(t*.7)*.06,1.0-exp(-4.0*delta))
    float_node.position.y=sin(t*1.1)*.05
    float_node.rotation.x=sin(t*.9+1.0)*.05
    for i in chains.size():
        var links: Array=chains[i]
        var reach: float=.45 if attacking else 0.0
        for s in links.size():
            links[s].rotation.x=sin(t*1.2+i*.8-s*.55)*.2+reach*sin(t*6.0-s*.6)*.5
            links[s].rotation.z=cos(t*1.0+i*.5-s*.5)*.2
