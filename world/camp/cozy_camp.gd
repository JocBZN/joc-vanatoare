extends Node3D
## The camp is just a fireplace now: log seats with blankets, a kettle warming
## on a stone, a guitar, firewood, string lights, lantern posts, fireflies, a
## hammock and a dog asleep by the fire. The Wandering Oak parks beside it.
## Built in the same flat toon style as the truck; all animation is local.

const Toon:=preload("res://world/camp/toon_builder.gd")
const FIRE:=Vector3(0,0,-1.8)
const BARK:=Color("6b4a2e")
const BARK_DARK:=Color("543823")
const HEART:=Color("c9a36b")
const RING:=Color("8a6236")
const PLANK:=Color("9a6b40")
const PLANK_DARK:=Color("6f4a2b")
const IRON:=Color("3a3a3e")
const WARM:=Color("ffcf7a")
const LEAF:=Color("4f8a3a")
const MOSS:=Color("5f8f3a")
const PLAIDS:=[[Color("b8453a"),Color("e8d6b0")],[Color("3f6b8a"),Color("d9c79a")],[Color("4f7a3f"),Color("e3b23c")]]

var t: Object
var _fireflies: Array[MeshInstance3D]=[]
var _steam: Array[MeshInstance3D]=[]
var _dog: Node3D
var _tail: Node3D
var _dog_body: Node3D
var _clock: float=0.0
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
    _rng.seed=2611
    t=Toon.new()
    _seats()
    _kettle()
    _woodpile()
    _guitar()
    _lights()
    _hammock()
    _flora()
    t.commit(self,"Cozy")
    _build_dog()
    _build_fireflies()

func _seats() -> void:
    # Two fallen logs and three stumps close the circle the benches started.
    for seat in [[Vector3(-3.9,0,-5.0),.62],[Vector3(-5.3,0,-1.4),1.45]]:
        var at: Vector3=seat[0];var yaw: float=seat[1]
        var along:=Vector3(cos(yaw),0,-sin(yaw))
        t.cylinder(at+Vector3(0,.32,0),.32,.34,2.6,BARK,Vector3(0,yaw,PI*.5),10)
        for end in [-1.0,1.0]:
            t.cylinder(at+Vector3(0,.32,0)+along*end*1.31,.27,.27,.02,HEART,Vector3(0,yaw,PI*.5),10)
            t.cylinder(at+Vector3(0,.32,0)+along*end*1.32,.12,.12,.02,RING,Vector3(0,yaw,PI*.5),10)
        var plaid: Array=PLAIDS[int(absf(at.x))%PLAIDS.size()]
        t.box_at(at+Vector3(0,.66,0)+along*.3,Vector3(1.0,.05,.72),Vector3(0,yaw,0),plaid[0])
        for k in 3: t.box_at(at+Vector3(0,.69,0)+along*(-.1+k*.32),Vector3(.08,.02,.74),Vector3(0,yaw,0),plaid[1])
        t.sphere(at+Vector3(0,.72,0)-along*.75,.2,plaid[1],Vector3(1.3,.6,1.0))
    for stump in [Vector3(.6,0,-5.6),Vector3(-2.0,0,-6.1),Vector3(-4.3,0,2.7)]:
        t.cylinder(stump+Vector3(0,.25,0),.32,.38,.5,BARK,Vector3.ZERO,9)
        t.cylinder(stump+Vector3(0,.505,0),.29,.29,.01,HEART,Vector3.ZERO,9)
        t.cylinder(stump+Vector3(0,.51,0),.14,.14,.01,RING,Vector3.ZERO,9)
    # Mugs and a lantern on the south-west stump, a plaid rug before the fire.
    var table:=Vector3(-4.3,.51,2.7)
    for k in 3:
        var mug: Vector3=table+Vector3(cos(k*2.1)*.15,.07,sin(k*2.1)*.15)
        t.cylinder(mug,.06,.06,.14,[Color("e8d6b0"),Color("b8453a"),Color("3f6b8a")][k],Vector3.ZERO,8)
    t.box(table+Vector3(-.08,0,-.08),table+Vector3(.08,.26,.08),IRON)
    t.box(table+Vector3(-.06,.03,-.06),table+Vector3(.06,.23,.06),WARM,2.4)
    t.box(Vector3(-1.6,.012,2.2),Vector3(1.6,.02,3.6),Color("8f3b3b"))
    for k in 5: t.box(Vector3(-1.6+k*.8,.021,2.2),Vector3(-1.5+k*.8,.026,3.6),Color("e3b23c"))
    for k in 3: t.box(Vector3(-1.6,.022,2.45+k*.5),Vector3(1.6,.027,2.53+k*.5),Color("e8d6b0"))

func _kettle() -> void:
    var stone:=FIRE+Vector3(-2.75,0,1.4)
    t.sphere(stone+Vector3(0,.18,0),.42,Color("7a7873"),Vector3(1.2,.5,1.0))
    t.cylinder(stone+Vector3(0,.5,0),.24,.3,.32,Color("2b2b30"),Vector3.ZERO,10)
    t.cylinder(stone+Vector3(0,.68,0),.12,.2,.08,Color("2b2b30"),Vector3.ZERO,10)
    t.rod(stone+Vector3(.22,.55,0),stone+Vector3(.42,.72,0),.03,Color("2b2b30"),5)
    t.rod(stone+Vector3(-.18,.72,0),stone+Vector3(.18,.72,0),.02,IRON,4)
    for k in 4:
        var puff:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.1;sphere.height=.2;sphere.radial_segments=6;sphere.rings=4
        puff.mesh=sphere;puff.material_override=Toon.toon(Color("e9ebe8"));puff.set_meta("styled",true)
        puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;puff.set_meta("phase",k*.25);puff.set_meta("origin",stone+Vector3(.44,.76,0))
        add_child(puff);_steam.append(puff)

func _woodpile() -> void:
    var pile:=Vector3(-7.6,0,-4.2)
    for row in 3:
        for k in 5-row:
            t.cylinder(pile+Vector3(0,.13+row*.24,-.5+k*.25+row*.12),.12,.12,1.2,BARK if (k+row)%2==0 else BARK_DARK,Vector3(0,0,PI*.5),7)
            t.cylinder(pile+Vector3(.605,.13+row*.24,-.5+k*.25+row*.12),.1,.1,.01,HEART,Vector3(0,0,PI*.5),7)
    for z in [-.75,.75]: t.box(pile+Vector3(-.05,0,z-.05),pile+Vector3(.05,1.0,z+.05),PLANK_DARK)
    var block:=pile+Vector3(1.6,0,.5)
    t.cylinder(block+Vector3(0,.3,0),.35,.4,.6,BARK,Vector3.ZERO,9)
    t.cylinder(block+Vector3(0,.605,0),.32,.32,.01,HEART,Vector3.ZERO,9)
    t.rod(block+Vector3(0,.62,0),block+Vector3(.35,1.15,.2),.03,PLANK)
    t.box_at(block+Vector3(.02,.66,-.01),Vector3(.05,.14,.24),Vector3(0,.5,-.4),Color("9aa1a6"))

func _guitar() -> void:
    var foot:=Vector3(-5.0,0,-2.4)
    var lean:=Vector3(0,.2,0)
    t.sphere(foot+Vector3(0,.32,0),.3,Color("c9853f"),Vector3(1,1,.35))
    t.sphere(foot+Vector3(0,.68,0)+lean*.3,.22,Color("c9853f"),Vector3(1,1,.35))
    t.cylinder(foot+Vector3(0,.5,.11),.08,.08,.02,Color("2b2117"),Vector3(PI*.5,0,0),10)
    t.rod(foot+Vector3(0,.85,0)+lean*.4,foot+Vector3(0,1.55,0)+lean,.035,Color("5a3a20"),5)
    t.box_at(foot+Vector3(0,1.62,0)+lean*1.05,Vector3(.1,.18,.05),Vector3(.0,0,0),Color("5a3a20"))

func _lights() -> void:
    # Poles in a ring away from the truck, strung with warm bulbs.
    var poles: Array=[]
    for angle_deg in [110,150,190,230,270,310]:
        var angle: float=deg_to_rad(angle_deg)
        poles.append(FIRE+Vector3(cos(angle)*10.5,0,-sin(angle)*10.5))
    for pole in poles:
        t.cylinder(pole+Vector3(0,1.6,0),.06,.08,3.2,PLANK_DARK,Vector3.ZERO,6)
        t.box(pole+Vector3(-.11,3.0,-.11),pole+Vector3(.11,3.25,.11),IRON)
    var colors: Array=[Color("ffcf6b"),Color("ff9a6b"),Color("ffe39a"),Color("ffb86b")]
    for i in poles.size()-1:
        var a: Vector3=poles[i]+Vector3(0,3.1,0);var b: Vector3=poles[i+1]+Vector3(0,3.1,0)
        for k in 9:
            var f: float=(k+.5)/9.0
            t.sphere(a.lerp(b,f)+Vector3(0,-.75*sin(PI*f),0),.07,colors[(i+k)%4],Vector3.ONE,2.6,5)
    for post in [Vector3(-6.4,0,4.6),Vector3(-6.0,0,-7.6),Vector3(3.6,0,7.4)]:
        t.cylinder(post+Vector3(0,.95,0),.07,.09,1.9,PLANK_DARK,Vector3.ZERO,6)
        t.rod(post+Vector3(0,1.85,0),post+Vector3(.35,1.85,0),.03,IRON,4)
        t.box(post+Vector3(.25,1.45,-.11),post+Vector3(.47,1.75,.11),IRON)
        t.box(post+Vector3(.28,1.48,-.08),post+Vector3(.44,1.72,.08),WARM,2.6)
        var lamp:=OmniLight3D.new();lamp.position=post+Vector3(.36,1.6,0);lamp.light_color=Color("ffc978")
        lamp.light_energy=1.1;lamp.omni_range=7.0;add_child(lamp)

func _hammock() -> void:
    var a:=Vector3(-12.2,0,3.6);var b:=Vector3(-12.2,0,7.6)
    for post in [a,b]: t.cylinder(post+Vector3(0,1.1,0),.09,.11,2.2,BARK,Vector3.ZERO,7)
    var cloth: Array=[Color("e3b23c"),Color("b8453a")]
    for k in 10:
        var f0: float=float(k)/10.0;var f1: float=float(k+1)/10.0
        var p0: Vector3=a.lerp(b,f0)+Vector3(0,1.75-.75*sin(PI*f0),0)
        var p1: Vector3=a.lerp(b,f1)+Vector3(0,1.75-.75*sin(PI*f1),0)
        t.rod(p0,p1,.32 if k>0 and k<9 else .1,cloth[k%2],8)
    t.sphere(a.lerp(b,.22)+Vector3(0,1.32,0),.2,Color("e8d6b0"),Vector3(1.4,.5,1.0))

func _flora() -> void:
    for k in 26:
        var angle: float=_rng.randf()*TAU
        var radius: float=_rng.randf_range(12.0,19.5)
        var at:=FIRE+Vector3(cos(angle)*radius,0,sin(angle)*radius)
        if at.x>5.0 and at.z<6.0: continue # keep the truck's parking spot clear
        if _rng.randf()<.5:
            t.cylinder(at+Vector3(0,.08,0),.03,.04,.16,Color("efe3c4"),Vector3.ZERO,5)
            t.sphere(at+Vector3(0,.18,0),.1,[Color("d23c3c"),Color("c9853f")][k%2],Vector3(1,.55,1))
        else:
            t.rod(at,at+Vector3(0,.3,0),.012,LEAF,4)
            t.sphere(at+Vector3(0,.32,0),.06,[Color("f2c94c"),Color("e07ab0"),Color("f2f0e6"),Color("5b8fd9")][k%4])

func _build_dog() -> void:
    # A sleepy camp dog curled on a blanket beside the fire.
    _dog=Node3D.new();_dog.name="CampDog";_dog.position=FIRE+Vector3(2.9,0,2.9);_dog.rotation.y=-.6;add_child(_dog)
    var blanket=Toon.new()
    blanket.box(Vector3(-.65,.01,-.5),Vector3(.65,.04,.5),Color("3f6b8a"))
    for k in 3: blanket.box(Vector3(-.65,.041,-.38+k*.36),Vector3(.65,.05,-.32+k*.36),Color("d9c79a"))
    blanket.commit(_dog,"Blanket")
    _dog_body=Node3D.new();_dog_body.name="Body";_dog.add_child(_dog_body)
    var fur:=Color("b07a45");var light:=Color("e8d2a8")
    var dog=Toon.new()
    dog.sphere(Vector3(0,.22,0),.3,fur,Vector3(1.5,.75,1.0))
    dog.sphere(Vector3(.05,.18,.1),.22,light,Vector3(1.3,.6,.8))
    dog.sphere(Vector3(.42,.17,.2),.17,fur,Vector3(1.15,.85,1.0))
    dog.sphere(Vector3(.56,.13,.24),.08,light,Vector3(1.3,.8,.9))
    dog.sphere(Vector3(.63,.15,.25),.03,Color("1d1a17"))
    for z in [.1,.31]: dog.box_at(Vector3(.4,.27,z),Vector3(.12,.04,.08),Vector3(0,0,-.3),Color("7a5230"))
    for x in [.25,-.25]: dog.sphere(Vector3(x,.07,.28),.07,light,Vector3(1.6,.6,.8))
    dog.commit(_dog_body,"Dog")
    _tail=Node3D.new();_tail.name="Tail";_tail.position=Vector3(-.42,.2,-.08);_dog.add_child(_tail)
    var tail=Toon.new()
    tail.sphere(Vector3(-.12,0,.08),.07,fur,Vector3(2.0,.8,.8))
    tail.commit(_tail,"Tail")

func _build_fireflies() -> void:
    for k in 26:
        var fly:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.045;sphere.height=.09;sphere.radial_segments=5;sphere.rings=3
        fly.mesh=sphere;fly.material_override=Toon.toon(Color("e6ff8a"),3.0);fly.set_meta("styled",true)
        fly.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var angle: float=_rng.randf()*TAU;var radius: float=_rng.randf_range(5.0,17.0)
        fly.set_meta("home",FIRE+Vector3(cos(angle)*radius,_rng.randf_range(.6,2.6),sin(angle)*radius))
        fly.set_meta("seed",_rng.randf()*100.0)
        add_child(fly);_fireflies.append(fly)

func _process(delta: float) -> void:
    _clock+=delta
    for fly in _fireflies:
        var s: float=float(fly.get_meta("seed"))
        fly.position=fly.get_meta("home")+Vector3(sin(_clock*.4+s)*1.2,sin(_clock*.9+s*1.7)*.35,cos(_clock*.33+s*.6)*1.2)
        fly.visible=sin(_clock*1.7+s*3.0)>-.35
    for puff in _steam:
        var phase: float=fmod(_clock*.45+float(puff.get_meta("phase")),1.0)
        puff.position=puff.get_meta("origin")+Vector3(phase*.15,phase*.9,sin(phase*6.0)*.05)
        puff.scale=Vector3.ONE*(.6+phase*1.6);puff.visible=phase<.88
    if is_instance_valid(_tail): _tail.rotation.y=sin(_clock*2.4)*.35
    if is_instance_valid(_dog_body): _dog_body.scale=Vector3(1,1.0+sin(_clock*1.6)*.035,1)
