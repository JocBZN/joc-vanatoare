extends Node3D
## Dresses an imported animal rig as a boss: the Ancient Bear (a forest grown on
## its back, amber crystals, a crown of antler-branches, glowing eyes, huge claws)
## or the Albino Saltwater Crocodile (osteoderm spikes, barnacles, an old harpoon
## with its rope still trailing, ruby eyes, a jaw full of teeth).
## Pieces are toon meshes on bone attachments, so they move with the animation,
## and are tagged "styled" so WildlifeAnimal keeps their colours.
## Points are written in the rig's own rest pose (from the stylized bear and the
## swamp crocodile at scale 1) and multiplied by `grow`, the boss's size factor.

const Toon:=preload("res://world/camp/toon_builder.gd")
@export var kind: String="ancient_bear"
@export var grow: float=2.2
var skeleton: Skeleton3D
var _builders: Dictionary={}
var _frames: Dictionary={}
var _rng:=RandomNumberGenerator.new()

const MOSS:=Color("4f7d34")
const MOSS_DARK:=Color("3b6229")
const LICHEN:=Color("a7b58a")
const BARK:=Color("5a3f28")
const BONE:=Color("eadfc6")
const AMBER:=Color("ffae3b")
const RUNE:=Color("7fe9ff")
const STONE:=Color("7a7873")
const FIR:=Color("2f5d3a")
const FIR_LIGHT:=Color("3f7346")
const CAP:=Color("d23c3c")
const IRON:=Color("4a4440")
const RUST:=Color("8a4b2a")
const ROPE:=Color("c9b48a")
const ALGAE:=Color("5d8a3a")
const BARNACLE:=Color("d8d2c4")
const RUBY:=Color("ff3048")

func _ready() -> void:
    _rng.seed=hash(kind)
    var found:=find_children("*","Skeleton3D",true,false)
    if found.is_empty(): return
    skeleton=found[0]
    if kind=="albino_crocodile": _crocodile()
    else: _bear()
    for bone in _builders: _builders[bone].commit(_frames[bone],"Boss",true)
    _builders.clear()

## Rig rest point scaled to the boss.
func p(x: float, y: float, z: float) -> Vector3:
    return Vector3(x,y,z)*grow

## The toon builder whose meshes follow `bone`, authored in model space.
func on(bone: String) -> Object:
    if _builders.has(bone): return _builders[bone]
    var index: int=skeleton.find_bone(bone)
    var parent: Node3D=self
    if index>=0:
        var attachment:=BoneAttachment3D.new();attachment.name="Boss"+bone.replace(".","");attachment.bone_name=bone
        skeleton.add_child(attachment)
        var rest: Transform3D=skeleton.global_transform*skeleton.get_bone_global_rest(index)
        var frame:=Node3D.new();frame.name="Frame";attachment.add_child(frame)
        frame.transform=rest.affine_inverse()*global_transform
        parent=frame
    _frames[bone]=parent
    _builders[bone]=Toon.new()
    return _builders[bone]

## A cone standing from `base` toward `tip`.
func cone(t: Object, base: Vector3, tip: Vector3, radius: float, color: Color, segments: int=6, glow: float=0.0) -> void:
    var along: Vector3=tip-base
    var length: float=along.length()
    if length<.001: return
    var up: Vector3=along/length
    var side: Vector3=up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<.9 else Vector3.RIGHT).normalized()
    var shape:=CylinderMesh.new();shape.top_radius=0.0;shape.bottom_radius=radius;shape.height=length;shape.radial_segments=segments;shape.rings=1
    t.mesh(shape,Transform3D(Basis(side,up,side.cross(up)).orthonormalized(),(base+tip)*.5),color,glow)

## A curved claw or tooth: two cone segments bending toward `bend`.
func claw(t: Object, base: Vector3, direction: Vector3, bend: Vector3, length: float, radius: float, color: Color) -> void:
    var middle: Vector3=base+direction.normalized()*length*.55
    t.rod(base,middle,radius,color,5,radius*.75)
    cone(t,middle,middle+(direction.normalized()*.55+bend.normalized()*.45).normalized()*length*.5,radius*.75,color,5)

# --- The Ancient Bear --------------------------------------------------------------

func _bear() -> void:
    _bear_back()
    _bear_shoulders()
    _bear_head()
    _bear_paws()
    var glow:=OmniLight3D.new();glow.light_color=Color("ffb35c");glow.light_energy=1.6;glow.omni_range=7.0
    glow.position=p(0,2.3,-.45);glow.distance_fade_enabled=true;glow.distance_fade_begin=60.0;add_child(glow)

## A little old forest grows along the spine: moss, firs, mushrooms, a nest.
func _bear_back() -> void:
    var spots: Array=[["Chest",-.55,2.02],["Chest",-.3,2.04],["Spine",-.05,2.0],["Spine",.25,1.96],["Spine",.5,1.9],["Pelvis",.8,1.82],["Pelvis",1.05,1.7]]
    for spot in spots:
        var t=on(spot[0])
        for k in 3:
            var x: float=(k-1)*.22+_rng.randf_range(-.06,.06)
            var y: float=float(spot[2])-absf(x)*.35
            t.sphere(p(x,y,float(spot[1])+_rng.randf_range(-.08,.08)),.16*grow,MOSS if k!=1 else MOSS_DARK,Vector3(1.5,.45,1.4))
    # Three small firs, as if the bear has slept under them for a century.
    for fir in [["Spine",-.12,1.98,.05,1.0],["Pelvis",.16,1.8,.82,.8],["Chest",.1,2.0,-.42,.7]]:
        var t=on(fir[0])
        var base: Vector3=p(float(fir[1]),float(fir[2]),float(fir[3]))
        var tall: float=float(fir[4])*grow
        t.rod(base,base+Vector3.UP*tall*.35,.035*grow,BARK,5)
        for layer in 3:
            var y: float=tall*(.22+layer*.24)
            var r: float=tall*(.3-layer*.07)
            t.cylinder(base+Vector3.UP*(y+r*.55),0.0,r,r*1.3,FIR if layer%2==0 else FIR_LIGHT,Vector3.ZERO,7)
    # Mushrooms on the flanks and a bird's nest with eggs on the rump.
    for m in [["Spine",.42,1.62,.1],["Spine",-.4,1.7,.35],["Pelvis",.38,1.5,.95],["Chest",-.45,1.75,-.6]]:
        var t=on(m[0])
        var at: Vector3=p(float(m[1]),float(m[2]),float(m[3]))
        var out:=Vector3(signf(float(m[1])),0,0)
        t.rod(at,at+out*.08*grow+Vector3.UP*.06*grow,.025*grow,BONE,5)
        t.sphere(at+out*.1*grow+Vector3.UP*.1*grow,.09*grow,CAP,Vector3(1,.55,1))
        t.sphere(at+out*.13*grow+Vector3.UP*.14*grow,.018*grow,BONE)
    var nest=on("Pelvis")
    var nest_at: Vector3=p(-.08,1.78,1.12)
    for k in 8:
        var angle: float=k*TAU/8.0
        nest.rod(nest_at+Vector3(cos(angle),0,sin(angle))*.13*grow,nest_at+Vector3(cos(angle+1.4),.05,sin(angle+1.4))*.13*grow,.016*grow,BARK,4)
    for k in 3: nest.sphere(nest_at+Vector3((k-1)*.05,.05,.02*k)*grow,.035*grow,Color("bfe3f0"),Vector3(1,1.3,1))
    # Old broken arrows from hunters who did not make it.
    for arrow in [[.36,1.65,.3,Vector3(.8,.5,.3)],[-.4,1.72,-.2,Vector3(-.7,.6,-.2)],[.3,1.55,.85,Vector3(.6,.7,.4)]]:
        var t=on("Spine")
        var at: Vector3=p(float(arrow[0]),float(arrow[1]),float(arrow[2]))
        var tail: Vector3=at+Vector3(arrow[3]).normalized()*.55*grow
        t.rod(at,tail,.012*grow,Color("8a6a43"),4)
        t.box_at(tail,Vector3(.01,.09,.12)*grow,Vector3(0,0,0),Color("e8e2d0"))

## Amber crystals burst out of the shoulders, with glowing runes and stone plates.
func _bear_shoulders() -> void:
    var t=on("Chest")
    for side in [-1.0,1.0]:
        for k in 4:
            var base: Vector3=p(side*(.26+k*.05),1.92-k*.06,-.62+k*.16)
            var tip: Vector3=base+Vector3(side*.25,.55+_rng.randf_range(-.08,.12),_rng.randf_range(-.15,.15)).normalized()*(.42-k*.06)*grow
            cone(t,base,tip,(.1-k*.012)*grow,AMBER,5,1.3)
        t.box_at(p(side*.5,1.62,-.5),Vector3(.06,.5,.42)*grow,Vector3(0,0,side*.25),STONE)
        t.box_at(p(side*.53,1.58,-.25),Vector3(.05,.36,.3)*grow,Vector3(0,0,side*.3),STONE.darkened(.15))
        for r in 3:
            t.box_at(p(side*.55,1.45+r*.12,-.52+r*.04),Vector3(.02,.035,.22)*grow,Vector3(0,0,side*.3),RUNE,3.0)
    # A shaggy mane of dark spikes around the neck.
    var mane=on("Neck")
    for k in 14:
        var angle: float=lerpf(-2.2,2.2,k/13.0)
        var root_point: Vector3=p(sin(angle)*.36,1.48+cos(angle)*.3,-.95)
        cone(mane,root_point,root_point+Vector3(sin(angle)*.35,cos(angle)*.3+.1,.25)*grow,.07*grow,Color("2e2620"),5)

## A crown of antler-like branches, glowing eyes and a hanging moss beard.
func _bear_head() -> void:
    var t=on("Head")
    for side in [-1.0,1.0]:
        var root_point: Vector3=p(side*.2,1.52,-1.42)
        var mid: Vector3=root_point+Vector3(side*.28,.42,.12)*grow
        var top: Vector3=mid+Vector3(side*.12,.4,.22)*grow
        t.rod(root_point,mid,.05*grow,BARK,6,.04*grow)
        t.rod(mid,top,.04*grow,BARK,6,.015*grow)
        t.rod(mid,mid+Vector3(side*.32,.18,-.12)*grow,.03*grow,BARK,5,.01*grow)
        t.rod(root_point.lerp(mid,.5),root_point.lerp(mid,.5)+Vector3(side*.1,.28,-.2)*grow,.025*grow,BARK,5,.01*grow)
        for leaf in [top,mid+Vector3(side*.32,.18,-.12)*grow]:
            t.sphere(leaf,.09*grow,MOSS,Vector3(1.3,.7,1.0))
        # Eyes: amber, glowing, deep in the brow.
        t.sphere(p(side*.17,1.36,-1.83),.07*grow,AMBER,Vector3.ONE,1.6)
        t.sphere(p(side*.17,1.37,-1.87),.03*grow,Color("2a1405"))
        t.box_at(p(side*.17,1.45,-1.8),Vector3(.16,.04,.1)*grow,Vector3(0,0,side*.35),Color("2e2620"))
        # Old scars across the muzzle.
        t.box_at(p(side*.08,1.28,-1.98),Vector3(.02,.18,.02)*grow,Vector3(.3,0,side*.6),Color("c9a58a"))
    var jaw=on("Jaw")
    for k in 7:
        var x: float=(k-3)*.07
        var root_point: Vector3=p(x,1.0,-1.72+absf(x)*.4)
        cone(jaw,root_point,root_point+Vector3(x*.3,-.4-_rng.randf_range(0,.18),.05)*grow,.05*grow,LICHEN if k%2==0 else MOSS_DARK,5)
    for side in [-1.0,1.0]:
        cone(jaw,p(side*.1,1.06,-1.95),p(side*.11,.88,-1.97),.025*grow,BONE,5)

## Huge pale claws on every paw.
func _bear_paws() -> void:
    for paw in ["FrontToe.L","FrontToe.R","RearToe.L","RearToe.R"]:
        var t=on(paw)
        var index: int=skeleton.find_bone(paw)
        if index<0: continue
        var x: float=.43*(1.0 if paw.ends_with("L") else -1.0)
        var z: float=-1.29 if paw.begins_with("Front") else .67
        for k in 4:
            var base: Vector3=p(x+(k-1.5)*.07,.1,z-.04)
            claw(t,base,Vector3(0,-.15,-1),Vector3(0,-1,0),.26*grow,.03*grow,BONE)

# --- The Albino Saltwater Crocodile ---------------------------------------------------

func _crocodile() -> void:
    # Osteoderm spikes in two rows down the back and one along the tail.
    var rows: Array=[["Body",-.35,.1,.46],["Body",-.1,.15,.5],["Body",.15,.2,.5],["Tail1",.4,.2,.44],["Tail2",.7,.15,.38],["Tail2",.95,.14,.32],["Tail3",1.2,.1,.26],["Tail3",1.45,.08,.2]]
    for spot in rows:
        var t=on(spot[0])
        var z: float=float(spot[1]);var spread: float=float(spot[2]);var y: float=float(spot[3])
        var sides: Array=[-1.0,1.0] if z<.6 else [0.0]
        for side in sides:
            var base:=p(side*spread*.5,y,z)
            cone(t,base,base+Vector3(side*.03,.13,.04)*grow,.045*grow,BONE.darkened(.05),4)
    # Barnacles and algae: it has been at sea.
    for b in [["Body",.14,.48,-.2],["Body",-.12,.47,.05],["Body",.05,.5,.3],["Tail1",-.1,.4,.6],["Head",.08,.36,-.7],["Head",-.06,.34,-.95]]:
        var t=on(b[0])
        var at:=p(float(b[1]),float(b[2]),float(b[3]))
        for k in 4:
            var offset:=Vector3(_rng.randf_range(-.04,.04),0,_rng.randf_range(-.04,.04))*grow
            t.cylinder(at+offset+Vector3.UP*.02*grow,.012*grow,.03*grow,.04*grow,BARNACLE,Vector3.ZERO,6)
    var tail=on("Tail3")
    for k in 5:
        var at:=p(_rng.randf_range(-.08,.08),.12,1.3+k*.08)
        tail.rod(at,at+Vector3(_rng.randf_range(-.05,.05),-.12,.1)*grow,.008*grow,ALGAE,4)
    # The old harpoon still in its back, rope trailing.
    var body=on("Body")
    var entry:=p(.08,.47,.0)
    var shaft_end:=entry+Vector3(.25,.75,.45).normalized()*.8*grow
    body.rod(entry,shaft_end,.022*grow,Color("7a5232"),6)
    body.rod(entry,entry-Vector3(.25,.75,.45).normalized()*.06*grow,.04*grow,RUST,6)
    for side in [-1.0,1.0]:
        body.rod(entry+Vector3(0,.04,0)*grow,entry+Vector3(side*.07,.09,-.03)*grow,.012*grow,RUST,4)
    var rope_points: Array[Vector3]=[shaft_end-Vector3(.25,.75,.45).normalized()*.15*grow]
    for k in 5: rope_points.append(rope_points[-1]+Vector3(_rng.randf_range(-.06,.06),-.1-k*.02,.22)*grow)
    for k in rope_points.size()-1: body.rod(rope_points[k],rope_points[k+1],.014*grow,ROPE,4)
    # Scars: thin raw-pink slashes.
    for s in [[-.18,.42,-.1,.7],[.2,.4,.25,-.6],[-.15,.38,.5,.4]]:
        body.box_at(p(float(s[0]),float(s[1]),float(s[2])),Vector3(.02,.012,.3)*grow,Vector3(0,float(s[3]),0),Color("c96a72"))
    # Ruby eyes on raised sockets, and a jaw full of crooked teeth.
    var head=on("Head")
    for side in [-1.0,1.0]:
        head.sphere(p(side*.11,.4,-.72),.05*grow,Color("e9d5cf"),Vector3(1,.8,1.2))
        head.sphere(p(side*.12,.43,-.75),.03*grow,RUBY,Vector3.ONE,1.8)
        for k in 7:
            var z: float=-1.0-k*.1
            var x: float=side*(.12-k*.008)
            cone(head,p(x,.2,z),p(x*1.05,.11 if k%2==0 else .29,z),.02*grow,BONE,4)
    var light:=OmniLight3D.new();light.light_color=Color("ff4a5e");light.light_energy=.9;light.omni_range=3.5
    light.position=p(0,.5,-.8);light.distance_fade_enabled=true;light.distance_fade_begin=40.0;add_child(light)
