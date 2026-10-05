extends SkeletonModifier3D
## Additive motion after the imported animation, using world axes across different rigs.
var animal: WildlifeAnimal
var head: int=-1
var chest: int=-1
var ears: Array[int]=[]
var tails: Array[int]=[]
var smooth_yaw: float=0
var smooth_pitch: float=0

func configure(owner_animal: WildlifeAnimal) -> void:
    animal=owner_animal
    var skeleton:=get_skeleton()
    for index in skeleton.get_bone_count():
        var bone:=skeleton.get_bone_name(index).to_lower()
        if bone=="head" or bone.ends_with("_head") or bone.ends_with(":head"): head=index
        if ("spine" in bone or "chest" in bone or bone=="body") and chest<0: chest=index
        var parent:=skeleton.get_bone_parent(index)
        if _is_ear_name(bone) and "tip" not in bone and (parent<0 or not _is_ear_name(skeleton.get_bone_name(parent).to_lower())): ears.append(index)
        if "tail" in bone and tails.size()<2: tails.append(index)

func _is_ear_name(bone: String) -> bool:
    return bone.begins_with("ear") or "_ear" in bone or ":ear" in bone

func _rotate(index: int, axis: Vector3,angle: float) -> void:
    if index<0: return
    var skeleton:=get_skeleton()
    var local_axis: Vector3=(skeleton.global_basis*skeleton.get_bone_global_pose(index).basis).inverse()*axis
    skeleton.set_bone_pose_rotation(index,skeleton.get_bone_pose_rotation(index)*Quaternion(local_axis.normalized(),angle))

func _process_modification_with_delta(delta: float) -> void:
    if not is_instance_valid(animal) or animal.dead: return
    var local: Vector3=animal.global_basis.inverse()*(animal.look_target-animal.global_position)
    var desired_yaw: float=clampf(atan2(-local.x,-local.z),-.55,.55)
    if local.z>0: desired_yaw=0
    var grazing: bool=animal.behavior=="Graze" and not animal.clips.has("Graze")
    var desired_pitch: float=.48 if grazing else -.08 if animal.behavior=="Alert" else sin(animal.motion_clock*.8)*.045
    smooth_yaw=lerpf(smooth_yaw,desired_yaw,1-exp(-4*delta))
    smooth_pitch=lerpf(smooth_pitch,desired_pitch,1-exp(-3*delta))
    _rotate(head,Vector3.UP,smooth_yaw)
    _rotate(head,animal.global_basis.x,smooth_pitch)
    _rotate(chest,animal.global_basis.x,sin(animal.motion_clock*2.6)*.012)
    for index in ears:
        _rotate(index,animal.global_basis.z,sin(animal.motion_clock*3.1+index)*.035+(.07 if animal.behavior=="Alert" else 0))
    for index in tails: _rotate(index,Vector3.UP,sin(animal.motion_clock*2.1+index)*.065)
