extends RefCounted
## The five absurd builds of the Wandering Oak that are not part of its basic kit
## (see TruckUpgrades): the Hospital Barbecue, the Loot Hoover, the Glass Sphere, the
## Shark-Scaring Gramophone and the Flying Oak rotor. Every one is a hidden Node3D under the
## truck body, drawn as merged toon primitives, with the moving parts as separate nodes
## that `animate_*` drives from replicated state. Truck-local frame: forward is -Z.
const Toon:=preload("res://world/camp/toon_builder.gd")

const IRON:=Color("3a3a3e")
const STEEL:=Color("8d9399")
const CHROME:=Color("c9cdd0")
const BRASS:=Color("d9b24a")
const BRASS_DARK:=Color("a9822c")
const RED:=Color("c9463a")
const CREAM:=Color("efe3c4")
const WARM:=Color("ffcf7a")
const WOOD:=Color("9a6b40")
const WOOD_DARK:=Color("6f4a2b")
const BLUE:=Color("3f7fd0")
const GREEN:=Color("4f9a3a")
const PINK:=Color("f08aa8")

const DECK_Y: float=7.8
## Where the glass sphere hangs when lowered, its radius, and where a diver stands inside it.
const SPHERE_CENTER:=Vector3(0,-1.55,1.7)
const SPHERE_RADIUS: float=1.75
const SPHERE_LANDING:=Vector3(0,-2.35,1.7)
const SPHERE_PORCH_HATCH:=Vector3(-1.3,3.65,3.7)
## The rotor hub, above the watchtower platform.
const ROTOR_HUB:=Vector3(0,16.3,-.05)
const ROTOR_RADIUS: float=7.6
## Grill and gramophone placement.
const GRILL_AT:=Vector3(0,3.6,-3.9)
const HORN_AT:=Vector3(1.0,DECK_Y,2.7)
const HOOVER_AT:=Vector3(-1.5,3.65,5.1)

var body: RigidBody3D
var shapes: Dictionary={}
var parts: Dictionary={}

func build_all(target: RigidBody3D) -> Dictionary:
    body=target
    var roots: Dictionary={}
    roots[&"grill"]=_grill()
    roots[&"vacuum"]=_vacuum()
    roots[&"sphere"]=_sphere()
    roots[&"horn"]=_horn()
    roots[&"rotor"]=_rotor()
    for id in roots:
        roots[id].visible=false
        for shape in shapes.get(id,[]): shape.disabled=true
    return roots

func _root(id: String) -> Node3D:
    var root:=Node3D.new();root.name=id.capitalize()+"Kit";body.add_child(root)
    shapes[StringName(id)]=[]
    return root

func _shape(id: StringName,a: Vector3,b: Vector3,yaw: float=0.0) -> void:
    var low:=Vector3(minf(a.x,b.x),minf(a.y,b.y),minf(a.z,b.z));var high:=Vector3(maxf(a.x,b.x),maxf(a.y,b.y),maxf(a.z,b.z))
    var box:=BoxShape3D.new();box.size=high-low
    var collision:=CollisionShape3D.new();collision.shape=box;collision.position=(low+high)*.5;collision.rotation.y=yaw
    body.add_child(collision);shapes[id].append(collision)

## A ring of rods in a plane (`basis` maps the circle's x/y/z axes), for hoops and frames.
func _ring(t: Object,center: Vector3,basis: Basis,radius: float,tube: float,color: Color,sides: int=20) -> void:
    for k in sides:
        var a0: float=TAU*k/sides;var a1: float=TAU*(k+1)/sides
        t.rod(center+basis*Vector3(cos(a0)*radius,sin(a0)*radius,0),center+basis*Vector3(cos(a1)*radius,sin(a1)*radius,0),tube,color,5)

func _particles(amount: int,life: float,velocity: Vector2,spread: float,direction: Vector3,gravity: Vector3,color: Color,radius: float,glow: bool=false) -> CPUParticles3D:
    var p:=CPUParticles3D.new();p.emitting=false;p.amount=amount;p.lifetime=life;p.direction=direction;p.spread=spread
    p.initial_velocity_min=velocity.x;p.initial_velocity_max=velocity.y;p.gravity=gravity;p.local_coords=false
    var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2.0;mesh.radial_segments=6;mesh.rings=3
    var m:=StandardMaterial3D.new();m.albedo_color=color;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    if glow: m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.5
    mesh.material=m;p.mesh=mesh
    var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,.9));ramp.set_color(1,Color(1,1,1,0.0));p.color_ramp=ramp
    return p

# --- The Hospital Barbecue -------------------------------------------------------------------
#
# A barrel grill the size of a bathtub on the cab roof: a lid that opens, a chimney, a striped
# umbrella with a chef's hat on top, sausages, a roast chicken, corn, a fork and a spatula for
# a flag. Everybody aboard heals while it sizzles (HuntingJeep applies the healing).

func _grill() -> Node3D:
    var root:=_root("grill");var t:=Toon.new()
    var at:=GRILL_AT
    # Legs and a wheeled frame.
    for x in [-.85,.85]:
        for z in [-.6,.6]:
            t.rod(at+Vector3(x,0,z),at+Vector3(x,1.2,z),.07,IRON,6)
    t.box(at+Vector3(-.95,.45,-.7),at+Vector3(.95,.52,.7),IRON)
    for x in [-1.05,1.05]: t.cylinder(at+Vector3(x,.22,.7),.2,.2,.08,IRON,Vector3(0,0,PI*.5),10)
    # The barrel body, banded in red, with a fire box glowing at the grate.
    t.cylinder(at+Vector3(0,1.5,0),.9,.9,2.15,Color("2c2c30"),Vector3(0,0,PI*.5),18)
    for x in [-.8,-.3,.3,.8]: t.cylinder(at+Vector3(x,1.5,0),.93,.93,.1,RED,Vector3(0,0,PI*.5),18)
    t.box(at+Vector3(-.95,1.72,-.62),at+Vector3(.95,1.8,.62),IRON)
    t.box(at+Vector3(-.9,1.6,-.55),at+Vector3(.9,1.64,.55),Color("ff7a1a"),2.4)
    # Grate goodies: sausages, a chicken, corn on the cob, a kebab skewer.
    for k in 6:
        t.cylinder(at+Vector3(-.75+k*.3,1.88,-.25),.07,.07,.5,Color("a8452e") if k%2==0 else Color("c8643a"),Vector3(PI*.5,0,0),8)
    t.sphere(at+Vector3(-.4,2.0,.3),.3,Color("d99a3a"),Vector3(1.2,.8,.9),0.0,8)
    t.sphere(at+Vector3(-.4,2.2,.25),.1,Color("d99a3a"),Vector3.ONE,0.0,6)
    t.cylinder(at+Vector3(.4,1.9,.3),.1,.1,.55,Color("f2c94c"),Vector3(0,0,PI*.5),8)
    t.rod(at+Vector3(.1,1.92,.05),at+Vector3(.85,1.92,.05),.012,STEEL,4)
    for k in 3: t.sphere(at+Vector3(.25+k*.2,1.92,.05),.07,[Color("c9463a"),Color("7fb53a"),Color("f2c94c")][k],Vector3.ONE,0.0,6)
    # Chimney and a hot-dog sign.
    t.rod(at+Vector3(.75,1.7,-.5),at+Vector3(.75,3.0,-.5),.1,IRON,8)
    t.cylinder(at+Vector3(.75,3.02,-.5),.16,.1,.14,IRON,Vector3.ZERO,8)
    # Umbrella on a pole: red-and-cream wedges and a chef's hat on top.
    t.rod(at+Vector3(-.9,1.0,-.55),at+Vector3(-.9,3.6,-.55),.05,WOOD_DARK,6)
    for k in 8:
        var a: float=TAU*k/8.0
        var c0:=Vector3(cos(a)*1.55,0,sin(a)*1.55);var c1:=Vector3(cos(a+TAU/8.0)*1.55,0,sin(a+TAU/8.0)*1.55)
        var top:=Vector3(-.9,3.95,-.55);var rim0:=Vector3(-.9,3.45,-.55)+c0;var rim1:=Vector3(-.9,3.45,-.55)+c1
        var wedge:=SurfaceTool.new();wedge.begin(Mesh.PRIMITIVE_TRIANGLES)
        for v in [top,rim0,rim1]: wedge.add_vertex(at+v)
        wedge.generate_normals()
        t.mesh(wedge.commit(),Transform3D.IDENTITY,RED if k%2==0 else CREAM,0.0,true)
    t.cylinder(at+Vector3(-.9,4.2,-.55),.2,.24,.35,Color("ffffff"),Vector3.ZERO,12)
    t.sphere(at+Vector3(-.9,4.5,-.55),.3,Color("ffffff"),Vector3(1,.8,1),0.0,10)
    # A fork and a spatula crossed on the front rail like a pennant.
    t.rod(at+Vector3(.95,1.9,.55),at+Vector3(1.5,3.2,.55),.03,STEEL,5)
    t.rod(at+Vector3(1.5,3.2,.55),at+Vector3(1.55,3.55,.55),.015,STEEL,4)
    for k in 3: t.rod(at+Vector3(1.43+k*.07,3.3,.55),at+Vector3(1.43+k*.07,3.62,.55),.012,STEEL,4)
    t.rod(at+Vector3(1.0,1.9,.55),at+Vector3(1.8,3.1,.55),.03,WOOD,5)
    t.box(at+Vector3(1.72,3.05,.5),at+Vector3(1.98,3.4,.6),STEEL)
    t.commit(root,"Grill")
    # The lid: a half barrel on a hinge that opens when the grill is cooking.
    var lid:=Node3D.new();lid.name="Lid";lid.position=at+Vector3(0,1.8,-.6);root.add_child(lid)
    var lt:=Toon.new()
    lt.cylinder(Vector3(0,.15,.6),.9,.9,2.15,Color("2c2c30"),Vector3(0,0,PI*.5),18)
    lt.box(Vector3(-1.0,-.05,.0),Vector3(1.0,.05,1.25),Color("2c2c30"))
    lt.rod(Vector3(-.5,.9,.6),Vector3(.5,.9,.6),.07,BRASS,6)
    lt.commit(lid,"Lid")
    parts[&"grill_lid"]=lid
    var fire:=OmniLight3D.new();fire.name="GrillFire";fire.position=at+Vector3(0,2.2,0);fire.light_color=Color("ff9a3a");fire.light_energy=1.2;fire.omni_range=7.0
    root.add_child(fire);parts[&"grill_fire"]=fire
    var smoke:=_particles(30,3.0,Vector2(.6,1.2),18.0,Vector3(0,1,0),Vector3(.25,.25,0),Color(.82,.82,.85,.5),.22)
    smoke.position=at+Vector3(.75,3.1,-.5);root.add_child(smoke);parts[&"grill_smoke"]=smoke
    var hearts:=_particles(14,2.0,Vector2(.9,1.5),30.0,Vector3(0,1,0),Vector3(0,.3,0),PINK,.14,true)
    hearts.position=at+Vector3(0,3.2,0);root.add_child(hearts);parts[&"grill_hearts"]=hearts
    return root

## `active`: someone aboard is being healed (lid open, fire roaring, hearts rising).
func animate_grill(delta: float,t: float,active: bool) -> void:
    if not parts.has(&"grill_lid"): return
    var lid: Node3D=parts[&"grill_lid"]
    lid.rotation.x=lerpf(lid.rotation.x,-1.45 if active else 0.0,1.0-exp(-5.0*delta))
    var fire: OmniLight3D=parts[&"grill_fire"]
    fire.light_energy=lerpf(fire.light_energy,(2.4+sin(t*13.0)*.5+sin(t*7.3)*.4) if active else .9,1.0-exp(-6.0*delta))
    parts[&"grill_smoke"].emitting=true
    parts[&"grill_hearts"].emitting=active

# --- The Loot Hoover ------------------------------------------------------------------------------
#
# A dust-bag drum with googly eyes on the porch corner and an eight-metre elephant trunk of
# banded rubber that curls out over the side to a flared nozzle. It sucks up loot within
# VACUUM_RADIUS (HuntingJeep does the collecting); the trunk bulges and a whirl of wind
# streams into the nozzle while it works.

func _vacuum() -> Node3D:
    var root:=_root("vacuum");var t:=Toon.new()
    var at:=HOOVER_AT
    # The drum: a fat red cylinder with a brass lid, a pressure gauge and a pair of eyes.
    t.cylinder(at+Vector3(0,.8,0),.62,.66,1.6,RED,Vector3.ZERO,16)
    t.cylinder(at+Vector3(0,1.64,0),.68,.68,.12,BRASS,Vector3.ZERO,16)
    t.cylinder(at+Vector3(0,1.8,0),.12,.2,.2,BRASS_DARK,Vector3.ZERO,10)
    for y in [.35,1.25]: t.cylinder(at+Vector3(0,y,0),.69,.69,.1,IRON,Vector3.ZERO,16)
    t.cylinder(at+Vector3(.0,1.0,-.64),.2,.2,.05,CREAM,Vector3(PI*.5,0,0),14)
    t.rod(at+Vector3(0,1.0,-.67),at+Vector3(.08,1.08,-.67),.012,RED,4)
    for side in [-1.0,1.0]:
        t.sphere(at+Vector3(side*.24,1.4,-.62),.17,Color("ffffff"),Vector3.ONE,0.0,10)
        t.sphere(at+Vector3(side*.24+side*.02,1.4,-.76),.08,Color("111111"),Vector3.ONE,0.0,8)
    t.box(at+Vector3(-.62,.1,-.5),at+Vector3(.62,.2,.5),IRON)
    for x in [-.5,.5]: t.cylinder(at+Vector3(x,.1,.5),.14,.14,.12,IRON,Vector3(0,0,PI*.5),8)
    t.commit(root,"Hoover")
    # The trunk: 14 banded rubber segments hinged one after another, curling out and down.
    var trunk:=Node3D.new();trunk.name="Trunk";trunk.position=at+Vector3(-.5,1.0,0);trunk.rotation.y=PI*.5;root.add_child(trunk)
    var segs: Array[Node3D]=[]
    var holder: Node3D=trunk
    for i in 14:
        var node:=Node3D.new();node.position=Vector3.ZERO if i==0 else Vector3(0,0,-.62);holder.add_child(node);segs.append(node);holder=node
        var f: float=float(i)/13.0
        var radius: float=lerpf(.3,.34,f)
        var st:=Toon.new()
        st.cylinder(Vector3(0,0,-.31),radius,radius,.62,Color("2a2a2e") if i%2==0 else Color("3a3a40"),Vector3(PI*.5,0,0),12)
        st.cylinder(Vector3(0,0,-.55),radius*1.12,radius*1.12,.06,BRASS if i%3==0 else IRON,Vector3(PI*.5,0,0),12)
        st.commit(node,"Seg")
    # The nozzle: a big flared bell with a whirling fan inside.
    var nozzle:=Node3D.new();nozzle.position=Vector3(0,0,-.62);holder.add_child(nozzle)
    var nt:=Toon.new()
    nt.cylinder(Vector3(0,0,-.5),.34,1.15,1.0,BRASS,Vector3(PI*.5,0,0),16)
    nt.cylinder(Vector3(0,0,-1.02),1.2,1.2,.08,BRASS_DARK,Vector3(PI*.5,0,0),18)
    nt.commit(nozzle,"Nozzle")
    var fan:=Node3D.new();fan.position=Vector3(0,0,-.75);nozzle.add_child(fan)
    var ft:=Toon.new()
    for blade in 5:
        var a: float=blade*TAU/5.0
        ft.box_at(Vector3(cos(a)*.5,sin(a)*.5,0),Vector3(.18,.7,.04),Vector3(0,0,a+PI*.5+.3),STEEL)
    ft.cylinder(Vector3.ZERO,.14,.14,.12,BRASS_DARK,Vector3(PI*.5,0,0),8)
    ft.commit(fan,"Fan")
    var wind:=_particles(36,.8,Vector2(2.0,5.0),12.0,Vector3(0,0,1),Vector3.ZERO,Color(.9,.95,1,.5),.08)
    wind.position=Vector3(0,0,-3.0);nozzle.add_child(wind)
    parts[&"hoover_segments"]=segs;parts[&"hoover_fan"]=fan;parts[&"hoover_wind"]=wind;parts[&"hoover_trunk"]=trunk
    return root

func animate_hoover(t: float,active: bool,delta: float) -> void:
    if not parts.has(&"hoover_segments"): return
    var segs: Array=parts[&"hoover_segments"]
    # Rest pose: the trunk rises, arches over the side and the nozzle hangs down; when working
    # it stretches out and bulges as the load passes along it.
    for i in segs.size():
        var f: float=float(i)/segs.size()
        var arch: float=lerpf(.34,-.22,f)
        var sway: float=sin(t*(1.1+(3.0 if active else 0.0))-i*.5)*(.05+(.06 if active else 0.0))
        segs[i].rotation=Vector3(arch+sway,sin(t*.7-i*.4)*.06,0)
        var bulge: float=1.0+(sin(t*9.0-i*.9)*.18 if active else 0.0)
        segs[i].scale=Vector3(bulge,bulge,1.0)
    parts[&"hoover_fan"].rotation.z+=delta*(26.0 if active else 1.2)
    parts[&"hoover_wind"].emitting=active

# --- The Glass Sphere ---------------------------------------------------------------------------------------
#
# A bathysphere that winches down under the hull once the boat is afloat: a glass ball with
# brass hoops, a ring of lamps, a wooden floor and a handrail inside. Climb down the porch
# hatch to stand inside and watch the sea (and everything in it) without getting wet. Sea
# creatures cannot bite through it.

func _sphere() -> Node3D:
    var root:=_root("sphere")
    var holder:=Node3D.new();holder.name="Sphere";holder.position=Vector3(SPHERE_CENTER.x,1.0,SPHERE_CENTER.z);root.add_child(holder)
    var t:=Toon.new()
    var R: float=SPHERE_RADIUS
    # Hoops: the equator and three meridians, and a collar with a hatch at the top.
    _ring(t,Vector3.ZERO,Basis(Vector3.RIGHT,PI*.5),R+.02,.05,BRASS,28)
    for k in 3:
        _ring(t,Vector3.ZERO,Basis(Vector3.UP,k*PI/3.0),R+.02,.04,BRASS_DARK,28)
    t.cylinder(Vector3(0,R+.12,0),.5,.62,.3,BRASS,Vector3.ZERO,16)
    t.cylinder(Vector3(0,R+.3,0),.38,.45,.12,BRASS_DARK,Vector3.ZERO,16)
    # Lamps around the equator, an anchor-chain cable up to the hull, and a rudder fin below.
    for k in 6:
        var a: float=TAU*k/6.0
        t.sphere(Vector3(cos(a)*(R+.12),.0,sin(a)*(R+.12)),.16,WARM,Vector3.ONE,2.6,8)
        t.cylinder(Vector3(cos(a)*(R+.04),.0,sin(a)*(R+.04)),.1,.12,.12,IRON,Vector3(0,0,0),8)
    t.rod(Vector3(0,-R-.05,0),Vector3(0,-R-.5,0),.07,IRON,6)
    t.box(Vector3(-.03,-R-.5,-.5),Vector3(.03,-R-.05,.5),IRON)
    for side in [-1.0,1.0]: t.box(Vector3(side*.5-.04,-R-.4,-.03),Vector3(side*.5+.04,-R-.05,.03),IRON)
    # Inside: a plank floor, a rail and a stool.
    t.cylinder(Vector3(0,-.85,0),1.25,1.25,.14,WOOD,Vector3.ZERO,18)
    t.cylinder(Vector3(0,-.78,0),1.05,1.05,.04,WOOD_DARK,Vector3.ZERO,18)
    _ring(t,Vector3(0,-.15,0),Basis(Vector3.RIGHT,PI*.5),1.45,.03,BRASS,24)
    for k in 8:
        var a: float=TAU*k/8.0
        t.rod(Vector3(cos(a)*1.45,-.8,sin(a)*1.45),Vector3(cos(a)*1.45,-.15,sin(a)*1.45),.03,BRASS,5)
    t.cylinder(Vector3(.0,-.5,.4),.2,.2,.5,RED,Vector3.ZERO,10)
    t.commit(holder,"Sphere")
    # The glass: a faint, shiny, see-through ball.
    var glass:=MeshInstance3D.new();glass.name="Glass";var ball:=SphereMesh.new();ball.radius=R;ball.height=R*2.0;ball.radial_segments=36;ball.rings=18
    var material:=StandardMaterial3D.new();material.albedo_color=Color(.72,.92,1.0,.1);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    material.roughness=.02;material.metallic=.1;material.metallic_specular=1.0;material.rim_enabled=true;material.rim=.6;material.rim_tint=.3
    material.cull_mode=BaseMaterial3D.CULL_DISABLED
    ball.material=material;glass.mesh=ball;glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;holder.add_child(glass)
    var lamp:=OmniLight3D.new();lamp.position=Vector3(0,.8,0);lamp.light_color=Color("fff0cf");lamp.light_energy=1.4;lamp.omni_range=7.0;holder.add_child(lamp)
    # The winch cable from the hull's belly bay down to the collar (its length follows the sphere).
    var cable:=MeshInstance3D.new();cable.name="Cable";var cm:=CylinderMesh.new();cm.top_radius=.05;cm.bottom_radius=.05;cm.height=1.0;cm.radial_segments=6
    var cmat:=StandardMaterial3D.new();cmat.albedo_color=IRON;cm.material=cmat;cable.mesh=cm;root.add_child(cable)
    parts[&"sphere"]=holder;parts[&"sphere_cable"]=cable
    var hatch:=LobbyInteractable.new();hatch.interaction_kind="sphere_down";hatch.interaction_range=1.3;hatch.position=SPHERE_PORCH_HATCH;hatch.name="SphereDown"
    var inside:=LobbyInteractable.new();inside.interaction_kind="sphere_up";inside.interaction_range=1.6;inside.position=SPHERE_LANDING+Vector3(0,.4,0);inside.name="SphereUp"
    root.add_child(hatch);root.add_child(inside)
    parts[&"sphere_prompts"]=[hatch,inside]
    # Collision: the floor and an octagon of walls, so a diver stands inside it.
    var c:=SPHERE_CENTER
    _shape(&"sphere",c+Vector3(-1.4,-.95,-1.4),c+Vector3(1.4,-.8,1.4))
    for k in 8:
        var a: float=TAU*k/8.0
        var mid:=c+Vector3(cos(a)*1.72,.1,sin(a)*1.72)
        _shape(&"sphere",mid+Vector3(-.65,-.8,-.08),mid+Vector3(.65,1.2,.08),-a+PI*.5)
    return root

## `d` 0..1: how far the sphere has been lowered. It drops with a bounce and sways a little.
func animate_sphere(d: float,t: float,speed: float) -> void:
    if not parts.has(&"sphere"): return
    var holder: Node3D=parts[&"sphere"]
    var drop: float=_ease_out_back(clampf(d,0.0,1.0))
    holder.visible=d>.01
    var y: float=lerpf(1.0,SPHERE_CENTER.y,drop)
    holder.position=Vector3(SPHERE_CENTER.x,y,SPHERE_CENTER.z)
    holder.scale=Vector3.ONE*lerpf(.3,1.0,clampf(d*1.6,0.0,1.0))
    holder.rotation=Vector3(sin(t*.8)*.025*d,0,cos(t*.6)*.03*d+speed*.002)
    var cable: MeshInstance3D=parts[&"sphere_cable"]
    var top: float=y+SPHERE_RADIUS*holder.scale.x+.3
    var length: float=maxf(.05,.8-top)
    cable.visible=d>.01
    cable.scale=Vector3(1,length,1)
    cable.position=Vector3(SPHERE_CENTER.x,top+length*.5,SPHERE_CENTER.z)

static func _ease_out_back(x: float) -> float:
    var c1: float=1.9;var c3: float=c1+1.0
    var v: float=clampf(x,0.0,1.0)-1.0
    return 1.0+c3*v*v*v+c1*v*v

# --- The Shark-Scaring Gramophone ---------------------------------------------------------------------------
#
# A brass horn five times the size of any sensible one, on a turntable at the rear of the
# terrace. A blast (the horn key) makes every animal within HORN_RADIUS bolt for a few seconds.
# The horn recoils and rings out in expanding rings and a flock of musical notes.

func _horn() -> Node3D:
    var root:=_root("horn");var t:=Toon.new()
    var at:=HORN_AT
    # Cabinet and turntable with a spinning record on its own node.
    t.box(at+Vector3(-.55,0,-.45),at+Vector3(.55,.85,.45),WOOD)
    t.box(at+Vector3(-.6,.85,-.5),at+Vector3(.6,.95,.5),WOOD_DARK)
    for k in 3: t.box(at+Vector3(-.5,.15+k*.22,.45),at+Vector3(.5,.25+k*.22,.47),WOOD_DARK)
    for x in [-.45,.45]:
        for z in [-.35,.35]: t.cylinder(at+Vector3(x,-.08,z),.09,.06,.16,WOOD_DARK,Vector3.ZERO,8)
    t.cylinder(at+Vector3(.35,.4,.47),.07,.07,.05,BRASS,Vector3(PI*.5,0,0),10)
    t.commit(root,"Cabinet")
    var record:=Node3D.new();record.position=at+Vector3(-.1,.97,.05);root.add_child(record)
    var rt:=Toon.new()
    rt.cylinder(Vector3.ZERO,.42,.42,.025,Color("141418"),Vector3.ZERO,24)
    rt.cylinder(Vector3(0,.014,0),.14,.14,.01,RED,Vector3.ZERO,16)
    rt.cylinder(Vector3(0,.02,0),.02,.02,.03,BRASS,Vector3.ZERO,6)
    rt.commit(record,"Record")
    parts[&"horn_record"]=record
    # The tone arm and the horn: a long brass trumpet curling up and out to a huge bell.
    var horn:=Node3D.new();horn.name="Horn";horn.position=at+Vector3(.0,1.0,.1);horn.rotation=Vector3(-.5,-.2,0);root.add_child(horn)
    var ht:=Toon.new()
    ht.rod(Vector3(-.1,-.0,.05),Vector3(-.1,.1,-.0),.05,BRASS,6)
    var prev:=Vector3(0,.15,0)
    var segments: int=16
    for i in segments:
        var f: float=float(i+1)/segments
        # The throat sweeps out along +X and up, widening exponentially into the bell.
        var p:=Vector3(1.0*f*1.8+.1*sin(f*PI)*.0,.15+f*1.1,-f*.9)
        var radius_a: float=.07+pow(float(i)/segments,3.0)*1.5
        var radius_b: float=.07+pow(f,3.0)*1.5
        ht.rod(prev,p,radius_a,BRASS if i%2==0 else BRASS_DARK,12,radius_b)
        prev=p
    ht.cylinder(prev,.12,1.65,.35,BRASS,Vector3(0,0,PI*.5),24)
    ht.cylinder(prev+Vector3(.12,0,0),1.52,1.52,.05,Color("4a2a18"),Vector3(0,0,PI*.5),24)
    ht.commit(horn,"Horn")
    parts[&"horn"]=horn;parts[&"horn_base"]=horn.transform
    var rings:=Node3D.new();rings.name="Rings";root.add_child(rings)
    var ring_nodes: Array[MeshInstance3D]=[]
    var glow:=StandardMaterial3D.new();glow.albedo_color=Color(1,.9,.5,.6);glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.emission_enabled=true;glow.emission=Color("ffd34a");glow.emission_energy_multiplier=2.0
    for k in 3:
        var r:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.92;torus.outer_radius=1.0;torus.rings=32;torus.ring_segments=8
        torus.material=glow;r.mesh=torus;r.visible=false;r.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;rings.add_child(r);ring_nodes.append(r)
    rings.position=at+Vector3(1.9,1.4,-.9)
    rings.rotation=Vector3(PI*.5-.3,0,-.9)
    parts[&"horn_rings"]=ring_nodes
    var notes:=_particles(22,1.6,Vector2(2.0,5.0),40.0,Vector3(.6,1,-.3),Vector3(0,-.4,0),Color("ffd34a"),.12,true)
    notes.position=at+Vector3(1.9,1.4,-.9);notes.one_shot=true;notes.explosiveness=.9;root.add_child(notes)
    parts[&"horn_notes"]=notes
    return root

## `pulse`: seconds since the last blast (negative: none yet).
func animate_horn(t: float,pulse: float,delta: float) -> void:
    if not parts.has(&"horn"): return
    parts[&"horn_record"].rotation.y+=delta*(5.0+(8.0 if pulse>=0.0 and pulse<1.5 else 0.0))
    var horn: Node3D=parts[&"horn"]
    var recoil: float=maxf(0.0,1.0-pulse*3.0) if pulse>=0.0 else 0.0
    horn.transform=parts[&"horn_base"]
    horn.position+=Vector3(0,0,recoil*.12)
    horn.rotation.z=sin(t*60.0)*.02*recoil
    var rings: Array=parts[&"horn_rings"]
    for i in rings.size():
        var age: float=pulse-i*.22
        rings[i].visible=pulse>=0.0 and age>=0.0 and age<1.1
        if rings[i].visible:
            var f: float=age/1.1
            rings[i].scale=Vector3.ONE*lerpf(.4,5.0,f)
            (rings[i].mesh.material as StandardMaterial3D).albedo_color.a=.6*(1.0-f)

func fire_horn() -> void:
    if parts.has(&"horn_notes"):
        parts[&"horn_notes"].restart();parts[&"horn_notes"].emitting=true

# --- The Flying Oak rotor ---------------------------------------------------------------------------------------
#
# A helicopter rotor on a mast above the watchtower. Idle it windmills; with the rotor key held
# it spins up into a blur, and HuntingJeep lifts the whole truck.

func _rotor() -> Node3D:
    var root:=_root("rotor");var t:=Toon.new()
    # Mast from the platform up to the hub, guyed to the corners, with a gearbox and a beacon.
    t.rod(Vector3(0,12.4,-.05),Vector3(0,ROTOR_HUB.y-.3,-.05),.14,IRON,8)
    for k in 4:
        var a: float=TAU*k/4.0+PI*.25
        t.rod(Vector3(cos(a)*.95,12.5,-.05+sin(a)*.95),Vector3(0,ROTOR_HUB.y-1.6,-.05),.025,STEEL,4)
    t.cylinder(Vector3(0,ROTOR_HUB.y-.55,-.05),.32,.36,.5,BRASS,Vector3.ZERO,12)
    t.cylinder(Vector3(0,ROTOR_HUB.y-.2,-.05),.2,.28,.22,IRON,Vector3.ZERO,12)
    t.sphere(Vector3(0,ROTOR_HUB.y+.4,-.05),.14,RED,Vector3.ONE,3.0,8)
    t.commit(root,"Mast")
    # The rotor head: four long blades with red tips and a brass hub, on a spinning node.
    var spin:=Node3D.new();spin.name="Spin";spin.position=ROTOR_HUB+Vector3(0,.05,-.05);root.add_child(spin)
    var rt:=Toon.new()
    rt.cylinder(Vector3.ZERO,.3,.3,.18,BRASS,Vector3.ZERO,14)
    for blade in 4:
        var a: float=blade*TAU/4.0
        var dir:=Vector3(cos(a),0,sin(a))
        rt.box_at(dir*(ROTOR_RADIUS*.5+.3),Vector3(ROTOR_RADIUS-.5,.07,.5),Vector3(0,-a,.05),Color("e9e2cf"))
        rt.box_at(dir*(ROTOR_RADIUS-.55),Vector3(1.1,.075,.52),Vector3(0,-a,.05),RED)
        rt.rod(Vector3.ZERO,dir*1.3,.05,IRON,5)
    rt.commit(spin,"Blades")
    # A translucent disc that fades in as it spins up, to read as a blur.
    var disc:=MeshInstance3D.new();disc.name="Blur";var dm:=CylinderMesh.new();dm.top_radius=ROTOR_RADIUS;dm.bottom_radius=ROTOR_RADIUS;dm.height=.02;dm.radial_segments=40
    var dmat:=StandardMaterial3D.new();dmat.albedo_color=Color(.92,.95,1.0,.0);dmat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;dmat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    dm.material=dmat;disc.mesh=dm;disc.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;spin.add_child(disc)
    parts[&"rotor_spin"]=spin;parts[&"rotor_blur"]=dmat;parts[&"rotor_speed"]=0.0
    return root

## `power` 0..1: how hard the rotor is working.
func animate_rotor(delta: float,power: float) -> void:
    if not parts.has(&"rotor_spin"): return
    var speed: float=lerpf(float(parts[&"rotor_speed"]),.8+power*26.0,1.0-exp(-2.2*delta))
    parts[&"rotor_speed"]=speed
    parts[&"rotor_spin"].rotation.y+=speed*delta
    var blur: StandardMaterial3D=parts[&"rotor_blur"]
    blur.albedo_color.a=clampf((speed-8.0)/40.0,0.0,.28)
