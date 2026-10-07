extends SceneTree
var scene
var session
var hunter
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await physics_frame
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");hunter=session.local_hunter()
    await frames(4)
    check(not scene.menu._return_lobby.visible,"pause menu has no lobby Start")
    check(scene.map_menu.DESTINATIONS==["forest","swamp","ocean"],"Forest, Swamp and Ocean available")
    scene.menu.resume()
    hunter.global_position=Vector3(14,.5,14)
    session.request_action("start_hunt","forest")
    check(session.phase=="lobby","host cannot start away from campfire")
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    # A real E event passes through Main's existing interaction handler.
    hunter.control_enabled=true
    var event:=InputEventAction.new();event.action="interact";event.pressed=true
    scene._unhandled_input(event)
    check(scene.map_menu.is_open and scene.map_menu.root_control.visible,"E at fire opens map menu")
    check(session.phase=="lobby" and session.animals.is_empty(),"opening map menu does not start expedition")
    check(not hunter.control_enabled and not scene.hud.visible,"map menu releases gameplay input")
    check(not scene.map_menu.start_button.disabled,"host can choose Forest")
    var locale=root.get_node("LocaleSettings")
    locale.set_language("ro")
    check(scene.map_menu.forest_title.text=="PĂDURE","map menu Romanian labels")
    locale.set_language("en")
    check(scene.map_menu.forest_title.text=="FOREST","map menu English labels")
    event.action="release_cursor";scene.map_menu._input(event)
    check(not scene.map_menu.is_open and hunter.control_enabled,"Esc closes maps and restores controls")
    var client=session._spawn_player(2,"Friend")
    client.global_position=hunter.global_position
    session._action(2,"start_hunt","forest")
    check(session.phase=="lobby","client cannot start from campfire")
    session._peer_disconnected(2)
    session.request_action("start_hunt","desert")
    check(session.phase=="lobby","unavailable map ID rejected")
    scene.interact_nearby()
    scene.map_menu.start_button.pressed.emit()
    check(session.phase=="loading" and not scene.map_menu.is_open,"map Start enters shared loading and closes selection")
    for i in 2400:
        if session.phase!="loading": break
        await process_frame
    check(session.phase=="hunt" and scene.world_router.active_id=="forest","selected Forest loads normally")
    check(scene.menu._return_lobby.visible,"return to camp remains in expedition pause menu")
    # Isolate AI tests from random wildlife and player keyboard input.
    for a in session.animals.values(): a.set_physics_process(false)
    hunter.control_enabled=false;hunter.set_physics_process(false)
    var stage:=StaticBody3D.new();stage.position=Vector3(0,29.5,-100)
    var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(250,1,250)
    shape.shape=box;stage.add_child(shape);scene.add_child(stage)
    await frames(3)
    for kind in ["wolf","bear","boar"]:
        hunter.health=100;hunter.seat_index=-1;hunter.world_ready=true
        hunter.global_position=Vector3(0,30,-100)
        var a=session.spawn_animal(StringName(kind),Vector3(0,0,-100))
        a.global_position=Vector3(0,30,-115);a.home=a.global_position
        var before: float=a.global_position.distance_to(hunter.global_position)
        await frames(45)
        check(a.target_peer==1 and a.state=="Run",kind+" acquires nearby hunter and runs toward them")
        check(a.global_position.distance_to(hunter.global_position)<before-2,kind+" approaches instead of fleeing")
        a.global_position=Vector3(0,30,-160);a.velocity=Vector3.ZERO
        a.take_damage(1,hunter.global_position,1)
        check(a.flee_until==0 and a.target_peer==1,kind+" shot provokes shooter without flee state")
        before=a.global_position.distance_to(hunter.global_position)
        await frames(40)
        check(a.global_position.distance_to(hunter.global_position)<before-2 and a.state=="Run",kind+" pursues shooter beyond detection range")
        a.global_position=Vector3(0,30,-101.6);a.velocity=Vector3.ZERO;a.attack_clock=0;a.leaping=false;a.leap_windup=-1
        var health: int=hunter.health
        await frames(38)
        check(hunter.health==health-a.definition.attack_damage and a.state=="Attack",kind+" attacks at melee distance")
        health=hunter.health
        await frames(20)
        check(hunter.health==health,kind+" respects attack cooldown")
        hunter.seat_index=0
        await frames(2)
        check(a.target_peer==0,kind+" drops target seated in jeep")
        a.set_physics_process(false);session.remove_animal(a.animal_id)
    for kind in ["rabbit","deer"]:
        hunter.health=100;hunter.seat_index=-1
        hunter.global_position=Vector3(0,30,-100)
        var a=session.spawn_animal(StringName(kind),Vector3(0,0,-100))
        a.global_position=Vector3(0,30,-105);a.home=a.global_position
        var before: float=a.global_position.distance_to(hunter.global_position)
        await frames(30)
        check(a.global_position.distance_to(hunter.global_position)>before+1 and a.target_peer==0,kind+" remains passive and flees")
        a.take_damage(1,hunter.global_position,1)
        check(a.flee_until>0 and a.target_peer==0,kind+" shot still triggers flight")
        session.remove_animal(a.animal_id)
    hunter.seat_index=-1
    # A predator changes targets when its previous hunter is downed.
    var friend=session._spawn_player(2,"Friend");friend.world_ready=true;friend.set_physics_process(false)
    friend.global_position=Vector3(12,30,-100)
    hunter.global_position=Vector3(0,30,-100);hunter.health=100
    var wolf=session.spawn_animal(&"wolf",Vector3(0,0,-100));wolf.global_position=Vector3(0,30,-110)
    wolf.take_damage(1,hunter.global_position,1)
    await frames(3);hunter.health=0;await frames(3)
    check(wolf.target_peer==2,"predator switches to another living hunter")
    session.mode="client"
    var health: int=friend.health
    wolf._physics_process(.1)
    check(friend.health==health,"client replica cannot apply predator damage")
    session.mode="solo"
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
