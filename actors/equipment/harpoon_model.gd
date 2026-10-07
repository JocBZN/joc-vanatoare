extends Node3D
## The Harpoon Gun: a heavy brass-and-iron whaler's launcher with a barbed spear loaded in
## the muzzle, a rope reel with a crank, a wooden stock and a rope coil. Built from toon
## primitives (no external asset) and given the Muzzle / Grip / SupportGrip markers every
## weapon scene carries. Faces -Z.
const Toon:=preload("res://world/camp/toon_builder.gd")
const IRON:=Color("3a3d44")
const STEEL:=Color("9aa3ad")
const BRASS:=Color("d6a93a")
const WOOD:=Color("7d4f2c")
const WOOD_DARK:=Color("55341d")
const ROPE:=Color("d8c08a")
const RED:=Color("c9463a")

func _ready() -> void:
    var t:=Toon.new()
    # Barrel: a fat iron tube with brass bands and a flared muzzle.
    t.cylinder(Vector3(0,.03,-.2),.062,.062,.95,IRON,Vector3(PI*.5,0,0),12)
    for z in [-.55,-.3,-.05]:
        t.cylinder(Vector3(0,.03,z),.072,.072,.05,BRASS,Vector3(PI*.5,0,0),12)
    t.cylinder(Vector3(0,.03,-.7),.1,.065,.11,IRON,Vector3(PI*.5,0,0),12)
    t.cylinder(Vector3(0,.03,-.76),.108,.108,.03,BRASS,Vector3(PI*.5,0,0),12)
    # The spear in the muzzle: shaft, a barbed head and a rope eye.
    t.rod(Vector3(0,.03,-.2),Vector3(0,.03,-1.12),.022,STEEL,8)
    t.cylinder(Vector3(0,.03,-1.22),.0,.05,.2,STEEL,Vector3(-PI*.5,0,0),8)
    for side in [-1.0,1.0]:
        t.box_at(Vector3(side*.05,.03,-1.12),Vector3(.1,.012,.06),Vector3(0,side*.5,0),STEEL)
    t.cylinder(Vector3(0,.03,-.95),.04,.04,.02,RED,Vector3(PI*.5,0,0),8)
    # Breech, a wooden stock and a pistol grip with a guard.
    t.box(Vector3(-.075,-.03,.28),Vector3(.075,.1,.46),IRON)
    t.box(Vector3(-.06,-.05,.42),Vector3(.06,.09,.72),WOOD)
    t.box(Vector3(-.065,-.07,.68),Vector3(.065,.1,.75),WOOD_DARK)
    t.box(Vector3(-.035,-.17,.02),Vector3(.035,-.03,.1),WOOD)
    t.rod(Vector3(0,-.12,-.02),Vector3(0,-.12,.2),.012,IRON,5)
    # Rope reel with a crank on the left, and a coil of rope hung on the right.
    t.cylinder(Vector3(-.11,.0,.22),.09,.09,.08,BRASS,Vector3(0,0,PI*.5),14)
    t.cylinder(Vector3(-.11,.0,.22),.06,.06,.1,ROPE,Vector3(0,0,PI*.5),12)
    t.rod(Vector3(-.16,.0,.22),Vector3(-.2,.06,.27),.012,IRON,5)
    t.sphere(Vector3(-.2,.06,.27),.022,RED,Vector3.ONE,0.0,6)
    for k in 4:
        t.cylinder(Vector3(.1,.0+k*.012,.12),.075,.075,.012,ROPE,Vector3.ZERO,12)
    t.rod(Vector3(-.11,.07,.18),Vector3(0,.03,-.4),.008,ROPE,4)
    # Iron sights: a post on the muzzle and a notch at the breech.
    t.box(Vector3(-.006,.09,-.66),Vector3(.006,.14,-.64),IRON)
    t.box(Vector3(-.03,.09,.2),Vector3(-.015,.14,.22),IRON)
    t.box(Vector3(.015,.09,.2),Vector3(.03,.14,.22),IRON)
    t.commit(self,"Harpoon")
    var muzzle:=Marker3D.new();muzzle.name="Muzzle";muzzle.position=Vector3(0,.03,-.78);add_child(muzzle)
    var grip:=Marker3D.new();grip.name="Grip";grip.position=Vector3(0,-.07,.04);add_child(grip)
    var support:=Marker3D.new();support.name="SupportGrip";support.position=Vector3(0,-.04,-.32);add_child(support)
