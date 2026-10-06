extends SceneTree
## One-off visual QA for the sourced weapon viewmodels; not part of the shipped suite.
var scene
var session
var helper
var output: String
var qa_failures: int=0
func check(ok: bool, message: String) -> void:
    if ok: print("WEAPON_QA_PASS ",message)
    else: qa_failures+=1;push_error("WEAPON_QA_FAIL "+message)

func verify_geometry(weapon_id: String) -> void:
    var model: Node3D=helper.camera_rig.view_model.model
    var muzzle: Vector3=model.get_node("Muzzle").position
    var front_z: float=INF
    var nearest: float=INF
    var meshes=model.get_node("Source").find_children("*","MeshInstance3D",true,false)
    for mesh in meshes:
        var relative: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
        for surface in mesh.mesh.get_surface_count():
            var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
            for vertex in vertices:
                var point: Vector3=relative*vertex
                front_z=minf(front_z,point.z);nearest=minf(nearest,point.distance_to(muzzle))
    check(meshes.size()==2 and muzzle.z<0 and absf(front_z-muzzle.z)<.025 and nearest<.06,weapon_id+" source muzzle matches forward barrel geometry")

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame

func view(aim: bool) -> void:
    if aim: Input.action_press("aim")
    else: Input.action_release("aim")
    for i in 30:
        await physics_frame

func run() -> void:
    output=OS.get_environment("HUNT_PREVIEW_DIR")
    if output.is_empty(): output=ProjectSettings.globalize_path("res://work/weapon_sources")
    DirAccess.make_dir_recursive_absolute(output)
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");helper=session.local_hunter()
    await frames(8);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"/preview_menu_credits.png")
    scene.menu.resume()
    session.set_physics_process(false);helper.set_physics_process(false)
    root.get_node("LocaleSettings").set_perspective("first")
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    helper.global_position=fire.global_position+Vector3(-14,.5,-4)
    helper.control_enabled=true
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    await frames(6)
    for weapon_id in ["rusty_pistol","old_rifle","double_barrel","scrap_blaster","beehive","sniper_rifle","thunder_tube","revolver","ak_rifle","railgun","raygun","chain_smg","nova_shotgun"]:
        helper.inventory.owned_weapons.append(StringName(weapon_id))
        helper.inventory.equipped_weapon_id=StringName(weapon_id)
        helper.inventory.loadout[0]=StringName(weapon_id)
        helper.inventory.changed.emit()
        await frames(4)
        await view(false)
        await RenderingServer.frame_post_draw
        var hip_path: String=output+"/preview_"+weapon_id+"_hip.png"
        root.get_texture().get_image().save_png(hip_path)
        verify_geometry(weapon_id)
        await view(true)
        await RenderingServer.frame_post_draw
        var ads_path: String=output+"/preview_"+weapon_id+"_ads.png"
        root.get_texture().get_image().save_png(ads_path)
        var dots=helper.camera_rig.view_model.model.find_children("SightDot*","MeshInstance3D",true,false)
        if not dots.is_empty():
            var center: Vector2=root.get_visible_rect().get_center()
            var front: Vector2=helper.camera_rig.camera.unproject_position(dots[2].global_position)
            check(front.distance_to(center)<3,weapon_id+" ADS front sight meets camera ray ("+str(front)+" / "+str(center)+")")
        else:
            check(helper.camera_rig.scope_overlay.visible,weapon_id+" ADS scope is visible")
        print("CAPTURED ", weapon_id, " -> ", ProjectSettings.globalize_path(hip_path), " / ads")
        await view(false)
        var definition=EquipmentCatalog.weapon(StringName(weapon_id))
        helper.inventory.reload_remaining=definition.reload_seconds*.5
        await frames(2);await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/preview_"+weapon_id+"_reload.png")
        helper.inventory.reload_remaining=0
    print("WEAPON_PREVIEW_DONE qa_failures=",qa_failures)
    quit(0 if qa_failures==0 else 1)
