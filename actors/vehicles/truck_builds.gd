extends RefCounted
## The four optional builds of the Wandering Oak (see TruckUpgrades): bull bar,
## watchtower, nitro boosters and the boat kit. Each is a hidden Node3D under the
## truck body, drawn as merged toon primitives like the rest of the truck, and
## switched on by HuntingJeep.set_upgrades. Truck-local frame: forward is -Z.
const Toon:=preload("res://world/camp/toon_builder.gd")

const IRON:=Color("3a3a3e")
const STEEL:=Color("8d9399")
const CHROME:=Color("c9cdd0")
const WARM:=Color("ffcf7a")
const HAZARD:=Color("f2c94c")
const BARK:=Color("6b4a2e")
const BARK_LIGHT:=Color("7d5836")
const PLANK:=Color("9a6b40")
const PLANK_LIGHT:=Color("c08a52")
const CREAM:=Color("efe3c4")
const RED:=Color("c9463a")
const ORANGE:=Color("e0662f")
const NAVY:=Color("2b4a6b")
const TEAL:=Color("2f8a92")
const BRASS:=Color("d9b24a")
const BRASS_DARK:=Color("a9822c")
const WOOD:=Color("9a6b40")
const WOOD_DARK:=Color("6f4a2b")
const TYRE_DARK:=Color("1d1d21")

## Terrace deck height (kept in step with oak_truck_model.gd).
const DECK_Y: float=7.8
## The watchtower stands at the front of the terrace and tops out here.
const TOWER_X0: float=-1.1
const TOWER_X1: float=1.1
const TOWER_Z0: float=-1.0
const TOWER_Z1: float=.9
const TOWER_TOP: float=12.4
const TOWER_RAIL: float=2.3
## Where the tower ladder puts a hunter: on the platform and back on the terrace.
const TOWER_LANDING:=Vector3(0,12.45,-.1)
const TOWER_DECK_LANDING:=Vector3(0,7.85,1.7)
const NITRO_PODS: Array[Vector3]=[Vector3(-1.15,1.0,6.2),Vector3(1.15,1.0,6.2)]

var body: RigidBody3D
var shapes: Dictionary={}
var parts: Dictionary={}

## Builds every kit; returns {id: Node3D root}. `shapes[id]` lists the collision
## shapes that belong to a build, so the truck only collides with what is fitted.
func build_all(target: RigidBody3D) -> Dictionary:
    body=target
    var roots: Dictionary={}
    roots[&"bar"]=_bar()
    roots[&"tower"]=_tower()
    roots[&"nitro"]=_nitro()
    roots[&"boat"]=_boat()
    for id in roots:
        roots[id].visible=false
        shapes.get(id,[]).map(func(shape: CollisionShape3D) -> void: shape.disabled=true)
    # The aft deck and stairs only collide once the boat is unfolded.
    for shape in shapes.get(&"boat_deck",[]): shape.disabled=true
    return roots

func _root(id: String) -> Node3D:
    var root:=Node3D.new();root.name=id.capitalize()+"Kit";body.add_child(root)
    shapes[StringName(id)]=[]
    return root

func _shape(id: StringName,a: Vector3,b: Vector3) -> void:
    var low:=Vector3(minf(a.x,b.x),minf(a.y,b.y),minf(a.z,b.z));var high:=Vector3(maxf(a.x,b.x),maxf(a.y,b.y),maxf(a.z,b.z))
    var box:=BoxShape3D.new();box.size=high-low
    var collision:=CollisionShape3D.new();collision.shape=box;collision.position=(low+high)*.5
    body.add_child(collision);shapes[id].append(collision)

# --- Bull bar ------------------------------------------------------------------------

## The Bull Head: an iron bull the size of a small car bolted to the front, with horns that
## sweep out and up, glowing red eyes, a brass nose ring, ears, a tuft, a white blaze and
## nostrils that snort steam when the truck gets up speed.
func _bar() -> Node3D:
    var root:=_root("bar");var t:=Toon.new()
    var IRON_BULL:=Color("4c4a52");var IRON_LIGHT:=Color("6c6a74");var BONE:=Color("efe6cc")
    var c:=Vector3(0,1.9,-8.35)
    # Skull, cheeks, brow ridge and a broad muzzle with a pinker, softer snout.
    t.sphere(c,1.0,IRON_BULL,Vector3(1.0,.92,1.15),0.0,14)
    for side in [-1.0,1.0]:
        t.sphere(c+Vector3(side*.62,-.5,-.45),.52,IRON_BULL,Vector3(.9,.9,1.2),0.0,10)
        t.box_at(c+Vector3(side*.45,.42,-.8),Vector3(.8,.18,.35),Vector3(0,0,side*-.28),IRON_LIGHT)
    t.box(Vector3(-.62,.95,-9.75),Vector3(.62,1.85,-8.75),Color("8d7f86"))
    t.sphere(Vector3(0,1.4,-9.75),.62,Color("8d7f86"),Vector3(1.0,.72,.6),0.0,10)
    for side in [-1.0,1.0]:
        t.cylinder(Vector3(side*.26,1.35,-10.05),.1,.1,.12,Color("1a1418"),Vector3(PI*.5,0,0),8)
    # The nose ring.
    _ring(t,Vector3(0,.98,-10.0),Basis.IDENTITY,.3,.045,BRASS)
    # A white blaze down the face and a tuft of hair between the horns.
    t.box(Vector3(-.11,1.95,-9.7),Vector3(.11,2.78,-8.35),CREAM)
    for k in 5: t.sphere(c+Vector3(-.4+k*.2,1.0,.1),.2,Color("5a3a22"),Vector3(1,1.2,1),0.0,6)
    # Ears.
    for side in [-1.0,1.0]:
        t.prism(c+Vector3(side*1.1,.45,.45),Vector3(.55,.9,.1),Vector3(0,0,side*-1.1),IRON_LIGHT)
    # Horns: thick brass collars, then curving bone sweeping out, up and forward.
    for side in [-1.0,1.0]:
        var pts: Array[Vector3]=[c+Vector3(side*.85,.3,.25),c+Vector3(side*1.65,.55,.1),c+Vector3(side*2.4,1.2,-.1),c+Vector3(side*2.75,2.1,-.45),c+Vector3(side*2.7,2.95,-.9)]
        var radii: Array[float]=[.26,.22,.17,.11,.05]
        t.cylinder(pts[0]+Vector3(side*.12,0,0),.3,.3,.18,BRASS,Vector3(0,0,PI*.5),12)
        for i in 4:
            t.rod(pts[i],pts[i+1],radii[i],BONE if i<3 else Color("d9cfae"),9,radii[i+1])
        t.sphere(pts[4]+Vector3(0,.05,-.03),.075,BRASS,Vector3.ONE,0.0,8)
    # Neck and mounting: stout bars back to the frame rails and a skid plate underneath.
    t.box(Vector3(-.85,.55,-8.0),Vector3(.85,1.35,-6.9),IRON_BULL)
    for side in [-1.0,1.0]:
        t.rod(Vector3(side*.8,.95,-8.1),Vector3(side*1.0,.85,-5.2),.12,IRON,7)
        t.rod(Vector3(side*.55,1.7,-7.6),Vector3(side*1.15,1.5,-6.5),.09,IRON,6)
    t.box(Vector3(-1.1,.35,-8.5),Vector3(1.1,.6,-6.9),IRON)
    t.commit(root,"Bar")
    # The eyes: glowing red, with their own material so they can burn brighter at speed.
    var eye_mat:=StandardMaterial3D.new();eye_mat.albedo_color=Color("ff2a1c");eye_mat.emission_enabled=true;eye_mat.emission=Color("ff1c10");eye_mat.emission_energy_multiplier=2.0
    for side in [-1.0,1.0]:
        var eye:=MeshInstance3D.new();var sm:=SphereMesh.new();sm.radius=.2;sm.height=.4;sm.radial_segments=10;sm.rings=6;sm.material=eye_mat;eye.mesh=sm
        eye.position=c+Vector3(side*.52,.3,-1.0);root.add_child(eye)
    var holder:=Node3D.new();holder.name="Snort";holder.position=Vector3(0,1.4,-10.35);root.add_child(holder)
    for side in [-1.0,1.0]:
        var puff:=_puff();puff.position=Vector3(side*.26,0,0);holder.add_child(puff);bull_steam.append(puff)
    parts[&"bull_eye"]=eye_mat
    return root

var bull_steam: Array[CPUParticles3D]=[]


func _puff() -> CPUParticles3D:
    var p:=CPUParticles3D.new();p.emitting=false;p.amount=14;p.lifetime=.9;p.direction=Vector3(0,.2,-1);p.spread=18.0
    p.initial_velocity_min=2.0;p.initial_velocity_max=4.0;p.gravity=Vector3(0,.8,0);p.local_coords=false
    var mesh:=SphereMesh.new();mesh.radius=.12;mesh.height=.24;mesh.radial_segments=6;mesh.rings=3
    var m:=StandardMaterial3D.new();m.albedo_color=Color(1,1,1,.55);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material=m;p.mesh=mesh
    var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,.8));ramp.set_color(1,Color(1,1,1,0.0));p.color_ramp=ramp
    return p

## Eyes burn hotter and the nostrils snort steam as the truck picks up speed.
func animate_bar(speed: float,t: float) -> void:
    if not parts.has(&"bull_eye"): return
    var heat: float=clampf(absf(speed)/12.0,0.0,1.0)
    var m: StandardMaterial3D=parts[&"bull_eye"]
    m.emission_energy_multiplier=1.6+heat*4.0+sin(t*9.0)*.3*heat
    for puff in bull_steam: puff.emitting=absf(speed)>3.0

# --- Watchtower ----------------------------------------------------------------------


func _tower() -> Node3D:
    var root:=_root("tower");var t:=Toon.new()
    var legs: Array[Vector3]=[Vector3(TOWER_X0+.1,0,TOWER_Z0+.1),Vector3(TOWER_X1-.1,0,TOWER_Z0+.1),Vector3(TOWER_X1-.1,0,TOWER_Z1-.1),Vector3(TOWER_X0+.1,0,TOWER_Z1-.1)]
    for leg in legs:
        t.rod(leg+Vector3(0,DECK_Y,0),leg+Vector3(0,TOWER_TOP,0),.11,BARK)
    # X-braces on the four faces, and a ring of cross-beams at each landing.
    for i in 4:
        var a: Vector3=legs[i];var b: Vector3=legs[(i+1)%4]
        for level in 2:
            var y0: float=DECK_Y+.4+level*2.2;var y1: float=y0+2.2
            t.rod(a+Vector3(0,y0,0),b+Vector3(0,y1,0),.045,BARK_LIGHT,5)
            t.rod(b+Vector3(0,y0,0),a+Vector3(0,y1,0),.045,BARK_LIGHT,5)
        for y in [DECK_Y+2.4,DECK_Y+4.4]:
            t.rod(a+Vector3(0,y,0),b+Vector3(0,y,0),.06,BARK)
    # Platform planks, with rope-wrapped rails all round.
    var depth: float=TOWER_Z1-TOWER_Z0
    for k in 8:
        var z0: float=TOWER_Z0+k*depth/8.0
        t.box(Vector3(TOWER_X0-.1,TOWER_TOP-.12,z0+.02),Vector3(TOWER_X1+.1,TOWER_TOP,z0+depth/8.0-.02),PLANK if k%2==0 else PLANK_LIGHT)
    var rail: float=TOWER_TOP+1.0
    var ring: Array[Vector3]=[Vector3(TOWER_X0-.1,0,TOWER_Z0-.05),Vector3(TOWER_X1+.1,0,TOWER_Z0-.05),Vector3(TOWER_X1+.1,0,TOWER_Z1+.05),Vector3(TOWER_X0-.1,0,TOWER_Z1+.05)]
    for i in 4:
        var a: Vector3=ring[i];var b: Vector3=ring[(i+1)%4]
        t.rod(a+Vector3(0,rail,0),b+Vector3(0,rail,0),.045,BARK_LIGHT)
        t.rod(a+Vector3(0,TOWER_TOP+.5,0),b+Vector3(0,TOWER_TOP+.5,0),.03,BARK_LIGHT)
        for k in 4:
            var at: Vector3=a.lerp(b,k/3.0)
            t.rod(at+Vector3(0,TOWER_TOP,0),at+Vector3(0,rail+.05,0),.035,BARK)
    # Ladder on the rear face, from the terrace up to the hatch.
    for x in [-.3,.3]: t.rod(Vector3(x,DECK_Y,TOWER_Z1+.08),Vector3(x,TOWER_TOP+1.1,TOWER_Z1+.08),.04,BARK)
    var rung: float=DECK_Y+.3
    while rung<TOWER_TOP:
        t.rod(Vector3(-.3,rung,TOWER_Z1+.08),Vector3(.3,rung,TOWER_Z1+.08),.028,BARK_LIGHT)
        rung+=.32
    # The big searchlight on a swivel post at the front rail, with a lens that glows.
    t.rod(Vector3(0,TOWER_TOP,TOWER_Z0+.25),Vector3(0,TOWER_TOP+1.25,TOWER_Z0+.25),.07,IRON)
    t.cylinder(Vector3(0,TOWER_TOP+1.5,TOWER_Z0-.1),.42,.3,.8,IRON,Vector3(PI*.5,0,0),12)
    t.cylinder(Vector3(0,TOWER_TOP+1.5,TOWER_Z0-.52),.38,.38,.05,WARM,Vector3(PI*.5,0,0),12,3.0)
    t.box(Vector3(-.12,TOWER_TOP+1.2,TOWER_Z0-.1),Vector3(.12,TOWER_TOP+1.3,TOWER_Z0+.3),IRON)
    # A pennant on a pole and a small dish: this is the crew's crow's nest.
    t.rod(Vector3(TOWER_X1-.1,TOWER_TOP,TOWER_Z1-.1),Vector3(TOWER_X1-.1,TOWER_TOP+2.7,TOWER_Z1-.1),.035,BARK_LIGHT)
    t.prism(Vector3(TOWER_X1-.1,TOWER_TOP+2.35,TOWER_Z1-.55),Vector3(.55,.8,.03),Vector3(PI*.5,0,PI*.5),RED)
    t.rod(Vector3(TOWER_X0+.1,TOWER_TOP,TOWER_Z1-.1),Vector3(TOWER_X0+.1,TOWER_TOP+1.8,TOWER_Z1-.1),.03,IRON)
    t.sphere(Vector3(TOWER_X0+.1,TOWER_TOP+1.85,TOWER_Z1-.1),.28,CHROME,Vector3(1,.35,1),0.0,8)
    # Bolted down: a base plate on the deck, and guy cables to the terrace rail.
    t.box(Vector3(TOWER_X0-.2,DECK_Y,TOWER_Z0-.15),Vector3(TOWER_X1+.2,DECK_Y+.12,TOWER_Z1+.15),IRON)
    for corner in legs:
        var anchor:=Vector3(signf(corner.x)*1.55,DECK_Y+.95,-1.0 if corner.z<0.0 else 3.55)
        t.rod(corner+Vector3(0,TOWER_TOP-2.0,0),anchor,.018,IRON,4)
    # Fixtures that make it the crew's crow's nest: a brass telescope on a tripod, a ship's
    # bell, a parrot on a perch, and a fish-shaped weather vane (the radar dish is added below).
    var base:=Vector3(TOWER_X1-.2,TOWER_TOP,TOWER_Z0+.5)
    for k in 3:
        var a: float=TAU*k/3.0+.4
        t.rod(base+Vector3(0,1.0,0),base+Vector3(cos(a)*.45,0,sin(a)*.45),.04,BARK,5)
    t.rod(base+Vector3(0,1.0,0),base+Vector3(-.15,1.35,-.15),.06,IRON,6)
    t.rod(base+Vector3(-.15,1.35,-.15),base+Vector3(-.5,2.2,-1.1),.13,BRASS,10,.1)
    t.rod(base+Vector3(-.5,2.2,-1.1),base+Vector3(-.75,2.7,-1.55),.1,BRASS_DARK,10,.12)
    t.cylinder(base+Vector3(-.78,2.75,-1.6),.15,.15,.08,CREAM,Vector3(-.6,0,0),12)
    t.rod(base+Vector3(-.15,1.35,-.15),base+Vector3(.12,1.15,.25),.05,BRASS,6)
    var bell:=Vector3(0,TOWER_TOP+1.75,TOWER_Z1-.15)
    t.rod(bell+Vector3(-.4,.35,0),bell+Vector3(.4,.35,0),.05,BARK,6)
    t.cylinder(bell+Vector3(0,.0,0),.12,.3,.38,BRASS,Vector3.ZERO,12)
    t.sphere(bell+Vector3(0,-.22,0),.07,IRON,Vector3.ONE,0.0,6)
    var perch:=Vector3(TOWER_X0+.35,TOWER_TOP+1.2,TOWER_Z0+.35)
    t.rod(perch+Vector3(0,-1.2,0),perch,.03,BARK,5)
    t.rod(perch+Vector3(-.2,0,0),perch+Vector3(.2,0,0),.03,BARK,5)
    t.sphere(perch+Vector3(0,.2,0),.14,RED,Vector3(1,1.1,1),0.0,8)
    t.sphere(perch+Vector3(0,.42,-.04),.09,RED,Vector3.ONE,0.0,8)
    t.prism(perch+Vector3(0,.4,-.16),Vector3(.06,.08,.06),Vector3(PI*.5,0,0),WARM)
    t.box(perch+Vector3(-.03,-.05,.1),perch+Vector3(.03,.1,.45),Color("2f8ad0"))
    for side in [-1.0,1.0]: t.box(perch+Vector3(side*.13,.05,-.05),perch+Vector3(side*.17,.3,.18),Color("ffd83a"))
    t.commit(root,"Tower")
    # The radar dish on its own mast, turning slowly, and a weather vane.
    var radar:=Node3D.new();radar.name="Radar";radar.position=Vector3(TOWER_X0+.2,TOWER_TOP+2.4,TOWER_Z1-.2);root.add_child(radar)
    var rt:=Toon.new()
    rt.rod(Vector3(-.8,0,0),Vector3(.8,0,0),.04,STEEL,5)
    rt.box(Vector3(-.85,-.05,-.3),Vector3(.85,.14,.3),CHROME)
    rt.box(Vector3(-.85,.14,-.3),Vector3(.85,.2,-.26),RED)
    rt.cylinder(Vector3(0,-.15,0),.1,.1,.3,IRON,Vector3.ZERO,8)
    rt.commit(radar,"Dish")
    var mast_rod:=Toon.new();mast_rod.rod(Vector3(TOWER_X0+.2,TOWER_TOP,TOWER_Z1-.2),Vector3(TOWER_X0+.2,TOWER_TOP+2.25,TOWER_Z1-.2),.04,IRON,6);mast_rod.commit(root,"RadarMast")
    var vane:=Node3D.new();vane.name="Vane";vane.position=Vector3(TOWER_X1-.1,TOWER_TOP+2.85,TOWER_Z1-.1);root.add_child(vane)
    var vt:=Toon.new()
    vt.rod(Vector3(0,-.45,0),Vector3(0,.0,0),.025,IRON,5)
    vt.sphere(Vector3(0,0,-.3),.12,Color("2f8ad0"),Vector3(.5,1,1.6),0.0,6)
    vt.prism(Vector3(0,0,.35),Vector3(.04,.32,.3),Vector3(PI*.5,0,0),Color("2f8ad0"))
    vt.rod(Vector3(0,0,-.5),Vector3(0,0,.5),.015,IRON,4)
    vt.commit(vane,"Fish")
    parts[&"radar"]=radar;parts[&"vane"]=vane
    var light:=SpotLight3D.new();light.name="Searchlight";light.position=Vector3(0,TOWER_TOP+1.5,TOWER_Z0-.55)
    light.rotation_degrees=Vector3(-5,0,0);light.light_color=Color("fff0cf");light.light_energy=5.0
    light.spot_range=150;light.spot_angle=22;light.spot_attenuation=.6;light.shadow_enabled=false
    root.add_child(light)
    var lamp:=OmniLight3D.new();lamp.position=Vector3(0,TOWER_TOP+1.0,.2);lamp.light_color=Color("ffcf8a");lamp.light_energy=1.0;lamp.omni_range=5
    root.add_child(lamp)
    # Collision: platform, a closed ring of walls taller than a jump, and four legs.
    _shape(&"tower",Vector3(TOWER_X0-.1,TOWER_TOP-.15,TOWER_Z0-.05),Vector3(TOWER_X1+.1,TOWER_TOP,TOWER_Z1+.05))
    _shape(&"tower",Vector3(TOWER_X0-.14,TOWER_TOP,TOWER_Z0-.1),Vector3(TOWER_X0-.06,TOWER_TOP+TOWER_RAIL,TOWER_Z1+.1))
    _shape(&"tower",Vector3(TOWER_X1+.06,TOWER_TOP,TOWER_Z0-.1),Vector3(TOWER_X1+.14,TOWER_TOP+TOWER_RAIL,TOWER_Z1+.1))
    _shape(&"tower",Vector3(TOWER_X0-.1,TOWER_TOP,TOWER_Z0-.1),Vector3(TOWER_X1+.1,TOWER_TOP+TOWER_RAIL,TOWER_Z0-.02))
    _shape(&"tower",Vector3(TOWER_X0-.1,TOWER_TOP,TOWER_Z1+.02),Vector3(TOWER_X1+.1,TOWER_TOP+TOWER_RAIL,TOWER_Z1+.1))
    for leg in legs: _shape(&"tower",leg+Vector3(-.12,DECK_Y,-.12),leg+Vector3(.12,TOWER_TOP,.12))
    # Ladder prompts, created with the build and only reachable while it is fitted.
    var up:=LobbyInteractable.new();up.interaction_kind="tower_up";up.interaction_range=1.2;up.position=Vector3(0,DECK_Y,TOWER_Z1+.8);up.name="TowerUp"
    var down:=LobbyInteractable.new();down.interaction_kind="tower_down";down.interaction_range=1.1;down.position=Vector3(0,TOWER_TOP,TOWER_Z1-.4);down.name="TowerDown"
    root.add_child(up);root.add_child(down)
    parts[&"tower_prompts"]=[up,down]
    return root

func animate_tower(t: float,delta: float) -> void:
    if not parts.has(&"radar"): return
    parts[&"radar"].rotation.y+=delta*1.6
    parts[&"vane"].rotation.y=sin(t*.5)*.9

# --- Nitro boosters: the Carrot Rockets --------------------------------------------------------
##
## Two enormous carrots strapped under the rear frame, nose forward and leafy end aft,
## ringed like real carrots and wearing googly eyes. The flames come out of the leaves.

func _nitro() -> Node3D:
    var root:=_root("nitro");var t:=Toon.new()
    var BLUE:=Color("3f7fd0");var CARROT:=Color("ff8a1c");var CARROT_DARK:=Color("d96a0c");var LEAF:=Color("3fa83a");var LEAF_DARK:=Color("2a7a2a")
    # Rocket bar: a stout cross-member bolted to the frame rails, with a tow eye.
    t.box(Vector3(-1.5,.85,6.05),Vector3(1.5,1.12,6.3),IRON)
    for side in [-1.0,1.0]:
        t.rod(Vector3(side*1.15,1.0,6.15),Vector3(side*1.0,1.2,4.9),.09,IRON,6)
        t.rod(Vector3(side*1.5,.98,6.15),Vector3(side*1.62,1.1,5.0),.08,IRON,6)
    t.cylinder(Vector3(0,.98,6.4),.14,.14,.12,STEEL,Vector3(PI*.5,0,0),10)
    for pod in NITRO_PODS:
        var side: float=signf(pod.x)
        # Carrot body: thick at the back, tapering to a blunt nose, with darker growth rings.
        t.cylinder(pod+Vector3(0,0,.05),.4,.06,2.2,CARROT,Vector3(PI*.5,0,0),14)
        for k in 7:
            var z: float=pod.z-.95+k*.3
            var f: float=float(k)/6.0
            var radius: float=lerpf(.07,.4,pow(f,.9))+.015
            t.cylinder(Vector3(pod.x,pod.y,z+.05),radius,radius,.05,CARROT_DARK,Vector3(PI*.5,0,0),14)
        t.sphere(pod+Vector3(0,0,-1.08),.07,CARROT_DARK,Vector3.ONE,0.0,8)
        # A steel nozzle collar at the back and the green leaves fanned round it.
        t.cylinder(pod+Vector3(0,0,1.18),.34,.28,.2,STEEL,Vector3(PI*.5,0,0),14)
        for leaf in 9:
            var a: float=TAU*leaf/9.0
            var out:=Vector3(cos(a),sin(a),0)
            t.box_at(pod+out*.3+Vector3(0,0,1.45),Vector3(.1,.46,.62),Vector3(.0,0,a+PI*.5),LEAF if leaf%2==0 else LEAF_DARK)
            t.box_at(pod+out*.52+Vector3(0,0,1.8),Vector3(.1,.36,.5),Vector3(.0,0,a+PI*.5),LEAF_DARK if leaf%2==0 else LEAF)
        # Googly eyes on the nose, a smile, and a pair of fins that look like leaves too.
        for e in [-1.0,1.0]:
            t.sphere(pod+Vector3(e*.14,.26,-.5),.13,Color("ffffff"),Vector3.ONE,0.0,10)
            t.sphere(pod+Vector3(e*.14+e*.015,.27,-.6),.065,Color("111111"),Vector3.ONE,0.0,8)
        for k in 5:
            var a: float=-.5+k*.25
            t.sphere(pod+Vector3(sin(a)*.18,.11-cos(a*2.0)*.04,-.7),.022,Color("3a1a0c"),Vector3.ONE,0.0,4)
        # Saddle straps holding each carrot to the rocket bar.
        for z in [.2,.9]: t.cylinder(pod+Vector3(0,.0,z),lerpf(.18,.34,(z+.9)/1.9)+.04,lerpf(.18,.34,(z+.9)/1.9)+.04,.07,IRON,Vector3(PI*.5,0,0),12)
        t.rod(pod+Vector3(0,.34,.2),Vector3(side*1.15,1.0,6.1),.06,IRON,5)
    # Nitrous rack on the bumper: two blue bottles in a frame, with hoses down to the carrots.
    for side in [-1.0,1.0]:
        var at:=Vector3(side*1.62,2.05,6.45)
        t.cylinder(at,.2,.2,1.5,BLUE,Vector3.ZERO,12)
        t.sphere(at+Vector3(0,.78,0),.2,BLUE,Vector3(1,.7,1),0.0,10)
        t.cylinder(at+Vector3(0,.32,0),.205,.205,.18,CREAM,Vector3.ZERO,12)
        t.cylinder(at+Vector3(0,.95,0),.05,.05,.16,STEEL,Vector3.ZERO,8)
        t.rod(at+Vector3(0,.95,0),at+Vector3(side*.15,1.15,0),.025,STEEL,5)
        for y in [-.45,.45]: t.box(at+Vector3(-.26,y-.04,-.26),at+Vector3(.26,y+.04,.26),IRON)
        t.box(at+Vector3(-.28,-.8,-.28),at+Vector3(.28,-.72,.28),IRON)
        t.rod(at+Vector3(0,-.75,.15),Vector3(side*1.62,1.15,6.45),.07,IRON,5)
        t.rod(at+Vector3(0,-.55,.2),Vector3(side*1.4,1.5,6.95),.035,Color("1a1a1e"),5)
        t.rod(Vector3(side*1.4,1.5,6.95),Vector3(side*1.18,.55,6.55),.035,Color("1a1a1e"),5)
    t.box(Vector3(-.5,.9,6.3),Vector3(.5,1.08,6.34),HAZARD)
    t.commit(root,"Nitro")
    # Flames: separate nodes so the truck can grow and shrink them with the burn.
    var flames:=Node3D.new();flames.name="Flames";root.add_child(flames)
    var glow:=StandardMaterial3D.new();glow.albedo_color=Color("ffb04a");glow.emission_enabled=true;glow.emission=Color("ff8a2a")
    glow.emission_energy_multiplier=3.0;glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    glow.albedo_color.a=.85
    var core:=StandardMaterial3D.new();core.albedo_color=Color("fff4c2");core.emission_enabled=true;core.emission=Color("fff0a0")
    core.emission_energy_multiplier=4.0;core.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var flame_nodes: Array[Node3D]=[]
    for pod in NITRO_PODS:
        var holder:=Node3D.new();holder.position=pod+Vector3(0,0,1.75);flames.add_child(holder)
        var outer:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=.32;cone.bottom_radius=.02;cone.height=3.0;cone.radial_segments=10;cone.rings=1;cone.material=glow
        outer.mesh=cone;outer.rotation.x=-PI*.5;outer.position=Vector3(0,0,1.5);outer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;holder.add_child(outer)
        var inner:=MeshInstance3D.new();var cone2:=CylinderMesh.new();cone2.top_radius=.16;cone2.bottom_radius=.01;cone2.height=1.7;cone2.radial_segments=8;cone2.rings=1;cone2.material=core
        inner.mesh=cone2;inner.rotation.x=-PI*.5;inner.position=Vector3(0,0,.85);inner.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;holder.add_child(inner)
        flame_nodes.append(holder)
    var light:=OmniLight3D.new();light.name="FlameLight";light.position=Vector3(0,1.2,9.0);light.light_color=Color("ff9a3a");light.light_energy=0.0;light.omni_range=18
    root.add_child(light)
    parts[&"flames"]=flame_nodes;parts[&"flame_light"]=light
    return root

# --- The Galleon (boat kit) ------------------------------------------------------------------------
#
# On land it is folded away: the hull planks lie in thin slivers along the chassis, the aft
# deck is telescoped under the porch, the duck is deflated, the stern drive is swung up and
# the mast is down. The moment the truck touches water HuntingJeep drives `boat_deploy` from
# 0 to 1 and `animate_boat` unfolds a full wooden hull around the truck in a staggered
# sequence with steam and a shudder (hull flanks swing out and bounce, the bow pops out
# and the rubber-duck figurehead inflates, the aft deck telescopes out with its stairs, the
# stern drive drops, the mast telescopes). It folds back on leaving the water.
const HULL_BOW: float=-10.6
const HULL_STERN: float=13.5
const BEAM: float=3.9
const HULL_BOTTOM: float=-.3
const HULL_RAIL: float=2.75
const HINGE_X: float=1.1
const HINGE_Y: float=1.0
const AFT_FLOOR_Y: float=1.6
const AFT_DECK_Z0: float=8.8
const AFT_ORIGIN_Z: float=6.1
## Where the stairs, the deck and the transom ladder put a hunter.
const AFT_LANDING:=Vector3(0,1.7,10.8)
const AFT_PORCH:=Vector3(.4,3.7,4.8)
const DRIVE_HINGE:=Vector3(0,1.1,13.7)
const MAST_AT:=Vector3(-1.35,3.7,5.4)

func _hull_half(z: float) -> float:
    if z>=-3.0: return BEAM*(1.0-.14*smoothstep(10.0,HULL_STERN,z))
    var u: float=clampf((-3.0-z)/(-3.0-HULL_BOW),0.0,1.0)
    return BEAM*pow(maxf(0.0,1.0-pow(u,2.1)),.75)

func _bow_u(z: float) -> float:
    return clampf((-4.0-z)/(-4.0-HULL_BOW),0.0,1.0)

func _hull_top(z: float) -> float:
    return HULL_RAIL+.25*smoothstep(10.0,HULL_STERN,z)+.9*pow(_bow_u(z),2.0)

func _hull_bot(z: float) -> float:
    return HULL_BOTTOM+1.6*pow(_bow_u(z),1.5)

func _ring(t: Object,center: Vector3,basis: Basis,radius: float,tube: float,color: Color,sides: int=18) -> void:
    for k in sides:
        var a0: float=TAU*k/sides;var a1: float=TAU*(k+1)/sides
        t.rod(center+basis*Vector3(cos(a0)*radius,sin(a0)*radius,0),center+basis*Vector3(cos(a1)*radius,sin(a1)*radius,0),tube,color,5)

func _boat() -> Node3D:
    var root:=_root("boat")
    parts[&"boat_root"]=root
    var hulls: Array[Node3D]=[]
    for side in [-1.0,1.0]:
        var hull:=_hull_side(side);root.add_child(hull);hulls.append(hull)
    parts[&"hulls"]=hulls
    # Bow: stem post, a carved scroll and the rubber-duck figurehead.
    var bow:=Node3D.new();bow.name="Bow";root.add_child(bow)
    var bt:=Toon.new()
    var tip_bot:=Vector3(0,_hull_bot(HULL_BOW)+.1,HULL_BOW)
    var tip_top:=Vector3(0,_hull_top(HULL_BOW)+.5,HULL_BOW-.1)
    bt.rod(tip_bot,tip_top,.2,BARK,8)
    bt.rod(tip_top,tip_top+Vector3(0,.55,-.45),.14,BARK,8,.08)
    bt.sphere(tip_top+Vector3(0,.62,-.5),.17,BRASS,Vector3.ONE,0.0,8)
    for side in [-1.0,1.0]: bt.rod(tip_top+Vector3(side*.1,-.2,.2),tip_top+Vector3(side*.5,-.9,1.2),.07,BARK,6)
    bt.commit(bow,"Stem")
    var duck:=Node3D.new();duck.name="Duck";duck.position=tip_top+Vector3(0,1.1,-.35);bow.add_child(duck)
    _duck(duck)
    parts[&"bow"]=bow;parts[&"duck"]=duck
    # Aft: transom, telescoping deck with railings, stairs from the porch, ladder, lanterns, clutter.
    var aft:=_aft();root.add_child(aft);parts[&"aft"]=aft
    # Stern drive: an arm that drops a propeller and rudder into the water.
    var drive:=Node3D.new();drive.name="Drive";drive.position=DRIVE_HINGE;root.add_child(drive)
    var d:=Toon.new()
    d.cylinder(Vector3.ZERO,.24,.24,.7,IRON,Vector3(0,0,PI*.5),10)
    d.rod(Vector3.ZERO,Vector3(0,-1.2,.55),.13,IRON,8)
    d.box(Vector3(-.05,-1.5,.4),Vector3(.05,-.45,1.15),STEEL)
    d.box(Vector3(-.08,-1.25,.35),Vector3(.08,-1.15,.95),IRON)
    d.commit(drive,"Drive")
    var hub:=Node3D.new();hub.name="Propeller";hub.position=Vector3(0,-1.2,.6);drive.add_child(hub)
    var blades:=Toon.new()
    blades.cylinder(Vector3.ZERO,.17,.17,.34,BRASS,Vector3(PI*.5,0,0),8)
    for blade in 4:
        var a: float=blade*TAU/4.0
        blades.box_at(Vector3(cos(a)*.5,sin(a)*.5,0),Vector3(.2,.9,.05),Vector3(0,0,a+PI*.5),BRASS)
    blades.commit(hub,"Blade")
    parts[&"drive"]=drive;parts[&"propeller"]=hub
    # Mast that telescopes up with a pennant (a rubber duck on a flag, naturally).
    var mast:=Node3D.new();mast.name="Mast";mast.position=MAST_AT;root.add_child(mast)
    var m:=Toon.new()
    m.rod(Vector3.ZERO,Vector3(0,3.6,0),.05,BARK_LIGHT)
    m.rod(Vector3(0,3.6,0),Vector3(0,4.0,0),.025,CHROME,5)
    m.box(Vector3(-.02,2.2,-.9),Vector3(.02,3.5,0),NAVY)
    m.cylinder(Vector3(0,2.75,-.45),.32,.32,.04,Color("ffd83a"),Vector3(0,0,PI*.5),14)
    m.sphere(Vector3(0,2.78,-.5),.12,Color("ff8a1c"),Vector3(1,.6,1),0.0,6)
    m.box(Vector3(-.1,1.5,-.1),Vector3(.1,1.7,.1),IRON)
    m.box(Vector3(-.07,1.53,-.07),Vector3(.07,1.67,.07),WARM,2.4)
    m.commit(mast,"Mast")
    parts[&"mast"]=mast
    # Bow and flank spray, steam vents at the hinges, and a life ring on the porch gate.
    var sprays: Array[CPUParticles3D]=[]
    var drop:=SphereMesh.new();drop.radius=.14;drop.height=.28;drop.radial_segments=6;drop.rings=3
    var foam:=StandardMaterial3D.new();foam.albedo_color=Color(.92,.97,1.0,.75);foam.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;foam.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    drop.material=foam
    for pos in [Vector3(-.5,.6,-10.3),Vector3(.5,.6,-10.3),Vector3(-3.7,.6,-5.5),Vector3(3.7,.6,-5.5)]:
        var spray:=CPUParticles3D.new();spray.name="Spray";spray.position=pos;spray.emitting=false;spray.amount=44;spray.lifetime=.9
        spray.direction=Vector3(signf(pos.x)*.7,1,-.6);spray.spread=42;spray.initial_velocity_min=2.0;spray.initial_velocity_max=5.5;spray.gravity=Vector3(0,-9,0)
        spray.mesh=drop;root.add_child(spray);sprays.append(spray)
    parts[&"sprays"]=sprays
    var steam: Array[CPUParticles3D]=[]
    var vapor:=SphereMesh.new();vapor.radius=.22;vapor.height=.44;vapor.radial_segments=6;vapor.rings=3
    var vm:=StandardMaterial3D.new();vm.albedo_color=Color(1,1,1,.5);vm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;vm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;vapor.material=vm
    for pos in [Vector3(-2.0,1.2,-4.0),Vector3(2.0,1.2,-4.0),Vector3(-2.0,1.2,4.5),Vector3(2.0,1.2,4.5),Vector3(0,1.3,6.4)]:
        var puff:=CPUParticles3D.new();puff.name="Steam";puff.position=pos;puff.emitting=false;puff.amount=18;puff.lifetime=1.1
        puff.direction=Vector3(signf(pos.x)*.6,1,0);puff.spread=30;puff.initial_velocity_min=1.5;puff.initial_velocity_max=3.5;puff.gravity=Vector3(0,.6,0)
        puff.mesh=vapor;root.add_child(puff);steam.append(puff)
    parts[&"steam"]=steam
    var rings:=Toon.new()
    for x in [-.55,.55]:
        rings.cylinder(Vector3(x,4.4,6.08),.3,.3,.08,RED,Vector3(PI*.5,0,0),14)
        rings.cylinder(Vector3(x,4.4,6.09),.14,.14,.09,CREAM,Vector3(PI*.5,0,0),12)
    rings.commit(root,"Rings")
    # Collision: only the aft deck is walkable, and only once it has unfolded (HuntingJeep
    # switches `boat_deck` on at full deployment).
    shapes[&"boat_deck"]=[]
    _deck_shape(Vector3(-3.3,AFT_FLOOR_Y-.2,AFT_DECK_Z0-.4),Vector3(3.3,AFT_FLOOR_Y,HULL_STERN-.2))
    for side in [-1.0,1.0]:
        _deck_shape(Vector3(side*3.4-.12,AFT_FLOOR_Y,AFT_DECK_Z0-.4),Vector3(side*3.4+.12,AFT_FLOOR_Y+2.4,HULL_STERN-.2))
        _deck_shape(Vector3(minf(side*.95,side*3.5),AFT_FLOOR_Y,HULL_STERN-.3),Vector3(maxf(side*.95,side*3.5),AFT_FLOOR_Y+2.4,HULL_STERN-.1))
    _deck_shape(Vector3(-3.5,AFT_FLOOR_Y,AFT_DECK_Z0-.5),Vector3(3.5,AFT_FLOOR_Y+2.4,AFT_DECK_Z0-.35))
    # The stairs from the porch down to the deck: a ramp of planks.
    var run: float=AFT_DECK_Z0-AFT_ORIGIN_Z;var drop_y: float=3.65-AFT_FLOOR_Y
    var slope: float=atan2(drop_y,run)
    var length: float=sqrt(run*run+drop_y*drop_y)
    var ramp:=CollisionShape3D.new();var rbox:=BoxShape3D.new();rbox.size=Vector3(1.9,.18,length+.4);ramp.shape=rbox
    ramp.transform=Transform3D(Basis(Vector3.RIGHT,slope),Vector3(0,(3.65+AFT_FLOOR_Y)*.5-.1,(AFT_ORIGIN_Z+AFT_DECK_Z0)*.5))
    body.add_child(ramp);shapes[&"boat_deck"].append(ramp)
    # Interactables: from the porch down to the aft deck and back, and from the water onto the deck.
    var down:=LobbyInteractable.new();down.interaction_kind="deck_down";down.interaction_range=1.3;down.position=Vector3(-1.3,3.65,5.2);down.name="DeckDown"
    var up:=LobbyInteractable.new();up.interaction_kind="deck_up";up.interaction_range=1.3;up.position=Vector3(-1.3,AFT_FLOOR_Y,AFT_DECK_Z0+.8);up.name="DeckUp"
    var swim:=LobbyInteractable.new();swim.interaction_kind="board_deck";swim.interaction_range=3.2;swim.position=Vector3(0,.6,HULL_STERN+1.2);swim.name="BoardDeck"
    root.add_child(down);root.add_child(up);root.add_child(swim)
    parts[&"deck_prompts"]=[down,up,swim]
    return root

func _deck_shape(a: Vector3,b: Vector3) -> void:
    var low:=Vector3(minf(a.x,b.x),minf(a.y,b.y),minf(a.z,b.z));var high:=Vector3(maxf(a.x,b.x),maxf(a.y,b.y),maxf(a.z,b.z))
    var box:=BoxShape3D.new();box.size=high-low
    var collision:=CollisionShape3D.new();collision.shape=box;collision.position=(low+high)*.5
    body.add_child(collision);shapes[&"boat_deck"].append(collision)

## One flank of the hull: planks in rows (navy waterline, a red boot stripe, three tones of
## wood, a dark wale and a cream cap), a gunwale with stanchions and a rope, lanterns,
## cannons, fender tyres, a life ring and an anchor. Vertices are relative to the hinge.
func _hull_side(side: float) -> Node3D:
    var node:=Node3D.new();node.name="Hull"+("L" if side<0 else "R");node.position=Vector3(side*HINGE_X,HINGE_Y,0)
    var t:=Toon.new()
    var stations: int=30;var rows: int=8
    var grid: Array=[]
    for i in stations+1:
        var z: float=lerpf(HULL_STERN,HULL_BOW,float(i)/stations)
        var g: float=_hull_half(z);var b: float=g*.6
        var bot: float=_hull_bot(z);var top: float=_hull_top(z)
        var row: Array[Vector3]=[]
        for k in rows+1:
            var f: float=float(k)/rows
            row.append(Vector3(side*lerpf(b,g,pow(f,.7)),lerpf(bot,top,f),z)-node.position)
        grid.append(row)
    var row_colors: Array[Color]=[NAVY,RED,Color("a8703c"),Color("9a6335"),Color("b07a45"),Color("9a6335"),Color("5e3a1e"),CREAM]
    for k in rows:
        var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in stations:
            var a: Vector3=grid[i][k];var b: Vector3=grid[i+1][k];var c: Vector3=grid[i+1][k+1];var d: Vector3=grid[i][k+1]
            for v in [a,b,c,a,c,d]: st.add_vertex(v)
        st.generate_normals()
        t.mesh(st.commit(),Transform3D.IDENTITY,row_colors[k],0.0,true)
    # Plank seams: thin dark lines along every row boundary.
    for k in range(1,rows):
        var prev: Vector3=grid[0][k]
        for i in range(1,stations+1):
            var cur: Vector3=grid[i][k]
            t.rod(prev,cur,.012,Color("3a2412"),3)
            prev=cur
    # Gunwale rail, stanchions and a rope between them, a lantern every few posts.
    var rail_prev: Vector3=grid[0][rows]+Vector3(0,.55,0)
    for i in stations+1:
        var top_point: Vector3=grid[i][rows]
        var post_top: Vector3=top_point+Vector3(0,.58,0)
        if i%3==0:
            t.rod(top_point,post_top,.06,BARK,5)
            if i%6==0 and absf(top_point.z)<12.0 and i>2:
                t.rod(post_top,post_top+Vector3(0,.25,0),.03,IRON,4)
                t.box(post_top+Vector3(-.07,.25,-.07),post_top+Vector3(.07,.45,.07),WARM,2.4)
        if i>0: t.rod(rail_prev,post_top,.04,Color("e0d2a8"),4)
        rail_prev=post_top
    var cap_prev: Vector3=grid[0][rows]
    for i in range(1,stations+1):
        var cur: Vector3=grid[i][rows]+Vector3(0,.04,0)
        t.rod(cap_prev,cur,.09,BARK,5)
        cap_prev=cur
    # Cannons poking out between the stanchions, with brass muzzle rings.
    for z in [-5.5,-1.5,2.5]:
        var span: float=_hull_half(z)
        var y: float=_hull_top(z)-.2
        var base:=Vector3(side*span,y,z)-node.position
        t.cylinder(base+Vector3(side*.45,0,0),.17,.2,1.1,Color("2a2a2e"),Vector3(0,0,PI*.5),10)
        t.cylinder(base+Vector3(side*1.0,0,0),.22,.22,.1,BRASS,Vector3(0,0,PI*.5),10)
        t.box(base+Vector3(side*.2-.2,-.22,-.25),base+Vector3(side*.2+.2,-.05,.25),WOOD_DARK)
    # Fender tyres, a life ring and an anchor.
    for z in [-3.2,.8,4.8,8.8,12.0]:
        var span2: float=_hull_half(z)*.99
        var y2: float=lerpf(_hull_bot(z),_hull_top(z),.62)
        t.cylinder(Vector3(side*(span2+.12),y2,z)-node.position,.3,.3,.3,Color("1d1d21"),Vector3(0,0,PI*.5),10)
    var lr:=Vector3(side*(_hull_half(-6.0)+.1),lerpf(_hull_bot(-6.0),_hull_top(-6.0),.55),-6.0)-node.position
    t.cylinder(lr,.42,.42,.1,RED,Vector3(0,0,PI*.5),14)
    t.cylinder(lr+Vector3(side*.02,0,0),.22,.22,.12,CREAM,Vector3(0,0,PI*.5),12)
    var an:=Vector3(side*(_hull_half(-8.0)+.15),lerpf(_hull_bot(-8.0),_hull_top(-8.0),.6),-8.0)-node.position
    t.rod(an,an+Vector3(0,-.9,0),.05,IRON,5)
    t.rod(an+Vector3(0,-.75,-.4),an+Vector3(0,-.75,.4),.05,IRON,5)
    t.rod(an+Vector3(0,-.9,0),an+Vector3(0,-.6,-.45),.05,IRON,5)
    t.rod(an+Vector3(0,-.9,0),an+Vector3(0,-.6,.45),.05,IRON,5)
    t.commit(node,"Planks")
    return node

## The rubber-duck figurehead: yellow, round, wearing a red bow tie and a tiny sailor hat.
func _duck(duck: Node3D) -> void:
    var t:=Toon.new()
    var YELLOW:=Color("ffd83a");var ORANGE:=Color("ff8a1c")
    t.sphere(Vector3(0,0,0),.95,YELLOW,Vector3(.9,.8,1.15),0.0,14)
    t.sphere(Vector3(0,.95,-.55),.58,YELLOW,Vector3.ONE,0.0,14)
    t.sphere(Vector3(0,.8,-1.15),.28,ORANGE,Vector3(1.3,.55,1.0),0.0,10)
    t.sphere(Vector3(0,.74,-1.28),.2,ORANGE,Vector3(1.2,.4,1.0),0.0,8)
    for side in [-1.0,1.0]:
        t.sphere(Vector3(side*.33,1.12,-.9),.1,Color("1a1a1e"),Vector3.ONE,0.0,8)
        t.sphere(Vector3(side*.36,1.16,-.96),.03,Color("ffffff"),Vector3.ONE,0.0,5)
        t.sphere(Vector3(side*.78,.1,.1),.5,YELLOW,Vector3(.35,.6,1.0),0.0,8)
    t.prism(Vector3(0,.85,.95),Vector3(.5,.7,.3),Vector3(-.4,0,0),YELLOW)
    t.box(Vector3(-.3,.42,-.78),Vector3(.3,.54,-.58),RED)
    t.box(Vector3(-.12,.36,-.74),Vector3(.12,.6,-.62),Color("7a2a22"))
    t.cylinder(Vector3(0,1.62,-.5),.3,.34,.22,Color("f4f4f0"),Vector3.ZERO,12)
    t.cylinder(Vector3(0,1.5,-.5),.4,.4,.06,Color("1f3a68"),Vector3.ZERO,12)
    t.commit(duck,"Duck")

## The aft end of the boat: the transom, the telescoping deck with its rail, the stairs
## from the porch, the transom ladder, lanterns, a rod rack, a bucket and crates. The node
## origin sits where the deck emerges from under the porch, so scaling z telescopes it out.
func _aft() -> Node3D:
    var node:=Node3D.new();node.name="Aft";node.position=Vector3(0,0,AFT_ORIGIN_Z)
    var t:=Toon.new()
    var z0: float=AFT_DECK_Z0-AFT_ORIGIN_Z;var z1: float=HULL_STERN-.2-AFT_ORIGIN_Z
    # Deck planks.
    var planks: int=10
    for k in planks:
        var a: float=lerpf(z0,z1,float(k)/planks);var b: float=lerpf(z0,z1,float(k+1)/planks)
        t.box(Vector3(-3.4,AFT_FLOOR_Y-.16,a+.02),Vector3(3.4,AFT_FLOOR_Y,b-.02),Color("b07a45") if k%2==0 else Color("9a6335"))
    t.box(Vector3(-3.5,AFT_FLOOR_Y-.5,z0),Vector3(3.5,AFT_FLOOR_Y-.16,z1),WOOD_DARK)
    # Transom: the flat back of the hull, planked, with a name board.
    var g: float=_hull_half(HULL_STERN)
    var bot: float=_hull_bot(HULL_STERN);var top: float=_hull_top(HULL_STERN)
    var zt: float=HULL_STERN-AFT_ORIGIN_Z
    var rows: int=7
    for k in rows:
        var y0: float=lerpf(bot,top,float(k)/rows);var y1: float=lerpf(bot,top,float(k+1)/rows)
        var c: Color=[NAVY,RED,Color("a8703c"),Color("9a6335"),Color("b07a45"),Color("5e3a1e"),CREAM][k]
        t.box(Vector3(-g,y0,zt-.1),Vector3(g,y1,zt+.04),c)
    t.box(Vector3(-1.4,AFT_FLOOR_Y+.7,zt+.04),Vector3(1.4,AFT_FLOOR_Y+1.3,zt+.1),Color("2a1a10"))
    t.box(Vector3(-1.3,AFT_FLOOR_Y+.78,zt+.1),Vector3(1.3,AFT_FLOOR_Y+1.22,zt+.12),BRASS)
    # Railings along the sides (the hull gunwale supplies the rest) and either side of the ladder gap.
    for side in [-1.0,1.0]:
        for k in 6:
            var z: float=lerpf(z0,z1,float(k)/5.0)
            t.rod(Vector3(side*3.4,AFT_FLOOR_Y,z),Vector3(side*3.4,AFT_FLOOR_Y+1.1,z),.05,BARK,5)
        t.rod(Vector3(side*3.4,AFT_FLOOR_Y+1.1,z0),Vector3(side*3.4,AFT_FLOOR_Y+1.1,z1),.05,Color("e0d2a8"),5)
        t.rod(Vector3(side*3.4,AFT_FLOOR_Y+.55,z0),Vector3(side*3.4,AFT_FLOOR_Y+.55,z1),.035,Color("e0d2a8"),5)
        t.rod(Vector3(side*.95,AFT_FLOOR_Y+1.1,zt-.05),Vector3(side*3.4,AFT_FLOOR_Y+1.1,zt-.05),.05,Color("e0d2a8"),5)
        for x in [1.2,2.0,2.8]:
            t.rod(Vector3(side*x,AFT_FLOOR_Y,zt-.05),Vector3(side*x,AFT_FLOOR_Y+1.1,zt-.05),.05,BARK,5)
        # Lanterns on tall stern posts.
        var lp:=Vector3(side*3.3,AFT_FLOOR_Y+1.1,zt-.1)
        t.rod(lp,lp+Vector3(0,.9,0),.05,BARK,5)
        t.box(lp+Vector3(-.12,.9,-.12),lp+Vector3(.12,1.25,.12),IRON)
        t.box(lp+Vector3(-.09,.94,-.09),lp+Vector3(.09,1.2,.09),Color("ff7a5a") if side<0 else Color("5aff9a"),2.6)
    # Stairs from the porch (z=0 at its edge, y=3.65) down to the deck.
    var run: float=z0;var drop_y: float=3.65-AFT_FLOOR_Y
    var steps: int=9
    for k in steps:
        var f0: float=float(k)/steps;var f1: float=float(k+1)/steps
        var y_top: float=3.65-drop_y*f1
        t.box(Vector3(-.9,y_top-.12,run*f0),Vector3(.9,y_top,run*f1),Color("b07a45") if k%2==0 else Color("9a6335"))
    for side in [-1.0,1.0]:
        t.rod(Vector3(side*.95,3.65,0),Vector3(side*.95,AFT_FLOOR_Y,run),.07,WOOD_DARK,6)
        t.rod(Vector3(side*.95,4.7,0),Vector3(side*.95,AFT_FLOOR_Y+1.05,run),.05,Color("e0d2a8"),5)
        for k in 4:
            var f: float=float(k)/3.0
            t.rod(Vector3(side*.95,lerpf(3.65,AFT_FLOOR_Y,f),run*f),Vector3(side*.95,lerpf(4.7,AFT_FLOOR_Y+1.05,f),run*f),.04,BARK,5)
    # Transom ladder down to the water, with rungs.
    for side in [-.55,.55]: t.rod(Vector3(side,AFT_FLOOR_Y+.1,zt+.12),Vector3(side,-.7,zt+.2),.05,STEEL,5)
    for k in 7:
        var f: float=float(k)/6.0
        t.rod(Vector3(-.55,lerpf(AFT_FLOOR_Y,-.6,f),zt+.14+f*.06),Vector3(.55,lerpf(AFT_FLOOR_Y,-.6,f),zt+.14+f*.06),.03,STEEL,4)
    # Deck clutter: a rack of fishing rods, a bucket, crates, a rope coil and a deck chair.
    t.box(Vector3(-3.2,AFT_FLOOR_Y,z0+.9),Vector3(-2.7,AFT_FLOOR_Y+.08,z0+2.6),WOOD_DARK)
    for k in 4:
        var z: float=z0+1.0+k*.45
        t.rod(Vector3(-2.95,AFT_FLOOR_Y+.05,z),Vector3(-3.25,AFT_FLOOR_Y+2.6,z-.5),.02,[RED,Color("2f8a92"),BRASS,CREAM][k],4)
        t.sphere(Vector3(-3.25,AFT_FLOOR_Y+2.6,z-.5),.04,IRON,Vector3.ONE,0.0,4)
    t.cylinder(Vector3(2.5,AFT_FLOOR_Y+.28,z0+1.1),.3,.24,.56,Color("4a7ac0"),Vector3.ZERO,10)
    t.rod(Vector3(2.25,AFT_FLOOR_Y+.56,z0+1.1),Vector3(2.75,AFT_FLOOR_Y+.56,z0+1.1),.03,STEEL,4)
    t.box(Vector3(1.9,AFT_FLOOR_Y,z0+2.2),Vector3(2.7,AFT_FLOOR_Y+.7,z0+3.0),Color("8a5a33"))
    t.box(Vector3(1.95,AFT_FLOOR_Y+.7,z0+2.25),Vector3(2.65,AFT_FLOOR_Y+1.3,z0+2.95),Color("a8703c"))
    t.cylinder(Vector3(-2.2,AFT_FLOOR_Y+.1,z1-1.1),.45,.45,.2,Color("d8c08a"),Vector3.ZERO,12)
    t.box(Vector3(1.0,AFT_FLOOR_Y+.05,z1-2.2),Vector3(1.8,AFT_FLOOR_Y+.1,z1-1.3),Color("e0482e"))
    t.box(Vector3(1.0,AFT_FLOOR_Y+.1,z1-2.2),Vector3(1.1,AFT_FLOOR_Y+.7,z1-1.3),Color("e0482e"))
    t.box(Vector3(1.0,AFT_FLOOR_Y+.45,z1-1.35),Vector3(1.8,AFT_FLOOR_Y+.7,z1-1.3),Color("e0482e"))
    t.commit(node,"Aft")
    return node

## The staggered unfold. `d` is boat_deploy 0..1; every part eases past its target and
## settles back, so the transformation snaps and bounces rather than gliding.
static func ease_out_back(x: float) -> float:
    var c1: float=1.5;var c3: float=c1+1.0
    var v: float=clampf(x,0.0,1.0)-1.0
    return 1.0+c3*v*v*v+c1*v*v

func animate_boat(d: float,t: float,speed: float,floating: bool) -> void:
    if not parts.has(&"hulls"): return
    var hull_p: float=ease_out_back(clampf(d/.5,0.0,1.0))
    var bow_p: float=ease_out_back(clampf((d-.2)/.45,0.0,1.0))
    var aft_p: float=ease_out_back(clampf((d-.35)/.45,0.0,1.0))
    var drive_p: float=ease_out_back(clampf((d-.5)/.4,0.0,1.0))
    var mast_p: float=clampf((d-.7)/.3,0.0,1.0)
    var side: float=-1.0
    for node in parts[&"hulls"]:
        node.visible=d>.015
        node.scale=Vector3(lerpf(.08,1.0,hull_p),lerpf(.5,1.0,hull_p),lerpf(.3,1.0,hull_p))
        node.rotation.z=-side*lerpf(.55,0.0,hull_p)
        side=1.0
    var bow: Node3D=parts[&"bow"]
    bow.visible=d>.015
    bow.scale=Vector3(1.0,1.0,lerpf(.1,1.0,bow_p))
    var duck: Node3D=parts[&"duck"]
    var pop: float=ease_out_back(clampf((d-.5)/.3,0.0,1.0))
    var squash: float=1.0+sin(t*3.0)*.02*d
    duck.scale=Vector3(lerpf(.05,1.0,pop),lerpf(.05,1.0,pop)*squash,lerpf(.05,1.0,pop))
    duck.rotation.z=sin(t*1.7)*.06*d+clampf(speed*.004,0.0,.12)
    var aft: Node3D=parts[&"aft"]
    aft.visible=d>.015
    aft.scale=Vector3(1.0,1.0,lerpf(.05,1.0,aft_p))
    parts[&"drive"].rotation.x=lerpf(-1.75,0.0,drive_p)
    parts[&"drive"].visible=d>.015
    parts[&"mast"].scale=Vector3(1.0,maxf(.001,mast_p),1.0)
    parts[&"mast"].visible=mast_p>.01
    var busy: bool=d>.03 and d<.97
    for puff in parts[&"steam"]: puff.emitting=busy
    var wake: bool=floating and absf(speed)>3.0 and d>.9
    for spray in parts[&"sprays"]: spray.emitting=wake
    # A shudder while the hull unfolds, felt by the whole kit.
    var root: Node3D=parts.get(&"boat_root")
    if root: root.position=Vector3(sin(t*55.0)*.025,0,cos(t*47.0)*.02)*(1.0 if busy else 0.0)
