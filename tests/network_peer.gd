extends SceneTree
## Multi-process ENet test. The test coordinator only controls test phases.
var scene: Node
var session
var role: String
var folder: String
var failures: int=0
var checks: int=0
var hunt_map: String="forest"
func _initialize() -> void: call_deferred("run")
func check(condition: bool, description: String) -> void:
    checks+=1
    if not condition: failures+=1;push_error("FAIL "+description)
    else: print("PASS ",description)
func frames(count: int) -> void:
    for i in count: await physics_frame
func write_phase(value: String) -> void:
    var file:=FileAccess.open(folder+"/phase.txt",FileAccess.WRITE)
    file.store_string(value)
func phase() -> String:
    return FileAccess.get_file_as_string(folder+"/phase.txt").strip_edges() if FileAccess.file_exists(folder+"/phase.txt") else ""
func wait_until(predicate: Callable, seconds: float=25.0) -> bool:
    var deadline:=Time.get_ticks_msec()+int(seconds*1000)
    while Time.get_ticks_msec()<deadline:
        if predicate.call(): return true
        await frames(2)
    return false
func run() -> void:
    if OS.get_environment("HUNT_TEST_MAP")=="swamp": hunt_map="swamp"
    var args:=OS.get_cmdline_user_args()
    role=args[0]
    folder=args[1]
    scene=load("res://game/main.tscn").instantiate()
    root.add_child(scene)
    current_scene=scene
    session=root.get_node("NetworkSession")
    scene.world_router.completed.disconnect(scene._world_prepared)
    scene.world_router.completed.connect(test_map_ready)
    session.multiplayer.peer_connected.connect(func(id): print("PEER_CONNECTED ",role," ",id))
    session.multiplayer.connected_to_server.connect(func(): print("CONNECTED ",role))
    if role=="host": await host_test()
    elif role=="extra": await extra_test()
    else: await client_test()
    print("RESULT ",role," ",checks," checks, ",failures," failures")
    var report:=FileAccess.open(folder+"/"+role+".json",FileAccess.WRITE)
    report.store_string(JSON.stringify({"checks":checks,"failures":failures}))
    report.close()
    report=null
    scene.queue_free()
    await frames(8)
    quit(1 if failures else 0)
func host_test() -> void:
    check(session.host_game("Host",24680)==OK,"create ENet host")
    scene.menu.resume()
    write_phase("join")
    check(await wait_until(func(): return session.players.size()==4),"host plus three real clients")
    if session.players.size()!=4: write_phase("done");return
    write_phase("full")
    check(await wait_until(func(): return FileAccess.file_exists(folder+"/extra.json"),16),"fifth client rejected")
    check(session.phase=="lobby" and session.animals.is_empty(),"host waits in unpopulated lobby")
    write_phase("lobby_check")
    check(await wait_until(func(): return all_marked("lobby")),"clients confirm waiting lobby")
    await frames(20)
    check(session.phase=="lobby","remote Start requests are rejected")
    var weapon_stall
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="weapons": weapon_stall=stall
    for peer in session.players:
        var p=session.players[peer]
        p.global_position=weapon_stall.interaction_position()
        p.inventory.coins=2000 if p.player_name=="client1" else 300 if p.player_name=="client2" else 0
        session._send_inventory(peer)
    await frames(20)
    write_phase("progression")
    check(await wait_until(func(): return all_marked("progression")),"clients finish authoritative shop purchases")
    for p in session.players.values():
        if p.player_name=="client1":
            check(p.inventory.coins==98 and p.inventory.owns_weapon(&"beehive"),"remote wallet paid weapon and three separate upgrades")
            check(p.inventory.upgrade_level(&"beehive","damage")==1 and p.inventory.upgrade_level(&"beehive","rate")==1 and p.inventory.magazine_capacity(&"beehive")==50,"host stores actual upgraded stats")
        elif p.player_name=="client2": check(p.inventory.coins==170 and not p.inventory.owns_weapon(&"thunder_tube"),"insufficient funds and locked equip rejected remotely")
        elif p.player_name=="client3": check(p.inventory.coins==0 and p.inventory.owned_weapons==[&"rusty_pistol"],"other client's progression stays private")
        p.inventory.coins=0
        session._send_inventory(p.peer_id)
    start_forest()
    check(session.phase=="loading" and not session.jeep.enabled,"host enters shared loading phase")
    write_phase("loading_check")
    check(await wait_until(func(): return session.ready_players.size()==3,30),"three ready peers wait for slow fourth peer")
    check(session.phase=="loading" and session.animals.is_empty(),"slow peer blocks wildlife and expedition")
    check(await wait_until(func(): return session.phase=="hunt",30),"four map acknowledgements commit expedition")
    check(session.animals.size()>=24 and session.world_id==hunt_map,"host starts separate forest with wildlife")
    check(await wait_until(func(): return all_marked("loaded")),"all clients loaded separate forest")
    for animal in session.animals.values(): animal.set_physics_process(false)
    for p in session.players.values(): p.control_enabled=false
    var a=session.spawn_animal(&"bear",Vector3(20,0,-70))
    a.set_physics_process(false)
    a.health=123
    session.spawn_loot(&"deer_pelt",Vector3(12,.2,15))
    await frames(15)
    write_phase("replicas")
    check(await wait_until(func(): return FileAccess.file_exists(folder+"/client1_replicas.txt") and FileAccess.file_exists(folder+"/client2_replicas.txt") and FileAccess.file_exists(folder+"/client3_replicas.txt")),"clients receive shared world")
    var predator_victim
    for p in session.players.values():
        if p.player_name=="client2": predator_victim=p
    predator_victim.health=100;predator_victim.global_position=Vector3(0,session.forest.height_at(0,-35)+.4,-35)
    var predator=session.spawn_animal(&"wolf",Vector3(0,0,-47))
    predator.take_damage(1,predator_victim.global_position,predator_victim.peer_id)
    check(await wait_until(func(): return predator_victim.health<100,8),"host predator chases and damages remote hunter")
    predator.set_physics_process(false)
    check(predator.state=="Attack" and predator.target_peer==predator_victim.peer_id and predator.flee_until==0,"predator attacks shooter without fleeing")
    var predator_file:=FileAccess.open(folder+"/predator_id.txt",FileAccess.WRITE)
    predator_file.store_string(str(predator.animal_id));predator_file.close()
    write_phase("predator")
    check(await wait_until(func(): return all_marked("predator")),"all clients see predator attack and damage")
    session.remove_animal(predator.animal_id)
    predator_victim.take_damage(999)
    var reviver
    for hunter in session.players.values():
        if hunter.player_name=="client1": reviver=hunter
    reviver.global_position=predator_victim.global_position+Vector3(1.8,0,0)
    await frames(30)
    write_phase("downed")
    check(await wait_until(func(): return all_marked("downed")),"every peer sees downed hunter lying on ground")
    check(predator_victim.health==0,"downed client stays on ground until teammate helps")
    write_phase("revive")
    check(await wait_until(func(): return predator_victim.revive_progress>.15,8),"remote held E starts authoritative revive progress")
    check(await wait_until(func(): return predator_victim.health==50,8),"remote teammate completes free three second revive")
    write_phase("revived")
    check(await wait_until(func(): return all_marked("revived")),"all peers see revived hunter standing")
    # A real remote hunter must manually recover the new corpse. Competing
    # clients cannot duplicate cuts or claim the same skin.
    for animal_id in session.animals.keys(): session.remove_animal(animal_id)
    session.spawn_clock=60
    var body=session.spawn_animal(&"rabbit",Vector3(30,0,-60))
    body.set_physics_process(false);body.global_position=Vector3(30,30,-60)
    var drops_before: int=session.loot.size()
    body.take_damage(999,reviver.global_position,reviver.peer_id)
    check(body.dead and session.loot.size()==drops_before,"network death produces corpse without automatic loot")
    for p in session.players.values():
        p.inventory.items.clear()
        p.set_physics_process(false)
        p.global_position=body.global_position+Vector3(1.6 if p.player_name=="client1" else -1.6 if p.player_name=="client2" else 8,0,0)
        session._send_inventory(p.peer_id)
    var body_file:=FileAccess.open(folder+"/harvest_id.txt",FileAccess.WRITE)
    body_file.store_string(str(body.animal_id));body_file.close()
    var harvested_id: int=body.animal_id
    await frames(12);write_phase("harvest")
    check(await wait_until(func(): return all_marked("harvest"),15),"remote cuts and exclusive corpse claim finish")
    check(not session.animals.has(harvested_id) and reviver.inventory.items.size()==1,"host awards one manually recovered remote pelt")
    if not reviver.inventory.items.is_empty():
        check(reviver.inventory.items[0].id==&"rabbit_pelt__s5" and reviver.inventory.loot_value()==15,"pristine quality value replicated through authoritative inventory")
    check(predator_victim.inventory.items.is_empty() and session.loot.size()==drops_before,"contested and replayed cuts award no extra loot")
    check(session.animals.is_empty(),"last corpse leaves an empty authoritative wildlife roster")
    session.spawn_clock=8
    for p in session.players.values(): p.set_physics_process(true)
    for peer in session.players:
        if peer==1: continue
        var p=session.players[peer]
        p.inventory.items.clear()
        p.inventory.collect(load("res://data/loot/deer_pelt.tres"))
        p.global_position=session.jeep.to_global(Vector3(0,.2,2.55))
        session._send_inventory(peer)
    await frames(20)
    write_phase("deposit")
    check(await wait_until(func(): return session.trunk.size()==3),"reliable deposit from all clients")
    var owners: Dictionary={}
    for item in session.trunk: owners[item.owner]=true
    check(owners.size()==3,"trunk tracks three individual owners")
    session.request_action("return_lobby")
    check(await wait_until(func(): return session.phase=="lobby",30),"four peers return through loading to camp")
    check(session.trunk.size()==3 and session.forest==null,"return keeps owned cargo and unloads forest")
    var seller
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="sell": seller=stall
    session.jeep.reset_state(Transform3D(Basis.IDENTITY,seller.global_position+Vector3(4,.6,0)))
    for p in session.players.values(): p.global_position=seller.interaction_position()
    await frames(20)
    write_phase("sell1")
    check(await wait_until(func(): return session.trunk.size()==2),"client sells own cargo")
    var paid:=0
    for p in session.players.values():
        if p.inventory.coins==30: paid+=1
    check(paid==1,"only selling hunter receives coins")
    start_forest()
    check(await wait_until(func(): return session.phase=="hunt",30),"second expedition loads for whole party")
    for animal in session.animals.values(): animal.set_physics_process(false)
    # Both biomes guarantee a flat, dry arrival area. Test transport/controls
    # here so a random hillside cannot roll the parked car during exit checks.
    var drive_point: Vector3=Vector3(0,session.forest.height_at(0,-12)+.6,-12)
    session.jeep.reset_state(Transform3D(Basis.IDENTITY,drive_point))
    await frames(90)
    for peer in session.players:
        session.players[peer].global_position=session.jeep.global_position+Vector3(2,.2,0)
    session.jeep.linear_velocity=Vector3.ZERO;session.jeep.angular_velocity=Vector3.ZERO
    var driver:=0
    for peer in session.players:
        if session.players[peer].player_name=="client1": driver=peer
    check(session.jeep.enter(driver),"remote client occupies driver seat")
    check(session.jeep.enter(1),"host occupies passenger seat")
    await frames(15)
    write_phase("enter")
    check(await wait_until(func(): return not session.jeep.occupants.has(0)),"three clients enter passenger seats")
    var before: Vector3=session.jeep.global_position
    write_phase("drive")
    check(await wait_until(func(): return Vector2(session.jeep.global_position.x-before.x,session.jeep.global_position.z-before.z).length()>1,5),"authoritative movement from remote driver input")
    write_phase("seats")
    await frames(120)
    session.jeep.linear_velocity=Vector3.ZERO;session.jeep.angular_velocity=Vector3.ZERO
    session.players[1].control_enabled=false
    session.jeep.exit_seat(1)
    await frames(10)
    write_phase("exit")
    check(await wait_until(func(): return session.jeep.occupants==[0,0,0,0]),"passengers exit via server commands")
    var peer: int=session.players.keys()[1]
    var p=session.players[peer]
    # Isolate muzzle validation from biome habitat relocation and boardwalk cover.
    p.set_physics_process(false);p.global_position=Vector3(0,30,-90)
    var victim=session.spawn_animal(&"rabbit",Vector3(0,0,-96))
    victim.set_physics_process(false);victim.global_position=Vector3(0,30,-96)
    p.visual.rotation.y=0
    await frames(20)
    var hp: int=victim.health
    var origin: Vector3=p.global_position+Vector3(0,1.62,0)
    var direction: Vector3=(victim.global_position+Vector3(0,.2,0)-origin).normalized()
    session._accept_input(peer,{"seq":int(session.last_inputs.get(peer,0))+1,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":asin(direction.y),"first":true,"aim":true})
    check(p.command.first,"server accepts remote first person aiming input")
    session._shoot(peer,origin,direction)
    check(victim.health<hp,"remote first person muzzle ray damages shared animal")
    var after: int=victim.health
    session._shoot(peer,origin,direction)
    check(victim.health==after,"server enforces weapon cooldown")
    p.set_physics_process(true)
    await frames(20)
    var reconnect_peer:=0
    var reconnect_profile: String=""
    for id in session.players:
        if session.players[id].player_name=="client3": reconnect_peer=id;reconnect_profile=session.identities[id]
    var reconnect_inventory=session.players[reconnect_peer].inventory
    reconnect_inventory.coins=1000
    reconnect_inventory.buy_weapon(&"scrap_blaster")
    reconnect_inventory.buy_upgrade(&"scrap_blaster","damage")
    reconnect_inventory.coins=17
    session._send_inventory(reconnect_peer)
    session.players[reconnect_peer].take_damage(999)
    await frames(20)
    write_phase("disconnect3")
    check(await wait_until(func(): return session.players.size()==3),"disconnect removes remote hunter")
    check(session.trunk.size()==2,"cargo survives owner disconnect")
    write_phase("rejoin3")
    check(await wait_until(func(): return session.players.size()==4),"same profile reconnects")
    var restored=false
    for id in session.players:
        if session.identities[id]==reconnect_profile: restored=session.players[id].inventory.coins==17
    check(restored,"wallet restored within live host session")
    for id in session.players:
        if session.identities[id]==reconnect_profile: check(session.players[id].health==0,"reconnecting does not revive a downed hunter")
    check(await wait_until(func(): return session.players.values().all(func(p): return p.world_ready),30),"late join finishes forest before host ends test")
    for id in session.players:
        if session.identities[id]==reconnect_profile:
            check(session.players[id].inventory.owns_weapon(&"scrap_blaster") and session.players[id].inventory.upgrade_level(&"scrap_blaster","damage")==1,"weapon ownership and upgrades survive reconnect")
    await frames(25)
    write_phase("done")
    await frames(35)
func client_test() -> void:
    check(await wait_until(func(): return phase()=="join",20),"host ready")
    check(session.join_game(role,"127.0.0.1",24680)==OK,"create ENet client")
    check(await wait_until(func(): return session.mode=="client"),"register with host")
    var first_local=session.local_hunter()
    var stale: Dictionary=session._snapshot()
    stale.sequence=session.roster_sequence-1
    stale.players=[]
    session._apply_snapshot(stale)
    check(session.local_hunter()==first_local,"stale roster cannot destroy local hunter")
    check(await wait_until(func(): return phase()=="lobby_check",20),"waiting lobby phase")
    check(session.phase=="lobby" and session.animals.is_empty(),"client sees closed forest without wildlife")
    check(scene.map_menu.start_button.disabled and not scene.menu._return_lobby.visible,"client map Start disabled; pause menu has no Start")
    start_forest()
    mark("lobby")
    check(await wait_until(func(): return phase()=="progression"),"progression phase")
    check(session.phase=="lobby" and session.forest==null,"shop progression remains in separate lobby")
    var inv=session.local_hunter().inventory
    if role=="client1":
        session.request_action("buy_weapon","beehive")
        check(await wait_until(func(): return inv.owns_weapon(&"beehive")),"remote weapon purchase replicated privately")
        session.request_action("upgrade","beehive:damage")
        session.request_action("upgrade","beehive:rate")
        session.request_action("upgrade","beehive:magazine")
        check(await wait_until(func(): return inv.coins==98 and inv.magazine_capacity(&"beehive")==50),"three independent upgrades replicated")
        check(inv.weapon_damage(&"beehive")==30 and inv.weapon_cooldown(&"beehive")<.12,"client sees upgraded damage and cadence")
    elif role=="client2":
        session.request_action("buy_weapon","thunder_tube")
        session.request_action("equip","thunder_tube")
        await frames(20)
        check(inv.coins==300 and inv.equipped_weapon_id==&"rusty_pistol","cannot buy or equip locked OP gun")
        session.request_action("buy_weapon","old_rifle")
        session.request_action("upgrade","old_rifle:damage")
        check(await wait_until(func(): return inv.coins==170 and inv.owns_weapon(&"old_rifle")),"different hunter buys own progression")
    else:
        session.request_action("upgrade","beehive:damage")
        session.request_action("upgrade","beehive:banana")
        await frames(20)
        check(inv.coins==0 and not inv.owns_weapon(&"beehive"),"unowned or invalid upgrades rejected")
    mark("progression")
    check(await wait_until(func(): return phase()=="loading_check"),"host starts map transition")
    check(await wait_until(func(): return session.phase=="loading"),"client receives loading transition")
    check(scene.loading_screen.root_control.visible and not session.jeep.enabled,"loading cover and frozen vehicle on client")
    check(await wait_until(func(): return session.phase=="hunt",30),"host commits after every client loaded")
    check(session.forest!=null and session.forest.built and scene.world_router.active_id==hunt_map,"client has actual separate forest")
    check(not scene.loading_screen.root_control.visible and session.local_hunter().world_ready,"commit restores playable client")
    mark("loaded")
    check(await wait_until(func(): return phase()=="replicas"),"replica phase")
    check(await wait_until(func(): return session.players.size()==4,4),"four hunter replicas")
    var bear_found:=false
    for a in session.animals.values():
        if a.definition.id==&"bear" and a.health==123: bear_found=true
    if not bear_found:
        await frames(30)
        for a in session.animals.values():
            if a.definition.id==&"bear" and a.health==123: bear_found=true
    check(bear_found,"host animal HP and model synchronized")
    check(await wait_until(func(): return session.loot.size()>=1,4),"host loot visible")
    var marker:=FileAccess.open(folder+"/"+role+"_replicas.txt",FileAccess.WRITE)
    marker.store_string("ok")
    marker.close()
    marker=null
    check(await wait_until(func(): return phase()=="predator"),"predator phase")
    var predator_id:=int(FileAccess.get_file_as_string(folder+"/predator_id.txt"))
    check(await wait_until(func(): return session.animals.has(predator_id) and session.animals[predator_id].state=="Attack"),"predator attack animation replicated")
    check(await wait_until(func():
        for p in session.players.values():
            if p.player_name=="client2": return p.health<100
        return false),"remote victim health replicated to all hunters")
    mark("predator")
    check(await wait_until(func(): return phase()=="downed"),"downed hunter phase")
    var fallen
    for hunter in session.players.values():
        if hunter.player_name=="client2": fallen=hunter
    check(await wait_until(func(): return fallen.health==0 and fallen.life_pose_downed),"downed health and lying pose synchronized")
    check(absf(fallen.visual.rotation.x+PI*.5)<.01,"replica displays horizontal body")
    mark("downed")
    check(await wait_until(func(): return phase()=="revive"),"held E revive phase")
    if role=="client1":
        session.set_physics_process(false)
        while phase()=="revive":
            var hunter=session.local_hunter();hunter.input_sequence+=1
            session.send_input({"seq":hunter.input_sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"revive":fallen.peer_id})
            await frames(1)
        session.set_physics_process(true)
    check(await wait_until(func(): return phase()=="revived"),"revive completed phase")
    check(await wait_until(func(): return fallen.health==50 and not fallen.life_pose_downed),"replicated revive gives fifty health and upright pose")
    mark("revived")
    check(await wait_until(func(): return phase()=="harvest"),"manual harvest network phase")
    var body_id:=int(FileAccess.get_file_as_string(folder+"/harvest_id.txt"))
    check(await wait_until(func(): return session.animals.has(body_id) and session.animals[body_id].dead),"dead harvestable corpse replicated")
    var local_hunter=session.local_hunter()
    local_hunter.set_physics_process(false)
    if role=="client1":
        session.set_physics_process(false)
        session.request_action("harvest_start",str(body_id))
        check(await wait_until(func(): return session.is_harvesting(session.local_id()),4),"remote player receives private harvest state")
        mark("harvest_claimed")
        # Play the skinning routine from the replicated state only: blade samples
        # carry this client's own clock, clicks go through the reliable action path.
        var bot=load("res://tests/harvest_bot.gd")
        var clock: Dictionary={}
        var queue: Array=[]
        var settle_fx: int=-1
        var settle_until: int=0
        var previous_cut: String=""
        var deadline: int=Time.get_ticks_msec()+20000
        while session.is_harvesting(session.local_id()) and Time.get_ticks_msec()<deadline:
            var state: Dictionary=session.harvest_state(session.local_id())
            local_hunter.input_sequence+=1
            var packet: Dictionary={"seq":local_hunter.input_sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"harvest":true}
            if int(clock.get("token",-1))!=int(state.token):
                clock.token=int(state.token);clock.blade=Vector2(state.get("blade",Vector2(.5,.5)))
            # Replan only once the host has answered the last batch (or gone quiet).
            if queue.is_empty() and (int(state.get("fx",0))!=settle_fx or Time.get_ticks_msec()>settle_until):
                queue=bot.next_ops(state,Vector2(clock.blade))
                settle_fx=int(state.get("fx",0));settle_until=Time.get_ticks_msec()+1500
            if not queue.is_empty():
                var op: Dictionary=queue.pop_front()
                if op.kind=="blade":
                    clock.stamp=int(clock.get("stamp",1000))+int(op.dt);clock.blade=op.p
                    packet["blade"]=op.p;packet["bt"]=int(clock.stamp)
                elif op.kind=="click":
                    clock.click=maxi(int(clock.get("click",0)),int(state.get("clicks",0)))+1
                    previous_cut="%d:%d:%d:%.5f:%.5f" % [int(state.id),int(state.token),int(clock.click),Vector2(op.p).x,Vector2(op.p).y]
                    session.request_action("harvest_click",previous_cut)
            session.send_input(packet)
            await frames(1)
        check(await wait_until(func(): return local_hunter.inventory.items.size()==1,3),"remote manual cuts deliver one pelt")
        if not local_hunter.inventory.items.is_empty():
            check(local_hunter.inventory.items[0].id==&"rabbit_pelt__s5" and local_hunter.inventory.loot_value()==15,"remote quality ID and value match host")
        session.request_action("harvest_click",previous_cut)
        session.request_action("harvest_start",str(body_id))
        await frames(8)
        check(local_hunter.inventory.items.size()==1,"remote completion replay cannot duplicate recovered skin")
        session.set_physics_process(true)
    elif role=="client2":
        check(await wait_until(func(): return FileAccess.file_exists(folder+"/client1_harvest_claimed.txt"),4),"other hunter starts exclusive harvest")
        session.request_action("harvest_start",str(body_id))
        await frames(12)
        check(not session.is_harvesting(session.local_id()) and local_hunter.inventory.items.is_empty(),"competing remote client cannot take occupied corpse")
    else:
        check(await wait_until(func(): return not session.animals.has(body_id),10),"bystander sees completed corpse removal")
    local_hunter.set_physics_process(true)
    mark("harvest")
    check(await wait_until(func(): return phase()=="deposit"),"deposit phase")
    session.request_action("deposit")
    check(await wait_until(func(): return session.local_hunter().inventory.items.is_empty()),"own bag updated by server")
    check(await wait_until(func(): return phase()=="sell1"),"sale phase")
    if role=="client1": session.request_action("sell_trunk")
    check(await wait_until(func(): return phase()=="enter"),"passenger phase")
    check(session.local_hunter().inventory.coins==(30 if role=="client1" else 0),"private wallet sale ownership")
    session.request_action("enter")
    check(await wait_until(func(): return session.local_hunter().seat_index>=0),"server assigns seat")
    var drive_start: Vector3=session.jeep.global_position
    check(await wait_until(func(): return phase()=="drive"),"remote driving phase")
    if role=="client1":
        # Headless DisplayServer can't capture a mouse. Send normal validated input RPCs.
        session.set_physics_process(false)
        var p=session.local_hunter()
        for i in 60:
            p.input_sequence+=1
            session.send_input({"seq":p.input_sequence,"direction":Vector3.ZERO,"drive":Vector2(0,-1),"yaw":0,"pitch":0})
            await frames(1)
        while phase() not in ["seats","exit"]:
            p.input_sequence+=1
            session.send_input({"seq":p.input_sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"brake":true})
            await frames(1)
        session.set_physics_process(true)
    check(await wait_until(func(): return phase()=="seats"),"drive phase")
    check(not session.jeep.occupants.has(0),"four shared seats synchronized")
    check(await wait_until(func(): return Vector2(session.jeep.global_position.x-drive_start.x,session.jeep.global_position.z-drive_start.z).length()>1,3),"driver movement visible on clients")
    if role=="client1":
        session.set_physics_process(false)
        while phase()!="exit":
            var p=session.local_hunter();p.input_sequence+=1
            session.send_input({"seq":p.input_sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0,"pitch":0,"brake":true})
            await frames(1)
        session.set_physics_process(true)
    check(await wait_until(func(): return phase()=="exit"),"exit phase")
    session.request_action("exit")
    check(await wait_until(func(): return session.local_hunter().seat_index<0),"server exits own seat")
    if role=="client3":
        check(await wait_until(func(): return phase()=="disconnect3"),"reconnect phase")
        session.leave_game()
        check(await wait_until(func(): return phase()=="rejoin3"),"host removed old peer")
        session.join_game(role,"127.0.0.1",24680)
        check(await wait_until(func(): return session.mode=="client"),"reconnected with same profile")
        check(session.local_hunter().inventory.coins==17,"own wallet restored")
        check(session.local_hunter().inventory.owns_weapon(&"scrap_blaster") and session.local_hunter().inventory.upgrade_level(&"scrap_blaster","damage")==1,"purchased weapon and upgrade restored")
        check(await wait_until(func(): return session.local_loaded_epoch==session.world_epoch and session.local_hunter().world_ready,30),"late join loads active map before playing")
        check(session.phase=="hunt" and session.forest!=null,"late join receives active expedition map")
        check(session.local_hunter().health==0 and session.local_hunter().life_pose_downed,"late join preserves downed state until another hunter revives")
        var owns:=false
        for item in session.trunk_view:
            if item.mine: owns=true
        check(owns,"trunk loot ownership follows reconnect")
    check(await wait_until(func(): return phase()=="done",30),"test completed")

func mark(suffix: String) -> void:
    var file:=FileAccess.open(folder+"/"+role+"_"+suffix+".txt",FileAccess.WRITE)
    file.store_string("ok")

func all_marked(suffix: String) -> bool:
    for client in ["client1","client2","client3"]:
        if not FileAccess.file_exists(folder+"/"+client+"_"+suffix+".txt"): return false
    return true

func extra_test() -> void:
    check(await wait_until(func(): return phase()=="full",20),"full camp ready")
    session.join_game(role,"127.0.0.1",24680)
    check(await wait_until(func(): return session.mode=="solo",14),"fifth hunter cannot join full camp")
    check(session.status_key=="NET_FAILED","full connection returns usable solo lobby")

func test_map_ready(epoch: int) -> void:
    if role=="client3" and epoch==1:
        await frames(300)
    if epoch==session.world_epoch: scene._world_prepared(epoch)

func start_forest() -> void:
    var session=root.get_node("NetworkSession")
    if session.phase=="lobby" and session.is_host():
        var fire=session.world.world_router.active.get_node("Camp/GiantCampfire/Expedition")
        session.local_hunter().global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt",hunt_map)
