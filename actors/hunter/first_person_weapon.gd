extends Node3D
var hunter
var rig
var holder: Node3D
var model: Node3D
var shown: StringName
var sight_height: float=.145
var ads_blend: float=0
var model_scale: float=1
var hip_distance: float=.56
var ads_pitch: float=0
var dot_material: StandardMaterial3D
var sight_index: int=0
var equip_blend: float=0
var reload_player: AnimationPlayer
var reload_clip: String=""
var _reload_was_active: bool=false

func _ready() -> void:
    rig=get_parent().get_parent().get_parent()
    hunter=rig.get_parent()
    holder=Node3D.new();add_child(holder)
    var light:=OmniLight3D.new();light.position=Vector3(0,.25,.15)
    light.light_energy=.14;light.omni_range=1.5;add_child(light)
    hide()

func _process(delta: float) -> void:
    if not hunter.local_player: hide();return
    if not rig.enabled or hunter.busy(): hide();return
    if not is_instance_valid(hunter.inventory): return
    if shown!=hunter.inventory.equipped_weapon_id: _equip(hunter.inventory.equipped_weapon_id)
    ads_blend=lerpf(ads_blend,1.0 if rig.aiming else 0.0,1-exp(-14*delta))
    visible=rig.is_first_person() and hunter.control_enabled and not rig.scope_visible()
    var hip:=Vector3(.24,-.25,-hip_distance)
    var aim:=Vector3(0,-sight_height,-maxf(.72,hip_distance+.16))
    position=hip.lerp(aim,ads_blend)
    var recoil: float=hunter.combat.recoil if is_instance_valid(hunter.combat) else 0
    position.z+=recoil*.12
    rotation=Vector3(-recoil*.4+ads_pitch*ads_blend,lerpf(-.10,0,ads_blend),0)
    var ground_speed: float=Vector2(hunter.velocity.x,hunter.velocity.z).length()
    var sway: float=clampf(ground_speed/5.5,0,1)*(1.0-ads_blend*.65)
    position.x+=cos(hunter._stride_time*.5)*sway*.018
    position.y+=absf(sin(hunter._stride_time))*sway*.015
    equip_blend=move_toward(equip_blend,0.0,delta*6.5)
    scale=Vector3.ONE*lerpf(1.0,.7,equip_blend)
    position.y-=equip_blend*.22
    rotation.x-=equip_blend*.4
    var reloading: bool=hunter.inventory.reload_remaining>0
    if reloading and reload_player and not reload_clip.is_empty():
        if not _reload_was_active:
            var weapon_seconds: float=EquipmentCatalog.weapon(hunter.inventory.equipped_weapon_id).reload_seconds
            var clip_length: float=reload_player.get_animation(reload_clip).length
            reload_player.speed_scale=clip_length/maxf(weapon_seconds,.05)
            reload_player.play(reload_clip)
    elif reloading:
        # Procedural fallback for weapons without a baked reload clip: a quick dip-and-rise arc, not a flat offset.
        var weapon_seconds: float=EquipmentCatalog.weapon(hunter.inventory.equipped_weapon_id).reload_seconds
        var fraction: float=1.0-clampf(hunter.inventory.reload_remaining/maxf(weapon_seconds,.05),0,1)
        var arc: float=sin(fraction*PI)
        position.y-=arc*.16
        position.z+=arc*.05
        rotation.x+=arc*.5
        rotation.z+=sin(fraction*TAU)*.12*(1.0-arc)
    _reload_was_active=reloading

func _equip(id: StringName) -> void:
    shown=id
    sight_index=0
    equip_blend=1.0
    _reload_was_active=false
    if is_instance_valid(model): holder.remove_child(model);model.queue_free()
    model=load(EquipmentCatalog.weapon(id).model_path).instantiate();holder.add_child(model)
    GameArt.dress_scene(model,"weapon")
    reload_player=null;reload_clip=""
    for player in model.find_children("*","AnimationPlayer",true,false):
        for clip_name in player.get_animation_list():
            if "reload" in clip_name.to_lower():
                reload_player=player;reload_clip=clip_name;break
        if reload_player: break
    var marker=model.get_node_or_null("Muzzle")
    var muzzle_y: float=marker.position.y if marker else .06
    var muzzle_z: float=marker.position.z if marker else -.5
    var length: float=absf(muzzle_z)+.15
    model_scale=minf(1,.85/length)
    # Top of the barrel/receiver region only (between the grip and most of the way to the muzzle);
    # a full-model scan would catch a raised stock or sling loop and drag the sight far too high.
    var sight_y: float=muzzle_y+.03
    var found_top: bool=false
    var rear_extent: float=0
    for mesh in model.find_children("*","MeshInstance3D",true,false):
        if not mesh.mesh: continue
        var box: AABB=mesh.get_aabb()
        var relative: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
        for cx in [0,1]:
            for cy in [0,1]:
                for cz in [0,1]:
                    var point: Vector3=relative*(box.position+box.size*Vector3(cx,cy,cz))
                    rear_extent=maxf(rear_extent,point.z)
                    if point.z<=.02 and point.z>=muzzle_z*.85:
                        if not found_top or point.y>sight_y: sight_y=point.y;found_top=true
    sight_y+=.016
    hip_distance=maxf(.56,rear_extent*model_scale+.18)
    var front_sight: Marker3D=model.get_node_or_null("FrontSight")
    var rear_sight: Marker3D=model.get_node_or_null("RearSight")
    ads_pitch=0
    if front_sight and rear_sight: sight_y=front_sight.position.y
    if EquipmentCatalog.weapon(id).sight_type=="iron":
        # Thin rear/front posts riding the barrel line itself (muzzle-anchored), not the tallest
        # point of the whole model — a stock or sling loop would otherwise drag the sight sky-high.
        dot_material=StandardMaterial3D.new();dot_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        dot_material.albedo_color=Color("eeefc5")
        var metal:=StandardMaterial3D.new();metal.albedo_color=Color("15191a");metal.roughness=.45
        var rear_z: float=rear_sight.position.z if rear_sight else muzzle_z*.22
        var front_z: float=front_sight.position.z if front_sight else muzzle_z*.94
        var rear_y: float=rear_sight.position.y if rear_sight else sight_y
        var rear_offset: float=.0015 if rear_sight else .012
        var front_offset: float=.0015 if front_sight else -.008
        var spacing: float=float(model.get_meta("sight_spacing",.016))
        for x in [-spacing,spacing]:
            if not rear_sight: _box(Vector3(x,sight_y-.006,rear_z),Vector3(.009,.016,.012),metal)
            _dot(Vector3(x,rear_y,rear_z+rear_offset),minf(.0014,spacing*.4) if rear_sight else .0028)
        if not front_sight: _box(Vector3(0,sight_y-.006,front_z),Vector3(.006,.016,.009),metal)
        _dot(Vector3(0,sight_y,front_z+front_offset),.0012 if front_sight else .0024)
        if front_sight and rear_sight:
            ads_pitch=atan2(rear_y-sight_y,rear_z+rear_offset-front_z-front_offset)
    model.scale=Vector3.ONE*model_scale
    var aligned_z: float=front_sight.position.z+.0015 if front_sight else 0.0
    sight_height=(sight_y*cos(ads_pitch)-aligned_z*sin(ads_pitch))*model_scale
    # Simple local hands follow the same weapon, without a second network actor.
    var skin:=StandardMaterial3D.new();skin.albedo_color=Color("c3a780");skin.roughness=.9
    var grip: Marker3D=model.get_node_or_null("Grip")
    var support: Marker3D=model.get_node_or_null("SupportGrip")
    for index in 2:
        var hand:=MeshInstance3D.new();var shape:=CapsuleMesh.new()
        shape.radius=.035 if grip else .045;shape.height=.14 if grip else .2
        hand.mesh=shape;hand.material_override=skin
        if grip and support:
            hand.position=(grip.position if index==1 else support.position)+Vector3(.022 if index==1 else -.026,-.035,.015)
        else:
            hand.position=Vector3(.055 if index==1 else -.075,-.16,.16 if index==1 else .04)
        hand.rotation.x=.5;model.add_child(hand)

func _box(point: Vector3,dimensions: Vector3,material: Material) -> void:
    var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=dimensions
    mesh.mesh=box;mesh.position=point;mesh.material_override=material;model.add_child(mesh)

func _dot(point: Vector3,radius: float) -> void:
    var mesh:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=radius;sphere.height=radius*2
    sphere.radial_segments=10;sphere.rings=5;mesh.mesh=sphere;mesh.material_override=dot_material;mesh.position=point
    sight_index+=1;mesh.name="SightDot"+str(sight_index);model.add_child(mesh)
