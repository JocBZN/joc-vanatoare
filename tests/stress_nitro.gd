extends SceneTree
## Drives the fully upgraded truck cross-country on full nitro, on fixed seeds, and reports
## the worst tilt. Used to tune the anti-flip stabilisers.
var scene
var session
func _initialize() -> void: call_deferred("run")
func lobby() -> void:
    if session.phase=="hunt":
        session.request_action("return_lobby")
        for i in 3600:
            if session.phase!="loading": break
            await process_frame
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    for i in 5: await process_frame
    for id in TruckUpgrades.ORDER: session.truck_state[String(id)]=TruckUpgrades.max_level(id)
    session.jeep.set_upgrades(session.truck_state)
    var hunter=session.local_hunter();var jeep=session.jeep
    var results: Array=[]
    for map_seed in [11,222,3333,44444]:
        await lobby()
        var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
        hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
        seed(map_seed)
        session.request_action("start_hunt","forest")
        for i in 3600:
            if session.phase!="loading": break
            await process_frame
        for a in session.animals.values(): a.set_physics_process(false)
        jeep.occupants[0]=2
        var worst_up: float=1.0;var flips: int=0;var worst_pitch: float=0.0
        for i in 900:
            # Straight at full boost, then a hard turn at speed: the classic rollover.
            var steer: float=0.0 if i<200 else (1.0 if i<330 else (-1.0 if i<460 else sin(i*.03)*.5))
            jeep.command={"drive":Vector2(steer,-1),"sprint":true,"time":Time.get_ticks_msec()}
            await physics_frame
            var up: float=jeep.global_basis.y.dot(Vector3.UP)
            worst_up=minf(worst_up,up)
            worst_pitch=maxf(worst_pitch,absf((-jeep.global_basis.z).y))
            if up<.2: flips+=1
        results.append([map_seed,snappedf(worst_up,.01),snappedf(worst_pitch,.01),flips,snappedf(jeep.linear_velocity.length(),.1)])
        jeep.occupants[0]=0
    print("STRESS (seed, worst up, worst pitch, flipped frames, final speed) ",results)
    quit()
