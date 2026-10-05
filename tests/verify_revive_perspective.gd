extends SceneTree
var scene
var session
var helper
var target
var checks: int=0
var failures: int=0
var sequence: int=50000
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await physics_frame
func hold(id: int,count: int) -> void:
    for i in count:
        sequence+=1
        session._accept_input(1,{"seq":sequence,"direction":Vector3.ONE,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"revive":id})
        session._tick_revives(1.0/60)
        await physics_frame
func view(first: bool,aim: bool) -> void:
    root.get_node("LocaleSettings").set_perspective("first" if first else "third")
    helper.camera_rig.set_aiming(aim)
    for i in 30:
        helper.camera_rig.update_camera(1.0/60)
        await physics_frame
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");helper=session.local_hunter();scene.menu.resume()
    session.set_physics_process(false);helper.set_physics_process(false)
    helper.global_position=Vector3(1.2,.2,8)
    target=session._spawn_player(2,"Fallen friend");target.global_position=Vector3(0,.2,8)
    target.inventory.coins=71;target.inventory.collect(load("res://data/loot/deer_pelt.tres"))
    target.take_damage(999)
    await frames(4)
    check(target.health==0 and target.life_pose_downed,"lethal damage leaves hunter downed")
    check(absf(target.visual.rotation.x+PI*.5)<.01,"downed model lies on the ground")
    check(target.name_tag.text.contains("DOBOR") or target.name_tag.text.contains("DOWNED"),"downed status above body")
    check(target.get_node("ReviveInteraction").can_interact(),"teammate body becomes interactable")
    var position_before: Vector3=target.global_position
    await frames(510)
    check(target.health==0 and Vector2(target.global_position.x-position_before.x,target.global_position.z-position_before.z).length()<.1,"no automatic respawn after old eight second timer")
    session._action(2,"reset","")
    check(target.health==0,"downed hunter cannot reset to heal")
    await hold(1,190)
    check(helper.health==100 and target.health==0,"hunter cannot revive self")
    helper.global_position=Vector3(15,.2,8)
    await hold(2,190)
    check(target.health==0 and target.revive_progress==0,"revive requires close proximity")
    helper.global_position=Vector3(1.2,.2,8)
    await hold(2,70)
    check(target.health==0 and target.revive_progress>.3 and target.revive_progress<.5,"hold E accumulates server progress")
    check(helper.command.direction==Vector3.ZERO,"reviving prevents movement")
    var ammunition: int=helper.inventory.ammunition()
    session._shoot(1,helper.global_position+Vector3.UP*1.4,Vector3.FORWARD)
    check(helper.inventory.ammunition()==ammunition,"reviving blocks firing on server")
    await hold(0,1)
    check(target.revive_progress==0 and target.health==0,"releasing E cancels progress")
    await hold(2,60)
    helper.command["time"]=Time.get_ticks_msec()-1000
    session._tick_revives(1.0/60)
    check(target.revive_progress==0,"expired network input cancels revive progress")
    await hold(2,60)
    helper.take_damage(1)
    await hold(2,1)
    check(target.revive_progress==0,"damage interrupts revive progress")
    await hold(2,190)
    check(target.health==50 and not target.life_pose_downed,"teammate revives with fifty health")
    check(target.inventory.coins==71 and target.inventory.items.size()==1,"revive keeps wallet and loot")
    check(target.revive_progress==0 and target.revive_helper==0,"completed revive clears interaction state")
    check(absf(target.visual.rotation.x)<.01 and target.get_node("CollisionShape3D").rotation==Vector3.ZERO,"revive restores upright body and collision")
    check(not target.get_node("ReviveInteraction").can_interact(),"living hunter has no revive prompt")
    # Dead helpers and solid obstacles must not revive someone.
    target.take_damage(999);helper.health=0
    await hold(2,190)
    check(target.health==0,"downed helper cannot revive another")
    helper.health=100;helper._life_pose()
    var wall:=StaticBody3D.new();var c:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.3,3,3)
    c.shape=box;wall.add_child(c);wall.position=Vector3(.6,1,7.5);scene.add_child(wall)
    await frames(3);await hold(2,190)
    check(target.health==0 and target.revive_progress==0,"revive cannot pass through solid obstacle")
    wall.queue_free();await frames(3)
    root.get_node("LocaleSettings").set_language("en")
    check(target.name_tag.text.ends_with("DOWNED"),"downed name updates when language changes")
    root.get_node("LocaleSettings").set_language("ro")
    helper.camera_rig.set_process(false)
    scene.menu._perspective.item_selected.emit(1)
    check(root.get_node("LocaleSettings").perspective=="first" and scene.menu._perspective.selected==1,"menu choice updates saved perspective")
    helper.inventory.equip_weapon(&"rusty_pistol")
    await view(true,false)
    check(helper.camera_rig.is_first_person() and helper.camera_rig.spring_arm.spring_length==0,"first person places camera at head")
    check(not helper.visual.visible and helper.camera_rig.view_model.visible,"first person hides local body and shows weapon")
    check(target.visual.visible,"other hunter body stays visible")
    await view(true,true)
    check(not scene.crosshair.visible,"first person ADS removes HUD crosshair")
    var vm=helper.camera_rig.view_model
    check(vm.ads_blend>.99 and absf(vm.position.x)<.002,"ADS centers weapon")
    check(vm.model.find_children("SightDot*","MeshInstance3D",true,false).size()==3,"pistol has physical rear dots and front sight")
    var dots=vm.model.find_children("SightDot*","MeshInstance3D",true,false)
    var camera=helper.camera_rig.camera
    var center: Vector2=Vector2(640,360)
    check(camera.unproject_position(dots[2].global_position).distance_to(center)<3,"front sight aligns with camera aiming ray")
    check(not helper.camera_rig.scope_overlay.visible,"pistol ADS uses irons instead of scope overlay")
    helper.inventory.coins=1000;helper.inventory.buy_weapon(&"old_rifle")
    await view(true,true)
    check(helper.camera_rig.scope_overlay.visible and camera.fov<26,"scoped rifle provides zoom and scope reticle")
    await view(false,false)
    check(helper.visual.visible and not vm.visible and helper.camera_rig.spring_arm.spring_length>4.9,"third person restores body and orbit camera")
    check(not helper.camera_rig.scope_overlay.visible,"scope closes when leaving first person")
    var state: Dictionary=target.snapshot()
    check(state.hp==0 and state.has("revive"),"downed state and revive progress included in snapshot")
    helper.health=0;helper._life_pose();await view(true,false)
    check(not helper.camera_rig.is_first_person() and helper.visual.visible,"downed first person hunter sees fallen body in third person")
    var config:=ConfigFile.new();config.load(root.get_node("LocaleSettings").settings_path)
    check(config.get_value("settings","perspective","")=="first","camera preference saved to settings")
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(6);quit(1 if failures else 0)
