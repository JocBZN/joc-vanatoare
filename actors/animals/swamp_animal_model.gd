extends Node3D
## Anatomical meshes and species-specific motion. The parent supplies replicated AI state.
@export var species: String="frog"
var animal: WildlifeAnimal
var body: Node3D
var head: Node3D
var limbs: Array[Node3D]=[]
var chain: Array[Node3D]=[]
var jaw: Node3D
var skin: ShaderMaterial
var eyes: StandardMaterial3D

func _ready() -> void:
    animal=get_parent()
    skin=ShaderMaterial.new();skin.shader=load("res://art/reptile_skin.gdshader")
    skin.set_shader_parameter("tint",Color("62723d") if species=="frog" else Color("58613b") if species=="turtle" else Color("756943") if species=="snake" else Color("435436"))
    skin.set_shader_parameter("wetness",.85 if species=="frog" else .45);skin.set_shader_parameter("scale_size",36 if species.begins_with("croc") else 16)
    skin.set_shader_parameter("amphibian",species=="frog")
    eyes=StandardMaterial3D.new();eyes.albedo_color=Color("0b1009");eyes.roughness=.1
    body=Node3D.new();body.name="Anatomy";add_child(body)
    if species=="frog": _frog()
    elif species=="turtle": _turtle()
    elif species=="snake": _snake()
    else: _crocodile()
    for instance in find_children("*","MeshInstance3D",true,false):
        instance.visibility_range_end=95

func _sphere(parent: Node3D,point: Vector3,size: Vector3,material: Material=null) -> MeshInstance3D:
    var mesh:=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=24;mesh.rings=12
    mesh.material=material if material else skin
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=point;node.scale=size;parent.add_child(node);return node
func _segment(parent: Node3D,a: Vector3,b: Vector3,radius: float,material: Material=null) -> MeshInstance3D:
    var mesh:=CapsuleMesh.new();mesh.radius=radius;mesh.height=maxf(radius*2,a.distance_to(b));mesh.radial_segments=12;mesh.rings=6;mesh.material=material if material else skin
    var node:=MeshInstance3D.new();node.mesh=mesh;node.position=(a+b)*.5;node.quaternion=Quaternion(Vector3.UP,(b-a).normalized());parent.add_child(node);return node
func _eyes(parent: Node3D,point: Vector3,separation: float,radius: float) -> void:
    var iris:=StandardMaterial3D.new();iris.albedo_color=Color("c3a455");iris.roughness=.3
    for side in [-1,1]:
        _sphere(parent,point+Vector3(side*separation,0,0),Vector3.ONE*radius*2,iris)
        _sphere(parent,point+Vector3(side*separation,0,-radius*.85),Vector3(radius*1.15,radius*.55,radius*.35) if species=="frog" else Vector3(radius*.7,radius*1.15,radius*.35),eyes)

func _frog() -> void:
    _sphere(body,Vector3(0,.18,.02),Vector3(.36,.27,.48))
    head=Node3D.new();head.position=Vector3(0,.21,-.18);body.add_child(head)
    _sphere(head,Vector3.ZERO,Vector3(.36,.19,.24));_eyes(head,Vector3(0,.07,-.06),.12,.035)
    for i in 8:
        var x: float=(i-4)*.035
        _segment(head,Vector3(x,-.015,-.11+absf(x)*.24),Vector3(x+.035,-.015,-.11+absf(x+.035)*.24),.003,eyes)
    var belly:=skin.duplicate() as ShaderMaterial;belly.set_shader_parameter("tint",Color("bdc18b"))
    _sphere(body,Vector3(0,.12,-.04),Vector3(.3,.1,.35),belly)
    for side in [-1,1]:
        for rear in [true,false]:
            var limb:=Node3D.new();limb.position=Vector3(side*.14,.13,.14 if rear else -.13);body.add_child(limb);limbs.append(limb)
            var knee:=Vector3(side*(.15 if rear else .08),-.06,.12 if rear else -.05)
            var foot:=Vector3(side*.12,-.12,-.06 if rear else -.14)
            _segment(limb,Vector3.ZERO,knee,.07 if rear else .025);_segment(limb,knee,foot,.034 if rear else .021)
            _sphere(limb,foot,Vector3(.13,.026,.11))
            for toe in 3: _segment(limb,foot,foot+Vector3((toe-1)*.035,-.005,-.08),.009)

func _turtle() -> void:
    var shell:=skin.duplicate() as ShaderMaterial;shell.set_shader_parameter("tint",Color("675336"));shell.set_shader_parameter("scale_size",7.0);shell.set_shader_parameter("wetness",.3)
    _sphere(body,Vector3(0,.28,0),Vector3(.76,.46,.92),shell)
    _sphere(body,Vector3(0,.14,0),Vector3(.78,.10,.92),skin)
    head=Node3D.new();head.position=Vector3(0,.22,-.51);body.add_child(head)
    _sphere(head,Vector3(0,0,-.06),Vector3(.19,.16,.28));_eyes(head,Vector3(0,.045,-.1),.078,.025)
    for side in [-1,1]:
        for z in [-.28,.29]:
            var limb:=Node3D.new();limb.position=Vector3(side*.29,.13,z);body.add_child(limb);limbs.append(limb)
            _sphere(limb,Vector3(side*.14,-.02,-.02),Vector3(.34,.09,.2))
            for toe in 3: _segment(limb,Vector3(side*.22,-.02,(toe-1)*.038),Vector3(side*.3,-.03,(toe-1)*.05-.03),.012,eyes)

func _snake() -> void:
    var parent: Node3D=body
    for i in 13:
        var link:=Node3D.new();link.position=Vector3(0,.10 if i==0 else 0,0 if i==0 else .14);parent.add_child(link);chain.append(link)
        var taper: float=1-smoothstep(7,13,i)*.82
        _sphere(link,Vector3(0,0,.055),Vector3(.12*taper,.1*taper,.22));parent=link
    head=Node3D.new();body.add_child(head);head.position=Vector3(0,.115,-.12)
    _sphere(head,Vector3.ZERO,Vector3(.18,.11,.28));_eyes(head,Vector3(0,.025,-.06),.079,.018)
    jaw=Node3D.new();head.add_child(jaw)
    var tongue:=StandardMaterial3D.new();tongue.albedo_color=Color("902c29")
    _segment(jaw,Vector3(0,-.01,-.11),Vector3(0,-.01,-.26),.005,tongue)

func _crocodile() -> void:
    var asset: Node3D=load("res://assets/animals/swamp/crocodile.glb").instantiate();add_child(asset)
    for instance in asset.find_children("*","MeshInstance3D",true,false): instance.material_override=skin
    # Eye ridges, teeth and the articulated lower jaw make the species readable.
    head=Node3D.new();body.add_child(head);head.position=Vector3(0,.38,-1.16)
    _eyes(head,Vector3(0,.04,0),.15,.037)
    jaw=Node3D.new();jaw.position=Vector3(0,-.12,.1);head.add_child(jaw)
    _sphere(jaw,Vector3(0,0,-.27),Vector3(.36,.06,.55))
    var teeth:=StandardMaterial3D.new();teeth.albedo_color=Color("ddd6a8");teeth.roughness=.6
    for side in [-1,1]:
        for i in 8:
            var cone:=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=.015;cone.height=.065;cone.radial_segments=6;cone.material=teeth
            var tooth:=MeshInstance3D.new();tooth.mesh=cone;tooth.position=Vector3(side*.15,.045,-.08-i*.055);jaw.add_child(tooth)
    if species=="crocodile_ancient": scale=Vector3.ONE*1.5;skin.set_shader_parameter("tint",Color("363d28"))

func _process(delta: float) -> void:
    if not is_instance_valid(animal) or not is_instance_valid(body): return
    var t: float=animal.motion_clock
    if animal.dead:
        body.rotation.z=lerpf(body.rotation.z,1.35,1-exp(-4*delta));return
    var moving: float=clampf(animal.movement_speed/maxf(.1,animal.definition.run_speed),0,1)
    var attacking: bool=animal.state=="Attack"
    body.scale.y=1+sin(t*2.1)*.012
    if species=="frog":
        var hop: float=maxf(0,sin(t*9))*moving
        body.position.y=hop*.16;body.rotation.x=cos(t*9)*moving*.13
        for i in limbs.size(): limbs[i].rotation.x=sin(t*9+(PI if i%2 else 0))*moving*.6
    elif species=="turtle":
        for i in limbs.size(): limbs[i].rotation.y=sin(t*5+i*PI*.8)*moving*.3
        head.position.z=lerpf(head.position.z,-.42 if animal.behavior=="Flee" else -.51,1-exp(-4*delta))
    elif species=="snake":
        for i in chain.size(): chain[i].rotation.y=sin(t*(7 if moving>.2 else 2)-i*.65)*(.12+moving*.25)
        head.position.y=.115+(absf(sin(t*4))*.17 if attacking else 0)
        jaw.visible=sin(t*2.8)>.92 or attacking
    else:
        jaw.rotation.x=lerpf(jaw.rotation.x,-.48 if attacking else -.015,1-exp(-9*delta))
        head.rotation.x=sin(t*2)*.015
