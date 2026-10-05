extends SceneTree
var failures: int=0
var checks: int=0
var scene
var session
var sequence: int=10000
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await physics_frame
func loaded() -> bool:
    for i in 2400:
        if session.phase!="loading": return true
        await process_frame
    return false
func drive(vector: Vector2,count: int,braking: bool=false) -> void:
    for i in count:
        sequence+=1
        session._accept_input(1,{"seq":sequence,"direction":Vector3.ZERO,"drive":vector,"yaw":0,"pitch":0,"brake":braking})
        await physics_frame
func platform(center: Vector3, dimensions: Vector3, tilt: float=0) -> StaticBody3D:
    var body:=StaticBody3D.new();body.collision_layer=1
    body.position=center;body.rotation.x=tilt
    var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=dimensions
    collision.shape=box;body.add_child(collision);scene.add_child(body)
    return body
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    await frames(4)
    var hunter=session.local_hunter()
    var inv=hunter.inventory
    var jeep=session.jeep
    check(scene.world_router.active_id=="lobby" and session.forest==null,"lobby is a separate map without forest")
    check(session.animals.is_empty() and scene.world_router.active.has_node("Camp"),"lobby has stalls and no wildlife")
    inv.coins=456;inv.buy_weapon(&"old_rifle");inv.collect(load("res://data/loot/deer_pelt.tres"))
    session.trunk.append({"owner":session.identities[1],"kind":"deer_pelt"})
    var wallet: int=inv.coins
    start_forest()
    check(session.phase=="loading" and scene.loading_screen.root_control.visible,"Start shows loading before expedition")
    check(not jeep.enabled and not hunter.world_ready and not hunter.control_enabled,"loading blocks players and vehicle")
    check(session.animals.is_empty(),"wildlife waits until map is ready")
    session.request_action("buy_weapon","thunder_tube")
    check(inv.coins==wallet,"loading cannot mutate shop purchases")
    check(await loaded() and session.phase=="hunt","map completes and starts expedition")
    check(scene.world_router.active_id=="forest" and not scene.world_router.active.has_node("Camp"),"forest contains no lobby scenery")
    check(is_instance_valid(session.forest) and session.forest.built,"forest terrain completed before spawn")
    check(session.animals.size()>=24 and hunter.world_ready,"wildlife and player activate together")
    check(hunter.global_position.distance_to(jeep.global_position)<8,"jeep spawns beside hunting party")
    check(not scene.loading_screen.root_control.visible,"loading closes after map readiness")
    check(inv.coins==wallet and inv.owns_weapon(&"old_rifle") and inv.items.size()==1,"inventory survives map transition")
    check(session.trunk.size()==1 and session.trunk[0].owner==session.identities[1],"cargo ownership survives map transition")
    var epoch: int=session.world_epoch
    start_forest()
    check(session.world_epoch==epoch,"repeated Start cannot restart active map")
    check(jeep is RigidBody3D and jeep.wheel_turns.size()==4,"jeep uses rigid body and four suspension contacts")
    session.set_physics_process(false)
    hunter.control_enabled=false
    for a in session.animals.values(): a.set_physics_process(false)
    var pad:=platform(Vector3(0,29.5,-100),Vector3(160,1,160))
    jeep.reset_state(Transform3D(Basis.IDENTITY,Vector3(0,31,-100)))
    await frames(150)
    print("SETTLED ",jeep.global_position," contacts ",jeep.grounded_wheels," velocity ",jeep.linear_velocity)
    check(jeep.grounded_wheels==4 and jeep.linear_velocity.length()<.2,"suspension settles on four wheels")
    check(jeep.global_basis.y.dot(Vector3.UP)>.98,"parked body stays upright")
    hunter.global_position=jeep.global_position+Vector3(2,1,0)
    check(jeep.enter(1),"hunter can take driver seat")
    var before: Vector3=jeep.global_position
    await drive(Vector2(0,-1),150)
    print("FORWARD ",jeep.global_position-before," speed ",jeep.speed," up ",jeep.global_basis.y.dot(Vector3.UP))
    check(jeep.global_position.z<before.z-8 and jeep.speed>5,"engine accelerates using wheel traction")
    check(not jeep.exit_seat(1),"cannot jump out of moving car")
    var heading: float=jeep.rotation.y
    await drive(Vector2(.7,-1),65)
    print("STEER yaw ",jeep.rotation.y-heading," up ",jeep.global_basis.y.dot(Vector3.UP))
    check(absf(jeep.rotation.y-heading)>.1,"front wheels turn the chassis")
    check(jeep.global_basis.y.dot(Vector3.UP)>.8,"normal cornering does not roll vehicle")
    await drive(Vector2.ZERO,100,true)
    print("BRAKE ",jeep.linear_velocity," speed ",jeep.speed)
    check(jeep.linear_velocity.length()<.6,"brakes stop vehicle")
    await drive(Vector2(0,1),100)
    check(jeep.speed < -1 and jeep.speed>=-jeep.max_reverse_speed-1,"reverse has controlled speed")
    await drive(Vector2.ZERO,100,true)
    check(jeep.exit_seat(1),"driver exits after stopping")
    before=jeep.global_position
    await frames(120)
    check(jeep.global_position.distance_to(before)<.25,"empty jeep applies parking brake")
    # A tilted slab exercises support normals and gravity compensation.
    var ramp:=platform(Vector3(0,45,-100),Vector3(40,1,40),.18)
    jeep.reset_state(Transform3D(Basis(Vector3.RIGHT,.18),Vector3(0,47,-100)))
    await frames(150)
    before=jeep.global_position
    await frames(120)
    print("SLOPE ",jeep.global_position-before," contacts ",jeep.grounded_wheels)
    check(jeep.grounded_wheels==4,"suspension conforms to sloped terrain")
    check(jeep.global_position.distance_to(before)<.4,"parking brake holds on slope")
    hunter.global_position=jeep.global_position+Vector3(2,1,0)
    check(jeep.enter(1),"driver can enter on slope")
    before=jeep.global_position
    await drive(Vector2(0,-1),90)
    check(jeep.global_position.y>before.y+.4 and jeep.global_basis.y.dot(Vector3.UP)>.85,"wheel traction climbs slope without overturning")
    await drive(Vector2.ZERO,100,true)
    jeep.exit_seat(1,true)
    var wall:=platform(Vector3(-40,32,-115),Vector3(20,5,1))
    jeep.reset_state(Transform3D(Basis.IDENTITY,Vector3(-40,31,-105)))
    await frames(100)
    hunter.global_position=jeep.global_position+Vector3(2,1,0)
    jeep.enter(1)
    await drive(Vector2(0,-1),170)
    check(jeep.global_position.z>-113,"chassis collision stops at solid wall")
    check(jeep.global_basis.y.dot(Vector3.UP)>.8,"front impact stays stable")
    await drive(Vector2.ZERO,90,true)
    jeep.exit_seat(1,true);wall.queue_free()
    # Recover an overturned jeep without losing cargo.
    jeep.reset_state(Transform3D(Basis(Vector3.FORWARD,PI),Vector3(50,34,-100)))
    await frames(150)
    hunter.global_position=jeep.global_position+Vector3(2,0,0)
    check(jeep.recover(1),"nearby hunter can recover overturned jeep")
    await frames(60)
    check(jeep.global_basis.y.dot(Vector3.UP)>.8 and session.trunk.size()==1,"recovery preserves cargo and restores wheels")
    pad.queue_free();ramp.queue_free()
    session.set_physics_process(true)
    var fallen=session._spawn_player(2,"Map transition friend");fallen.world_ready=true;fallen.take_damage(999)
    session.request_action("return_lobby")
    session._accept_loaded(2,session.world_epoch)
    check(await loaded() and session.phase=="lobby","host can return party to lobby")
    check(session.forest==null and scene.world_router.active_id=="lobby" and session.animals.is_empty(),"return unloads forest and wildlife")
    check(inv.coins==wallet and inv.items.size()==1 and session.trunk.size()==1,"return preserves personal bag and trunk")
    check(fallen.health==0 and fallen.life_pose_downed,"map travel does not revive a downed hunter")
    session._peer_disconnected(2)
    start_forest()
    await frames(3)
    session.request_action("cancel_loading")
    check(await loaded() and session.phase=="lobby","cancel interrupted load returns to camp")
    check(not scene.loading_screen.root_control.visible and jeep.enabled,"cancel restores usable lobby")
    var slow=session._spawn_player(2,"Slow peer")
    slow.world_ready=true
    start_forest()
    for i in 2400:
        if session.ready_players.has(1): break
        await process_frame
    check(session.phase=="loading" and session.ready_players.size()==1,"connected peer without acknowledgement blocks start")
    session._accept_loaded(2,session.world_epoch-1)
    check(session.phase=="loading","old map acknowledgement cannot release barrier")
    session._peer_disconnected(2)
    await frames(2)
    check(session.phase=="hunt","disconnect of unready peer releases remaining party")
    var count: int=session.loot.size()
    session._loot_added(999,"deer_pelt",Vector3.ZERO,session.world_epoch-1)
    check(session.loot.size()==count,"loot from previous map cannot enter current world")
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await process_frame;await process_frame
    quit(1 if failures else 0)

func start_forest() -> void:
    var session=root.get_node("NetworkSession")
    if session.phase=="lobby" and session.is_host():
        var fire=session.world.world_router.active.get_node("Camp/GiantCampfire/Expedition")
        session.local_hunter().global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
