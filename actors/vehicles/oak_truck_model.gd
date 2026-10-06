extends RefCounted
## Builds the Wandering Oak onto a HuntingJeep body: a little green truck cab
## pulling an old fallen oak, hollowed out into three shop windows, with a log
## cottage growing out of its back (storage and the hide workshop), a porch with
## a fold-down ramp, and a lookout terrace above the tiled roof.
## Truck-local frame: forward is -Z, +X is the right-hand side, y=0 is the
## ground under the wheels. Collision shapes are direct children of the body.

const Toon:=preload("res://world/camp/toon_builder.gd")
const CounterScript:=preload("res://world/camp/shop_counter.gd")
const CleanerScript:=preload("res://world/camp/hide_cleaner.gd")

const AXIS_Y: float=2.45
const LOG_R: float=1.62
const LOG_Z0: float=-2.6
const LOG_Z1: float=6.0
const FLOOR_Y: float=3.65
const HOUSE_Z0: float=-2.4
const HOUSE_Z1: float=3.1
const WALL_X: float=1.82
const WALL_TOP: float=6.15
const EAVE_X: float=2.3
const EAVE_Y: float=6.0
const RIDGE_Y: float=7.45
const ROOF_Z0: float=-2.75
const ROOF_Z1: float=3.45
const DECK_Y: float=7.8
const DECK_Z0: float=-1.0
const DECK_Z1: float=3.6
const DECK_X: float=1.6
## The hinge sits a centimetre above the porch boards so walkers roll over the
## seam instead of catching the floor's edge.
const RAMP_PIVOT:=Vector3(0,FLOOR_Y+.01,6.0)
const RAMP_LENGTH: float=6.55
## Shop windows cut into the left flank of the log: kind, centre z, awning colours.
const WINDOWS: Array=[
    {"kind":"weapons","z":-1.3,"slogan":"BASE_SLOGAN_WEAPONS","awning":[Color("6b7a3a"),Color("55622d")]},
    {"kind":"backpacks","z":1.3,"slogan":"BASE_SLOGAN_BACKPACKS","awning":[Color("d9a33a"),Color("b8862a")]},
    {"kind":"sell","z":3.9,"slogan":"BASE_SLOGAN_SELL","awning":[Color("c9463a"),Color("efe3c4")]},
]

const CAB:=Color("3f6b45")
const CAB_DARK:=Color("2f5236")
const CREAM:=Color("efe3c4")
const CHROME:=Color("c9cdd0")
const TYRE:=Color("1d1d21")
const IRON:=Color("3a3a3e")
const BARK:=Color("6b4a2e")
const BARK_DARK:=Color("543823")
const BARK_LIGHT:=Color("7d5836")
const HEART:=Color("c9a36b")
const HEART_LIGHT:=Color("ddb985")
const RING:=Color("8a6236")
const MOSS:=Color("5f8f3a")
const MOSS_DARK:=Color("4a7530")
const LOG_WALL:=Color("b07a45")
const LOG_WALL_DARK:=Color("99663a")
const PLANK:=Color("9a6b40")
const PLANK_DARK:=Color("6f4a2b")
const PLANK_LIGHT:=Color("c08a52")
const TILES:=[Color("b5452f"),Color("c4553a"),Color("a63e2a"),Color("bd4b33")]
const STONES:=[Color("8a8a85"),Color("73736f"),Color("9b978e"),Color("6a6864")]
const DOOR:=Color("3f7a4a")
const BRASS:=Color("d9b24a")
const WARM:=Color("ffcf7a")
const GLASS:=Color("2d4a52")
const LEAF:=Color("4f8a3a")
const FLOWERS:=[Color("e0483e"),Color("f2c94c"),Color("5b8fd9"),Color("f2f0e6"),Color("e07ab0")]

var body: RigidBody3D
var t: Object
var rng:=RandomNumberGenerator.new()
var parts: Dictionary={"turns":[],"spins":[],"extra_spins":[],"puffs":[],"counters":{},"labels":{}}

func build(target: RigidBody3D, wheels: Array, wheel_radius: float) -> Dictionary:
    body=target
    t=Toon.new()
    rng.seed=7741
    _cab()
    _trailer()
    _log()
    _shops()
    _house()
    _roof()
    _terrace()
    _porch()
    _workshop()
    _interactables()
    _collisions()
    _wheels(wheels,wheel_radius)
    _ramp()
    _smoke()
    t.commit(target,"Oak")
    return parts

# --- Cab ----------------------------------------------------------------------

func _cab() -> void:
    t.box(Vector3(-1.12,1.15,-6.75),Vector3(1.12,2.35,-4.5),CAB)
    t.box(Vector3(-.95,2.35,-6.6),Vector3(.95,2.5,-4.5),CAB)
    t.box(Vector3(-1.3,1.15,-4.5),Vector3(1.3,3.45,-2.9),CAB)
    t.box(Vector3(-1.38,3.45,-4.6),Vector3(1.38,3.6,-2.82),CREAM)
    t.box(Vector3(-1.32,1.1,-4.55),Vector3(1.32,1.25,-2.85),CAB_DARK)
    # Windscreen, side windows and the warm dashboard glow behind them.
    t.box(Vector3(-1.15,2.45,-4.54),Vector3(1.15,3.3,-4.5),GLASS,.12)
    for x in [-1.31,1.31]:
        t.box(Vector3(x-.02,2.45,-4.3),Vector3(x+.02,3.3,-3.25),GLASS,.12)
        t.box(Vector3(x-.03,1.3,-4.35),Vector3(x+.03,1.36,-3.1),CAB_DARK)
        t.box(Vector3(x-.03,1.3,-3.12),Vector3(x+.03,2.42,-3.06),CAB_DARK)
        t.box(Vector3(x-.05,1.95,-3.4),Vector3(x+.05,2.0,-3.2),CHROME)
        t.rod(Vector3(x,2.9,-4.45),Vector3(x*1.18,3.0,-4.75),.03,CHROME)
        t.box(Vector3(x*1.18-.08,2.75,-4.82),Vector3(x*1.18+.08,3.1,-4.68),CHROME)
    t.box(Vector3(-1.1,2.1,-4.45),Vector3(1.1,2.35,-4.15),PLANK_DARK)
    t.cylinder(Vector3(-.6,2.5,-4.05),.2,.2,.04,IRON,Vector3(-1.1,0,0),10)
    t.box(Vector3(-1.0,1.25,-3.7),Vector3(-.2,1.75,-3.1),Color("7a3b2a"))
    t.box(Vector3(-1.0,1.75,-3.15),Vector3(-.2,2.5,-3.0),Color("7a3b2a"))
    # Grille, round headlights and a bumper made from a log.
    t.box(Vector3(-.78,1.35,-6.8),Vector3(.78,2.22,-6.74),CHROME)
    for y in [1.5,1.7,1.9,2.1]: t.box(Vector3(-.7,y-.04,-6.83),Vector3(.7,y+.04,-6.79),IRON)
    for x in [-.88,.88]:
        t.cylinder(Vector3(x,2.05,-6.8),.22,.22,.1,CHROME,Vector3(PI*.5,0,0),10)
        t.cylinder(Vector3(x,2.05,-6.86),.17,.17,.04,Color("fff4c2"),Vector3(PI*.5,0,0),10,3.0)
        t.cylinder(Vector3(x*1.18,1.62,-6.78),.07,.07,.05,Color("ffb347"),Vector3(PI*.5,0,0),6,2.0)
    t.cylinder(Vector3(0,1.15,-6.92),.2,.2,2.7,BARK,Vector3(0,0,PI*.5),8)
    # Antlers on the bonnet, mudguards, roof rack with a lantern and firewood.
    for side in [-1.0,1.0]:
        t.rod(Vector3(side*.1,2.5,-6.4),Vector3(side*.35,2.85,-6.55),.035,HEART_LIGHT)
        t.rod(Vector3(side*.35,2.85,-6.55),Vector3(side*.55,3.05,-6.45),.03,HEART_LIGHT)
        t.rod(Vector3(side*.35,2.85,-6.55),Vector3(side*.42,3.12,-6.75),.025,HEART_LIGHT)
        t.box(Vector3(side*1.05,1.82,-6.05),Vector3(side*1.68,1.95,-4.55),CAB_DARK)
        t.box_at(Vector3(side*1.37,1.55,-6.2),Vector3(.62,.12,.5),Vector3(-.9,0,0),CAB_DARK)
    for x in [-1.2,1.2]: t.box(Vector3(x-.04,3.6,-4.4),Vector3(x+.04,3.8,-3.0),IRON)
    t.box(Vector3(-1.2,3.76,-4.4),Vector3(1.2,3.82,-3.0),IRON)
    for k in 5: t.cylinder(Vector3(-.5+k*.2,3.95,-3.7),.09,.09,1.2,BARK,Vector3(PI*.5,0,0),6)
    t.box(Vector3(.5,3.82,-4.1),Vector3(.75,4.12,-3.85),IRON)
    t.box(Vector3(.54,3.86,-4.06),Vector3(.71,4.08,-3.89),WARM,2.2)
    # Chrome stack behind the cab; the smoke puffs are added in _smoke().
    t.cylinder(Vector3(1.18,3.2,-2.98),.1,.1,3.2,CHROME,Vector3.ZERO,8)
    t.cylinder(Vector3(1.18,4.85,-2.98),.13,.12,.12,IRON,Vector3.ZERO,8)
    _label("CabNameL",Vector3(-1.34,2.05,-3.7),-PI*.5,"BASE_NAME",30,CREAM)
    _label("CabNameR",Vector3(1.34,2.05,-3.7),PI*.5,"BASE_NAME",30,CREAM)

# --- Trailer frame -------------------------------------------------------------

func _trailer() -> void:
    for x in [-.85,.85]: t.box(Vector3(x-.12,.7,-3.2),Vector3(x+.12,1.0,6.1),IRON)
    t.box(Vector3(-.6,.95,-3.05),Vector3(.6,1.12,-2.6),IRON)
    for z in [-1.6,1.5,4.6]:
        t.box(Vector3(-1.05,.95,z-.25),Vector3(1.05,1.2,z+.25),PLANK_DARK)
    for side in [-1.0,1.0]:
        # Wooden arches over the tandem wheels, and mud flaps.
        t.box(Vector3(side*1.48,1.72,1.85),Vector3(side*2.08,1.84,5.35),PLANK)
        t.box_at(Vector3(side*1.78,1.62,1.75),Vector3(.6,.12,.35),Vector3(.7,0,0),PLANK)
        t.box_at(Vector3(side*1.78,1.62,5.45),Vector3(.6,.12,.35),Vector3(-.7,0,0),PLANK)
        t.box(Vector3(side*1.5,.35,5.6),Vector3(side*2.05,1.0,5.65),IRON)
        t.box(Vector3(side*1.15,.8,6.08),Vector3(side*1.45,1.0,6.14),Color("e0483e"),2.0)

# --- The log -------------------------------------------------------------------

func _log() -> void:
    var count: int=14
    var step: float=TAU/count
    var width: float=2.0*LOG_R*tan(step*.5)*1.04
    var windows: Array=[]
    for window in WINDOWS: windows.append(Vector2(window.z-1.0,window.z+1.0))
    for k in count:
        if k>=2 and k<=5: continue # the cottage floor is cut into the top of the trunk
        var angle: float=k*step
        var color: Color=[BARK,BARK_DARK,BARK_LIGHT][k%3]
        var spans: Array=[Vector2(LOG_Z0,LOG_Z1)]
        if k==7 or k==8: spans=_split(LOG_Z0,LOG_Z1,windows)
        for span in spans:
            var length: float=span.y-span.x
            if length<.05: continue
            var center:=Vector3(cos(angle)*(LOG_R-.15),AXIS_Y+sin(angle)*(LOG_R-.15),(span.x+span.y)*.5)
            t.box_at(center,Vector3(width,.3,length),Vector3(0,0,angle-PI*.5),color)
            # Bark ridges along each stave.
            t.box_at(center+Vector3(cos(angle),sin(angle),0)*.16,Vector3(width*.25,.05,length*.96),Vector3(0,0,angle-PI*.5),BARK_DARK)
    # Heartwood lining the far side of the hollow, seen through the windows,
    # the floor inside the hollow and plank walls between the three shops.
    for k in 9:
        var angle: float=-1.45+k*.3
        var center:=Vector3(cos(angle)*1.28,AXIS_Y+sin(angle)*1.28,(LOG_Z0+LOG_Z1)*.5)
        if center.y>FLOOR_Y-.05: continue
        t.box_at(center,Vector3(.4,.06,LOG_Z1-LOG_Z0-.1),Vector3(0,0,angle-PI*.5),HEART if k%2==0 else HEART_LIGHT)
    t.box(Vector3(-1.1,1.12,LOG_Z0+.05),Vector3(1.1,1.25,LOG_Z1-.05),PLANK)
    for z in [0.0,2.6]: t.box(Vector3(-1.3,1.25,z-.04),Vector3(1.3,FLOOR_Y-.2,z+.04),PLANK_DARK)
    for z in [LOG_Z0+.06,LOG_Z1-.06]: t.box(Vector3(-1.3,1.25,z-.04),Vector3(1.3,FLOOR_Y-.2,z+.04),HEART)
    # Tree rings on both ends, cut flat where the cottage floor sits.
    var cut: float=FLOOR_Y-AXIS_Y-.02
    for end in [[LOG_Z0,-1.0],[LOG_Z1,1.0]]:
        var z: float=end[0];var facing: float=end[1]
        var layers: Array=[[LOG_R,BARK_DARK],[LOG_R-.17,HEART_LIGHT],[1.1,RING],[1.03,HEART],[.72,RING],[.66,HEART_LIGHT],[.32,RING],[.26,HEART]]
        for i in layers.size():
            t.disc(Vector3(0,AXIS_Y,z+facing*(.004+i*.004)),layers[i][0],cut,layers[i][1],facing,14)
    # Moss, a sprouting branch and mushrooms: it is still a bit alive.
    for spot in [Vector3(-1.38,3.25,-2.0),Vector3(1.4,3.2,.4),Vector3(1.35,3.3,4.9),Vector3(-1.3,3.35,5.3),Vector3(1.5,2.0,-1.9)]:
        t.sphere(spot,.32,MOSS,Vector3(1.0,.35,1.6))
        t.sphere(spot+Vector3(0,.05,.35),.2,MOSS_DARK,Vector3(1.0,.4,1.3))
    t.rod(Vector3(-1.3,3.0,-2.2),Vector3(-2.0,3.9,-2.5),.08,BARK,6,.04)
    t.rod(Vector3(-2.0,3.9,-2.5),Vector3(-2.2,4.4,-2.3),.04,BARK,5,.02)
    for leaf in [Vector3(-2.2,4.45,-2.3),Vector3(-2.05,4.15,-2.6),Vector3(-2.3,4.2,-2.15)]: t.sphere(leaf,.16,LEAF,Vector3(1.2,.7,1.0))
    for spot in [Vector3(1.55,1.75,2.6),Vector3(1.6,1.95,2.85),Vector3(1.52,1.6,-.6),Vector3(-1.5,1.55,5.7),Vector3(1.45,3.0,5.6)]:
        var outward:=Vector3(signf(spot.x),0,0)
        t.cylinder(spot+outward*.06,.035,.045,.16,CREAM,Vector3(0,0,-signf(spot.x)*.5),6)
        t.sphere(spot+outward*.12+Vector3(0,.09,0),.11,Color("d23c3c"),Vector3(1.0,.55,1.0))
        t.sphere(spot+outward*.17+Vector3(0,.13,.04),.025,CREAM)

func _split(z0: float, z1: float, holes: Array) -> Array:
    var spans: Array=[]
    var cursor: float=z0
    for hole in holes:
        if hole.x>cursor: spans.append(Vector2(cursor,hole.x))
        cursor=maxf(cursor,hole.y)
    if cursor<z1: spans.append(Vector2(cursor,z1))
    return spans

# --- Shop windows ----------------------------------------------------------------

func _shops() -> void:
    for window in WINDOWS:
        var z: float=window.z
        # Carved frame, counter shelf and apron board.
        for side in [-1.0,1.0]: t.box(Vector3(-1.7,1.42,z+side*1.02-.07),Vector3(-1.56,2.98,z+side*1.02+.07),PLANK_LIGHT)
        t.box(Vector3(-1.72,2.82,z-1.1),Vector3(-1.52,2.98,z+1.1),PLANK_LIGHT)
        t.box(Vector3(-2.05,1.42,z-1.05),Vector3(-1.45,1.55,z+1.05),PLANK)
        # Painted apron under the counter carries the shop's name and slogan.
        t.box(Vector3(-2.06,.82,z-.95),Vector3(-2.0,1.42,z+.95),PLANK_DARK)
        for k in 3: t.box_at(Vector3(-1.85,1.1,z-.8+k*.8),Vector3(.06,.6,.06),Vector3(0,0,.4),PLANK_DARK)
        # Shingled awning in the shop's colours.
        var colors: Array=window.awning
        for row in 4:
            var s: float=.12+row*.24
            var at:=Vector3(-1.5-s*.93,3.05-s*.36+.03,z)
            t.box_at(at,Vector3(.27,.05,2.3),Vector3(0,0,.37),colors[row%2])
        t.box_at(Vector3(-2.4,2.69,z),Vector3(.05,.1,2.32),Vector3(0,0,.37),PLANK_DARK)
        # Window lantern and warm light inside the hollow.
        t.rod(Vector3(-1.62,2.6,z+1.2),Vector3(-1.95,2.6,z+1.2),.02,IRON,4)
        t.box(Vector3(-2.02,2.3,z+1.13),Vector3(-1.88,2.55,z+1.27),IRON)
        t.box(Vector3(-2.0,2.33,z+1.15),Vector3(-1.9,2.52,z+1.25),WARM,2.4)
        var lamp:=OmniLight3D.new();lamp.position=Vector3(-.45,2.75,z);lamp.light_color=Color("ffcf8a")
        lamp.light_energy=1.2;lamp.omni_range=3.2;body.add_child(lamp)
        var counter=CounterScript.new();counter.name=String(window.kind).capitalize()+"Counter"
        # Windows sit 2.6 m apart: a tight reach keeps each customer at one window.
        counter.interaction_kind=window.kind;counter.interaction_range=2.0;counter.slogan_key=window.slogan
        counter.position=Vector3(-2.0,0,z)
        var point:=Marker3D.new();point.name="InteractionPoint";point.position=Vector3(-.75,0,0);counter.add_child(point)
        var title:=_make_label(40,Color("ffe3a3"));title.name="Title";title.position=Vector3(-.075,1.24,0);title.rotation.y=-PI*.5;counter.add_child(title)
        var slogan:=_make_label(20,Color("f1d6b0"));slogan.name="Slogan";slogan.position=Vector3(-.075,.96,0);slogan.rotation.y=-PI*.5;counter.add_child(slogan)
        body.add_child(counter)
        parts.counters[window.kind]=counter
    # What each window shows inside the hollow.
    t.box(Vector3(.95,1.6,-2.2),Vector3(1.02,2.95,-.4),PLANK_DARK)
    _display("res://actors/equipment/ak_rifle.tscn",Vector3(.85,2.55,-1.3),Vector3(0,PI,0),1.5,"weapon")
    _display("res://actors/equipment/nova_shotgun.tscn",Vector3(.85,2.15,-1.3),Vector3(0,PI,0),1.5,"weapon")
    _display("res://actors/equipment/revolver.tscn",Vector3(.85,1.8,-1.5),Vector3(0,PI,0),1.8,"weapon")
    for k in 3: t.box(Vector3(-1.95+k*.22,1.55,-2.0),Vector3(-1.78+k*.22,1.7,-1.75),Color("6b7a3a"))
    t.box(Vector3(.5,1.6,.45),Vector3(1.05,1.68,2.15),PLANK_DARK)
    _display("res://actors/equipment/backpack_ranger.tscn",Vector3(.8,1.68,.85),Vector3(0,-PI*.5,0),1.0,"backpack")
    _display("res://actors/equipment/backpack_expedition.tscn",Vector3(.8,1.68,1.75),Vector3(0,-PI*.5,0),1.0,"backpack")
    for k in 3:
        var hide_z: float=3.35+k*.55
        t.rod(Vector3(.9,2.95,hide_z),Vector3(.9,2.7,hide_z),.01,IRON,4)
        t.box(Vector3(.86,1.75,hide_z-.24),Vector3(.94,2.7,hide_z+.24),[Color("8a5a33"),Color("c09a62"),Color("6e4a2c")][k])
    t.cylinder(Vector3(-1.75,1.62,4.45),.16,.2,.14,BRASS,Vector3.ZERO,10)
    t.box(Vector3(-1.77,1.69,4.15),Vector3(-1.73,1.98,4.75),BRASS)
    for side in [-1.0,1.0]: t.cylinder(Vector3(-1.75,1.97,4.45+side*.28),.12,.1,.03,BRASS,Vector3.ZERO,8)
    t.cylinder(Vector3(-1.78,1.66,3.35),.1,.1,.22,Color("f2c94c"),Vector3.ZERO,8,1.4)

func _display(path: String, at: Vector3, euler: Vector3, scale_value: float, kind: String) -> void:
    if not ResourceLoader.exists(path): return
    var model: Node3D=load(path).instantiate()
    model.position=at;model.rotation=euler;model.scale=Vector3.ONE*scale_value
    body.add_child(model)
    GameArt.dress_scene(model,kind)
    for mesh in model.find_children("*","MeshInstance3D",true,false): mesh.set_meta("styled",true)

# --- Cottage -------------------------------------------------------------------

func _house() -> void:
    # Floor and rim for the cottage and porch, cut into the top of the trunk.
    t.box(Vector3(-1.95,FLOOR_Y-.2,HOUSE_Z0),Vector3(1.95,FLOOR_Y,LOG_Z1),PLANK)
    for x in range(-18,19,4): t.box(Vector3(x*.1-.012,FLOOR_Y,HOUSE_Z1),Vector3(x*.1+.012,FLOOR_Y+.006,LOG_Z1),PLANK_DARK)
    for side in [-1.0,1.0]: t.box(Vector3(side*1.95-.06,FLOOR_Y-.26,HOUSE_Z0),Vector3(side*1.95+.06,FLOOR_Y-.02,LOG_Z1),PLANK_DARK)
    # Branches growing out of the trunk to hold up the overhanging floor.
    for side in [-1.0,1.0]:
        for z in [-1.9,0.1,2.3,4.6]:
            var root:=Vector3(side*1.42,2.75,z)
            var knee:=Vector3(side*1.72,3.15,z+.12)
            var tip:=Vector3(side*1.9,FLOOR_Y-.22,z+.22)
            t.rod(root,knee,.11,BARK,6,.09)
            t.rod(knee,tip,.09,BARK,6,.07)
            t.sphere(root,.13,BARK_DARK,Vector3(1,1.2,1))
    # Living branches climbing the cottage corners, still in leaf.
    for corner in [Vector3(-1.95,FLOOR_Y,HOUSE_Z0+.05),Vector3(1.95,FLOOR_Y,HOUSE_Z0+.05),Vector3(1.95,FLOOR_Y,HOUSE_Z1-.1)]:
        var out: float=signf(corner.x)
        var mid: Vector3=corner+Vector3(out*.12,1.2,.1)
        var top: Vector3=corner+Vector3(out*.05,2.45,.25)
        t.rod(corner-Vector3(out*.1,.6,0),mid,.07,BARK,6,.055)
        t.rod(mid,top,.055,BARK,5,.03)
        for k in 4: t.sphere(top+Vector3(out*.1*k,-.3*k+.1,.15*sin(k*1.7)),.17,LEAF if k%2==0 else MOSS,Vector3(1.2,.8,1.0))
    # Log-cabin walls: round logs stacked with notched, overhanging corners.
    var rows: int=9
    for row in rows:
        var y: float=FLOOR_Y+.14+row*.27
        var color: Color=LOG_WALL if row%2==0 else LOG_WALL_DARK
        for side in [-1.0,1.0]:
            t.cylinder(Vector3(side*WALL_X,y,(HOUSE_Z0+HOUSE_Z1)*.5),.14,.14,HOUSE_Z1-HOUSE_Z0+.45,color,Vector3(PI*.5,0,0),8)
        var cross_y: float=y+.135 if row<rows-1 else y
        t.cylinder(Vector3(0,cross_y,HOUSE_Z0+.12),.14,.14,2*WALL_X+.45,color.darkened(.04),Vector3(0,0,PI*.5),8)
        if cross_y>5.55:
            t.cylinder(Vector3(0,cross_y,HOUSE_Z1-.1),.14,.14,2*WALL_X+.45,color.darkened(.04),Vector3(0,0,PI*.5),8)
        else:
            for side in [-1.0,1.0]:
                t.cylinder(Vector3(side*1.4,cross_y,HOUSE_Z1-.1),.14,.14,1.65,color.darkened(.04),Vector3(0,0,PI*.5),8)
    for corner in [Vector2(-WALL_X,HOUSE_Z0+.12),Vector2(WALL_X,HOUSE_Z0+.12),Vector2(-WALL_X,HOUSE_Z1-.1),Vector2(WALL_X,HOUSE_Z1-.1)]:
        t.cylinder(Vector3(corner.x,(FLOOR_Y+WALL_TOP)*.5,corner.y),.17,.17,WALL_TOP-FLOOR_Y,PLANK_DARK,Vector3.ZERO,8)
    # Round windows glowing warm, each with a flower box.
    for side in [-1.0,1.0]:
        for z in [-.9,1.6]: _round_window(Vector3(side*(WALL_X+.15),5.0,z),Vector3(side,0,0))
    _round_window(Vector3(0,5.0,HOUSE_Z0-.03),Vector3(0,0,-1),false)
    # Hobbit door: stone arch, round-topped green door swung open against the wall.
    var door_z: float=HOUSE_Z1+.05
    for k in 13:
        var angle: float=PI*float(k)/12.0
        var at:=Vector3(cos(angle)*.66,5.0+sin(angle)*.66,door_z)
        t.box_at(at,Vector3(.24,.18,.2),Vector3(0,0,angle+PI*.5),STONES[k%4])
    for side in [-1.0,1.0]:
        for k in 5: t.box(Vector3(side*.58-.11,FLOOR_Y+k*.27,door_z-.1),Vector3(side*.58+.11,FLOOR_Y+k*.27+.25,door_z+.1),STONES[(k+1)%4])
    t.box(Vector3(.62,FLOOR_Y+.05,door_z+.08),Vector3(1.72,5.0,door_z+.14),DOOR)
    t.cylinder(Vector3(1.17,5.0,door_z+.11),.55,.55,.06,DOOR,Vector3(PI*.5,0,0),14)
    for k in 4: t.box(Vector3(.7+k*.27,FLOOR_Y+.1,door_z+.145),Vector3(.72+k*.27,5.3,door_z+.16),DOOR.darkened(.25))
    t.sphere(Vector3(1.17,4.55,door_z+.2),.06,BRASS)
    t.box(Vector3(-.6,FLOOR_Y,door_z+.15),Vector3(.6,FLOOR_Y+.02,door_z+.85),Color("8f3b3b"))
    _label("HouseSign",Vector3(0,5.95,door_z+.16),0.0,"BASE_HOUSE_SIGN",26,CREAM)
    t.box(Vector3(-.85,5.78,door_z+.08),Vector3(.85,6.12,door_z+.14),PLANK_DARK)

func _round_window(center: Vector3, normal: Vector3, flowers: bool=true) -> void:
    var euler:=Vector3(0,0,PI*.5) if absf(normal.x)>.5 else Vector3(PI*.5,0,0)
    t.cylinder(center,.42,.42,.05,WARM,euler,12,1.5)
    var across:=Vector3(0,0,1) if absf(normal.x)>.5 else Vector3(1,0,0)
    var flowers_right: bool=normal.x>0
    for k in 12:
        var angle: float=TAU*float(k)/12.0
        var radial: Vector3=across*cos(angle)+Vector3.UP*sin(angle)
        t.box_at(center+radial*.47,Vector3(.16,.16,.16),Vector3.ZERO,PLANK_DARK)
    t.box_at(center+normal*.03,(across*.84+Vector3.UP*.05+normal*.04).abs(),Vector3.ZERO,PLANK_DARK)
    t.box_at(center+normal*.03,(across*.05+Vector3.UP*.84+normal*.04).abs(),Vector3.ZERO,PLANK_DARK)
    if not flowers: return
    var box_center: Vector3=center-Vector3(0,.62,0)+normal*.12
    t.box_at(box_center,(across*.95+Vector3.UP*.2+normal*.25).abs(),Vector3.ZERO,PLANK)
    for k in 6:
        var at: Vector3=box_center+across*(-.38+k*.152)+Vector3.UP*(.14+.04*sin(k*2.1))
        t.sphere(at,.075,FLOWERS[(k+(1 if flowers_right else 0))%FLOWERS.size()])
        t.sphere(at+Vector3(0,-.06,0)+normal*.05,.06,LEAF)

# --- Roof ----------------------------------------------------------------------

func _roof() -> void:
    var run: float=EAVE_X
    var rise: float=RIDGE_Y-EAVE_Y
    var slope: float=atan2(rise,run)
    var span: float=sqrt(run*run+rise*rise)
    for side in [-1.0,1.0]:
        var direction:=Vector3(-side*cos(slope),sin(slope),0)
        var normal:=Vector3(side*sin(slope),cos(slope),0)
        var euler:=Vector3(0,0,-side*slope)
        var eave:=Vector3(side*run,EAVE_Y,0)
        t.box_at(eave+direction*span*.5-normal*.05+Vector3(0,0,(ROOF_Z0+ROOF_Z1)*.5),Vector3(span+.05,.08,ROOF_Z1-ROOF_Z0),euler,PLANK_DARK)
        var rows: int=6
        for row in rows:
            var s: float=.22+row*.44
            var tiles: int=12
            for k in tiles:
                var z: float=ROOF_Z0+(k+.5)*(ROOF_Z1-ROOF_Z0)/tiles
                var lift: float=.02*float((k+row)%2)
                var at: Vector3=eave+direction*s+normal*(.02+lift)+Vector3(0,0,z)
                var tilt: float=rng.randf_range(-.035,.035)
                t.box_at(at,Vector3(.5,.07,(ROOF_Z1-ROOF_Z0)/tiles+.01),euler+Vector3(tilt,0,0),TILES[(k*3+row)%TILES.size()])
        # Moss tufts near the eaves.
        for k in 4:
            var z: float=ROOF_Z0+.6+k*1.6+rng.randf_range(-.3,.3)
            t.sphere(eave+direction*rng.randf_range(.3,1.2)+normal*.08+Vector3(0,0,z),.22,MOSS,Vector3(1.4,.35,1.1))
    t.cylinder(Vector3(0,RIDGE_Y+.05,(ROOF_Z0+ROOF_Z1)*.5),.13,.13,ROOF_Z1-ROOF_Z0+.1,TILES[2].darkened(.2),Vector3(PI*.5,0,0),8)
    # Plank gables with a little round attic window at the back.
    for z in [HOUSE_Z0+.08,HOUSE_Z1-.06]:
        t.prism(Vector3(0,(WALL_TOP-.15+RIDGE_Y)*.5,z),Vector3(2*WALL_X+.3,RIDGE_Y-WALL_TOP+.15,.12),Vector3.ZERO,PLANK)
        for x in range(-3,4): t.box(Vector3(x*.5-.015,WALL_TOP,z-.07),Vector3(x*.5+.015,WALL_TOP+(1.0-absf(x)*.3)*.95,z+.07),PLANK_DARK)
    t.cylinder(Vector3(0,6.7,HOUSE_Z1+.02),.22,.22,.05,WARM,Vector3(PI*.5,0,0),10,1.4)
    # Stone chimney on the right slope.
    for layer in 8:
        var y: float=6.0+layer*.33
        var shift: float=.04*float(layer%2)
        t.box(Vector3(.95+shift,y,-2.0+shift),Vector3(1.55+shift,y+.32,-1.4+shift),STONES[layer%4])
    t.box(Vector3(.88,8.64,-2.07),Vector3(1.62,8.74,-1.33),STONES[3])

# --- Lookout terrace ---------------------------------------------------------------

func _terrace() -> void:
    var planks: int=12
    for k in planks:
        var z0: float=DECK_Z0+k*(DECK_Z1-DECK_Z0)/planks
        t.box(Vector3(-DECK_X,DECK_Y-.12,z0+.02),Vector3(DECK_X,DECK_Y,z0+(DECK_Z1-DECK_Z0)/planks-.02),PLANK if k%2==0 else PLANK_LIGHT)
    for side in [-1.0,1.0]:
        t.box(Vector3(side*DECK_X-.08,DECK_Y-.28,DECK_Z0),Vector3(side*DECK_X+.08,DECK_Y-.12,DECK_Z1),PLANK_DARK)
        # Posts: short ones stand on the roof, the back pair runs down to the porch.
        for z in [DECK_Z0+.15,1.3]:
            var roof_y: float=RIDGE_Y-(1.45/EAVE_X)*(RIDGE_Y-EAVE_Y)
            t.cylinder(Vector3(side*1.45,(roof_y+DECK_Y)*.5,z),.09,.09,DECK_Y-roof_y,BARK,Vector3.ZERO,6)
        t.cylinder(Vector3(side*1.45,(FLOOR_Y+DECK_Y)*.5,DECK_Z1-.15),.11,.11,DECK_Y-FLOOR_Y,BARK,Vector3.ZERO,6)
        t.rod(Vector3(side*1.45,FLOOR_Y+2.6,DECK_Z1-.15),Vector3(side*1.45,DECK_Y-.2,DECK_Z1-1.0),.05,BARK)
    # Twig railing all round, with a hatch where the ladder arrives.
    var top: float=DECK_Y+.95
    var corners: Array=[Vector3(-DECK_X,0,DECK_Z0),Vector3(DECK_X,0,DECK_Z0),Vector3(DECK_X,0,DECK_Z1),Vector3(-DECK_X,0,DECK_Z1)]
    for i in 4:
        var a: Vector3=corners[i];var b: Vector3=corners[(i+1)%4]
        var pieces: Array=[[a,b]]
        if i==2: pieces=[[a,Vector3(1.5,0,DECK_Z1)],[Vector3(.85,0,DECK_Z1),b]]
        for piece in pieces:
            var from: Vector3=piece[0];var to: Vector3=piece[1]
            t.rod(from+Vector3(0,top,0),to+Vector3(0,top,0),.045,BARK_LIGHT)
            t.rod(from+Vector3(0,DECK_Y+.5,0),to+Vector3(0,DECK_Y+.5,0),.03,BARK_LIGHT)
            var length: float=from.distance_to(to)
            var posts: int=maxi(1,int(length/.8))
            for k in posts+1:
                var at: Vector3=from.lerp(to,float(k)/posts)
                t.rod(at+Vector3(0,DECK_Y,0),at+Vector3(0,top+.05,0),.04,BARK)
    # Ladder from the porch, round rugs, lanterns, string lights and a pennant.
    for x in [.9,1.45]: t.rod(Vector3(x,FLOOR_Y,DECK_Z1+.05),Vector3(x,DECK_Y+1.0,DECK_Z1+.05),.04,BARK)
    var rung: float=FLOOR_Y+.3
    while rung<DECK_Y+.9:
        t.rod(Vector3(.9,rung,DECK_Z1+.05),Vector3(1.45,rung,DECK_Z1+.05),.03,BARK_LIGHT)
        rung+=.32
    for seat in [Vector3(-.95,DECK_Y,-.2),Vector3(.95,DECK_Y,-.2),Vector3(0,DECK_Y,2.7)]:
        t.cylinder(seat+Vector3(0,.015,0),.42,.42,.03,Color("b9893f"),Vector3.ZERO,10)
        t.cylinder(seat+Vector3(0,.02,0),.3,.3,.03,Color("8f6a2f"),Vector3.ZERO,10)
    for corner in [Vector3(-DECK_X,0,DECK_Z0),Vector3(DECK_X,0,DECK_Z0)]:
        t.rod(corner+Vector3(0,top,0),corner+Vector3(0,top+.45,0),.03,IRON,4)
        t.box(corner+Vector3(-.09,top+.2,-.09),corner+Vector3(.09,top+.42,.09),IRON)
        t.box(corner+Vector3(-.07,top+.22,-.07),corner+Vector3(.07,top+.4,.07),WARM,2.4)
    var bulbs: Array=[Color("ffcf6b"),Color("ff7a7a"),Color("8fe3ff"),Color("b7f58a")]
    for i in 4:
        var a: Vector3=corners[i]+Vector3(0,top+.02,0);var b: Vector3=corners[(i+1)%4]+Vector3(0,top+.02,0)
        for k in 6:
            var f: float=(k+.5)/6.0
            t.sphere(a.lerp(b,f)+Vector3(0,-.18*sin(PI*f),0),.05,bulbs[(i+k)%4],Vector3.ONE,2.2,5)
    t.rod(Vector3(0,DECK_Y,DECK_Z0+.1),Vector3(0,DECK_Y+2.0,DECK_Z0+.1),.035,BARK_LIGHT)
    t.prism(Vector3(0,DECK_Y+1.72,DECK_Z0+.48),Vector3(.5,.7,.03),Vector3(PI*.5,0,PI*.5),Color("2f8a52"))

# --- Porch ---------------------------------------------------------------------

func _porch() -> void:
    for side in [-1.0,1.0]:
        var x: float=side*1.88
        t.rod(Vector3(x,FLOOR_Y+1.0,HOUSE_Z1),Vector3(x,FLOOR_Y+1.0,LOG_Z1),.045,BARK_LIGHT)
        t.rod(Vector3(x,FLOOR_Y+.5,HOUSE_Z1),Vector3(x,FLOOR_Y+.5,LOG_Z1),.03,BARK_LIGHT)
        for k in 5: t.rod(Vector3(x,FLOOR_Y,HOUSE_Z1+k*.72),Vector3(x,FLOOR_Y+1.05,HOUSE_Z1+k*.72),.045,BARK)
        t.rod(Vector3(side*1.88,FLOOR_Y+1.0,LOG_Z1-.05),Vector3(side*.78,FLOOR_Y+1.0,LOG_Z1-.05),.045,BARK_LIGHT)
        t.rod(Vector3(side*1.3,FLOOR_Y,LOG_Z1-.05),Vector3(side*1.3,FLOOR_Y+1.0,LOG_Z1-.05),.04,BARK)
        # Gate posts with the truck's name over the ramp, and porch lanterns.
        t.cylinder(Vector3(side*.85,FLOOR_Y+.9,LOG_Z1-.05),.08,.08,1.8,BARK,Vector3.ZERO,6)
        t.rod(Vector3(side*1.85,FLOOR_Y+1.0,LOG_Z1-.1),Vector3(side*1.85,FLOOR_Y+1.6,LOG_Z1-.1),.03,IRON,4)
        t.box(Vector3(side*1.85-.1,FLOOR_Y+1.6,LOG_Z1-.2),Vector3(side*1.85+.1,FLOOR_Y+1.85,LOG_Z1),IRON)
        t.box(Vector3(side*1.85-.08,FLOOR_Y+1.62,LOG_Z1-.18),Vector3(side*1.85+.08,FLOOR_Y+1.83,LOG_Z1-.02),WARM,2.4)
    t.box(Vector3(-1.0,FLOOR_Y+1.72,LOG_Z1-.11),Vector3(1.0,FLOOR_Y+2.02,LOG_Z1+.01),PLANK_DARK)
    _label("GateName",Vector3(0,FLOOR_Y+1.87,LOG_Z1+.03),0.0,"BASE_NAME",34,Color("ffe3a3"))
    var lamp:=OmniLight3D.new();lamp.position=Vector3(0,FLOOR_Y+2.0,4.6);lamp.light_color=Color("ffc978")
    lamp.light_energy=1.3;lamp.omni_range=6.0;body.add_child(lamp)
    # An empty rocking chair with a folded blanket, for whoever is not driving.
    var chair:=Vector3(-1.2,FLOOR_Y,4.75)
    t.box(chair+Vector3(-.28,.42,-.28),chair+Vector3(.28,.5,.28),PLANK)
    t.box(chair+Vector3(.2,.5,-.28),chair+Vector3(.28,1.2,.28),PLANK)
    for z in [-.24,.24]:
        t.box_at(chair+Vector3(0,.06,z),Vector3(.9,.06,.06),Vector3(0,0,.12),PLANK_DARK)
        t.rod(chair+Vector3(-.22,.08,z),chair+Vector3(-.22,.42,z),.025,PLANK_DARK,4)
        t.rod(chair+Vector3(.22,.08,z),chair+Vector3(.22,.42,z),.025,PLANK_DARK,4)
    t.box(chair+Vector3(-.24,.5,-.22),chair+Vector3(.16,.58,.22),Color("b5452f"))
    t.box(chair+Vector3(-.2,.58,-.2),chair+Vector3(.12,.6,.2),Color("efe3c4"))
    # Barrel, pots and a rope ladder down the right side for quick boarding.
    t.cylinder(Vector3(1.45,FLOOR_Y+.4,5.4),.3,.3,.8,PLANK,Vector3.ZERO,10)
    for y in [.15,.65]: t.cylinder(Vector3(1.45,FLOOR_Y+y,5.4),.31,.31,.05,IRON,Vector3.ZERO,10)
    for k in 2:
        var pot:=Vector3(1.55,FLOOR_Y,4.2+k*.5)
        t.cylinder(pot+Vector3(0,.15,0),.16,.12,.3,Color("b5602f"),Vector3.ZERO,8)
        t.sphere(pot+Vector3(0,.42,0),.2,LEAF,Vector3(1,.8,1))
        t.sphere(pot+Vector3(.05,.55,.04),.07,FLOWERS[k+1])
    for x in [1.95,2.05]: t.rod(Vector3(x+.0,FLOOR_Y,5.0),Vector3(x+.15,.25,5.05),.02,Color("c9b48a"),4)
    var step: float=FLOOR_Y-.3
    while step>.3:
        var f: float=(FLOOR_Y-step)/(FLOOR_Y-.25)
        t.rod(Vector3(1.95+.15*f,step,4.82),Vector3(1.95+.15*f,step,5.22),.03,PLANK_LIGHT,4)
        step-=.35

# --- Workshop and storage inside the cottage ------------------------------------------

func _workshop() -> void:
    var cleaner=CleanerScript.new();cleaner.name="HideCleaner";cleaner.mounted=true
    cleaner.position=Vector3(0,FLOOR_Y,-1.42);cleaner.rotation.y=PI
    body.add_child(cleaner);parts["cleaner"]=cleaner
    # Storage counter along the left wall, shelves of jars behind it.
    t.box(Vector3(-.95,FLOOR_Y,.9),Vector3(-.55,FLOOR_Y+1.05,2.4),PLANK)
    t.box(Vector3(-1.0,FLOOR_Y+1.05,.85),Vector3(-.5,FLOOR_Y+1.12,2.45),PLANK_DARK)
    for z in [.9,2.4]: t.box(Vector3(-1.75,FLOOR_Y,z-.04),Vector3(-.95,FLOOR_Y+1.05,z+.04),PLANK_DARK)
    for level in 3:
        t.box(Vector3(-1.75,FLOOR_Y+1.3+level*.45,.95),Vector3(-1.5,FLOOR_Y+1.35+level*.45,2.35),PLANK_DARK)
        for k in 4:
            var tone: Color=[Color("c79a5b"),Color("8fa65d"),Color("b4583f"),Color("5b7f9d")][(k+level)%4]
            t.box(Vector3(-1.72,FLOOR_Y+1.35+level*.45,1.0+k*.34),Vector3(-1.52,FLOOR_Y+1.6+level*.45,1.27+k*.34),tone)
    var counter=CounterScript.new();counter.name="StorageCounter";counter.interaction_kind="storage"
    counter.interaction_range=2.4;counter.slogan_key="BASE_SLOGAN_STORAGE";counter.position=Vector3(-.3,FLOOR_Y,1.65)
    var point:=Marker3D.new();point.name="InteractionPoint";point.position=Vector3(.45,0,0);counter.add_child(point)
    var title:=_make_label(34,Color("ffe3a3"));title.name="Title";title.position=Vector3(-.23,.72,0);title.rotation.y=PI*.5;counter.add_child(title)
    var slogan:=_make_label(20,Color("f1d6b0"));slogan.name="Slogan";slogan.position=Vector3(-.23,.42,0);slogan.rotation.y=PI*.5;counter.add_child(slogan)
    body.add_child(counter);parts.counters["storage"]=counter
    # Hides drying on the right wall, a tanning frame and a hanging lantern.
    for k in 3:
        var z: float=.6+k*.62
        t.rod(Vector3(1.55,5.55,z),Vector3(1.55,5.25,z),.012,IRON,4)
        t.box(Vector3(1.5,4.15,z-.26),Vector3(1.6,5.25,z+.26),[Color("8a5a33"),Color("c09a62"),Color("6e4a2c")][k])
    t.box(Vector3(1.55,FLOOR_Y,2.2),Vector3(1.65,FLOOR_Y+1.8,2.28),PLANK_DARK)
    for y in [FLOOR_Y+.3,FLOOR_Y+1.7]: t.box(Vector3(1.2,y,2.2),Vector3(1.65,y+.06,2.28),PLANK_DARK)
    t.rod(Vector3(0,RIDGE_Y,.6),Vector3(0,5.85,.6),.012,IRON,4)
    t.box(Vector3(-.12,5.55,.48),Vector3(.12,5.85,.72),IRON)
    t.box(Vector3(-.09,5.58,.51),Vector3(.09,5.82,.69),WARM,2.4)
    t.box(Vector3(-1.2,FLOOR_Y,-.4),Vector3(1.2,FLOOR_Y+.015,2.8),Color("7e3b3b"))
    var lamp:=OmniLight3D.new();lamp.position=Vector3(.2,5.5,.8);lamp.light_color=Color("ffd59a")
    lamp.light_energy=1.3;lamp.omni_range=6.0;body.add_child(lamp)

# --- Interactables ----------------------------------------------------------------

func _interactables() -> void:
    _use("jeep",Vector3(-2.35,0,-3.7),3.2)
    _use("trunk",Vector3(2.6,0,.8),3.2)
    # Ladders: the rope ladder joins the ground and the porch (boarding goes
    # straight up to the terrace), the wooden one joins the porch and the terrace.
    _use("board",Vector3(2.65,0,5.0),3.0)
    _use("alight",Vector3(1.6,FLOOR_Y,5.0),1.0)
    _use("ladder_up",Vector3(1.15,FLOOR_Y,3.95),1.0)
    _use("ladder_down",Vector3(1.18,DECK_Y,3.45),.95)
    # Cargo hatch on the right flank of the trunk.
    t.box(Vector3(1.55,1.65,-.1),Vector3(1.66,2.75,1.7),PLANK_LIGHT)
    for z in [.0,.8,1.6]: t.box(Vector3(1.64,1.7,z-.03),Vector3(1.69,2.7,z+.03),PLANK_DARK)
    for y in [1.85,2.55]: t.box(Vector3(1.66,y-.05,-.15),Vector3(1.71,y+.05,.25),IRON)
    _label("TrunkTag",Vector3(1.72,2.2,.8),PI*.5,"trunk",24,CREAM)

func _use(kind: String, at: Vector3, reach: float) -> void:
    var use:=LobbyInteractable.new();use.interaction_kind=kind;use.interaction_range=reach;use.position=at
    use.name=kind.capitalize()+"Use"+str(body.get_child_count())
    body.add_child(use)

# --- Collision -------------------------------------------------------------------------

func _collisions() -> void:
    _shape(Vector3(-1.15,.7,-6.5),Vector3(1.15,1.15,6.1))
    _shape(Vector3(-1.15,1.15,-6.8),Vector3(1.15,2.45,-4.5))
    _shape(Vector3(-1.3,1.15,-4.5),Vector3(1.3,3.55,-2.9))
    _shape(Vector3(-1.45,1.45,LOG_Z0),Vector3(1.45,FLOOR_Y,LOG_Z1))
    _shape(Vector3(-.95,.85,LOG_Z0),Vector3(.95,1.45,LOG_Z1))
    for window in WINDOWS: _shape(Vector3(-2.06,.82,window.z-1.05),Vector3(-1.45,1.55,window.z+1.05))
    for side in [-1.0,1.0]:
        _shape(Vector3(side*1.5,1.0,1.9),Vector3(side*2.05,1.8,5.3))
        _shape(Vector3(side*1.1,1.0,-6.0),Vector3(side*1.68,1.9,-4.6))
    _shape(Vector3(-1.95,FLOOR_Y-.2,HOUSE_Z0),Vector3(1.95,FLOOR_Y,LOG_Z1))
    _shape(Vector3(-1.95,FLOOR_Y,HOUSE_Z0),Vector3(-1.75,WALL_TOP,HOUSE_Z1))
    _shape(Vector3(1.75,FLOOR_Y,HOUSE_Z0),Vector3(1.95,WALL_TOP,HOUSE_Z1))
    _shape(Vector3(-1.95,FLOOR_Y,HOUSE_Z0),Vector3(1.95,WALL_TOP,HOUSE_Z0+.2))
    _shape(Vector3(-1.95,FLOOR_Y,HOUSE_Z1-.2),Vector3(-.55,WALL_TOP,HOUSE_Z1))
    _shape(Vector3(.55,FLOOR_Y,HOUSE_Z1-.2),Vector3(1.95,WALL_TOP,HOUSE_Z1))
    _shape(Vector3(-.55,5.55,HOUSE_Z1-.2),Vector3(.55,WALL_TOP,HOUSE_Z1))
    _shape(Vector3(-2.2,WALL_TOP,ROOF_Z0),Vector3(2.2,RIDGE_Y,ROOF_Z1))
    _shape(Vector3(-DECK_X,DECK_Y-.15,DECK_Z0),Vector3(DECK_X,DECK_Y,DECK_Z1))
    # Railings are walls taller than a jump, so riders cannot fall or hop off a
    # moving truck. The ladder hatch is closed too: the ladders work with E.
    var rail: float=2.3
    for side in [-1.0,1.0]:
        _shape(Vector3(side*DECK_X-.08,DECK_Y,DECK_Z0-.08),Vector3(side*DECK_X+.08,DECK_Y+rail,DECK_Z1+.08))
        _shape(Vector3(side*1.95-.07,FLOOR_Y,HOUSE_Z1),Vector3(side*1.95+.07,FLOOR_Y+rail,LOG_Z1))
        _shape(Vector3(side*1.95,FLOOR_Y,LOG_Z1-.14),Vector3(side*.75,FLOOR_Y+rail,LOG_Z1))
    for z in [DECK_Z0,DECK_Z1]: _shape(Vector3(-DECK_X,DECK_Y,z-.08),Vector3(DECK_X,DECK_Y+rail,z+.08))
    # The porch gate between the ramp posts, closed whenever the ramp is up.
    var gate:=_shape(Vector3(-.75,FLOOR_Y,LOG_Z1-.14),Vector3(.75,FLOOR_Y+rail,LOG_Z1))
    gate.name="GateShape";parts["gate_shape"]=gate
    _shape(Vector3(-1.3,FLOOR_Y,-2.22),Vector3(1.3,FLOOR_Y+1.9,-.62))
    _shape(Vector3(-.95,FLOOR_Y,.9),Vector3(-.55,FLOOR_Y+1.1,2.4))
    for z in [.9,2.4]: _shape(Vector3(-1.75,FLOOR_Y,z-.04),Vector3(-.95,FLOOR_Y+1.1,z+.04))

func _shape(a: Vector3, b: Vector3) -> CollisionShape3D:
    var low:=Vector3(minf(a.x,b.x),minf(a.y,b.y),minf(a.z,b.z));var high:=Vector3(maxf(a.x,b.x),maxf(a.y,b.y),maxf(a.z,b.z))
    var box:=BoxShape3D.new();box.size=high-low
    var collision:=CollisionShape3D.new();collision.shape=box;collision.position=(low+high)*.5
    body.add_child(collision)
    return collision

# --- Wheels, ramp and smoke ---------------------------------------------------------------

func _wheels(wheels: Array, radius: float) -> void:
    for i in wheels.size():
        var turn:=Node3D.new();turn.name="Suspension"+str(i);body.add_child(turn)
        turn.position=wheels[i]
        var offsets: Array=[0.0] if i<2 else [-.85,.85]
        for k in offsets.size():
            var spin:=Node3D.new();spin.name="Spin"+str(k);spin.position=Vector3(0,0,offsets[k]);turn.add_child(spin)
            var wheel=Toon.new()
            var face: float=signf(wheels[i].x)
            wheel.cylinder(Vector3.ZERO,radius,radius,.52,TYRE,Vector3(0,0,PI*.5),14)
            wheel.cylinder(Vector3(face*.2,0,0),radius*.55,radius*.55,.16,CREAM if i<2 else PLANK_LIGHT,Vector3(0,0,PI*.5),10)
            wheel.cylinder(Vector3(face*.29,0,0),radius*.18,radius*.18,.04,BRASS,Vector3(0,0,PI*.5),8)
            for n in 8:
                var angle: float=n*TAU/8.0
                wheel.box_at(Vector3(0,cos(angle)*radius*.97,sin(angle)*radius*.97),Vector3(.54,.16,.24),Vector3(-angle,0,0),Color("2b2b30"))
            wheel.commit(spin,"Wheel")
            if k==0: parts.spins.append(spin)
            else: parts.extra_spins.append(spin)
        parts.turns.append(turn)

func _ramp() -> void:
    var pivot:=Node3D.new();pivot.name="RampPivot";pivot.position=RAMP_PIVOT;body.add_child(pivot)
    var ramp=Toon.new()
    ramp.box(Vector3(-.72,-.12,0),Vector3(.72,0,RAMP_LENGTH),PLANK)
    var cleat: float=.35
    while cleat<RAMP_LENGTH-.1:
        ramp.box(Vector3(-.66,0,cleat-.04),Vector3(.66,.05,cleat+.04),PLANK_DARK)
        cleat+=.42
    for x in [-.74,.74]: ramp.box(Vector3(x-.05,-.18,0),Vector3(x+.05,.06,RAMP_LENGTH),IRON)
    ramp.commit(pivot,"Ramp")
    parts["ramp"]=pivot
    # Collision for the lowered ramp only; the truck enables it while parked.
    var angle: float=asin(RAMP_PIVOT.y/RAMP_LENGTH)
    var basis:=Basis(Vector3.RIGHT,angle)
    var box:=BoxShape3D.new();box.size=Vector3(1.44,.12,RAMP_LENGTH)
    var collision:=CollisionShape3D.new();collision.name="RampShape";collision.shape=box
    collision.transform=Transform3D(basis,RAMP_PIVOT+basis*Vector3(0,-.06,RAMP_LENGTH*.5))
    collision.disabled=true;body.add_child(collision)
    parts["ramp_shape"]=collision;parts["ramp_down"]=angle

func _smoke() -> void:
    # Puffs turn see-through as a camera comes close, so riders on the terrace
    # never find the chimney smoke filling their view (a soft fade, not dither dots).
    var smoke: StandardMaterial3D=Toon.toon(Color("c9cbc8")).duplicate()
    smoke.distance_fade_mode=BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
    smoke.distance_fade_min_distance=3.0;smoke.distance_fade_max_distance=8.0
    for source in [Vector3(1.18,4.95,-2.98),Vector3(1.25,8.8,-1.7)]:
        for k in 5:
            var puff:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.28;sphere.height=.56;sphere.radial_segments=6;sphere.rings=4
            puff.mesh=sphere;puff.material_override=smoke;puff.set_meta("styled",true)
            puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            puff.set_meta("phase",float(k)/5.0);puff.set_meta("source",source);puff.position=source
            body.add_child(puff);parts.puffs.append(puff)

# --- Labels -----------------------------------------------------------------------

func _make_label(size: int, color: Color) -> Label3D:
    var label:=Label3D.new();label.font_size=size;label.outline_size=10;label.pixel_size=.006
    label.modulate=color;label.outline_modulate=Color("1a120c");label.shaded=false
    return label

func _label(id: String, at: Vector3, yaw: float, key: String, size: int, color: Color) -> void:
    var label:=_make_label(size,color);label.name=id;label.position=at;label.rotation.y=yaw
    body.add_child(label);parts.labels[label]=key
