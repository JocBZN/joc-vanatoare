extends SceneTree
## The ocean map: terrain and water contract, the truck as a boat, swimming and
## the diving suit, the sea creatures (spawning, hunting, the lunge, the eel's
## shock, floating corpses, skinning at sea), loot and text, minimap and map menu.
var scene
var session
var hunter
var jeep
var ocean
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
    for i in 7200:
        if session.phase!="loading": return true
        await process_frame
    return false
## A point of open water at least `depth` deep, searched outward from a start.
func deep_point(start: Vector3,depth: float) -> Vector3:
    var p:=start
    for pass_index in 2:
        p=start
        for i in 400:
            var open: bool=ocean.water_depth(p)>=depth and Vector2(p.x,p.z).length()>260.0
            # Open sea all round (the boat tests sail some distance in a straight line).
            if open and pass_index==0:
                for k in 8:
                    var around:=p+Vector3(sin(k*TAU/8.0),0,cos(k*TAU/8.0))*120.0
                    if ocean.water_depth(around)<6.0: open=false
            if open: return p
            p+=Vector3(53,0,-31)
            if absf(p.x)>900 or absf(p.z)>900: p=Vector3(randf_range(-700,700),0,randf_range(-700,700))
    return p

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    await frames(5)
    hunter=session.local_hunter();jeep=session.jeep
    var catalog=load("res://data/animal_catalog.gd")
    var locale=root.get_node("LocaleSettings")

    # --- Content and text ---------------------------------------------------------------------
    check(WorldCatalog.is_hunt("ocean") and WorldRouter.PATHS.has("ocean"),"the ocean is a hunt destination")
    check(catalog.OCEAN_ANIMALS.size()==18 and catalog.boss_for("ocean").id==&"megalodon" and catalog.bosses_for("ocean").size()==2 and catalog.bosses_for("ocean")[1].id==&"colossal_squid","eighteen sea creatures and two bosses: the megalodon and the colossal squid")
    var text_ok: bool=true;var loot_ok: bool=true;var swim_ok: bool=true
    for entry: AnimalDefinition in catalog.OCEAN_ANIMALS+catalog.bosses_for("ocean"):
        text_ok=text_ok and locale.text(entry.display_name)!=entry.display_name
        var item=catalog.loot(entry.loot_id)
        loot_ok=loot_ok and item!=null and tr(item.display_name)!=item.display_name and catalog.raw_hide(entry.loot_id,0)!=null
        swim_ok=swim_ok and entry.swimmer and entry.aquatic and ResourceLoader.exists(entry.model_path)
    check(text_ok,"every sea creature has a translated name")
    check(loot_ok,"every sea creature has a hide that sells and a translated name")
    check(swim_ok,"every sea creature swims, is aquatic and has a model")
    var passive: int=0
    for entry: AnimalDefinition in catalog.OCEAN_ANIMALS:
        if not entry.aggressive: passive+=1
    check(passive==4,"four peaceful creatures: dolphin, turtle, manta ray and grouper")
    for id in catalog.TROPHY_IDS:
        loot_ok=loot_ok and catalog.loot(id)!=null and tr(String(id))!=String(id)
    check(loot_ok,"the new trophies exist and are named")
    check(locale.text("MAP_OCEAN")!="MAP_OCEAN" and locale.text("OCEAN_NEEDS_BOAT")!="OCEAN_NEEDS_BOAT","ocean map texts exist")

    # --- Map menu gate --------------------------------------------------------------------------
    scene.map_menu.select_map("ocean")
    scene.map_menu.refresh()
    check(scene.map_menu.start_button.disabled,"the map menu blocks the ocean without the boat kit")
    for build in ["bar","tower","nitro","boat"]: session.truck_state[build]=1
    scene.map_menu.refresh()
    var at_wheel_ready: bool=not scene.map_menu.start_button.disabled or not session.is_host() or session.phase!="lobby"
    check(at_wheel_ready,"with the boat kit the ocean can be started from the menu")

    # --- Load the ocean --------------------------------------------------------------------------------
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","ocean")
    check(await loaded() and session.phase=="hunt" and session.world_id=="ocean","the ocean loads as a hunt")
    ocean=scene.world_router.map()
    check(ocean.has_method("map_places") and session.forest==ocean,"the router hands out the ocean map")
    var near_camp: bool=false
    for a in session.animals.values():
        if Vector2(a.global_position.x,a.global_position.z).length()<150.0: near_camp=true
    check(not near_camp,"nothing lurks right off the camp island at the start")
    var starting: int=session.animals.size()
    for a in session.animals.values(): a.set_physics_process(false)
    hunter.control_enabled=false

    # --- Terrain and water contract -----------------------------------------------------------------
    check(ocean.islands.size()>=12,"a scatter of islands (%d)" % ocean.islands.size())
    check(ocean.height_at(0,-4.5)>1.0 and ocean.height_at(0,-4.5)<1.5 and ocean.slope_at(0,-4.5)<3.0,"the camp island is flat, just above the water")
    check(ocean.water_depth(Vector3(0,0,-4.5))==0.0 and ocean.water_depth(Vector3(0,0,-200))>0.0,"the camp is dry and the sea beyond it is water")
    var sea: Vector3=deep_point(Vector3(300,0,-300),20.0)
    check(ocean.water_depth(sea)>=20.0 and ocean.water_submersion(Vector3(sea.x,-3,sea.z))==3.0 and ocean.water_submersion(Vector3(sea.x,2,sea.z))==0.0,"depth and submersion are consistent")
    var sample: Array=[Vector2(100,100),Vector2(-310,70),Vector2(700,-640)]
    var before: Array=[]
    for p in sample: before.append(ocean.height_at(p.x,p.y))
    ocean.set_seed(ocean.current_seed)
    var same: bool=true
    for i in sample.size(): same=same and is_equal_approx(before[i],ocean.height_at(sample[i].x,sample[i].y))
    check(same,"the same seed gives the same sea")
    check(ocean.flora_counts.get("branching",0)>3000 and ocean.flora_counts.get("kelp",0)>1500 and ocean.flora_counts.get("palm",0)>300,"corals, kelp forests and palms were planted")
    check(ocean.landmarks.size()>=4 and ocean.wreck_spots.size()>=1,"a lighthouse, wrecks and ruins mark the map")
    check(ocean.heights.size()==(ocean.CELLS+1)*(ocean.CELLS+1),"the height grid exists for the minimap")
    check(ocean.clip_rings.size()==ocean.CLIP_LEVELS,"the water is a clipmap of rings")
    check(ocean.has_method("map_places") and ocean.map_places().size()>=4,"the big map has place names")
    check(session.world.world_router.active.environment!=null,"the ocean has its own atmosphere")

    # --- The truck arrives on the island and is a boat -----------------------------------------------------
    await physics(90)
    check(jeep.global_position.y>.4 and jeep.global_position.y<3.0,"the truck stands on the camp island")
    check(jeep.boat_deploy==0.0 and not jeep.kits[&"boat"].get_node("HullL").visible,"on dry land the boat kit stays folded away")
    jeep.reset_state(Transform3D(Basis.IDENTITY,Vector3(sea.x,.6,sea.z)))
    jeep.set_upgrades(session.truck_state)
    await physics(240)
    check(jeep.floating and jeep.global_position.y<.4 and jeep.global_position.y>-1.8,"the boat floats at the surface (y=%.2f)" % jeep.global_position.y)
    check(jeep.boat_deploy>.95 and jeep.kits[&"boat"].get_node("HullL").visible and absf(jeep.kits[&"boat"].get_node("HullL").scale.x-1.0)<.1,"touching the water unfolds the pontoons")
    check(jeep.snapshot().dep>.95,"the deployment is replicated")
    var rest_y: float=jeep.global_position.y
    await physics(120)
    check(absf(jeep.global_position.y-rest_y)<.4,"the floating truck settles instead of bobbing wildly")
    jeep.occupants[0]=2
    jeep.command={"drive":Vector2(0,-1),"sprint":false,"time":Time.get_ticks_msec()}
    for i in 240:
        await physics_frame
        jeep.command["time"]=Time.get_ticks_msec()
    var cruise: float=jeep.linear_velocity.length()
    check(cruise>5.0,"the propeller drives the boat (%.1f m/s)" % cruise)
    var heading_before: Vector3=-jeep.global_basis.z
    jeep.command={"drive":Vector2(1,-1),"sprint":false,"time":Time.get_ticks_msec()}
    for i in 120:
        await physics_frame
        jeep.command["time"]=Time.get_ticks_msec()
    check((-jeep.global_basis.z).dot(heading_before)<.97,"the wheel turns the boat")
    jeep.command={}
    jeep.occupants[0]=0
    await physics(360)
    check(jeep.linear_velocity.length()<cruise*.5,"with nobody at the helm the boat drifts to a stop")
    var up_after: float=jeep.global_basis.y.dot(Vector3.UP)
    check(up_after>.9,"the boat stays upright")
    # Faster with the engine upgrades: more thrust means a higher top speed.
    session.truck_state["accel"]=3;session.truck_state["speed"]=3
    jeep.set_upgrades(session.truck_state)
    jeep.occupants[0]=2
    jeep.command={"drive":Vector2(0,-1),"sprint":false,"time":Time.get_ticks_msec()}
    for i in 420:
        await physics_frame
        jeep.command["time"]=Time.get_ticks_msec()
    check(jeep.linear_velocity.length()>cruise*1.15,"the engine upgrades make the boat faster (%.1f vs %.1f m/s)" % [jeep.linear_velocity.length(),cruise])
    jeep.command={};jeep.occupants[0]=0
    jeep.reset_state(Transform3D(Basis.IDENTITY,Vector3(0,1.7,-4.5)))
    await physics(300)
    check(jeep.boat_deploy<.1 and not jeep.kits[&"boat"].get_node("HullL").visible,"back on the beach the kit folds away again")

    # --- Swimming and the diving suit ---------------------------------------------------------------------
    var DivingSuit=hunter.DivingSuit
    check(DivingSuit.is_dressed(hunter.visual),"hunters wear the diving suit in the ocean")
    check(not hunter.visual.get_node("Hat").visible and not hunter.visual.get_node("BackpackMount").visible,"the suit replaces the hat and the backpack")
    var tank_nodes: Array=hunter.visual.find_children("Tanks","Node3D",true,false)
    check(tank_nodes.size()==1,"twin air tanks on the back")
    var friend=session._spawn_player(2,"Friend");friend.world_ready=true;friend.set_physics_process(true)
    await frames(3)
    check(DivingSuit.is_dressed(friend.visual) and DivingSuit.accent_for(1)!=DivingSuit.accent_for(2),"every diver gets their own stripe colour")
    hunter.global_position=Vector3(sea.x,3.0,sea.z)
    hunter.velocity=Vector3.ZERO
    await physics(150)
    check(hunter.swimming and hunter.global_position.y<-.4 and hunter.global_position.y>-2.4,"stepping into deep water you float with your head in the air (y=%.2f)" % hunter.global_position.y)
    hunter.global_position=Vector3(sea.x,-10.0,sea.z)
    hunter.velocity=Vector3.ZERO
    await physics(90)
    check(hunter.swimming and absf(hunter.global_position.y+10.0)<1.2,"deep down you hang in the water, you do not sink (y=%.2f)" % hunter.global_position.y)
    for i in 8:
        hunter.velocity=Vector3(0,-.6,-3.2)
        await physics_frame
    check(hunter._swim_lean<-.4,"a swimming diver lies prone (lean %.2f)" % hunter._swim_lean)
    hunter.global_position=Vector3(0,3.0,-120.0)
    while ocean.water_depth(hunter.global_position)<=0.2 and hunter.global_position.z<-5: hunter.global_position.z+=3
    var shore: Vector3=hunter.global_position
    for i in 60: shore.z+=2.0
    var shallow: Vector3=Vector3(0,-.2,0)
    for z in range(-60,-200,-4):
        var depth: float=ocean.water_depth(Vector3(0,0,z))
        if depth>.25 and depth<.45: shallow=Vector3(0,ocean.height_at(0,z)+.05,z);break
    hunter.global_position=shallow
    hunter.velocity=Vector3.ZERO
    await physics(30)
    check(not hunter.swimming,"wading in the shallows you still walk")
    DivingSuit.undress(hunter.visual)
    check(not DivingSuit.is_dressed(hunter.visual) and hunter.visual.get_node("Hat").visible and hunter.visual.get_node("BackpackMount").visible,"taking the suit off restores the hunter")
    await frames(2)
    check(DivingSuit.is_dressed(hunter.visual),"the suit goes back on while in the ocean")

    # --- The sea is crowded -------------------------------------------------------------------------------------
    check(starting>=30,"the sea starts crowded (%d creatures)" % starting)
    var all_sea: bool=true;var all_wet: bool=true;var kinds: Dictionary={}
    for a in session.animals.values():
        all_sea=all_sea and a.definition.swimmer
        all_wet=all_wet and ocean.water_depth(a.global_position)>2.0 and a.global_position.y<-.5
        kinds[a.definition.id]=true
    check(all_sea and all_wet,"every creature starts in open water, underwater")
    check(kinds.size()>=5,"many different species (%d)" % kinds.size())
    var boss_ids: Array=[]
    for boss in session.living_bosses(): boss_ids.append(boss.definition.id)
    check(boss_ids.has(&"megalodon") and boss_ids.has(&"colossal_squid"),"both ocean bosses are out there: the megalodon and the colossal squid")

    # --- Hunting AI -----------------------------------------------------------------------------------------
    for a in session.animals.values(): session.remove_animal(a.animal_id)
    session.spawn_clock=99999.0
    hunter.health=100;hunter.global_position=Vector3(sea.x,-3.0,sea.z);hunter.velocity=Vector3.ZERO
    hunter.world_ready=true;hunter.seat_index=-1
    var shark=session.spawn_animal(&"great_white",Vector3(sea.x+24,-6,sea.z))
    shark.global_position=Vector3(sea.x+24,-5.0,sea.z);shark.home=shark.global_position;shark.velocity=Vector3.ZERO
    var closing: float=shark.global_position.distance_to(hunter.global_position)
    var lunged: bool=false;var hurt_at: int=-1
    for i in 720:
        await physics_frame
        if shark.lunge_time>0.0 or shark.behavior=="Leap": lunged=true
        if hunter.health<100 and hurt_at<0: hurt_at=i
        if hurt_at>=0 and i>hurt_at+40: break
    check(shark.target_peer==1,"the shark notices the swimmer")
    check(lunged,"the shark strikes with a lunge")
    check(hunter.health<100,"the shark hurts the swimmer (health %d)" % hunter.health)
    check(shark.global_position.y<1.0,"the shark stays in the water")
    # Biting breaks the shark off for a moment, then it comes round again.
    check(shark.retreat_clock>0.0 or shark.behavior in ["Retreat","Circle","Pursue","Pounce","Leap","Attack"],"the shark keeps hunting after the bite (%s)" % shark.behavior)
    # Safe on the beach and on the truck: sea creatures only hunt people in the water.
    hunter.health=100;hunter.global_position=Vector3(0,2.0,-4.5);hunter.velocity=Vector3.ZERO
    shark.global_position=Vector3(sea.x,-5,sea.z)
    await physics(120)
    check(shark.target_peer!=1 or not shark._eligible(hunter),"a person on dry land is not prey")
    check(not shark._eligible(hunter),"dry land is safe")
    session.remove_animal(shark.animal_id)

    # --- Electric eel shock -----------------------------------------------------------------------------------
    hunter.health=100;friend.health=100
    hunter.global_position=Vector3(sea.x,-5.0,sea.z);friend.global_position=Vector3(sea.x+3.0,-5.0,sea.z)
    hunter.velocity=Vector3.ZERO;friend.velocity=Vector3.ZERO
    var eel=session.spawn_animal(&"electric_eel",Vector3(sea.x,-5,sea.z+4))
    eel.global_position=Vector3(sea.x+1.5,-5.0,sea.z+3.0);eel.home=eel.global_position
    for i in 300:
        await physics_frame
        hunter.global_position=Vector3(sea.x,-5.0,sea.z);friend.global_position=Vector3(sea.x+3.0,-5.0,sea.z)
        if hunter.health<100 and friend.health<100: break
    check(hunter.health<100 and friend.health<100,"the electric eel shocks everyone around it (%d, %d)" % [hunter.health,friend.health])
    session.remove_animal(eel.animal_id)

    # --- Corpses float and can be skinned at sea ------------------------------------------------------------------
    friend.global_position=Vector3(0,3,-4.5)
    hunter.health=100;hunter.global_position=Vector3(sea.x+40,-3.0,sea.z)
    var fish=session.spawn_animal(&"barracuda",Vector3(sea.x+40,-9,sea.z+3))
    fish.set_physics_process(true);fish.global_position=Vector3(sea.x+40,-9.0,sea.z+3);fish.home=fish.global_position
    fish.take_damage(9999,hunter.global_position,1)
    check(fish.dead and fish.collision_layer==0,"a barracuda can be killed")
    await physics(420)
    check(fish.global_position.y>-1.6,"the dead creature drifts up to the surface (y=%.2f)" % fish.global_position.y)
    hunter.global_position=fish.global_position+Vector3(1.2,-.2,0)
    hunter.velocity=Vector3.ZERO
    await physics(10)
    session.request_action("harvest_start",str(fish.animal_id))
    check(session.harvest_jobs.has(1),"a diver can start skinning at the surface")
    var hang: float=hunter.global_position.y
    await physics(90)
    check(absf(hunter.global_position.y-hang)<.6,"the skinning diver does not sink")
    session.request_action("harvest_cancel")
    session.remove_animal(fish.animal_id)

    # --- Every model builds and animates -----------------------------------------------------------------------------
    session.spawn_clock=99999.0
    var models_ok: bool=true;var animated: int=0
    var bad: Array=[]
    for entry: AnimalDefinition in catalog.OCEAN_ANIMALS+catalog.bosses_for("ocean"):
        var specimen=session.spawn_animal(entry.id,Vector3(sea.x-60,-10,sea.z+60))
        if specimen==null: models_ok=false;bad.append(String(entry.id));continue
        specimen.set_physics_process(false)
        specimen.velocity=Vector3(0,0,-entry.run_speed*.5)
        await frames(4)
        var meshes: int=specimen.model.find_children("*","MeshInstance3D",true,false).size()
        if meshes<4: models_ok=false;bad.append(String(entry.id))
        else: animated+=1
        session.remove_animal(specimen.animal_id)
    check(models_ok and animated==20,"all 20 sea models build and animate (%d, bad: %s)" % [animated,bad])

    # --- Peaceful creatures flee -----------------------------------------------------------------------------------------
    hunter.health=100;hunter.global_position=Vector3(sea.x,-4.0,sea.z);hunter.velocity=Vector3.ZERO
    var dolphin=session.spawn_animal(&"dolphin",Vector3(sea.x+14,-5,sea.z))
    dolphin.global_position=Vector3(sea.x+14,-5.0,sea.z);dolphin.home=dolphin.global_position;dolphin.velocity=Vector3.ZERO
    var start_gap: float=dolphin.global_position.distance_to(hunter.global_position)
    await physics(90)
    check(dolphin.global_position.distance_to(hunter.global_position)>start_gap+8.0 and dolphin.target_peer==0 and hunter.health==100,"a dolphin swims away from a diver and never attacks")
    dolphin.take_damage(5,hunter.global_position,1)
    check(dolphin.flee_until>0.0,"a shot dolphin flees")
    session.remove_animal(dolphin.animal_id)

    # --- New dangerous creatures -----------------------------------------------------------------------------------------------
    hunter.health=100;hunter.global_position=Vector3(sea.x,-4.0,sea.z);hunter.velocity=Vector3.ZERO
    var sword=session.spawn_animal(&"swordfish",Vector3(sea.x+30,-5,sea.z))
    sword.global_position=Vector3(sea.x+30,-5.0,sea.z);sword.home=sword.global_position;sword.velocity=Vector3.ZERO
    var stabbed: bool=false
    for i in 480:
        await physics_frame
        if hunter.health<100: stabbed=true;break
    check(stabbed,"the swordfish charges and stabs a swimmer (health %d)" % hunter.health)
    session.remove_animal(sword.animal_id)
    hunter.health=100;hunter.global_position=Vector3(sea.x,-1.2,sea.z);hunter.velocity=Vector3.ZERO
    var jelly=session.spawn_animal(&"man_o_war",Vector3(sea.x+3,-1,sea.z))
    jelly.global_position=Vector3(sea.x+3.0,-1.0,sea.z);jelly.home=jelly.global_position;jelly.velocity=Vector3.ZERO
    for i in 240:
        await physics_frame
        hunter.global_position=Vector3(sea.x,-1.2,sea.z)
        if hunter.health<100: break
    check(hunter.health<100,"the man o' war stings a swimmer at the surface (health %d)" % hunter.health)
    session.remove_animal(jelly.animal_id)

    # --- The colossal squid ---------------------------------------------------------------------------------------------------------
    var squid_def: AnimalDefinition=catalog.animal(&"colossal_squid")
    check(squid_def.boss and squid_def.max_health>=5000 and squid_def.bite_reach>=14.0 and squid_def.trophies.size()>=5,"the colossal squid is a tough boss with trophies")
    hunter.health=100;hunter.global_position=Vector3(sea.x,-8.0,sea.z);hunter.velocity=Vector3.ZERO
    var squid=session.spawn_animal(&"colossal_squid",Vector3(sea.x+12,-9,sea.z))
    squid.global_position=Vector3(sea.x+12,-9.0,sea.z);squid.home=squid.global_position;squid.velocity=Vector3.ZERO
    check(squid.model.arms.size()==8 and squid.model.tentacles.size()==2 and squid.model.tentacles[0].segs.size()==14,"the squid has eight arms and two long feeding tentacles")
    var drops: int=0;var last_health: int=hunter.health;var combo_seen: bool=false
    for i in 420:
        await physics_frame
        hunter.global_position=Vector3(sea.x,-8.0,sea.z)
        if hunter.health<last_health: drops+=1;last_health=hunter.health
        if squid.attack_combo>0: combo_seen=true
        if drops>=2 or hunter.health<=0: break
    check(combo_seen and drops>=2,"the squid lashes in a tentacle combo (%d hits)" % drops)
    # Badly hurt, it bolts backwards in a cloud of ink.
    hunter.health=100;last_health=100
    squid.health=int(squid.definition.max_health*.4);squid.ink_clock=0.0;squid.attack_clock=0.0
    var inked: bool=false;var gap_before: float=squid.global_position.distance_to(hunter.global_position)
    for i in 120:
        await physics_frame
        hunter.global_position=Vector3(sea.x,-8.0,sea.z)
        if squid.behavior=="Ink": inked=true
    check(inked,"hurt, the squid releases ink and bolts")
    check(squid.global_position.distance_to(hunter.global_position)>gap_before,"the squid jets away from the diver")
    squid.take_damage(999999,hunter.global_position,1)
    await physics(30)
    check(squid.dead and squid.model.arms.size()==8,"the squid can be killed")
    session.remove_animal(squid.animal_id)

    # --- Minimap ---------------------------------------------------------------------------------------------------
    check(scene.minimap._ensure_relief(ocean),"the minimap can paint the ocean from its height grid")

    # --- The boss -------------------------------------------------------------------------------------------------------
    for existing in session.living_bosses(): session.remove_animal(existing.animal_id)
    var first=session.spawn_boss();var second=session.spawn_boss()
    var spawned: Array=[]
    if is_instance_valid(first): spawned.append(first.definition.id)
    if is_instance_valid(second): spawned.append(second.definition.id)
    check(spawned.has(&"megalodon") and spawned.has(&"colossal_squid"),"two bosses wake in turn, one of each (%s)" % [spawned])
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
