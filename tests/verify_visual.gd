extends SceneTree
var scene
var session
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await physics_frame
func snap(name_value: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://docs/"+name_value+".png")
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    var locale=root.get_node("LocaleSettings");locale.set_language("ro")
    await frames(8);await snap("preview_perspective_menu")
    scene.menu.resume()
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    scene.hunter.global_position=fire.global_position+Vector3(0,.2,3.4)
    session.request_action("start_hunt","forest")
    for i in 2400:
        if session.phase=="hunt": break
        await process_frame
    for a in session.animals.values(): a.set_physics_process(false)
    var hunter=session.local_hunter()
    hunter.global_position=Vector3(0,.05,-32);hunter.camera_rig.rotation=Vector3.ZERO
    locale.set_perspective("first")
    await frames(30);await snap("preview_fps_hip")
    Input.action_press("aim")
    var bear=session.spawn_animal(&"bear",Vector3(0,0,-42));bear.set_physics_process(false)
    await frames(3)
    var point: Vector3=bear.global_position+Vector3.UP*bear.definition.height*.5
    var delta: Vector3=point-hunter.camera_rig.camera.global_position
    hunter.camera_rig.rotation.x=atan2(delta.y,Vector2(delta.x,delta.z).length())
    await frames(20)
    var hp: int=bear.health
    Input.action_press("fire");await frames(2);Input.action_release("fire")
    check(bear.health<hp and hunter.combat.shots_fired==1,"native first person fire hits the animal")
    await frames(35);await snap("preview_pistol_irons")
    check(hunter.camera_rig.aiming and not scene.crosshair.visible,"native first person ADS hides HUD crosshair")
    print("FPS_AIM ",hunter.camera_rig.aiming," first ",hunter.camera_rig.is_first_person()," scope ",hunter.camera_rig.scope_overlay.visible)
    hunter.inventory.coins=5000;hunter.inventory.buy_weapon(&"old_rifle")
    scene._toast_time=0
    await frames(35);await snap("preview_rifle_scope")
    check(hunter.camera_rig.scope_overlay.visible and hunter.camera_rig.camera.fov<26,"native rifle aim shows the scope")
    Input.action_release("aim")
    locale.set_perspective("third")
    var friend=session._spawn_player(2,"Forest friend")
    friend.world_ready=true;friend.global_position=Vector3(0,.1,-35);friend.take_damage(999)
    hunter.global_position=Vector3(1.2,.1,-34)
    await frames(60)
    var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(5,3,-30);camera.look_at(Vector3(0,.4,-35));camera.current=true
    Input.action_press("interact")
    await frames(90)
    check(friend.health==0 and friend.revive_progress>.4 and friend.revive_progress<.6,"native held E advances revive progress")
    await snap("preview_downed_revive")
    for i in 4:
        await frames(30)
    Input.action_release("interact")
    check(friend.health==50,"native held E completes teammate revive")
    await snap("preview_revived_teammate")
    print("REVIVED_HP ",friend.health)
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
