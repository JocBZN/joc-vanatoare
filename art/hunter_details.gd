extends RefCounted
## Anatomical joints and equipment details on the existing replicated visual hierarchy.
static func apply(visual: Node3D) -> void:
    var cloth:=GameArt.pbr("fabric_pattern_07",4).duplicate() as StandardMaterial3D
    cloth.albedo_texture=null;cloth.albedo_color=Color("435346")
    var trousers:=cloth.duplicate() as StandardMaterial3D;trousers.albedo_color=Color("343d36")
    var skin:=StandardMaterial3D.new();skin.albedo_color=Color("b58d70");skin.roughness=.85
    var leather:=cloth.duplicate() as StandardMaterial3D;leather.albedo_color=Color("24251e");leather.roughness=.7
    var torso: MeshInstance3D=visual.get_node("Torso")
    var body:=CapsuleMesh.new();body.radius=.27;body.height=.7;body.radial_segments=24;body.rings=12
    torso.mesh=body;torso.position.y=1.16;torso.scale.z=.72;torso.material_override=cloth
    var head: MeshInstance3D=visual.get_node("Head")
    var skull:=SphereMesh.new();skull.radius=.145;skull.height=.34;skull.radial_segments=32;skull.rings=16
    head.mesh=skull;head.position=Vector3(0,1.68,-.025);head.material_override=skin
    var hat: MeshInstance3D=visual.get_node("Hat")
    var crown:=CylinderMesh.new();crown.top_radius=.15;crown.bottom_radius=.16;crown.height=.11;crown.radial_segments=32
    hat.mesh=crown;hat.position=Vector3(0,1.84,-.025);hat.material_override=cloth
    var brim:=CylinderMesh.new();brim.top_radius=.24;brim.bottom_radius=.24;brim.height=.018;brim.radial_segments=32
    _mesh(hat,brim,Vector3(0,-.056,0),cloth)
    for side in [-1,1]:
        var eye:=SphereMesh.new();eye.radius=.012;eye.height=.013
        var dark:=StandardMaterial3D.new();dark.albedo_color=Color("171411");dark.roughness=.2
        _mesh(head,eye,Vector3(side*.05,.034,-.136),dark)
        _capsule(head,.021,.066,Vector3(side*.137,0,0),skin)
        var leg: MeshInstance3D=visual.get_node("LeftLeg" if side<0 else "RightLeg")
        leg.mesh=null;leg.position=Vector3(side*.135,.91,0)
        _capsule(leg,.091,.43,Vector3(0,-.2,0),trousers)
        var knee:=Node3D.new();knee.name="Knee";knee.position.y=-.4;leg.add_child(knee)
        _capsule(knee,.071,.41,Vector3(0,-.19,0),trousers)
        var boot:=_capsule(knee,.092,.28,Vector3(0,-.43,-.065),leather);boot.rotation.x=PI*.5;boot.scale.y=.85
        var arm: MeshInstance3D=visual.get_node("LeftArm" if side<0 else "RightArm")
        arm.mesh=null;arm.position=Vector3(side*.30,1.41,0)
        _capsule(arm,.084,.35,Vector3(side*.025,-.15,0),cloth)
        var elbow:=Node3D.new();elbow.name="Elbow";elbow.position=Vector3(side*.025,-.3,0);arm.add_child(elbow)
        elbow.rotation.x=-.6
        _capsule(elbow,.073,.30,Vector3(0,-.12,0),cloth)
        _capsule(elbow,.062,.15,Vector3(0,-.28,0),leather)
        var pocket:=BoxMesh.new();pocket.size=Vector3(.12,.15,.025)
        _mesh(torso,pocket,Vector3(side*.135,.07,-.22),trousers)
    var nose:=SphereMesh.new();nose.radius=.025;nose.height=.05
    _mesh(head,nose,Vector3(0,.007,-.15),skin)
    var belt:=CylinderMesh.new();belt.top_radius=.255;belt.bottom_radius=.255;belt.height=.07;belt.radial_segments=24
    var band:=_mesh(visual,belt,Vector3(0,.94,0),leather);band.scale.z=.7
    for index in 5:
        var button:=SphereMesh.new();button.radius=.007;button.height=.014
        _mesh(torso,button,Vector3(0,.22-index*.09,-.268),leather)
    visual.get_node("BackpackMount").position=Vector3(0,1.29,.245)

static func _capsule(parent: Node3D,radius: float,height: float,point: Vector3,material: Material) -> MeshInstance3D:
    var mesh:=CapsuleMesh.new();mesh.radius=radius;mesh.height=height;mesh.radial_segments=20;mesh.rings=8
    return _mesh(parent,mesh,point,material)
static func _mesh(parent: Node3D,mesh: Mesh,point: Vector3,material: Material) -> MeshInstance3D:
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=point;node.material_override=material;parent.add_child(node);return node
