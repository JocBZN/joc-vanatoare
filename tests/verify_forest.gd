extends SceneTree
## Run with --headless --path PROJECT --script res://tests/verify_forest.gd.
var failures: int=0
var checks: int=0
func _initialize() -> void: call_deferred("verify")
func check(condition: bool, description: String) -> void:
    checks+=1
    if not condition: failures+=1;push_error("FAIL "+description)
    else: print("PASS ",description)
func frames(count: int) -> void:
    for i in count: await physics_frame
func verify() -> void:
    var scene: Node=load("res://game/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    var session=root.get_node("NetworkSession")
    scene.menu.resume()
    start_forest()
    for i in 2400:
        if session.phase!="loading": break
        await process_frame
    await frames(12)
    var p=scene.hunter
    check(session.players.size()==1,"solo hunter")
    check(session.animals.size()>=24,"initial host wildlife")
    check(session.forest.trees.size()>5000,"large forest has deterministic trees")
    check(session.forest.height_at(0,0)==0,"camp terrain flat")
    var terrain_mesh=session.forest.get_child(0).mesh
    var normals: PackedVector3Array=terrain_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    check(normals[0].y>0,"terrain faces upward")
    p.global_position=Vector3(0,session.forest.height_at(0,-80)+2,-80)
    await frames(110)
    check(p.is_on_floor(),"hunter can stand on forest terrain")
    var last: float=1000
    for kind in ["rabbit","deer","boar","wolf","bear"]:
        var a=session.spawn_animal(StringName(kind),Vector3(90,0,-30))
        a.set_physics_process(false)
        check(a.definition.spawn_weight<last,"descending rarity "+kind)
        last=a.definition.spawn_weight
        check(a.label.text==TranslationServer.translate(a.definition.display_name),"translated name "+kind)
        check(a.animation!=null and not a.clips.is_empty(),"skeletal animation "+kind)
        check(a.take_damage(1,p.global_position),"host damage "+kind)
        check(a.health==a.definition.max_health-1,"correct health "+kind)
        var before: int=session.loot.size()
        a.take_damage(a.definition.max_health,p.global_position)
        check(session.loot.size()==before+1,"single species loot "+kind)
        a.take_damage(999,p.global_position)
        check(session.loot.size()==before+1,"no duplicate death payout "+kind)
    p.inventory.items.clear()
    p.inventory.coins=0
    p.inventory.collect(load("res://data/loot/wolf_pelt.tres"))
    p.global_position=session.jeep.to_global(Vector3(0,0,2.55))
    session.request_action("deposit")
    check(p.inventory.items.is_empty() and session.trunk.size()==1,"deposit bag into trunk")
    check(session.trunk[0].owner==session.identities[1],"trunk keeps loot owner")
    session.request_action("withdraw")
    check(session.trunk.is_empty() and p.inventory.items.size()==1,"owner can withdraw")
    session.request_action("deposit")
    var other=session._spawn_player(2,"Other")
    session.identities[2]="12345678901234567890123456789012"
    session.owner_names[session.identities[2]]="Other"
    other.world_ready=true
    other.global_position=p.global_position
    other.inventory.collect(load("res://data/loot/rabbit_pelt.tres"))
    session._action(2,"deposit","")
    session._action(2,"withdraw","")
    check(other.inventory.items.size()==1 and session.trunk.size()==1,"cannot withdraw another hunter's loot")
    session._action(2,"deposit","")
    # Synthetic peer explicitly acknowledges once the host finishes its map.
    session.request_action("return_lobby")
    for i in 2400:
        if session.local_loaded_epoch==session.world_epoch:
            session._accept_loaded(2,session.world_epoch)
            break
        await process_frame
    var seller
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="sell": seller=stall
    p.global_position=seller.interaction_position()
    session.jeep.reset_state(Transform3D(Basis.IDENTITY,seller.global_position+Vector3(3,.6,0)))
    session.request_action("sell_trunk")
    check(p.inventory.coins==110,"trunk sale credits only owner's value")
    check(session.trunk.size()==1 and session.trunk[0].owner==session.identities[2],"other cargo untouched by sale")
    check(other.inventory.coins==0,"other wallet stays individual")
    session.jeep.linear_velocity=Vector3.ZERO
    for peer in [1,2]:
        session.players[peer].global_position=session.jeep.global_position+Vector3(2,0,0)
        check(session.jeep.enter(peer),"jeep seat "+str(peer))
    for peer in [3,4]:
        var passenger=session._spawn_player(peer,"Passenger")
        passenger.global_position=session.jeep.global_position
        check(session.jeep.enter(peer),"jeep seat "+str(peer))
    check(session.jeep.occupants.size()==4 and not session.jeep.occupants.has(0),"four occupied seats")
    session.jeep.linear_velocity=Vector3(0,0,10)
    check(not session.jeep.exit_seat(2),"cannot exit moving jeep")
    session.jeep.linear_velocity=Vector3.ZERO
    check(session.jeep.exit_seat(2),"exit stopped jeep")
    scene._open_menu()
    check(scene.world_router.active.process_mode!=Node.PROCESS_MODE_DISABLED,"menu does not pause shared world")
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free()
    await process_frame
    quit(1 if failures else 0)

func start_forest() -> void:
    var session=root.get_node("NetworkSession")
    if session.phase=="lobby" and session.is_host():
        var fire=session.world.world_router.active.get_node("Camp/GiantCampfire/Expedition")
        session.local_hunter().global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
