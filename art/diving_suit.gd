extends RefCounted
## The crew's diving costume for the ocean map: a neoprene wetsuit with a coloured
## stripe per diver, hood, mask with a glowing lens, snorkel, twin air tanks on the
## back, long fins, a weight belt, a headlamp for the deep and a trickle of bubbles.
## It is added to the existing replicated Hunter visual and removed again on land,
## so nothing about the hunter's rig or network state changes. Preloaded by path.
const ACCENTS: Array[Color]=[Color("ff7a29"),Color("2fd0e8"),Color("9be04a"),Color("e84fb0")]
const SUIT_NAME:="DivingSuit"

static func is_dressed(visual: Node3D) -> bool:
    return visual.has_node(SUIT_NAME)

static func accent_for(peer_id: int) -> Color:
    return ACCENTS[posmod(peer_id-1,ACCENTS.size())]

static func _material(color: Color,rough: float=.55,glow: float=0.0) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;m.metallic_specular=.6
    if glow>0.0: m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
    return m

static func _mesh(parent: Node3D,mesh: Mesh,point: Vector3,material: Material,euler: Vector3=Vector3.ZERO) -> MeshInstance3D:
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=point;node.rotation=euler;node.material_override=material
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.set_meta("suit_gear",true)
    parent.add_child(node);return node

static func _cylinder(radius: float,height: float,sides: int=12) -> CylinderMesh:
    var m:=CylinderMesh.new();m.top_radius=radius;m.bottom_radius=radius;m.height=height;m.radial_segments=sides;m.rings=1;return m

static func _capsule(radius: float,height: float) -> CapsuleMesh:
    var m:=CapsuleMesh.new();m.radius=radius;m.height=height;m.radial_segments=10;m.rings=4;return m

static func _sphere(radius: float,squash: Vector3=Vector3.ONE) -> SphereMesh:
    var m:=SphereMesh.new();m.radius=radius;m.height=radius*2.0;m.radial_segments=16;m.rings=8;return m

## Puts the suit on: recolours the body, hides the hat and backpack, adds the gear.
static func dress(visual: Node3D,peer_id: int) -> void:
    if is_dressed(visual): return
    var accent: Color=accent_for(peer_id)
    var neoprene:=_material(Color("182533"),.5)
    var skin_cover:=_material(Color("101a26"),.45)
    var accent_mat:=_material(accent,.45,.15)
    var rubber:=_material(Color("0d1117"),.7)
    var steel:=_material(Color("aab6c0"),.3)
    var suit:=Node3D.new();suit.name=SUIT_NAME;visual.add_child(suit)
    # Recolour the rig in place and remember what was there.
    var backup: Array=[]
    for part in ["Torso","LeftLeg","RightLeg","LeftArm","RightArm"]:
        var root: Node=visual.get_node(part)
        for node in [root]+root.find_children("*","MeshInstance3D",true,false):
            if node is MeshInstance3D:
                backup.append([node,node.material_override])
                node.material_override=neoprene
    suit.set_meta("backup",backup)
    var hat: Node3D=visual.get_node("Hat");hat.visible=false
    var pack: Node3D=visual.get_node("BackpackMount");pack.visible=false
    suit.set_meta("hat",hat);suit.set_meta("pack",pack)
    var head: Node3D=visual.get_node("Head")
    # Hood: a cap over the top and back of the head, with the face left open.
    var hood:=SphereMesh.new();hood.radius=.158;hood.height=.316;hood.is_hemisphere=true;hood.radial_segments=18;hood.rings=7
    _mesh(head,hood,Vector3(0,.045,.012),skin_cover)
    _mesh(head,_sphere(.15),Vector3(0,-.03,.045),skin_cover)
    # Mask: rubber frame, glowing lens and a strap round the back of the head.
    var frame:=BoxMesh.new();frame.size=Vector3(.215,.088,.05)
    _mesh(head,frame,Vector3(0,.034,-.138),rubber)
    var lens:=BoxMesh.new();lens.size=Vector3(.175,.058,.012)
    var glass:=_material(Color("7fe9ff"),.1,1.2);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color.a=.62
    _mesh(head,lens,Vector3(0,.034,-.167),glass)
    var strap:=_cylinder(.152,.03,18)
    _mesh(head,strap,Vector3(0,.034,.005),accent_mat)
    # Snorkel along the left cheek, up past the ear, with a bright tip.
    for part in [[Vector3(.1,-.035,-.125),Vector3(.158,.03,-.06)],[Vector3(.158,.03,-.06),Vector3(.172,.17,.015)],[Vector3(.172,.17,.015),Vector3(.172,.33,.03)]]:
        var a: Vector3=part[0];var b: Vector3=part[1]
        var seg:=_mesh(head,_capsule(.016,maxf(.032,a.distance_to(b))),(a+b)*.5,accent_mat)
        seg.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
    _mesh(head,_cylinder(.022,.04,8),Vector3(.172,.345,.03),_material(Color("fff4d0"),.4,.5))
    _mesh(head,_cylinder(.028,.03,8),Vector3(.098,-.04,-.128),rubber,Vector3(PI*.5,0,0))
    # Twin tanks on the back with a valve block and a hose over the shoulder.
    var tank_root:=Node3D.new();tank_root.name="Tanks";tank_root.position=pack.position+Vector3(0,.02,.075);tank_root.set_meta("suit_gear",true);visual.add_child(tank_root)
    for side in [-1.0,1.0]:
        _mesh(tank_root,_cylinder(.088,.58,12),Vector3(side*.105,0,0),steel)
        _mesh(tank_root,_sphere(.088),Vector3(side*.105,.29,0),steel)
        _mesh(tank_root,_sphere(.088),Vector3(side*.105,-.29,0),rubber)
        _mesh(tank_root,_cylinder(.092,.07,12),Vector3(side*.105,.12,0),accent_mat)
    _mesh(tank_root,_cylinder(.035,.2,8),Vector3(0,.4,0),rubber,Vector3(0,0,PI*.5))
    _mesh(tank_root,_capsule(.02,.35),Vector3(.05,.54,-.02),rubber)
    _mesh(tank_root,_cylinder(.02,.5,6),Vector3(.11,.6,-.18),rubber,Vector3(.9,0,.2))
    # Fins on both feet (the knee nodes carry the shin and boot), and stripes.
    for side in [-1.0,1.0]:
        var leg: Node3D=visual.get_node("LeftLeg" if side<0 else "RightLeg")
        var knee: Node3D=leg.get_node("Knee")
        var fin:=BoxMesh.new();fin.size=Vector3(.2,.028,.52)
        _mesh(knee,fin,Vector3(0,-.455,-.36),accent_mat,Vector3(.08,0,0))
        var blade:=BoxMesh.new();blade.size=Vector3(.26,.022,.2)
        _mesh(knee,blade,Vector3(0,-.46,-.62),accent_mat,Vector3(.12,0,0))
        _mesh(leg,_cylinder(.098,.06,12),Vector3(0,-.12,0),accent_mat)
        var arm: Node3D=visual.get_node("LeftArm" if side<0 else "RightArm")
        _mesh(arm,_cylinder(.088,.05,12),Vector3(side*.025,-.12,0),accent_mat)
    var torso: Node3D=visual.get_node("Torso")
    var chest:=BoxMesh.new();chest.size=Vector3(.46,.07,.02)
    _mesh(torso,chest,Vector3(0,.09,-.205),accent_mat)
    var belt:=_cylinder(.262,.07,16)
    var belt_node:=_mesh(visual,belt,Vector3(0,.97,0),_material(Color("f2c94c"),.5,.1))
    belt_node.scale.z=.74
    # A headlamp for the dark, only lit when the diver is deep.
    var lamp:=SpotLight3D.new();lamp.name="Headlamp";lamp.position=Vector3(0,.1,-.16);lamp.light_color=Color("e2f7ff")
    lamp.light_energy=3.0;lamp.spot_range=30.0;lamp.spot_angle=36.0;lamp.spot_attenuation=.7;lamp.shadow_enabled=false;lamp.visible=false
    lamp.set_meta("suit_gear",true);head.add_child(lamp);suit.set_meta("lamp",lamp)
    _mesh(head,_cylinder(.028,.03,8),Vector3(0,.13,-.158),_material(Color("ffffff"),.2,2.0),Vector3(PI*.5,0,0))
    # Bubbles from the regulator.
    var bubbles:=CPUParticles3D.new();bubbles.name="Bubbles";bubbles.position=Vector3(.1,-.04,-.14);bubbles.amount=10;bubbles.lifetime=2.4
    bubbles.direction=Vector3(0,1,0);bubbles.spread=14.0;bubbles.initial_velocity_min=.6;bubbles.initial_velocity_max=1.1;bubbles.gravity=Vector3(0,.9,0)
    bubbles.scale_amount_min=.5;bubbles.scale_amount_max=1.3;bubbles.emitting=false;bubbles.local_coords=false
    var drop:=SphereMesh.new();drop.radius=.03;drop.height=.06;drop.radial_segments=6;drop.rings=3
    var foam:=StandardMaterial3D.new();foam.albedo_color=Color(.9,.97,1.0,.55);foam.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;foam.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    drop.material=foam;bubbles.mesh=drop;bubbles.set_meta("suit_gear",true);head.add_child(bubbles);suit.set_meta("bubbles",bubbles)

## Takes the suit off again and restores the rig exactly as it was.
static func undress(visual: Node3D) -> void:
    if not is_dressed(visual): return
    var suit: Node3D=visual.get_node(SUIT_NAME)
    for entry in suit.get_meta("backup"):
        if is_instance_valid(entry[0]): entry[0].material_override=entry[1]
    if is_instance_valid(suit.get_meta("hat")): suit.get_meta("hat").visible=true
    if is_instance_valid(suit.get_meta("pack")): suit.get_meta("pack").visible=true
    # Everything the suit hung on the rig carries the "suit_gear" tag, wherever it sits.
    for node in visual.find_children("*","",true,false):
        if node.has_meta("suit_gear"): node.queue_free()
    visual.remove_child(suit)
    suit.queue_free()

## Per frame: lamp when deep, bubbles when submerged. `depth` is how far below the surface.
static func update(visual: Node3D,depth: float) -> void:
    if not is_dressed(visual): return
    var suit: Node3D=visual.get_node(SUIT_NAME)
    var lamp: SpotLight3D=suit.get_meta("lamp")
    var bubbles: CPUParticles3D=suit.get_meta("bubbles")
    if is_instance_valid(lamp): lamp.visible=depth>6.0
    if is_instance_valid(bubbles): bubbles.emitting=depth>1.3
