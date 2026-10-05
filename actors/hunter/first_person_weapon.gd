extends Node3D
var hunter
var rig
var holder: Node3D
var model: Node3D
var shown: StringName
var sight_height: float=.145
var ads_blend: float=0
var model_scale: float=1
var dot_material: StandardMaterial3D
var sight_index: int=0

func _ready() -> void:
    rig=get_parent().get_parent().get_parent()
    hunter=rig.get_parent()
    holder=Node3D.new();add_child(holder)
    var light:=OmniLight3D.new();light.position=Vector3(0,.25,.15)
    light.light_energy=.55;light.omni_range=1.5;add_child(light)
    hide()

func _process(delta: float) -> void:
    if not hunter.local_player: hide();return
    if not is_instance_valid(hunter.inventory): return
    if shown!=hunter.inventory.equipped_weapon_id: _equip(hunter.inventory.equipped_weapon_id)
    ads_blend=lerpf(ads_blend,1.0 if rig.aiming else 0.0,1-exp(-14*delta))
    visible=rig.is_first_person() and hunter.control_enabled and not rig.scope_visible()
    var hip:=Vector3(.24,-.25,-.56)
    var aim:=Vector3(0,-sight_height,-.5)
    position=hip.lerp(aim,ads_blend)
    var recoil: float=hunter.combat.recoil if is_instance_valid(hunter.combat) else 0
    position.z+=recoil*.12
    rotation=Vector3(-recoil*.4,lerpf(-.10,0,ads_blend),0)
    if hunter.inventory.reload_remaining>0:
        position.y-=.15;rotation.x+=.55

func _equip(id: StringName) -> void:
    shown=id
    sight_index=0
    if is_instance_valid(model): holder.remove_child(model);model.queue_free()
    model=load(EquipmentCatalog.weapon(id).model_path).instantiate();holder.add_child(model)
    GameArt.dress_scene(model,"weapon")
    var marker=model.get_node_or_null("Muzzle")
    var length: float=absf(marker.position.z)+.15 if marker else .6
    model_scale=minf(1,.85/length)
    var top: float=.08
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        var box: AABB=mesh.get_aabb()
        var relative: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
        for x in [0,1]:
            for y in [0,1]:
                for z in [0,1]: top=maxf(top,(relative*(box.position+box.size*Vector3(x,y,z))).y)
    var sight_y: float=top+.045
    dot_material=StandardMaterial3D.new();dot_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    dot_material.albedo_color=Color("eeefc5")
    var metal:=StandardMaterial3D.new();metal.albedo_color=Color("1e2524");metal.roughness=.5
    # Physical rear notch, two rear dots and a front post, aligned to the eye ray.
    for x in [-.035,.035]:
        _box(Vector3(x,sight_y-.014,.105),Vector3(.021,.039,.044),metal)
        _dot(Vector3(x,sight_y,.130),.0055)
    _box(Vector3(0,sight_y-.014,-.245),Vector3(.014,.038,.024),metal)
    _dot(Vector3(0,sight_y,-.232),.0045)
    model.scale=Vector3.ONE*model_scale
    sight_height=sight_y*model_scale
    # Simple local hands follow the same weapon, without a second network actor.
    var skin:=StandardMaterial3D.new();skin.albedo_color=Color("c3a780");skin.roughness=.9
    for x in [-.075,.055]:
        var hand:=MeshInstance3D.new();var shape:=CapsuleMesh.new();shape.radius=.045;shape.height=.2
        hand.mesh=shape;hand.material_override=skin;hand.position=Vector3(x,-.16,.16 if x>0 else .04)
        hand.rotation.x=.5;model.add_child(hand)

func _box(point: Vector3,dimensions: Vector3,material: Material) -> void:
    var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=dimensions
    mesh.mesh=box;mesh.position=point;mesh.material_override=material;model.add_child(mesh)

func _dot(point: Vector3,radius: float) -> void:
    var mesh:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=radius;sphere.height=radius*2
    sphere.radial_segments=10;sphere.rings=5;mesh.mesh=sphere;mesh.material_override=dot_material;mesh.position=point
    sight_index+=1;mesh.name="SightDot"+str(sight_index);model.add_child(mesh)
