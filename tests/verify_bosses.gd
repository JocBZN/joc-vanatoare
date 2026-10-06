extends SceneTree
## The 2.4 km maps, the two bosses (spawning, roaming, sweeping attacks,
## trophies, hides, prices), the relief minimap's data and the new HUD's logic.
var scene
var session
var catalog
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
func start(map_id: String) -> bool:
    var hunter=session.local_hunter()
    if session.phase=="hunt":
        session.request_action("return_lobby")
        if not await loaded(): return false
    var fire=scene.world_router.active.get_node("Camp/GiantCampfire/Expedition")
    hunter.global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt",map_id)
    return await loaded() and session.phase=="hunt" and session.world_id==map_id

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    catalog=load("res://data/animal_catalog.gd")
    await frames(5)
    # --- Content: two bosses, their trophies and prices ----------------------------------
    var bear=catalog.boss_for("forest");var croc=catalog.boss_for("swamp")
    check(bear.id==&"ancient_bear" and croc.id==&"albino_crocodile" and bear.boss and croc.boss,"one boss per map: the Ancient Bear and the Albino Saltwater Crocodile")
    check(croc.aquatic and not bear.aquatic and bear.spawn_weight==0.0 and croc.spawn_weight==0.0,"bosses never come from the ordinary spawn roll")
    var regular_best: int=0
    for entry in catalog.ANIMALS+catalog.SWAMP_ANIMALS:
        regular_best=maxi(regular_best,catalog.loot(entry.loot_id).sell_value)
        check(entry.max_health*2<bear.max_health,entry.id+" is far weaker than a boss")
    check(catalog.loot(bear.loot_id).sell_value>regular_best and catalog.loot(croc.loot_id).sell_value>regular_best,"boss hides are worth more than any ordinary hide")
    for boss in [bear,croc]:
        var total: int=0
        for id in boss.trophies:
            var item=catalog.loot(id)
            check(item!=null and item.space<=2 and item.sell_value>=300 and id in catalog.TROPHY_IDS,"%s trophy %s exists and is valuable" % [boss.id,id])
            if item: total+=item.sell_value
        check(boss.trophies.size()>=6 and total>=2500,"%s drops %d trophies worth %d coins" % [boss.id,boss.trophies.size(),total])
        check(catalog.raw_hide(boss.loot_id,0).sell_value>catalog.raw_hide(&"bear_pelt",0).sell_value,boss.id+" raw hide outsells a bear's")
        check(catalog.animal_for_loot(boss.loot_id)==boss,boss.id+" hide traces back to its boss for the cleaner")
    for locale in ["ro","en"]:
        var text: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/"+locale+".json"))
        var missing: Array=[]
        for key in [bear.display_name,croc.display_name,"BOSS_SPAWNED","BOSS_DOWN","HUD_BOSS_DOWN","MAP_LEGEND_BOSSES","MAP_BOSS_COUNT","MAP_TROPHY","HUD_LOOT","HINT_WALK_DECK","COMPASS_W"]+catalog.TROPHY_IDS+[bear.loot_id,croc.loot_id]:
            if not text.has(String(key)): missing.append(key)
        check(missing.is_empty(),locale+" names bosses, trophies, maps and the HUD "+str(missing))
    # --- The forest: 2.4 km, built fast from one height grid --------------------------------
    check(await start("forest"),"forest expedition loads")
    var map=session.forest
    check(map.SIZE==2400.0 and map.LIMIT>1150.0,"maps are 2.4 km across")
    check(map.heights.size()==(map.CELLS+1)*(map.CELLS+1),"the terrain keeps its height grid for the minimap")
    check(is_equal_approx(map.heights[(map.CELLS/2)*(map.CELLS+1)+map.CELLS/2],map.height_at(0,0)),"the grid matches the height field")
    check(map.trees.size()>15000,"the bigger forest is still dense (%d trees)" % map.trees.size())
    var near: PackedInt32Array=map.trees_near(Vector3(300,0,300),40.0)
    var brute: int=0
    for tree in map.trees:
        if Vector2(tree.x-300,tree.z-300).length()<40.0: brute+=1
    check(near.size()==brute,"tree buckets find exactly the nearby trees (%d)" % brute)
    check(map.rim_at(0,0)==0.0 and map.rim_at(1190,0)>10.0,"hills rise along the edge of the world (%.1f m)" % map.rim_at(1190,0))
    var hunter=session.local_hunter()
    hunter.global_position=Vector3(5000,40,0);hunter.set_physics_process(true);await physics(3)
    check(absf(hunter.global_position.x)<=map.LIMIT+.01,"hunters stay inside the bigger map")
    hunter.global_position=Vector3(2,map.height_at(2,8)+.3,8)
    # --- Bosses: spawning ---------------------------------------------------------------
    var bosses: Array=session.living_bosses()
    check(bosses.size()==1 and bosses[0].definition.id==&"ancient_bear","the hunt wakes one Ancient Bear at once")
    if bosses.is_empty(): print("RESULT ",checks," checks, ",failures," failures");quit(1);return
    var first=bosses[0]
    check(first.global_position.distance_to(hunter.global_position)>=250.0,"it wakes far from the hunters (%.0f m)" % first.global_position.distance_to(hunter.global_position))
    check(session.boss_clock>60.0,"the next boss is minutes away")
    var second=session.spawn_boss()
    check(second!=null and session.living_bosses().size()==2,"a second boss may roam the map")
    check(second==null or second.global_position.distance_to(first.global_position)>=380.0,"the two bosses keep their distance")
    check(session.spawn_boss()==null and session.living_bosses().size()==2,"never more than two bosses at once")
    session.boss_clock=0.0;session._tick_bosses(.1)
    check(session.living_bosses().size()==2 and session.boss_clock>100.0,"the boss clock waits while two are alive")
    for animal in session.animals.values(): animal.set_physics_process(false)
    session.spawn_clock=99.0
    session._spawn_near_player()
    check(is_instance_valid(first) and session.animals.has(first.animal_id),"far-away bosses are never culled")
    # --- Bosses: fighting --------------------------------------------------------------
    var friend=session._spawn_player(2,"Friend");friend.world_ready=true
    # On the road, where no tree can hide anyone from the bear.
    var arena:=Vector3(sin(-140.0*.012)*28.0,0,-140)
    arena.y=map.height_at(arena.x,arena.z)
    first.global_position=arena+Vector3.UP*.1;first.home=first.global_position
    hunter.global_position=arena+Vector3(1.8,0,-3.0);friend.global_position=arena+Vector3(-1.8,0,-3.0)
    for who in [hunter,friend]: who.global_position.y=map.height_at(who.global_position.x,who.global_position.z)+.1;who.health=100;who.set_physics_process(false)
    first.set_physics_process(true)
    first.take_damage(1,hunter.global_position,1)
    var hurt: bool=false
    for i in 240:
        await physics_frame
        if hunter.health<100 and friend.health<100: hurt=true;break
    check(hurt,"one sweep of the Ancient Bear hits every hunter in reach (%d / %d)" % [hunter.health,friend.health])
    check(hunter.health>=100-bear.attack_damage*2,"a boss hit hurts a lot but does not one-shot")
    first.set_physics_process(false)
    var loot_before: int=session.loot.size()
    var killer_coins: int=hunter.inventory.coins
    first.take_damage(999999,hunter.global_position,1)
    var dropped: Array=[]
    for pickup in session.loot.values(): if pickup.loot_definition.id in bear.trophies: dropped.append(pickup)
    check(first.dead and session.loot.size()-loot_before==bear.trophies.size() and dropped.size()==bear.trophies.size(),"the fallen bear scatters %d trophies" % bear.trophies.size())
    var spread: bool=true
    for pickup in dropped:
        var gap: float=Vector2(pickup.global_position.x-first.global_position.x,pickup.global_position.z-first.global_position.z).length()
        if gap<1.0 or gap>bear.width*.5+3.0: spread=false
    check(spread and dropped.all(func(p) -> bool: return p.trophy),"trophies land in a ring around the body, glowing")
    check(hunter.inventory.coins==killer_coins and session.living_bosses().size()==1,"no automatic reward: the trophies wait on the ground")
    check(session.boss_clock>=150.0,"the next boss comes a few minutes after a kill")
    hunter.inventory.backpack_id=&"hoarder";hunter.inventory.items.clear()
    hunter.global_position=dropped[0].global_position
    session.request_action("pickup",str(dropped[0].network_id))
    check(hunter.inventory.items.size()==1 and hunter.inventory.items[0].id in bear.trophies,"a trophy goes into the backpack")
    # The big body can be skinned from its flank.
    var harvest=first.get_node("HarvestInteraction")
    check(harvest.interaction_range>3.5,"boss bodies can be worked from further away")
    hunter.global_position=first.global_position+Vector3(4.0,0,0)
    check(session._can_harvest(1,first),"skinning starts beside the huge bear")
    # --- HUD logic ----------------------------------------------------------------------
    var view=scene.hud_view
    second.global_position=hunter.global_position+Vector3(0,0,-40)
    check(view._boss_in_focus(hunter)==second,"the boss bar follows the closest boss")
    second.global_position=hunter.global_position+Vector3(0,0,-600)
    view._boss_hit_at.clear()
    check(view._boss_in_focus(hunter)==null,"and hides when no boss is near")
    for i in 5: view.toast("note %d" % i)
    check(view._toasts.size()==3 and view._toasts[-1].text=="note 4","toasts stack three deep, newest last")
    view.hit(42)
    check(view._hits.size()==1,"damage numbers float up from the crosshair")
    check(view._context_of(hunter)=="foot","hints know when you walk")
    hunter.health=0
    check(view._context_of(hunter)=="downed","and when you are down");hunter.health=100
    # --- Minimap data ------------------------------------------------------------------
    var minimap=scene.minimap
    check(minimap._ensure_relief(map) and minimap.heights_texture.get_width()==map.CELLS+1,"the radar paints the real relief from the height grid")
    minimap._turn=0.0;minimap._range=100.0;minimap._center=Vector2(0,0)
    var north: Vector2=minimap._to_radar(Vector3(0,0,-50))
    var east: Vector2=minimap._to_radar(Vector3(50,0,0))
    var middle: float=minimap.RADAR_SIZE*.5
    check(north.y<middle-10 and absf(north.x-middle)<.5 and east.x>middle+10 and absf(east.y-middle)<.5,"north is up and east is right on an unturned radar")
    minimap._turn=PI*.5
    var ahead: Vector2=minimap._to_radar(Vector3(-50,0,0))
    check(ahead.y<middle-10 and absf(ahead.x-middle)<.5,"facing west, what is ahead of you is up on the radar")
    check(absf(minimap._radar_turn(PI*.5))<.001,"your arrow points up when you face where the camera looks")
    minimap.toggle_detail();await frames(2)
    check(minimap.full_root.visible and not minimap.radar.visible,"M swaps the radar for the whole map")
    minimap.close_detail();await frames(2)
    check(minimap.radar.visible and not minimap.full_root.visible,"and back")
    # --- The swamp: its own boss lives in the water ---------------------------------------------
    session._peer_disconnected(2)
    check(await start("swamp"),"swamp expedition loads")
    var swamp_bosses: Array=session.living_bosses()
    check(swamp_bosses.size()==1 and swamp_bosses[0].definition.id==&"albino_crocodile","the swamp wakes an Albino Saltwater Crocodile")
    if not swamp_bosses.is_empty():
        var croc_body=swamp_bosses[0]
        check(session.forest.water_depth(croc_body.global_position)>0.0 or session.forest.height_at(croc_body.global_position.x,croc_body.global_position.z)<.15,"it spawns in the water")
        check(croc_body.model.find_children("Boss*","BoneAttachment3D",true,false).size()>=4,"the albino wears its harpoon, spikes and barnacles on its bones")
    check(is_instance_valid(session.forest) and session.forest.trees.size()>10000,"the bigger swamp has its trees (%d)" % (session.forest.trees.size() if is_instance_valid(session.forest) else 0))
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
