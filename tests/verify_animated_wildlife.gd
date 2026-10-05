extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func run() -> void:
    for definition in AnimalCatalog.ANIMALS+AnimalCatalog.SWAMP_ANIMALS:
        var animal=load("res://actors/animals/wildlife_animal.gd").new();animal.definition=definition;animal.animal_id=checks+1
        root.add_child(animal);animal.set_physics_process(false);animal.set_process(false)
        var skeletons=animal.model.find_children("*","Skeleton3D",true,false)
        check(not skeletons.is_empty(),str(definition.id)+" has a real skeleton")
        var skinned: bool=false
        for mesh in animal.model.find_children("*","MeshInstance3D",true,false):
            skinned=skinned or mesh.skin!=null
        check(skinned,str(definition.id)+" mesh is skinned to the rig")
        check(animal.animation!=null,str(definition.id)+" has an AnimationPlayer")
        for key in ["Idle","Walk","Run","Die"]:
            if key=="Run" and not animal.clips.has(key): continue
            check(animal.clips.has(key),str(definition.id)+" has "+key)
        if definition.aggressive: check(animal.clips.has("Attack"),str(definition.id)+" has attack")
        if animal.animation and not skeletons.is_empty():
            var skeleton: Skeleton3D=skeletons[0]
            var walk: String=str(animal.clips.get("Walk",animal.clips.get("Run","")))
            if not walk.is_empty():
                animal.animation.play(walk);animal.animation.seek(.05,true);skeleton.force_update_all_bone_transforms()
                var before: Array[Transform3D]=[]
                for i in skeleton.get_bone_count(): before.append(skeleton.get_bone_pose(i))
                animal.animation.seek(animal.animation.get_animation(walk).length*.42,true);skeleton.force_update_all_bone_transforms()
                var moved: int=0
                for i in skeleton.get_bone_count():
                    if not before[i].is_equal_approx(skeleton.get_bone_pose(i)): moved+=1
                check(moved>=2,str(definition.id)+" locomotion changes multiple joints")
            if animal.clips.has("Die"):
                check(animal.animation.get_animation(animal.clips.Die).loop_mode==Animation.LOOP_NONE,str(definition.id)+" death holds instead of looping")
            if animal.clips.has("Die"):
                animal._animate("Die",true)
                animal.animation.advance(animal.animation.get_animation(animal.clips.Die).length+1.0)
                animal._animate("Die")
                check(not animal.animation.is_playing(),str(definition.id)+" snapshots do not restart a finished death")
            print("ANIMAL_RIG ",definition.id," bones=",skeleton.get_bone_count()," clips=",animal.clips)
        animal.free()
    print("RESULT ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)

