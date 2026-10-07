extends Node3D
## The Colossal Squid: ocean boss, ~28 m from the tips of its feeding tentacles to the end
## of its fins. Built procedurally and animated entirely from replicated state.
##
## Anatomy (the model faces -Z, arms and tentacles lead, the mantle trails):
##  - a lofted mantle with two broad swimming fins and a row of glowing photophores;
##  - a head with two enormous eyes (glossy, with a glowing iris that turns red when angry),
##    a funnel that flares when it jets, and a hinged beak ringed with tiny teeth;
##  - eight arms of nine linked segments with rows of suckers, and two feeding tentacles of
##    fourteen segments each ending in a club armed with large suckers and hooks.
##
## Animation: idle drifting (arms fanned and rippling, mantle breathing, fins waving),
## hunting (arms spread, tentacles reaching), a three-hit tentacle combo (coil back, lash
## with a travelling whip, recover) retriggered on each `attack_sequence`, a jet lunge (arms
## streamlined, mantle contracting, fins folded), an ink cloud when it bolts, and a limp roll
## onto its back when it dies.
const Flora:=preload("res://world/ocean/ocean_flora.gd")
const SquidShader:=preload("res://actors/animals/squid.gdshader")
const BACK:=Color("9a2636")
const MID:=Color("c8472f")
const BELLY:=Color("f6c4aa")
const ARM:=Color("92243a")
const SUCKER:=Color("f0b9a8")
const ARM_COUNT: int=8
const ARM_SEGMENTS: int=9
const TENTACLE_SEGMENTS: int=14

var animal: WildlifeAnimal
var skin: ShaderMaterial
var eye_mat: StandardMaterial3D
var iris_mat: StandardMaterial3D
var glow_mat: StandardMaterial3D
var mantle: Node3D
var head: Node3D
var funnel: Node3D
var beak_up: Node3D
var beak_low: Node3D
var fins: Array[Node3D]=[]
var arms: Array=[]
var tentacles: Array=[]
var ink: CPUParticles3D
var _agit: float=0.0
var _strike_t: float=99.0
var _seq: int=0
var _roll: float=0.0
var _dead_roll: float=0.0
var _last_yaw: float=0.0
var _yaw_rate: float=0.0
var _hunt: float=0.0
var _jet: float=0.0

func _ready() -> void:
    animal=get_parent() as WildlifeAnimal
    skin=ShaderMaterial.new();skin.shader=SquidShader
    eye_mat=StandardMaterial3D.new();eye_mat.albedo_color=Color("05070c");eye_mat.roughness=.08;eye_mat.metallic=.2;eye_mat.metallic_specular=1.0
    iris_mat=StandardMaterial3D.new();iris_mat.albedo_color=Color("ffb347");iris_mat.emission_enabled=true;iris_mat.emission=Color("ffa133");iris_mat.emission_energy_multiplier=1.6;iris_mat.roughness=.1
    glow_mat=StandardMaterial3D.new();glow_mat.albedo_color=Color("9be8ff");glow_mat.emission_enabled=true;glow_mat.emission=Color("5fd8ff");glow_mat.emission_energy_multiplier=1.5;glow_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    _build_mantle()
    _build_fins()
    _build_head()
    _build_arms()
    _build_tentacles()
    _build_ink()
    for node in find_children("*","MeshInstance3D",true,false):
        node.set_meta("styled",true)
        node.visibility_range_end=520.0
        node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if is_instance_valid(animal): _last_yaw=animal.rotation.y;_seq=animal.attack_sequence

func _node(parent: Node3D,mesh: ArrayMesh,material: Material,point: Vector3=Vector3.ZERO) -> MeshInstance3D:
    if mesh.get_surface_count()>0: mesh.surface_set_material(0,material)
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=point;parent.add_child(node);return node

# --- Build ----------------------------------------------------------------------------------------------

func _mantle_radius(t: float) -> float:
    return 1.95*pow(maxf(0.0,1.0-pow(t,1.9)),.72)*(.62+.38*smoothstep(.0,.2,t))

func _build_mantle() -> void:
    mantle=Node3D.new();mantle.name="Mantle";mantle.position=Vector3(0,0,.5);add_child(mantle)
    var b:=Flora.Builder.new()
    var rings: int=22;var sides: int=24
    var length: float=9.8
    var prev: Array[Vector3]=[];var prev_c: Array[Color]=[]
    for k in rings+1:
        var t: float=float(k)/rings
        var r: float=_mantle_radius(t)
        var z: float=t*length
        var ring: Array[Vector3]=[];var colors: Array[Color]=[]
        for s in sides+1:
            var a: float=TAU*s/sides
            ring.append(Vector3(cos(a)*r*.94,sin(a)*r*.88,z))
            var back: float=smoothstep(-.45,.5,sin(a))
            var c: Color=BELLY.lerp(MID,smoothstep(-.8,-.1,sin(a))).lerp(BACK,back)
            colors.append(c)
        if not prev.is_empty():
            for s in sides:
                var o:=Vector3(ring[s].x+ring[s+1].x,ring[s].y+ring[s+1].y,0.0)
                b.tri_out_c(prev[s],prev[s+1],ring[s],prev_c[s],prev_c[s+1],colors[s],o)
                b.tri_out_c(prev[s+1],ring[s+1],ring[s],prev_c[s+1],colors[s+1],colors[s],o)
        prev=ring;prev_c=colors
    for s in sides:
        b.tri_out_c(Vector3(0,0,length+.25),prev[s],prev[s+1],BACK,prev_c[s],prev_c[s+1],Vector3(0,0,1))
    # Mantle collar where it meets the head: a rim of pale muscle.
    b.tube(Vector3(0,0,-.1),Vector3(0,0,.3),.98,1.0,24,BELLY,MID)
    _node(mantle,b.finish(),skin)
    # Photophores: two rows of glowing studs along the sides of the mantle.
    var pb:=Flora.Builder.new()
    for i in 14:
        var t: float=.12+float(i)/14.0*.72
        var r: float=_mantle_radius(t)*.94
        for side in [-1.0,1.0]:
            pb.blob(Vector3(side*r*.99,-r*.18,t*length),Vector3(.07,.07,.07),Color("9be8ff"),6,4,0.0,3,Color("9be8ff"),-1.0)
    _node(mantle,pb.finish(),glow_mat)

func _build_fins() -> void:
    for side in [-1.0,1.0]:
        var hinge:=Node3D.new();hinge.position=Vector3(side*.8,.0,6.4);mantle.add_child(hinge);fins.append(hinge)
        var b:=Flora.Builder.new()
        # A lens-shaped fin: leading edge swept forward, trailing edge rounded.
        var perimeter: Array[Vector3]=[]
        for i in 15:
            var u: float=float(i)/14.0
            var z: float=lerpf(-2.6,2.7,u)
            var x: float=side*(.15+4.6*pow(sin(PI*u),.8))
            perimeter.append(Vector3(x,-.04*sin(u*PI),z))
        var root_a:=Vector3(side*.1,0,-2.6);var root_b:=Vector3(side*.1,0,2.7)
        for i in 14:
            var u0: float=float(i)/14.0;var u1: float=float(i+1)/14.0
            var c0: Color=ARM.lerp(MID,u0);var c1: Color=ARM.lerp(MID,u1)
            var edge: Color=Color("c9606a")
            var r0: Vector3=root_a.lerp(root_b,u0);var r1: Vector3=root_a.lerp(root_b,u1)
            b.tri_out_c(r0,perimeter[i],perimeter[i+1],c0,edge,edge,Vector3.UP)
            b.tri_out_c(r0,perimeter[i+1],r1,c0,edge,c1,Vector3.UP)
            b.tri_out_c(r0,perimeter[i+1],perimeter[i],c0,edge,edge,Vector3.DOWN)
            b.tri_out_c(r0,r1,perimeter[i+1],c0,c1,edge,Vector3.DOWN)
        _node(hinge,b.finish(),skin)

func _build_head() -> void:
    head=Node3D.new();head.name="Head";head.scale=Vector3.ONE*1.3;add_child(head)
    var b:=Flora.Builder.new()
    b.blob(Vector3(0,0,-.55),Vector3(1.22,1.1,1.35),MID,18,10,.02,5,BACK,-1.0)
    b.blob(Vector3(0,-.5,-1.15),Vector3(.95,.55,.7),BELLY,14,6,.03,6,MID,-1.0)
    _node(head,b.finish(),skin)
    # Eyes: huge, glossy and dark, with a glowing iris and a black slit pupil, set into brow ridges.
    for side in [-1.0,1.0]:
        var eb:=Flora.Builder.new()
        eb.blob(Vector3(side*1.18,.2,-.62),Vector3(.62,.66,.62),Color("0a1018"),18,10,0.0,3,Color("0a1018"),-1.0)
        _node(head,eb.finish(),eye_mat)
        var ib:=Flora.Builder.new()
        ib.blob(Vector3(side*1.52,.2,-.78),Vector3(.3,.34,.2),Color("ffb347"),14,8,0.0,3,Color("ffb347"),-1.0)
        _node(head,ib.finish(),iris_mat)
        var pb:=Flora.Builder.new()
        pb.blob(Vector3(side*1.66,.2,-.84),Vector3(.1,.26,.1),Color("020304"),10,6,0.0,3,Color("020304"),-1.0)
        pb.blob(Vector3(side*1.71,.34,-.96),Vector3(.045,.045,.045),Color("ffffff"),6,4,0.0,3,Color("ffffff"),-1.0)
        _node(head,pb.finish(),eye_mat)
        var brow:=Flora.Builder.new()
        brow.tube(Vector3(side*.78,.78,-.2),Vector3(side*1.62,.62,-1.0),.14,.08,6,MID)
        _node(head,brow.finish(),skin)
    # Funnel under the head: the jet nozzle.
    funnel=Node3D.new();funnel.position=Vector3(0,-.82,.35);head.add_child(funnel)
    var fb:=Flora.Builder.new()
    fb.tube(Vector3.ZERO,Vector3(0,.1,1.2),.34,.28,12,BELLY,MID)
    fb.tube(Vector3(0,.1,1.2),Vector3(0,.12,1.45),.3,.36,12,MID,BELLY)
    _node(funnel,fb.finish(),skin)
    # Beak: two hooked halves of dark horn with a pale tip, ringed by tiny buccal teeth.
    beak_up=Node3D.new();beak_up.position=Vector3(0,-.12,-1.62);head.add_child(beak_up)
    beak_low=Node3D.new();beak_low.position=Vector3(0,-.28,-1.62);head.add_child(beak_low)
    var ub:=Flora.Builder.new()
    ub.tube(Vector3(0,.12,.3),Vector3(0,.02,-.35),.26,.1,8,Color("2a1810"))
    ub.tube(Vector3(0,.02,-.35),Vector3(0,-.28,-.62),.1,.01,8,Color("2a1810"),Color("e8d9b8"))
    _node(beak_up,ub.finish(),eye_mat)
    var lb:=Flora.Builder.new()
    lb.tube(Vector3(0,-.05,.28),Vector3(0,-.12,-.3),.2,.09,8,Color("2a1810"))
    lb.tube(Vector3(0,-.12,-.3),Vector3(0,-.05,-.52),.09,.01,8,Color("2a1810"),Color("e8d9b8"))
    _node(beak_low,lb.finish(),eye_mat)
    var tb:=Flora.Builder.new()
    for i in 16:
        var a: float=TAU*i/16.0
        var at:=Vector3(cos(a)*.62,-.2+sin(a)*.46,-1.5)
        tb.tube(at,at+Vector3(0,0,-.12),.03,.004,3,Color("f0e4c6"))
    _node(head,tb.finish(),eye_mat)

## A chain of linked segments pointing along -Z: each one hangs off the end of the last.
func _chain(parent: Node3D,at: Vector3,count: int,seg_len: float,r0: float,r1: float,color: Color,belly: Color,inward: Vector3,club: bool) -> Array[Node3D]:
    var result: Array[Node3D]=[]
    var holder: Node3D=parent
    for i in count:
        var node:=Node3D.new();node.position=at if i==0 else Vector3(0,0,-seg_len);holder.add_child(node);result.append(node);holder=node
        var f0: float=float(i)/count;var f1: float=float(i+1)/count
        var ra: float=lerpf(r0,r1,f0);var rb: float=lerpf(r0,r1,f1)
        if club:
            var swell0: float=clampf((float(i)-(count-5))/3.0,0.0,1.0)
            var swell1: float=clampf((float(i+1)-(count-5))/3.0,0.0,1.0)
            ra*=1.0+1.7*sin(swell0*PI*.5);rb*=1.0+1.7*sin(swell1*PI*.5)
            if i==count-1: rb*=.25
        var b:=Flora.Builder.new()
        b.tube(Vector3.ZERO,Vector3(0,0,-seg_len),ra,rb,9,color.lerp(belly,.0),color.lerp(belly,.18))
        # Suckers: little discs on the inner face, bigger and rimmed on the club.
        var big: bool=club and i>=count-4
        for k in (3 if big else 2):
            var z: float=-seg_len*(.2+.3*k)
            var rr: float=lerpf(ra,rb,.2+.3*k)
            var s_r: float=rr*(.34 if big else .3)
            var base: Vector3=inward*rr*.92+Vector3(0,0,z)
            b.tube(base,base+inward*s_r*.9,s_r,s_r*.8,8,SUCKER,SUCKER.lightened(.15))
            b.tube(base+inward*s_r*.88,base+inward*s_r*1.0,s_r*.55,s_r*.5,8,Color("5a1a28"),Color("5a1a28"))
            if big and k==1:
                b.tube(base+Vector3(0,0,-s_r*1.4),base+Vector3(0,0,-s_r*1.4)+inward*s_r*1.7,s_r*.3,.004,4,Color("1c1410"))
        var m:=MeshInstance3D.new();m.mesh=b.finish();if m.mesh.get_surface_count()>0: m.mesh.surface_set_material(0,skin)
        node.add_child(m)
    return result

func _build_arms() -> void:
    var ring_z: float=-1.45
    for i in ARM_COUNT:
        var a: float=TAU*i/ARM_COUNT+TAU/16.0
        var at:=Vector3(cos(a)*.78,sin(a)*.66-.12,ring_z)
        var inward:=Vector3(-cos(a),-sin(a),0).normalized()
        var count: int=ARM_SEGMENTS+(2 if i%4==0 else 0)
        var segs: Array[Node3D]=_chain(head,at,count,1.05,.46,.04,ARM,BELLY,inward,false)
        arms.append({"segs":segs,"angle":a})

func _build_tentacles() -> void:
    for side in [-1.0,1.0]:
        var at:=Vector3(side*.34,.5,-1.5)
        var segs: Array[Node3D]=_chain(head,at,TENTACLE_SEGMENTS,1.25,.2,.1,Color("b83c36"),BELLY,Vector3(0,-1,0),true)
        tentacles.append({"segs":segs,"side":side})

func _build_ink() -> void:
    ink=CPUParticles3D.new();ink.name="Ink";ink.position=Vector3(0,-.7,1.9);ink.emitting=false;ink.amount=90;ink.lifetime=3.4
    ink.direction=Vector3(0,0,1);ink.spread=38.0;ink.initial_velocity_min=7.0;ink.initial_velocity_max=13.0;ink.damping_min=3.0;ink.damping_max=5.0
    ink.gravity=Vector3.ZERO;ink.local_coords=false;ink.scale_amount_min=1.4;ink.scale_amount_max=3.6
    var curve:=Curve.new();curve.add_point(Vector2(0,.35));curve.add_point(Vector2(.5,1.0));curve.add_point(Vector2(1,1.5));ink.scale_amount_curve=curve
    var ramp:=Gradient.new();ramp.set_color(0,Color(.02,.01,.04,.92));ramp.set_color(1,Color(.03,.02,.07,0.0));ink.color_ramp=ramp
    var sphere:=SphereMesh.new();sphere.radius=1.0;sphere.height=2.0;sphere.radial_segments=14;sphere.rings=8
    var smoke:=StandardMaterial3D.new();smoke.vertex_color_use_as_albedo=true;smoke.albedo_color=Color(1,1,1,1);smoke.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    sphere.material=smoke;ink.mesh=sphere
    add_child(ink)

# --- Animation --------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
    if not is_instance_valid(animal): return
    var t: float=animal.motion_clock
    var speed: float=clampf(animal.movement_speed/maxf(.1,animal.definition.run_speed),0.0,1.0)
    var state: String=animal.state
    var behavior: String=animal.behavior
    var dead: bool=animal.dead
    var jetting: bool=state=="Leap"
    var hunting: bool=behavior in ["Pursue","Circle","Retreat","Attack","Pounce","Leap"]
    var yaw: float=animal.rotation.y
    _yaw_rate=lerpf(_yaw_rate,wrapf(yaw-_last_yaw,-PI,PI)/maxf(delta,.001),1.0-exp(-6.0*delta))
    _last_yaw=yaw
    # A new strike (each hit of the combo bumps attack_sequence) restarts the lash timeline.
    if animal.attack_sequence!=_seq and not dead:
        _seq=animal.attack_sequence
        if not jetting: _strike_t=0.0
    _strike_t+=delta
    var agit_target: float=1.0 if (state=="Attack" or jetting or _strike_t<1.0) else (.55 if hunting else .08)
    if dead: agit_target=0.0
    _agit=lerpf(_agit,agit_target,1.0-exp(-5.0*delta))
    _hunt=lerpf(_hunt,1.0 if hunting and not dead else 0.0,1.0-exp(-3.0*delta))
    _jet=lerpf(_jet,1.0 if jetting else 0.0,1.0-exp(-9.0*delta))
    skin.set_shader_parameter("agitation",_agit)
    skin.set_shader_parameter("glow_amount",0.0 if dead else .6+_agit*.8)
    iris_mat.emission_energy_multiplier=0.0 if dead else 1.4+_agit*2.8
    iris_mat.emission=Color("ffa133").lerp(Color("ff2a1c"),_agit)
    iris_mat.albedo_color=Color("ffb347").lerp(Color("ff4a30"),_agit)
    glow_mat.emission_energy_multiplier=0.0 if dead else 1.2+sin(t*2.0)*.5+_agit*1.5
    ink.emitting=behavior=="Ink" and not dead
    _animate_body(delta,t,speed,dead)
    _animate_limbs(t,dead)

func _animate_body(delta: float,t: float,speed: float,dead: bool) -> void:
    if dead:
        _dead_roll=lerpf(_dead_roll,PI,1.0-exp(-2.0*delta));rotation.z=_dead_roll
        mantle.scale=mantle.scale.lerp(Vector3.ONE,1.0-exp(-3.0*delta))
        for fin in fins: fin.rotation=fin.rotation.lerp(Vector3.ZERO,1.0-exp(-3.0*delta))
        beak_up.rotation.x=lerpf(beak_up.rotation.x,.25,1.0-exp(-3.0*delta))
        beak_low.rotation.x=lerpf(beak_low.rotation.x,-.25,1.0-exp(-3.0*delta))
        return
    _dead_roll=lerpf(_dead_roll,0.0,1.0-exp(-5.0*delta))
    _roll=lerpf(_roll,clampf(-_yaw_rate*.2,-.45,.45),1.0-exp(-5.0*delta))
    rotation.z=_dead_roll+_roll
    # Mantle: slow breathing when idle, hard contractions when jetting.
    var rate: float=1.2+_jet*2.4+speed*.8
    var pulse: float=sin(t*rate*(1.0 if _jet<.5 else 2.6))
    var amount: float=.03+_jet*.13
    mantle.scale=Vector3(1.0+pulse*amount,1.0+pulse*amount,1.0-pulse*amount*.8)
    funnel.scale=Vector3.ONE*(1.0+_jet*.55+maxf(0.0,pulse)*_jet*.3)
    # Fins ripple lazily; they fold back against the mantle in a jet.
    for i in fins.size():
        var side: float=-1.0 if i==0 else 1.0
        var flap: float=sin(t*(1.8+speed*1.5)-i*.4)*(.3-.2*_jet)
        fins[i].rotation=Vector3(0,side*(-.7*_jet),side*flap)
    # The head looks where the animal is looking, within limits.
    var local: Vector3=animal.global_basis.inverse()*(animal.look_target-animal.global_position)
    var want: float=clampf(atan2(-local.x,-local.z),-.5,.5) if local.z<0.0 else 0.0
    head.rotation.y=lerpf(head.rotation.y,want,1.0-exp(-3.0*delta))
    # Beak: chews idly, gapes when striking.
    var gape: float=.5 if (_strike_t>.3 and _strike_t<.9) else (.12+maxf(0.0,sin(t*1.1))*.1)
    beak_up.rotation.x=lerpf(beak_up.rotation.x,gape*.7,1.0-exp(-14.0*delta))
    beak_low.rotation.x=lerpf(beak_low.rotation.x,-gape*.9,1.0-exp(-14.0*delta))

func _animate_limbs(t: float,dead: bool) -> void:
    # Arms: fanned out and rippling; flared at a strike, drawn together in a jet, limp in death.
    var strike_wind: float=clampf(_strike_t/.4,0.0,1.0) if _strike_t<.9 else 0.0
    var spread: float=lerpf(.3,.58,_hunt)+.35*strike_wind*(1.0 if _strike_t<.75 else 0.0)
    spread=lerpf(spread,.04,_jet)
    var wave: float=lerpf(.13,.07,_hunt)*(1.0-_jet*.85)
    for arm in arms:
        var segs: Array=arm.segs;var a: float=arm.angle
        for i in segs.size():
            var f: float=float(i)/segs.size()
            if dead:
                segs[i].rotation=segs[i].rotation.lerp(Vector3(-.12,0,0),.04)
                continue
            var yaw: float=sin(t*1.1-i*.6+a*3.0)*wave*(.4+f)
            var pitch: float=cos(t*.9-i*.5+a*2.0)*wave*(.4+f)-.025
            if i==0:
                yaw+=-cos(a)*spread
                pitch+=sin(a)*spread
            else:
                yaw+=-cos(a)*spread*.2*(1.0-f)
                pitch+=sin(a)*spread*.2*(1.0-f)
            if strike_wind>0.0 and _strike_t<.75: pitch+=.08*strike_wind
            segs[i].rotation=Vector3(pitch,yaw,0)
    # Tentacles: coiled and relaxed when idle, reaching when hunting, and on a strike they pull
    # back (coil), whip out with a travelling wave, then recover.
    var base_reach: float=lerpf(.15,.8,_hunt)
    base_reach=lerpf(base_reach,.9,_jet)
    var reach: float=base_reach;var whip: float=0.0
    if _strike_t<.4:
        reach=lerpf(base_reach,-.3,_ease(_strike_t/.4))
    elif _strike_t<.72:
        var u: float=(_strike_t-.4)/.32
        reach=lerpf(-.3,1.2,u*u*(3.0-2.0*u))
        whip=sin(u*PI)
    elif _strike_t<1.4:
        reach=lerpf(1.2,base_reach,_ease((_strike_t-.72)/.68))
        whip=maxf(0.0,1.0-(_strike_t-.72)/.5)*.5
    for tentacle in tentacles:
        var segs: Array=tentacle.segs;var side: float=tentacle.side
        var curl: float=clampf(1.0-reach,-.3,1.3)
        for i in segs.size():
            var f: float=float(i)/segs.size()
            if dead:
                segs[i].rotation=segs[i].rotation.lerp(Vector3(-.1,0,0),.04)
                continue
            var pitch: float=curl*.4+sin(t*1.4-i*.5+side)*.1*(1.0+curl)
            var yaw: float=cos(t*1.2-i*.45+side*2.0)*.12*(1.0+curl)+curl*.2*side*(1.0-f*.5)
            if whip>0.0:
                yaw+=sin(_strike_t*14.0-i*.6)*.55*whip*(1.0-f*.35)
                pitch*=1.0-whip*.6
            segs[i].rotation=Vector3(pitch,yaw,0)

func _ease(x: float) -> float:
    var v: float=clampf(x,0.0,1.0)
    return v*v*(3.0-2.0*v)
