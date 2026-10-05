extends SceneTree
## One-off check that different random seeds actually produce different terrain, and that a
## live expedition picks and syncs a real nonzero seed. The broadcast/reconnect plumbing itself
## is already covered by run_network_tests.ps1 (host+3 clients+reconnect, all green).
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
    # Core mechanism: two independently-seeded maps must diverge, while both keep the camp flat.
    var a=load("res://world/forest/forest_map.gd").new();root.add_child(a);a.set_seed(111111)
    var b=load("res://world/forest/forest_map.gd").new();root.add_child(b);b.set_seed(222222)
    check(a.height_at(0,0)==0.0 and b.height_at(0,0)==0.0,"camp stays flat for any seed")
    check(not is_equal_approx(a.height_at(300,300),b.height_at(300,300)),"different seeds diverge in the wilds")
    var a2=load("res://world/forest/forest_map.gd").new();root.add_child(a2);a2.set_seed(111111)
    check(is_equal_approx(a.height_at(300,300),a2.height_at(300,300)),"same seed reproduces identical terrain on another instance")
    var sa=load("res://world/swamp/swamp_map.gd").new();root.add_child(sa);sa.set_seed(333333)
    var sb=load("res://world/swamp/swamp_map.gd").new();root.add_child(sb);sb.set_seed(444444)
    check(sa.height_at(0,0)>1.0 and sb.height_at(0,0)>1.0,"swamp arrival stays dry and elevated for any seed")
    check(not is_equal_approx(sa.height_at(480,480),sb.height_at(480,480)),"different seeds diverge in the swamp's hilly margins")
    a.queue_free();b.queue_free();a2.queue_free();sa.queue_free();sb.queue_free()

    # Live session: a real expedition start picks a real, nonzero, network-stored seed.
    var scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    var session=root.get_node("NetworkSession")
    scene.menu.resume()
    await frames(6)
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    session.local_hunter().global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
    for i in 2400:
        if session.phase!="loading": break
        await process_frame
    await frames(10)
    check(session.active_map_seed!=0 and session.forest.current_seed==session.active_map_seed,"a live expedition picks and applies a real random seed, no manual input")

    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free()
    await process_frame
    quit(1 if failures else 0)
