extends SceneTree
var scene
var session
var checks: int=0
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await physics_frame
func loaded() -> void:
    for i in 3000:
        if session.phase!="loading": return
        await process_frame
    check(false,"bounded world loading finishes")
func start_swamp() -> void:
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    session.local_hunter().global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","swamp")
func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene;session=root.get_node("NetworkSession")
    await frames(4);scene.menu.resume()
    var hunter=session.local_hunter()
    scene.map_menu.select_map("swamp")
    var locale=root.get_node("LocaleSettings");locale.set_language("ro")
    check(scene.map_menu.forest_title.text=="MLAȘTINĂ","Swamp selectable in Romanian")
    locale.set_language("en");check(scene.map_menu.forest_title.text=="SWAMP","Swamp selectable in English")
    var friend=session._spawn_player(2,"Friend");friend.world_ready=true
    session._action(2,"start_hunt","swamp");check(session.phase=="lobby","client cannot launch Swamp")
    session._peer_disconnected(2)
    hunter.global_position=Vector3(15,1,15);session.request_action("start_hunt","swamp")
    check(session.phase=="lobby","host must stand at fire for Swamp")
    start_swamp();check(session.phase=="loading" and session.world_id=="swamp","Swamp enters shared loading")
    check(not session.jeep.enabled and not hunter.world_ready,"loading freezes vehicle and hunter")
    await loaded()
    check(session.phase=="hunt" and scene.world_router.active_id=="swamp","Swamp commits an expedition")
    var map=session.forest
    check(map.built and map.trees.size()>3000,"1200m wetland is fully built with streamed trees")
    check(map.height_at(0,0)>1 and hunter.global_position.y>1,"arrival is dry and elevated")
    check(session.jeep.global_position.distance_to(hunter.global_position)<12,"four-seat jeep arrives alongside hunters")
    check(map.has_node("Water") and map.water_material!=null,"animated water material exists")
    var sounds=scene.world_router.active.find_children("*","AudioStreamPlayer",true,false)
    check(not sounds.is_empty() and sounds[0].playing and sounds[0].stream.loop_mode==1,"original Swamp ambience loops during exploration")
    var water_points:=0;var bank_points:=0
    for x in range(-400,400,25):
        for z in range(-400,400,25):
            if map.height_at(x,z)<-.2: water_points+=1
            if map.height_at(x,z)>.3: bank_points+=1
    check(water_points>200 and bank_points>200,"height field contains water and dry banks")
    check(map.mud_factor(Vector3.ZERO)==0 and map.mud_factor(Vector3(50,2,50))==0,"dry landing and raised decks preserve grip")
    check(scene.world_router.active.has_node("AbandonedHut") and scene.world_router.active.has_node("OldWatchtower") and scene.world_router.active.has_node("CrocodileLair"),"three distinct exploration landmarks exist")
    check(scene.world_router.active.find_children("Boardwalk*","Node3D",true,false).size()==3,"three solid jeep-width boardwalks link the banks")
    check(session.animals.size()==24,"host populates initial Swamp wildlife")
    var twin=load("res://world/swamp/swamp_map.gd").new();scene.add_child(twin)
    twin.set_seed(map.current_seed)
    check(is_equal_approx(twin.height_at(135,-216),map.height_at(135,-216)),"same seed produces identical Swamp elevation on another peer")
    twin.queue_free()
    var kinds: Dictionary={}
    for a in session.animals.values(): kinds[a.definition.id]=true;a.set_physics_process(false)
    check(kinds.size()==5,"all five species including rare lair crocodile exist")
    var guard_id: int=0
    for a in session.animals.values():
        if a.get_meta("lair_guard",false): guard_id=a.animal_id
    session._spawn_near_player()
    check(session.animals.has(guard_id),"distant lair guardian persists during exploration")
    for a in session.animals.values(): a.set_physics_process(false)
    var wet:=Vector3.ZERO
    for x in range(40,250,10):
        for z in range(-240,-40,10):
            var point:=Vector3(x,map.height_at(x,z),z)
            if map.water_depth(point)>.75 and map.trees.all(func(t: Vector3) -> bool: return Vector2(t.x-point.x,t.z-point.z).length()>8): wet=point;break
        if wet!=Vector3.ZERO: break
    check(wet!=Vector3.ZERO,"a clear shallow-water test habitat exists")
    var swimmer=session.spawn_animal(&"crocodile",wet);swimmer.global_position=wet;swimmer.heading=Vector3.ZERO;swimmer.wander_clock=100
    swimmer.home=wet;await frames(45)
    check(swimmer.global_position.y>-.2,"aquatic predator floats above the submerged ground")
    check(swimmer.animation!=null and swimmer.clips.size()>=5,"crocodile contains five rigged animation clips")
    session.remove_animal(swimmer.animal_id)
    hunter.set_physics_process(false)
    var walker=session._spawn_player(2,"Walker");walker.world_ready=true;walker.local_player=false
    walker.global_position=Vector3(0,1.17,0);walker.velocity=Vector3.ZERO
    for i in 30:
        session._accept_input(2,{"seq":i+1,"direction":Vector3.RIGHT,"drive":Vector2.ZERO})
        await frames(1)
    var dry_distance: float=walker.global_position.x
    walker.global_position=wet+Vector3.UP*.05;walker.velocity=Vector3.ZERO
    for i in 30:
        session._accept_input(2,{"seq":i+31,"direction":Vector3.RIGHT,"drive":Vector2.ZERO})
        await frames(1)
    print("PACE dry=",dry_distance," wet=",walker.global_position.x-wet.x)
    check(walker.global_position.x-wet.x<dry_distance*.8,"actual walking slows in wet mud")
    session._peer_disconnected(2)
    var catalog=load("res://data/animal_catalog.gd")
    var rng:=RandomNumberGenerator.new();rng.seed=824;var count: Dictionary={}
    for i in 15000:
        var id=catalog.roll(rng,"swamp").id;count[id]=count.get(id,0)+1
    var previous:=INF;var hp:=0;var value:=0
    for entry in catalog.SWAMP_ANIMALS:
        check(count[entry.id]<previous,str(entry.id)+" spawn rarity increases")
        check(entry.max_health>hp and catalog.loot(entry.loot_id).sell_value>value,str(entry.id)+" strength and loot value increase")
        previous=count[entry.id];hp=entry.max_health;value=catalog.loot(entry.loot_id).sell_value
    hunter.set_physics_process(false);hunter.control_enabled=false
    # Elevated controlled ground isolates predator behavior from random terrain.
    var stage:=StaticBody3D.new();stage.position=Vector3(0,29.5,-100);scene.add_child(stage)
    var c:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,1,200);c.shape=box;stage.add_child(c);await frames(3)
    for kind in [&"snake",&"crocodile",&"ancient_crocodile"]:
        hunter.health=100;hunter.global_position=Vector3(0,30,-100)
        var animal=session.spawn_animal(kind,Vector3(0,0,-100));animal.global_position=Vector3(0,30,-113);animal.home=animal.global_position
        # The aquatic support is relevant only near water level, not on raised decks.
        var before: float=animal.global_position.distance_to(hunter.global_position)
        await frames(45)
        check(animal.target_peer==1 and animal.global_position.distance_to(hunter.global_position)<before-1,str(kind)+" hunts instead of fleeing")
        animal.global_position=Vector3(0,30,-101.4);animal.velocity=Vector3.ZERO;animal.attack_clock=0
        await frames(38);check(hunter.health<100,str(kind)+" applies an animated bite after windup")
        animal.set_physics_process(false);session.remove_animal(animal.animal_id)
    hunter.inventory.items.clear();hunter.inventory.coins=0
    var frog=session.spawn_animal(&"frog",Vector3(60,0,-80));frog.set_physics_process(false)
    check(not frog.model.find_children("*","Skeleton3D",true,false).is_empty() and frog.animation!=null,"frog has imported articulated skeleton and animation")
    frog.take_damage(999,hunter.global_position,1)
    hunter.set_physics_process(false)
    hunter.control_enabled=true # Restore input after the isolated predator checks.
    hunter.global_position=frog.global_position+Vector3(1.5,0,0)
    session.set_physics_process(false)
    session.request_action("harvest_start",str(frog.animal_id))
    check(session.is_harvesting(1),"Swamp corpse begins a manual harvest")
    # Frogs take two slippery slash waves and one yank, played through the host.
    var bot=load("res://tests/harvest_bot.gd")
    var clock: Dictionary={}
    for i in 3:
        hunter.command={"harvest":true,"time":Time.get_ticks_msec()}
        if not bool(session.harvest_state(1).get("active",false)): break
        bot.play_step(func() -> Dictionary: return session.harvest_state(1),
            func(point: Vector2, stamp: int) -> void: session._harvest_blade(1,point,stamp),
            func(value: String) -> void: session.request_action("harvest_click",value),
            func(seconds: float) -> void: hunter.command={"harvest":true,"time":Time.get_ticks_msec()};session._tick_harvests(seconds),
            clock)
        check(frog.harvest_completed==i+1,"manual Swamp step "+str(i+1)+" advances once")
    check(frog.harvested and hunter.inventory.items.size()==1,"Swamp loot requires manual cuts on the animal")
    session.set_physics_process(true);hunter.set_physics_process(true)
    hunter.global_position=session.jeep.to_global(Vector3(0,.2,2.55));session.request_action("deposit")
    check(session.trunk.size()==1 and hunter.inventory.items.is_empty(),"Swamp loot enters owned shared cargo")
    session.request_action("return_lobby");await loaded()
    check(session.phase=="lobby" and session.trunk.size()==1 and session.animals.is_empty(),"return unloads Swamp and preserves cargo")
    var seller
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="sell": seller=stall
    session.jeep.reset_state(Transform3D(Basis.IDENTITY,seller.global_position+Vector3(4,.6,0)));hunter.global_position=seller.interaction_position()
    var pristine: int=AnimalCatalog.loot(&"frog_hide__s5").sell_value
    session.request_action("sell_trunk");check(hunter.inventory.coins==pristine and session.trunk.is_empty(),"seller pays owner for pristine Swamp loot")
    var wallet: int=hunter.inventory.coins
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    hunter.global_position=fire.global_position+Vector3(0,.5,3.4);session.request_action("start_hunt","forest");await loaded()
    check(session.phase=="hunt" and session.world_id=="forest","Forest still loads after a Swamp expedition")
    check(session.animals.values().all(func(a) -> bool: return a.definition.id in [&"rabbit",&"deer",&"boar",&"wolf",&"bear"]),"Forest spawns only its own fauna")
    check(hunter.inventory.coins==wallet,"wallet persists across the two biome expeditions")
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
