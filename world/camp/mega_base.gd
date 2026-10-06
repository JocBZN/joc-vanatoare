class_name MegaBase
extends Node3D
## "The Mammoth": the hunters' base, an absurd low-poly monster truck that has
## not moved since 2009. Four axles of giant wheels carry a bazaar deck with the
## arsenal and the backpack shop, a school bus bolted on top as the storage
## floor, and a roof with a hot tub, a windmill and a crow's nest. A scaffold of
## switchback ramps climbs the left end; the loot buyer works a drive-through
## booth at ground level so the jeep can park beside it.
##
## Everything is built procedurally like the hide cleaner. Static geometry is
## merged per colour into a handful of meshes; collisions are plain boxes and
## cylinders on the World layer. Local +Z faces the campfire, +X is the bonnet.

const F1: float=3.4
const F2: float=6.8
const F3: float=10.2
const SLAB: float=.3
const X0: float=-15.0
const X1: float=9.5
const W: float=4.6
const WALL: float=.25
const RAIL: float=1.05
const LANE_A:=Vector2(-17.0,-15.0)
const LANE_B:=Vector2(-19.0,-17.0)

const PAINT:=Color("c4502e")
const PAINT_DARK:=Color("8a3324")
const BUS:=Color("e8b23a")
const BUS_DARK:=Color("b9832a")
const TEAL:=Color("2f7f7a")
const CAB:=Color("3d6fa3")
const CHROME:=Color("c9cdd0")
const TYRE:=Color("1d1d21")
const RUST:=Color("8d5a35")
const PLANK:=Color("9a6b40")
const PLANK_DARK:=Color("6f4a2b")
const STEEL:=Color("8b8f91")
const GLASS:=Color("223845")
const CREAM:=Color("efe3c4")

var _tools: Dictionary={}
var _body: StaticBody3D
var counters: Dictionary={}
var keepers: Dictionary={}
var _clock: float=0.0
var _dish: Node3D
var _windmill: Node3D
var _beacon: Node3D
var _duck: Node3D
var _neon: Label3D
var _puffs: Array[MeshInstance3D]=[]
var _labels: Dictionary={}

func _ready() -> void:
    _body=StaticBody3D.new();_body.name="Collision";add_child(_body)
    _build_chassis()
    _build_floor_one()
    _build_floor_two()
    _build_roof()
    _build_cab()
    _build_scaffold()
    _build_sell_booth()
    _build_fences()
    _flush()
    LocaleSettings.changed.connect(_localize)
    _localize()

# --- Structure -------------------------------------------------------------

func _build_chassis() -> void:
    # Hull from the ground up so nobody crawls under the truck.
    _solid_box(Vector3(X0,0,-3.9),Vector3(15.5,3.1,3.9))
    _visual(Vector3(X0,1.15,-3.6),Vector3(15.5,3.1,3.6),PAINT_DARK)
    _visual(Vector3(X0-.1,.9,-3.4),Vector3(15.6,1.25,3.4),Color("2a2a2e"))
    for z in [-3.62,3.62]:
        _visual(Vector3(X0,2.35,z-.04),Vector3(15.5,2.55,z+.04),CREAM)
    # Rust patches, because it has been parked in a forest for seventeen years.
    for spot in [Vector3(-12,1.8,3.62),Vector3(-4.6,2.4,3.62),Vector3(6.3,1.6,3.62),Vector3(-8,2.0,-3.62)]:
        _visual(spot-Vector3(.7,.35,.03),spot+Vector3(.7,.35,.03),RUST)
    _visual(Vector3(X0,3.1,-W),Vector3(X1,F1,W),PLANK)
    _solid_box(Vector3(X0,3.1,-W),Vector3(X1,F1,W))
    for x in range(-14,10,2): _visual(Vector3(x-.03,F1,-W),Vector3(x+.03,F1+.01,W),PLANK_DARK)
    for x in [-11.5,-6.5,3.0,12.0]:
        for z in [-4.0,4.0]: _wheel(Vector3(x,1.55,z))
        _visual(Vector3(x-1.9,3.08,3.25),Vector3(x+1.9,3.22,4.75),TEAL) # mudguards
        _visual(Vector3(x-1.9,3.08,-4.75),Vector3(x+1.9,3.22,-3.25),TEAL)

func _wheel(at: Vector3) -> void:
    _cylinder(at,1.55,1.55,1.2,TYRE,Vector3(PI*.5,0,0),14)
    var face: float=signf(at.z)
    _cylinder(at+Vector3(0,0,face*.12),.78,.78,1.0,CHROME,Vector3(PI*.5,0,0),10)
    _cylinder(at+Vector3(0,0,face*.56),.3,.3,.16,Color("e8c443"),Vector3(PI*.5,0,0),8)
    for k in 7:
        var angle: float=k*TAU/7.0
        var tread:=at+Vector3(cos(angle)*1.5,sin(angle)*1.5,0)
        _visual_rotated(tread,Vector3(.32,.32,1.26),Vector3(0,0,angle),Color("2b2b30"))
    var shape:=CylinderShape3D.new();shape.radius=1.55;shape.height=1.2
    var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=at;collision.rotation.x=PI*.5
    _body.add_child(collision)

func _build_floor_one() -> void:
    # Back wall, left wall with the scaffold doorway, front railing and pillars.
    _box(Vector3(X0,F1,-W),Vector3(X1,F2-SLAB,-W+WALL),PAINT)
    _box(Vector3(X0-WALL,F1,-2.6),Vector3(X0,F2-SLAB,W),PAINT)
    _rail_x(X0,X1,W-WALL,W,F1)
    for x in [X0,-9.0,-3.0,3.0,X1-.3]:
        _box(Vector3(x,F1,W-.35),Vector3(x+.3,F2-SLAB,W),PAINT_DARK)
    for x in [-13.2,-2.2,7.7]: _poster(Vector3(x,F1+1.9,-W+WALL+.02))
    _counter_booth("weapons","gica",Vector3(-7.0,F1,-3.4),-10.0,-4.0,"BASE_SLOGAN_WEAPONS")
    _counter_booth("backpacks","rucsandra",Vector3(2.5,F1,-3.4),-.5,5.5,"BASE_SLOGAN_BACKPACKS")
    _gun_rack(Vector3(-7.0,F1,-W+WALL))
    _bag_shelf(Vector3(2.5,F1,-W+WALL))
    # A vending machine that has only ever sold dust, plus a lounge corner.
    _box(Vector3(X0+.05,F1,.8),Vector3(X0+1.0,F1+2.1,2.2),Color("b8262f"))
    _visual(Vector3(X0+1.0,F1+.9,1.0),Vector3(X0+1.03,F1+1.9,2.0),Color("9fe3ff"),.4)
    _box(Vector3(6.2,F1,-W+WALL),Vector3(9.2,F1+.55,-3.2),Color("5d3a6e"))
    _visual(Vector3(6.2,F1+.55,-W+WALL),Vector3(9.2,F1+1.25,-3.95),Color("6b4880"))
    _box(Vector3(7.1,F1,1.2),Vector3(8.4,F1+.5,2.4),PLANK_DARK)
    _visual(Vector3(7.3,F1+.5,1.5),Vector3(7.7,F1+.95,1.8),Color("d9d2c4"))
    _light(Vector3(-7.0,F2-.6,-.5),Color("ffcf8a"),1.3,9.0)
    _light(Vector3(2.5,F2-.6,-.5),Color("ffd9a0"),1.2,9.0)
    _bulbs(Vector3(X0,F2-.42,W-.1),Vector3(X1,F2-.42,W-.1),18)
    _sign("Floor1",Vector3(-11.5,F2-SLAB*.5,W+.02),"BASE_FLOOR_1",40,CREAM)

func _build_floor_two() -> void:
    _box(Vector3(X0,F2-SLAB,-W),Vector3(X1,F2,W),BUS_DARK)
    _box(Vector3(X0,F2-SLAB,W),Vector3(-10.0,F2,6.6),PLANK)
    _rail_z(W,6.6,-10.0,F2)
    _rail_x(X0,-10.0,6.6-WALL,6.6,F2)
    # School bus shell: windows on both sides, a door toward the balcony.
    _box(Vector3(X0,F2,-W),Vector3(X1,F3-SLAB,-W+WALL),BUS)
    _box(Vector3(X0-WALL,F2,-W),Vector3(X0,F3-SLAB,W),BUS)
    _box(Vector3(X1-WALL,F2,-W),Vector3(X1,F3-SLAB,W),BUS)
    _box(Vector3(X0,F2,W-WALL),Vector3(X0+.4,F3-SLAB,W),BUS)
    _box(Vector3(-12.2,F2,W-WALL),Vector3(X1,F2+1.0,W),BUS)
    _box(Vector3(X0,F2+2.1,W-WALL),Vector3(X1,F3-SLAB,W),BUS)
    _visual(Vector3(-12.2,F2+.98,W-.02),Vector3(X1,F2+1.08,W+.03),Color("2b2b2b"))
    for x in [-9.0,-5.0,-1.0,3.0,7.0]:
        _box(Vector3(x,F2+1.0,W-WALL),Vector3(x+.35,F2+2.1,W),BUS)
    for x in range(-14,9,3):
        _visual(Vector3(x+.15,F2+1.05,-W-.03),Vector3(x+2.6,F2+2.05,-W+WALL+.02),GLASS)
    _visual(Vector3(X0,F2+.35,-W-.04),Vector3(X1,F2+.5,-W),Color("2b2b2b"))
    _counter_booth("storage","debara",Vector3(-3.0,F2,-3.4),-6.0,.0,"BASE_SLOGAN_STORAGE")
    # Junk: shelves of crates, barrels, an '89 fridge and a washing machine.
    for x in [-13.4,-11.4,2.0,4.0]:
        _box(Vector3(x,F2,-W+WALL),Vector3(x+1.7,F2+2.4,-3.7),PLANK_DARK)
        for level in 3:
            var tone: Color=[Color("c79a5b"),Color("8fa65d"),Color("b4583f"),Color("5b7f9d")][(int(x)+level)%4]
            _visual(Vector3(x+.15,F2+.15+level*.8,-4.25),Vector3(x+1.55,F2+.7+level*.8,-3.75),tone)
    for x in [6.4,7.4]: _barrel(Vector3(x,F2,-3.6))
    _box(Vector3(8.0,F2,1.6),Vector3(9.2,F2+1.9,2.8),Color("eeeae0"))
    _visual(Vector3(8.0,F2+1.25,2.8),Vector3(8.15,F2+1.6,2.86),CHROME)
    _box(Vector3(8.2,F2,-.4),Vector3(9.2,F2+.95,.6),Color("dfe3e6"))
    _cylinder(Vector3(8.18,F2+.5,.1),.32,.32,.04,Color("26343c"),Vector3(0,0,PI*.5),10)
    _light(Vector3(-3.0,F3-.7,0),Color("ffe0a8"),1.1,10.0)
    _bulbs(Vector3(X0+.5,F3-.55,W-.4),Vector3(X1-.5,F3-.55,W-.4),14)
    _sign("Floor2",Vector3(-2.0,F2+.55,W+.03),"BASE_FLOOR_2",40,Color("2b2117"))
    _sign("BusName",Vector3(-2.0,F2+2.55,W+.03),"BASE_NAME",60,Color("b8262f"))

func _build_roof() -> void:
    _box(Vector3(X0,F3-SLAB,-W),Vector3(X1,F3,W),TEAL)
    _visual(Vector3(X0,F3,-W),Vector3(X1,F3+.01,W),Color("3e968f"))
    _rail_x(X0,X1,W-WALL,W,F3)
    _rail_x(X0,X1,-W,-W+WALL,F3)
    _rail_z(-W,W,X1-WALL,F3)
    _rail_z(-2.6,W,X0-WALL,F3)
    # Inflatable hot tub with a rubber duck the size of a calf.
    _cylinder(Vector3(4.5,F3+.4,0),1.6,1.6,.8,Color("e06c9f"),Vector3.ZERO,12,true)
    _cylinder(Vector3(4.5,F3+.68,0),1.38,1.38,.06,Color("57d6d0"),Vector3.ZERO,12,false,.6)
    _duck=Node3D.new();_duck.name="Duck";_duck.position=Vector3(4.1,F3+.95,.4);add_child(_duck)
    _part(_duck,_sphere_mesh(.42,8,6),Vector3.ZERO,Color("f5d33a")).scale=Vector3(1.2,.8,1)
    _part(_duck,_sphere_mesh(.26,8,6),Vector3(.3,.38,0),Color("f5d33a"))
    _part(_duck,_box_mesh(Vector3(.2,.07,.14)),Vector3(.56,.36,0),Color("f08a24"))
    for z in [-.09,.09]: _part(_duck,_box_mesh(Vector3(.03,.05,.05)),Vector3(.5,.45,z),Color("111111"))
    _light(Vector3(4.5,F3+1.4,0),Color("ff8fc8"),.9,6.0)
    # Sun bed and umbrella for the driver, who has not driven since 2009.
    _box(Vector3(-2.45,F3,.9),Vector3(-1.55,F3+.45,3.1),Color("f0f0ea"))
    _cylinder(Vector3(-.8,F3+1.2,1.8),.05,.05,2.4,STEEL,Vector3.ZERO,6,true)
    _cylinder(Vector3(-.8,F3+2.45,1.8),.05,1.6,.5,Color("e85d4a"),Vector3.ZERO,8)
    _keeper("nelu",Vector3(-2.0,F3+.02,3.05),0.0,"lounge")
    # Satellite dish, crow's nest mast with a rotating beacon, and a windmill.
    _cylinder(Vector3(-9,F3+.8,-2.6),.12,.12,1.6,STEEL,Vector3.ZERO,6,true)
    _dish=Node3D.new();_dish.name="Dish";_dish.position=Vector3(-9,F3+1.7,-2.6);add_child(_dish)
    var bowl:=_part(_dish,_cylinder_mesh(1.1,.15,.45,12),Vector3(0,.2,0),Color("e6e6e1"));bowl.rotation.x=-.9
    _part(_dish,_cylinder_mesh(.04,.04,1.1,4),Vector3(0,.55,.35),STEEL).rotation.x=-.9
    _cylinder(Vector3(-12.6,F3+3.5,-1.0),.14,.18,7.0,STEEL,Vector3.ZERO,6,true)
    _cylinder(Vector3(-12.6,F3+6.6,-1.0),.8,.65,.7,PLANK_DARK,Vector3.ZERO,8)
    _beacon=Node3D.new();_beacon.name="Beacon";_beacon.position=Vector3(-12.6,F3+7.3,-1.0);add_child(_beacon)
    _part(_beacon,_cylinder_mesh(.2,.25,.35,8),Vector3.ZERO,Color("ffb347"),2.5)
    var spot:=SpotLight3D.new();spot.light_color=Color("ffc46b");spot.light_energy=2.0;spot.spot_range=28.0;spot.spot_angle=16.0
    spot.rotation.x=-.25;_beacon.add_child(spot)
    var flag:=_part(self,_box_mesh(Vector3(1.4,.8,.04)),Vector3(-11.85,F3+7.6,-1.0),Color("2f8a52"))
    flag.name="Flag"
    _part(self,_box_mesh(Vector3(.5,.35,.05)),Vector3(-11.75,F3+7.62,-.99),Color("f2e9d0"))
    _cylinder(Vector3(8.2,F3+2.0,-3.4),.1,.12,4.0,STEEL,Vector3.ZERO,6,true)
    _windmill=Node3D.new();_windmill.name="Windmill";_windmill.position=Vector3(8.2,F3+4.0,-3.15);add_child(_windmill)
    for k in 4:
        var blade:=_part(_windmill,_box_mesh(Vector3(.28,1.6,.05)),Vector3.ZERO,CREAM if k%2==0 else Color("d9534f"))
        blade.rotation.z=k*PI*.5;blade.position=Vector3(cos(k*PI*.5+PI*.5),sin(k*PI*.5+PI*.5),0)*.8
    # Plastic terrace set and a barrel grill with coals that never go out.
    _box(Vector3(-7.6,F3,1.2),Vector3(-6.4,F3+.75,2.4),Color("f2f2ec"))
    for offset in [Vector3(-8.3,0,1.8),Vector3(-5.7,0,1.8)]:
        _visual(Vector3(offset.x-.3,F3+.42,offset.z-.3),Vector3(offset.x+.3,F3+.48,offset.z+.3),Color("e9e7df"))
        _visual(Vector3(offset.x-.3,F3+.48,offset.z+.24),Vector3(offset.x+.3,F3+1.0,offset.z+.3),Color("e9e7df"))
        _visual(Vector3(offset.x-.25,F3,offset.z-.25),Vector3(offset.x+.25,F3+.42,offset.z+.25),Color("d6d3ca"))
    _cylinder(Vector3(-.5,F3+.9,-3.2),.42,.42,1.2,Color("2b2b2b"),Vector3(0,0,PI*.5),10,true)
    _visual(Vector3(-1.05,F3+1.2,-3.5),Vector3(.05,F3+1.27,-2.9),Color("ff7a2e"),1.8)
    for x in [-.95,-.05]: _visual(Vector3(x-.04,F3,-3.45),Vector3(x+.04,F3+.6,-2.95),STEEL)
    # Flamingo and garden gnome guarding the railing.
    _cylinder(Vector3(-6.0,F3+.45,3.8),.03,.03,.9,Color("f07aa8"),Vector3.ZERO,4)
    _visual(Vector3(-6.25,F3+.9,3.65),Vector3(-5.75,F3+1.2,3.95),Color("f07aa8"))
    _cylinder(Vector3(1.0,F3+.25,3.7),.18,.22,.5,Color("3f6fd1"),Vector3.ZERO,6)
    _cylinder(Vector3(1.0,F3+.7,3.7),.0,.2,.45,Color("d23c3c"),Vector3.ZERO,6)
    _neon=_sign("Neon",Vector3(-2.5,F3+1.92,W+.05),"BASE_NAME",130,Color("ff5f8f"))
    _visual(Vector3(-6.6,F3+1.15,W-.06),Vector3(1.6,F3+2.45,W-.02),Color("1b1b24"))
    for x in [-6.4,1.4]: _visual(Vector3(x-.06,F3,W-.1),Vector3(x+.06,F3+2.45,W-.04),STEEL)
    _sign("Tagline",Vector3(-2.5,F3+1.36,W+.05),"BASE_TAGLINE",40,Color("ffe6a6"))
    _sign("Floor3",Vector3(X0+1.2,F3+1.6,-3.6),"BASE_FLOOR_3",34,CREAM,-PI*.5)

func _build_cab() -> void:
    _box(Vector3(X1,3.1,-3.9),Vector3(15.5,8.6,3.9),CAB)
    _visual(Vector3(X1+.4,8.6,-3.6),Vector3(15.2,8.75,3.6),Color("2c5580"))
    for z in [-3.92,3.92]:
        var face: float=signf(z)
        _visual(Vector3(11.0,6.0,z-.02*face),Vector3(15.1,7.9,z+.02*face),GLASS)
        _visual(Vector3(10.0,3.4,z-.03*face),Vector3(12.6,5.8,z+.03*face),Color("2c5580"))
    _visual(Vector3(15.5,6.0,-3.4),Vector3(15.56,8.1,3.4),GLASS,.15)
    _box(Vector3(15.5,1.2,-3.0),Vector3(17.8,4.8,3.0),CAB)
    for y in [1.6,2.2,2.8,3.4,4.0]: _visual(Vector3(17.8,y,-2.1),Vector3(17.9,y+.32,2.1),CHROME)
    _box(Vector3(17.8,.9,-3.2),Vector3(18.3,1.5,3.2),CHROME)
    for z in [-2.9,2.9]: _box(Vector3(17.85,1.5,z-.12),Vector3(18.2,3.4,z+.12),CHROME)
    _visual(Vector3(17.85,3.25,-3.0),Vector3(18.2,3.45,3.0),CHROME)
    for z in [-2.45,2.45]:
        var lamp:=_part(self,_sphere_mesh(.42,8,6),Vector3(17.85,3.9,z),Color("fff4c2"),3.0);lamp.scale=Vector3(.5,1,1)
    var beam:=SpotLight3D.new();beam.position=Vector3(18.0,3.9,0);beam.rotation.y=-PI*.5;beam.light_color=Color("fff0c2")
    beam.light_energy=1.6;beam.spot_range=22.0;beam.spot_angle=38.0;add_child(beam)
    # Twin air horns and two chrome stacks that still smoke out of habit.
    for z in [-.7,.7]: _cylinder(Vector3(13.6,9.05,z),.08,.32,1.6,CHROME,Vector3(0,0,-PI*.5),8)
    for z in [-4.25,4.25]:
        _cylinder(Vector3(14.6,7.4,z),.26,.26,8.6,CHROME,Vector3.ZERO,8,true)
        _cylinder(Vector3(14.6,11.75,z),.32,.3,.2,Color("3a3a3a"),Vector3.ZERO,8)
        for k in 5:
            var puff:=_part(self,_sphere_mesh(.35,6,4),Vector3(14.6,12,z),Color("b9bcbd"))
            puff.set_meta("phase",float(k)/5.0+(.5 if z>0 else 0.0));puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            _puffs.append(puff)

func _build_scaffold() -> void:
    # Switchback ramps: lane A climbs to the bazaar and the roof, lane B to the bus.
    _ramp(LANE_A,Vector2(6.6,0),Vector2(-2.6,F1))
    _landing(Vector2(-4.6,-2.6),F1)
    _ramp(LANE_B,Vector2(-2.6,F1),Vector2(W,F2))
    _landing(Vector2(W,6.6),F2)
    _ramp(LANE_A,Vector2(W,F2),Vector2(-2.6,F3))
    _landing(Vector2(-4.6,-2.6),F3)
    # Mid rails between the lanes stop short of the landings so the turns stay open.
    _sloped_rail(-17.0,Vector2(5.1,(6.6-5.1)/9.2*F1),Vector2(-1.1,(6.6+1.1)/9.2*F1))
    _sloped_rail(-17.0,Vector2(-1.1,F1+1.5/7.2*(F2-F1)),Vector2(3.1,F1+5.7/7.2*(F2-F1)))
    _sloped_rail(-17.0,Vector2(3.1,F2+1.5/7.2*(F3-F2)),Vector2(-1.1,F2+5.7/7.2*(F3-F2)))
    _box(Vector3(LANE_B.x,F3,-2.6),Vector3(LANE_B.y,F3+RAIL,-2.45),STEEL)
    _box(Vector3(LANE_B.x,F2,6.6-.15),Vector3(LANE_A.y,F2+RAIL,6.6),STEEL)
    # Outer and back faces: one tall collider each, dressed as scaffold poles and braces.
    _solid_box(Vector3(-19.25,0,-4.85),Vector3(-19.0,F3+RAIL,6.6))
    _solid_box(Vector3(-19.25,0,-4.85),Vector3(X0,F3+RAIL,-W))
    for z in [-4.72,-.5,3.0,6.5]:
        _cylinder(Vector3(-19.12,(F3+1.4)*.5,z),.07,.07,F3+1.4,STEEL,Vector3.ZERO,6)
    for x in [-19.12,-17.0,-15.1]: _cylinder(Vector3(x,(F3+1.4)*.5,-4.72),.07,.07,F3+1.4,STEEL,Vector3.ZERO,6)
    for y in [1.0,F1+RAIL,F2+RAIL,F3+RAIL]:
        _visual(Vector3(-19.18,y-.05,-4.8),Vector3(-19.06,y+.05,6.6),STEEL)
        _visual(Vector3(-19.2,y-.05,-4.8),Vector3(X0,y+.05,-4.66),STEEL)
    for level in 3:
        var low: float=level*F1+.4
        _strut(Vector3(-19.12,low,-4.6),Vector3(-19.12,low+F1-.6,6.4))
    _sign("Stairs",Vector3(-16.0,2.55,6.85),"BASE_STAIRS",40,Color("ffd27a"))
    _visual(Vector3(-17.1,1.95,6.62),Vector3(-14.9,3.05,6.68),Color("2b2117"))
    _cylinder(Vector3(-17.0,1.5,6.65),.06,.06,3.0,STEEL,Vector3.ZERO,6)
    _light(Vector3(-17.0,F2+2.0,1.0),Color("ffd9a0"),.8,9.0)

func _build_sell_booth() -> void:
    # Drive-through window between the second and fourth axle.
    _box(Vector3(5.2,0,W),Vector3(5.45,3.0,7.4),PLANK_DARK)
    _box(Vector3(9.95,0,W),Vector3(10.2,3.0,7.4),PLANK_DARK)
    _box(Vector3(5.45,0,6.7),Vector3(9.95,1.15,7.4),PLANK)
    _visual(Vector3(5.35,1.15,6.6),Vector3(10.05,1.25,7.55),PLANK_DARK)
    _visual(Vector3(5.0,3.0,4.4),Vector3(10.4,3.15,7.6),TEAL)
    for k in 6:
        var stripe:=_part(self,_box_mesh(Vector3(.9,.06,1.2)),Vector3(5.45+k*.9,2.75,8.05),Color("d9534f") if k%2==0 else CREAM)
        stripe.rotation.x=.38
    for k in 4: _visual(Vector3(5.7+k*1.05,1.7,W+.02),Vector3(6.4+k*1.05,2.6,W+.08),[Color("8a5a33"),Color("a8743f"),Color("6e4a2c"),Color("c09a62")][k])
    _cylinder(Vector3(6.2,1.35,7.0),.25,.25,.2,CHROME,Vector3.ZERO,10)
    _visual(Vector3(8.8,1.25,6.8),Vector3(9.6,1.6,7.25),Color("3b3b3b"))
    _light(Vector3(7.7,2.6,6.0),Color("ffcf8a"),1.2,6.5)
    _bulbs(Vector3(5.0,3.05,7.65),Vector3(10.4,3.05,7.65),8)
    _counter_node("sell","fane",Vector3(10.2,0,7.4),Vector3(-2.5,0,-1.8),Vector3(-2.5,0,.95),Vector3(-2.5,3.75,.4),"BASE_SLOGAN_SELL")

func _build_fences() -> void:
    # Close the gaps between the camp fence and the truck's two ends.
    for pair in [[Vector3(-19.4,0,8.0),Vector3(-19.15,0,6.55)],[Vector3(19.4,0,8.0),Vector3(18.3,0,3.25)]]:
        var a: Vector3=pair[0];var b: Vector3=pair[1]
        var mid: Vector3=(a+b)*.5;var length: float=a.distance_to(b)
        var yaw: float=atan2(b.x-a.x,b.z-a.z)
        _visual_rotated(mid+Vector3(0,.8,0),Vector3(.12,.12,length),Vector3(0,yaw,0),PLANK_DARK)
        _visual_rotated(mid+Vector3(0,.4,0),Vector3(.12,.12,length),Vector3(0,yaw,0),PLANK_DARK)
        var shape:=BoxShape3D.new();shape.size=Vector3(.2,1.6,length)
        var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=mid+Vector3(0,.8,0);collision.rotation.y=yaw
        _body.add_child(collision)

# --- Booths ------------------------------------------------------------------

## A counter with side boards that pens the keeper in against the back wall.
func _counter_booth(kind: String, npc_id: String, keeper_at: Vector3, x0: float, x1: float, slogan: String) -> void:
    var y: float=keeper_at.y
    _box(Vector3(x0,y,-2.2),Vector3(x1,y+1.1,-1.4),PLANK)
    _visual(Vector3(x0-.1,y+1.1,-2.3),Vector3(x1+.1,y+1.2,-1.3),PLANK_DARK)
    for x in [x0-.1,x1]: _box(Vector3(x,y,-W+WALL),Vector3(x+.1,y+1.1,-1.4),PLANK_DARK)
    var origin:=Vector3((x0+x1)*.5,y,-1.8)
    _counter_node(kind,npc_id,origin,keeper_at-origin,Vector3(0,0,1.55),Vector3(0,.8,.43),slogan)

func _counter_node(kind: String, npc_id: String, origin: Vector3, keeper_offset: Vector3, interaction: Vector3, sign_offset: Vector3, slogan: String) -> void:
    var counter:=ShopCounter.new();counter.name=kind.capitalize()+"Counter"
    counter.interaction_kind=kind;counter.interaction_range=3.0;counter.slogan_key=slogan;counter.position=origin
    var point:=Marker3D.new();point.name="InteractionPoint";point.position=interaction;counter.add_child(point)
    var title:=_label(58,Color("ffe3a3"));title.name="Title";title.position=sign_offset;counter.add_child(title)
    var line:=_label(30,Color("f1d6b0"));line.name="Slogan";line.position=sign_offset-Vector3(0,.42,0);counter.add_child(line)
    var keeper:=Shopkeeper.new();keeper.name="Keeper";keeper.npc_id=npc_id;keeper.position=keeper_offset
    counter.add_child(keeper);counter.keeper=keeper
    add_child(counter)
    counters[kind]=counter;keepers[npc_id]=keeper

func _keeper(npc_id: String, at: Vector3, yaw: float, pose: String) -> void:
    var keeper:=Shopkeeper.new();keeper.name=npc_id.capitalize();keeper.npc_id=npc_id;keeper.pose=pose
    keeper.position=at;keeper.rotation.y=yaw;add_child(keeper);keepers[npc_id]=keeper

func _gun_rack(back: Vector3) -> void:
    _visual(Vector3(back.x-2.6,back.y+1.15,back.z),Vector3(back.x+2.6,back.y+2.2,back.z+.06),Color("3a2a1f"))
    var ids: Array=["sniper_rifle","ak_rifle","nova_shotgun","chain_smg","revolver","beehive"]
    for i in ids.size():
        var path: String="res://actors/equipment/"+String(ids[i])+".tscn"
        if not ResourceLoader.exists(path): continue
        var model: Node3D=load(path).instantiate()
        model.scale=Vector3.ONE*1.7;model.rotation.y=PI*.5 if i%2==0 else -PI*.5
        model.position=Vector3(back.x-1.9+(i%3)*1.9,back.y+1.4+(i/3)*.5,back.z+.25)
        add_child(model)
        GameArt.dress_scene(model,"weapon")
        for mesh in model.find_children("*","MeshInstance3D",true,false): mesh.set_meta("styled",true)

func _bag_shelf(back: Vector3) -> void:
    for level in 2: _visual(Vector3(back.x-2.6,back.y+.92+level*.7,back.z),Vector3(back.x+2.6,back.y+1.0+level*.7,back.z+.5),PLANK_DARK)
    var ids: Array=["backpack_small","backpack_ranger","backpack_expedition","backpack_hoarder"]
    for i in ids.size():
        var path: String="res://actors/equipment/"+String(ids[i])+".tscn"
        if not ResourceLoader.exists(path): continue
        var model: Node3D=load(path).instantiate()
        model.position=Vector3(back.x-1.9+(i%2)*1.6+(i/2)*.9,back.y+1.0+(i/2)*.7,back.z+.28)
        add_child(model)
        GameArt.dress_scene(model,"backpack")
        for mesh in model.find_children("*","MeshInstance3D",true,false): mesh.set_meta("styled",true)

func _poster(at: Vector3) -> void:
    var colors: Array=[Color("e8b23a"),Color("57a3c4"),Color("d9534f"),Color("8fa65d")]
    var tone: Color=colors[int(absf(at.x))%4]
    _visual(at-Vector3(.55,.7,0),at+Vector3(.55,.7,.02),tone)
    _visual(at-Vector3(.35,.15,-.02),at+Vector3(.35,.45,.03),tone.darkened(.35))

func _barrel(at: Vector3) -> void:
    _cylinder(at+Vector3(0,.55,0),.42,.42,1.1,Color("3f6d8f"),Vector3.ZERO,10,true)
    for y in [.25,.85]: _cylinder(at+Vector3(0,y,0),.44,.44,.07,STEEL,Vector3.ZERO,10)

# --- Railings and ramps -------------------------------------------------------

func _rail_x(x0: float, x1: float, z0: float, z1: float, floor_y: float) -> void:
    _solid_box(Vector3(x0,floor_y,z0),Vector3(x1,floor_y+RAIL,z1))
    _visual(Vector3(x0,floor_y+RAIL-.08,z0-.02),Vector3(x1,floor_y+RAIL,z1+.02),STEEL)
    _visual(Vector3(x0,floor_y+.45,z0),Vector3(x1,floor_y+.52,z1),STEEL)
    var x: float=x0
    while x<=x1:
        _visual(Vector3(x,floor_y,z0),Vector3(x+.06,floor_y+RAIL,z1),STEEL)
        x+=1.2

func _rail_z(z0: float, z1: float, x: float, floor_y: float) -> void:
    _solid_box(Vector3(x,floor_y,z0),Vector3(x+WALL,floor_y+RAIL,z1))
    _visual(Vector3(x-.02,floor_y+RAIL-.08,z0),Vector3(x+WALL+.02,floor_y+RAIL,z1),STEEL)
    _visual(Vector3(x,floor_y+.45,z0),Vector3(x+WALL,floor_y+.52,z1),STEEL)

func _landing(span_z: Vector2, top: float) -> void:
    _box(Vector3(LANE_B.x,top-SLAB,span_z.x),Vector3(LANE_A.y,top,span_z.y),PLANK)
    for x in [LANE_B.x+.1,LANE_A.y-.1]: _cylinder(Vector3(x,top*.5,span_z.x+.1),.07,.07,top,STEEL,Vector3.ZERO,6)

## A plank ramp across one lane whose top surface runs from `a` to `b` (z, y).
func _ramp(lane: Vector2, a: Vector2, b: Vector2) -> void:
    var low: Vector2=a if a.y<b.y else b
    var high: Vector2=b if a.y<b.y else a
    var along:=Vector3(0,high.y-low.y,high.x-low.x)
    var length: float=along.length()
    var direction: Vector3=along/length
    # Run a little past the low end so it tucks under the ground or the landing.
    var start:=Vector3(0,low.y,low.x)-direction*.4
    length+=.4
    var normal:=Vector3(0,direction.z,-direction.y)
    if normal.y<0: normal=-normal
    var basis:=Basis(Vector3.RIGHT,normal,Vector3.RIGHT.cross(normal))
    var width: float=lane.y-lane.x
    var center:=Vector3((lane.x+lane.y)*.5,0,0)+start+direction*length*.5-normal*SLAB*.5
    var shape:=BoxShape3D.new();shape.size=Vector3(width,SLAB,length)
    var collision:=CollisionShape3D.new();collision.shape=shape;collision.transform=Transform3D(basis,center)
    _body.add_child(collision)
    var plank:=BoxMesh.new();plank.size=Vector3(width,SLAB,length)
    _append(plank,Transform3D(basis,center),PLANK)
    var steps: int=int(length/.45)
    for k in steps:
        var at: Vector3=Vector3((lane.x+lane.y)*.5,0,0)+start+direction*(.4+k*.45)+normal*.02
        var slat:=BoxMesh.new();slat.size=Vector3(width-.1,.05,.09)
        _append(slat,Transform3D(basis,at),PLANK_DARK)
    for x in [lane.x+.05,lane.y-.05]:
        var stringer:=BoxMesh.new();stringer.size=Vector3(.1,.36,length)
        _append(stringer,Transform3D(basis,Vector3(x,0,0)+start+direction*length*.5-normal*.12),STEEL)

func _sloped_rail(x: float, a: Vector2, b: Vector2) -> void:
    var from:=Vector3(x,a.y+RAIL*.5,a.x);var to:=Vector3(x,b.y+RAIL*.5,b.x)
    var along: Vector3=to-from
    var direction: Vector3=along.normalized()
    var up:=Vector3(0,direction.z,-direction.y)
    if up.y<0: up=-up
    var basis:=Basis(Vector3.RIGHT,up,Vector3.RIGHT.cross(up))
    var center: Vector3=(from+to)*.5
    var shape:=BoxShape3D.new();shape.size=Vector3(.1,RAIL,along.length())
    var collision:=CollisionShape3D.new();collision.shape=shape;collision.transform=Transform3D(basis,center)
    _body.add_child(collision)
    var top:=BoxMesh.new();top.size=Vector3(.12,.08,along.length())
    _append(top,Transform3D(basis,center+up*RAIL*.46),STEEL)
    var mid:=BoxMesh.new();mid.size=Vector3(.08,.06,along.length())
    _append(mid,Transform3D(basis,center),STEEL)

func _strut(a: Vector3, b: Vector3) -> void:
    var along: Vector3=b-a
    var forward: Vector3=along.normalized()
    var side:=Vector3.RIGHT
    var basis:=Basis(side,forward.cross(side).normalized(),forward)
    if basis.determinant()<0: basis=Basis(side,side.cross(forward).normalized(),forward)
    var bar:=BoxMesh.new();bar.size=Vector3(.08,.08,along.length())
    _append(bar,Transform3D(basis.orthonormalized(),(a+b)*.5),STEEL)

# --- Lights, signs and animation ------------------------------------------------

func _light(at: Vector3, color: Color, energy: float, reach: float) -> void:
    var lamp:=OmniLight3D.new();lamp.position=at;lamp.light_color=color;lamp.light_energy=energy;lamp.omni_range=reach
    add_child(lamp)

func _bulbs(from: Vector3, to: Vector3, count: int) -> void:
    var colors: Array=[Color("ffcf6b"),Color("ff7a7a"),Color("8fe3ff"),Color("b7f58a")]
    for k in count:
        var at: Vector3=from.lerp(to,(float(k)+.5)/float(count))
        var bulb:=_sphere_mesh(.08,6,4)
        _append(bulb,Transform3D(Basis.IDENTITY,at+Vector3(0,-.06*sin(PI*fmod(float(k)*.5,1.0)),0)),colors[k%4],2.2)

func _label(size: int, color: Color) -> Label3D:
    var label:=Label3D.new();label.font_size=size;label.outline_size=10;label.pixel_size=.006
    label.modulate=color;label.outline_modulate=Color("1a120c");label.shaded=false
    return label

func _sign(id: String, at: Vector3, key: String, size: int, color: Color, yaw: float=0.0) -> Label3D:
    var label:=_label(size,color);label.name=id;label.position=at;label.rotation.y=yaw
    add_child(label);_labels[label]=key
    return label

func _localize() -> void:
    for label in _labels: label.text=tr(_labels[label])

func _process(delta: float) -> void:
    _clock+=delta
    if is_instance_valid(_dish): _dish.rotation.y=sin(_clock*.25)*1.4
    if is_instance_valid(_windmill): _windmill.rotation.z-=delta*2.2
    if is_instance_valid(_beacon): _beacon.rotation.y+=delta*1.6
    if is_instance_valid(_duck):
        _duck.position.y=F3+.95+sin(_clock*1.8)*.05
        _duck.rotation.y=sin(_clock*.4)*.6
    if is_instance_valid(_neon):
        # A tired neon tube: mostly on, with the odd stutter.
        var stutter: bool=fmod(_clock,7.3)<.18 or fmod(_clock,11.1)<.09
        _neon.modulate=Color("ff5f8f") if not stutter else Color("5a2333")
    for puff in _puffs:
        var phase: float=fmod(_clock*.35+float(puff.get_meta("phase")),1.0)
        puff.position.y=12.0+phase*3.2
        puff.position.x=14.6-phase*1.4
        puff.scale=Vector3.ONE*(.5+phase*1.6)
        puff.visible=phase<.92

# --- Geometry helpers -----------------------------------------------------------

func _box(a: Vector3, b: Vector3, color: Color, glow: float=0.0) -> void:
    _visual(a,b,color,glow)
    _solid_box(a,b)

func _solid_box(a: Vector3, b: Vector3) -> void:
    var low:=Vector3(minf(a.x,b.x),minf(a.y,b.y),minf(a.z,b.z));var high:=Vector3(maxf(a.x,b.x),maxf(a.y,b.y),maxf(a.z,b.z))
    var shape:=BoxShape3D.new();shape.size=high-low
    var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=(low+high)*.5
    _body.add_child(collision)

func _visual(a: Vector3, b: Vector3, color: Color, glow: float=0.0) -> void:
    var low:=Vector3(minf(a.x,b.x),minf(a.y,b.y),minf(a.z,b.z));var high:=Vector3(maxf(a.x,b.x),maxf(a.y,b.y),maxf(a.z,b.z))
    var mesh:=BoxMesh.new();mesh.size=high-low
    _append(mesh,Transform3D(Basis.IDENTITY,(low+high)*.5),color,glow)

func _visual_rotated(center: Vector3, size: Vector3, euler: Vector3, color: Color) -> void:
    var mesh:=BoxMesh.new();mesh.size=size
    _append(mesh,Transform3D(Basis.from_euler(euler),center),color)

func _cylinder(center: Vector3, top: float, bottom: float, height: float, color: Color, euler: Vector3=Vector3.ZERO, segments: int=8, solid: bool=false, glow: float=0.0) -> void:
    _append(_cylinder_mesh(top,bottom,height,segments),Transform3D(Basis.from_euler(euler),center),color,glow)
    if solid:
        var shape:=CylinderShape3D.new();shape.radius=maxf(top,bottom);shape.height=height
        var collision:=CollisionShape3D.new();collision.shape=shape;collision.position=center;collision.rotation=euler
        _body.add_child(collision)

func _append(mesh: Mesh, transform_value: Transform3D, color: Color, glow: float=0.0) -> void:
    var key: String=color.to_html()+"|"+str(glow)
    if not _tools.has(key):
        var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        _tools[key]={"tool":tool,"color":color,"glow":glow}
    _tools[key].tool.append_from(mesh,0,transform_value)

## Commits every colour batch as one mesh; the camp art pass leaves them alone.
func _flush() -> void:
    for key in _tools:
        var entry: Dictionary=_tools[key]
        var node:=MeshInstance3D.new();node.name="Paint"+str(get_child_count())
        node.mesh=entry.tool.commit();node.material_override=Shopkeeper.toon(entry.color,entry.glow)
        node.set_meta("styled",true);add_child(node)
    _tools.clear()

func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, glow: float=0.0) -> MeshInstance3D:
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at
    node.material_override=Shopkeeper.toon(color,glow);node.set_meta("styled",true);parent.add_child(node)
    return node

func _box_mesh(size: Vector3) -> BoxMesh:
    var mesh:=BoxMesh.new();mesh.size=size;return mesh

func _sphere_mesh(radius: float, segments: int, rings: int) -> SphereMesh:
    var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2;mesh.radial_segments=segments;mesh.rings=rings
    return mesh

func _cylinder_mesh(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
    var mesh:=CylinderMesh.new();mesh.top_radius=top;mesh.bottom_radius=bottom;mesh.height=height;mesh.radial_segments=segments
    return mesh
