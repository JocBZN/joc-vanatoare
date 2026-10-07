extends SceneTree
## The Wandering Oak's upgrades: catalog rules, host-validated purchases at the
## garage bench, the four builds (bull bar, watchtower, nitro, boat kit), their
## effects, and replication through the truck snapshot.
var scene
var session
var hunter
var jeep
var checks: int=0
var failures: int=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await process_frame
func physics(count: int) -> void:
    for i in count: await physics_frame
func loaded() -> bool:
    for i in 3600:
        if session.phase!="loading": return true
        await process_frame
    return false

func stall(kind: String):
    for node in get_nodes_in_group("lobby_interactables"):
        if node.interaction_kind==kind: return node
    return null


func buy(id: String) -> void:
    session.request_action("truck_upgrade",id)

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    await frames(5)
    hunter=session.local_hunter();jeep=session.jeep

    # --- Catalog rules ---------------------------------------------------------------------
    var fresh: Dictionary=TruckUpgrades.fresh()
    check(TruckUpgrades.ORDER.size()==11 and TruckUpgrades.BUILDS.size()==9,"two performance upgrades and nine builds")
    check(TruckUpgrades.BUILDS[3]==&"boat" and TruckUpgrades.BUILDS[8]==&"rotor","the galleon sits fourth, the rotor is the last build")
    check(TruckUpgrades.max_level(&"speed")==3 and TruckUpgrades.max_level(&"accel")==3,"speed and acceleration have three levels")
    check(TruckUpgrades.blocker(fresh,&"tower")=="TRUCK_NEEDS" and TruckUpgrades.blocker(fresh,&"boat")=="TRUCK_NEEDS","builds unlock one after another")
    check(TruckUpgrades.blocker(fresh,&"bar")=="" and TruckUpgrades.blocker(fresh,&"nope")=="TRUCK_UNKNOWN","bull bar buyable at once, unknown ids refused")
    var forged: Dictionary=TruckUpgrades.sanitize({"boat":1,"speed":99,"accel":-4,"bar":"x"})
    check(TruckUpgrades.level(forged,&"boat")==0 and TruckUpgrades.level(forged,&"speed")==3 and TruckUpgrades.level(forged,&"accel")==0,"sanitize drops forged levels")
    var costs_ok: bool=true
    for id in TruckUpgrades.ORDER:
        for level in TruckUpgrades.max_level(id): costs_ok=costs_ok and int(TruckUpgrades.COSTS[id][level])>0
        if TruckUpgrades.max_level(id)>1: costs_ok=costs_ok and int(TruckUpgrades.COSTS[id][1])>int(TruckUpgrades.COSTS[id][0])
    check(costs_ok,"every level has a price and later levels cost more")

    # --- Purchases at the bench --------------------------------------------------------------
    var bench=stall("garage")
    check(bench!=null,"the truck carries a garage bench")
    hunter.inventory.coins=100000
    hunter.global_position=Vector3(0,40,0)
    var before: int=hunter.inventory.coins
    buy("bar")
    check(TruckUpgrades.level(session.truck_state,&"bar")==0 and hunter.inventory.coins==before,"nothing is sold away from the bench")
    hunter.global_position=bench.global_position+Vector3(0,.6,0)
    hunter.inventory.coins=0
    buy("bar")
    check(TruckUpgrades.level(session.truck_state,&"bar")==0,"buying without coins fails")
    hunter.inventory.coins=100000
    buy("tower")
    check(TruckUpgrades.level(session.truck_state,&"tower")==0 and hunter.inventory.coins==100000,"tower refused before the bull bar")
    buy("bar")
    check(TruckUpgrades.level(session.truck_state,&"bar")==1 and hunter.inventory.coins==100000-900,"bull bar bought: level 1, 900 coins")
    check(jeep.kits[&"bar"].visible and not jeep.kits[&"tower"].visible,"only the bull bar is fitted on the truck")
    buy("bar")
    check(hunter.inventory.coins==100000-900,"a one-level build cannot be bought twice")
    for i in 4: buy("speed")
    check(TruckUpgrades.level(session.truck_state,&"speed")==3,"speed stops at level 3")
    check(is_equal_approx(jeep.max_forward_speed,19.0*1.55),"top speed follows the speed level")
    for i in 3: buy("accel")
    check(is_equal_approx(jeep.engine_force,24000.0*2.1),"engine force follows the acceleration level")
    var spent: int=100000-hunter.inventory.coins
    check(spent==900+600+1400+3000+500+1200+2600,"the buyer paid exactly the listed prices (%d)" % spent)

    # --- Replication ---------------------------------------------------------------------------
    buy("tower")
    var snapshot: Dictionary=jeep.snapshot()
    check(snapshot.has("up") and int(snapshot.up.get("tower",0))==1,"the truck snapshot carries the upgrade levels")
    jeep.set_upgrades(TruckUpgrades.fresh())
    check(not jeep.kits[&"bar"].visible and is_equal_approx(jeep.max_forward_speed,19.0),"a stock truck shows no builds")
    jeep.apply_snapshot(snapshot)
    check(jeep.kits[&"bar"].visible and jeep.kits[&"tower"].visible and is_equal_approx(jeep.max_forward_speed,19.0*1.55),"a client rebuilds the truck from the snapshot")

    # --- Watchtower -----------------------------------------------------------------------------
    var up=null
    for node in get_nodes_in_group("lobby_interactables"):
        if node.interaction_kind=="tower_up": up=node
    check(up!=null,"tower ladder prompt exists once the tower is fitted")
    hunter.global_position=up.global_position+Vector3(0,.2,0)
    session.request_action("climb","tower_up")
    var local: Vector3=jeep.to_local(hunter.global_position)
    check(local.y>12.0 and jeep.carries(hunter.global_position),"climbing the tower puts the hunter on its platform, still carried")
    for node in get_nodes_in_group("lobby_interactables"):
        if node.interaction_kind=="tower_down": hunter.global_position=node.global_position+Vector3(0,.2,0)
    session.request_action("climb","tower_down")
    check(jeep.to_local(hunter.global_position).y<8.5 and jeep.carries(hunter.global_position),"the ladder brings the hunter back to the terrace")

    # --- Bull bar -------------------------------------------------------------------------------
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
    check(await loaded() and session.phase=="hunt","forest hunt loads with the upgrades kept")
    check(TruckUpgrades.level(session.truck_state,&"tower")==1,"upgrades survive a map change")
    for a in session.animals.values(): a.set_physics_process(false)
    var boar=session.spawn_animal(&"boar",Vector3(0,0,-100))
    boar.set_physics_process(false)
    boar.global_position=jeep.to_global(Vector3(0,.2,-7.6))
    var hp: int=boar.health
    jeep.linear_velocity=-jeep.global_basis.z*12.0
    jeep._bar_attack(.016)
    check(boar.health<hp,"the bull bar hurts an animal it meets at speed (%d -> %d)" % [hp,boar.health])
    var after_first: int=boar.health
    jeep._bar_attack(.016)
    check(boar.health==after_first,"the same animal is not struck twice at once")
    var slow=session.spawn_animal(&"boar",Vector3(0,0,-100));slow.set_physics_process(false)
    slow.global_position=jeep.to_global(Vector3(0,.2,-7.6))
    jeep.linear_velocity=-jeep.global_basis.z*2.0
    jeep._bar_attack(.016)
    check(slow.health==slow.definition.max_health,"a crawling truck does not hurt animals")

    # --- Nitro ----------------------------------------------------------------------------------
    jeep.linear_velocity=Vector3.ZERO
    var nitro_coins: int=hunter.inventory.coins
    hunter.global_position=stall("garage").global_position+Vector3(0,.6,0)
    buy("boat")
    check(TruckUpgrades.level(session.truck_state,&"boat")==0,"boat kit refused before the nitro boosters")
    buy("nitro")
    check(TruckUpgrades.level(session.truck_state,&"nitro")==1 and hunter.inventory.coins==nitro_coins-3200,"nitro boosters bought")
    check(jeep.kits[&"nitro"].visible,"the nitro pods are fitted")
    jeep.command={"drive":Vector2(0,-1),"sprint":false,"time":Time.get_ticks_msec()}
    # A stand-in driver (peer 2), so the host's own idle keyboard input does not overwrite the command.
    jeep.occupants[0]=2
    jeep.global_position+=Vector3(0,.5,0)
    await physics(30)
    var plain_tank: float=jeep.nitro
    jeep.command={"drive":Vector2(0,-1),"sprint":true,"time":Time.get_ticks_msec()}
    var worst_pitch: float=0.0;var worst_roll: float=0.0;var top: float=0.0
    for i in 190:
        await physics_frame
        jeep.command["time"]=Time.get_ticks_msec()
        worst_pitch=maxf(worst_pitch,absf((-jeep.global_basis.z).y));worst_roll=maxf(worst_roll,absf(jeep.global_basis.x.y))
        top=maxf(top,jeep.linear_velocity.length())
        if i==80:
            check(jeep.boosting and jeep.nitro<plain_tank-.1,"holding Shift burns the nitro tank")
            print("NITRO pitch=",worst_pitch," roll=",worst_roll," top=",top)
    check(worst_pitch<.3 and worst_roll<.2,"full nitro does not flip the truck (pitch %.2f, roll %.2f)" % [worst_pitch,worst_roll])
    check(jeep.global_basis.y.dot(Vector3.UP)>.85,"the truck is still on its wheels after the burn")
    jeep.command={"drive":Vector2(0,0),"sprint":false,"time":Time.get_ticks_msec()}
    jeep.occupants[0]=0

    # --- Boat kit and the ocean gate --------------------------------------------------------------
    session.request_action("return_lobby")
    check(await loaded(),"back at camp")
    session.truck_state[String(&"boat")]=0
    jeep.set_upgrades(session.truck_state)
    hunter.global_position=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition").global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","ocean")
    hunter.global_position=stall("garage").global_position+Vector3(0,.6,0)
    check(session.phase=="lobby","the ocean is closed until the boat kit is fitted")
    buy("boat")
    check(TruckUpgrades.level(session.truck_state,&"boat")==1 and jeep.kits[&"boat"].visible,"boat kit bought and fitted")
    check(jeep.hull_min.x<-3.0 and jeep.hull_max.y>13.0,"the boarding box grows with the pontoons and the tower")
    # --- The absurd builds ---------------------------------------------------------------------------
    var everything: Dictionary=TruckUpgrades.fresh()
    for id in TruckUpgrades.ORDER: everything[String(id)]=TruckUpgrades.LEVELS[id]
    session.truck_state=everything
    jeep.set_upgrades(everything)
    var all_fitted: bool=true
    for id in TruckUpgrades.BUILDS: all_fitted=all_fitted and jeep.kits.has(id) and jeep.kits[id].visible
    check(all_fitted,"all nine builds are fitted and visible")
    # The galleon: unfolded, it opens the aft deck, lengthens the ride box and makes the stairs solid.
    jeep.boat_deploy=1.0;jeep.floating=true
    for i in 12: jeep._update_kits(.2)
    check(jeep._deck_open and jeep.ride_max.z>14.0 and jeep.ride_min.x<-3.5,"the unfolded galleon opens the aft terrace and widens the ride box")
    var deck_solid: bool=true
    for shape in jeep.kit_shapes.get(&"boat_deck",[]): deck_solid=deck_solid and not shape.disabled
    check(deck_solid,"the terrace floor, rails and stairs are solid once unfolded")
    check(jeep.carries(jeep.to_global(Vector3(0,2.6,11.0))),"a hunter standing on the terrace is carried")
    # The glass sphere winches down while afloat, then it can be boarded and carries its occupants.
    for i in 5: jeep._host_extras(1.0)
    for i in 12: jeep._update_kits(.3)
    check(jeep.sphere_deploy>.99 and jeep._sphere_open,"the glass sphere lowers while the boat floats")
    check(jeep.carries(jeep.to_global(jeep.Extras.SPHERE_LANDING+Vector3(0,.8,0))),"a diver inside the sphere is carried")
    jeep.floating=false
    for i in 5: jeep._host_extras(1.0)
    for i in 12: jeep._update_kits(.3)
    check(jeep.sphere_deploy<.01 and not jeep._sphere_open,"the sphere winches back up when the boat leaves the water")
    jeep.boat_deploy=0.0
    for i in 12: jeep._update_kits(.3)
    check(not jeep._deck_open,"the terrace folds away with the boat")
    # The grill heals everyone aboard.
    var saved_phase: String=session.phase
    session.phase="hunt"
    hunter.health=40;hunter.riding=true
    for i in 10: jeep._host_extras(.5)
    check(hunter.health>=60 and jeep.grill_active,"the hospital barbecue heals the crew (40 -> %d)" % hunter.health)
    # The horn: scares even a predator and then needs to recharge.
    var wolf=session._make_animal(901,"bear",jeep.to_global(Vector3(0,0,-30)))
    wolf.set_physics_process(false)
    check(jeep.blast_horn(1) and wolf.scare_clock>0.0 and jeep.horn_cooldown>10.0,"the gramophone scares a nearby bear")
    check(not jeep.blast_horn(1),"the horn has to recharge")
    session.phase=saved_phase
    hunter.riding=false
    # The rotor lifts the truck.
    jeep.global_position+=Vector3(0,1.0,0)
    var y0: float=jeep.global_position.y
    jeep.occupants[0]=2
    jeep.command={"drive":Vector2(0,0),"rotor":true,"time":Time.get_ticks_msec()}
    for i in 120:
        await physics_frame
        jeep.command["time"]=Time.get_ticks_msec()
    check(jeep.rotor_on and jeep.global_position.y>y0+3.0 and jeep.rotor_fuel<.95,"the flying oak rises on the rotor (%.1f m)" % (jeep.global_position.y-y0))
    jeep.command={"drive":Vector2(0,0),"rotor":false,"time":Time.get_ticks_msec()}
    jeep.occupants[0]=0
    # The harpoon: double damage only against marine animals.
    var harpoon: WeaponDefinition=EquipmentCatalog.weapon(&"harpoon")
    var shark=session._make_animal(902,"reef_shark",Vector3(0,0,-140));shark.set_physics_process(false)
    var boar_def=session._make_animal(903,"boar",Vector3(0,0,-150));boar_def.set_physics_process(false)
    check(harpoon and harpoon.reload_seconds>=8.0 and harpoon.magazine_size==1,"the harpoon reloads very slowly")
    check(session.damage_against(harpoon,230,shark)==460 and session.damage_against(harpoon,230,boar_def)==230,"the harpoon does +100% damage to sea animals only")
    pass

    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
