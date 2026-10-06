extends SceneTree
## The Wandering Oak truck as the crew's moving base: cozy camp layout, the
## shops, cottage and workshop aboard (no NPCs), walking up the ramp through the
## host's own movement, the ladders, riders walking freely on the terrace and
## shooting while someone drives, choosing the map from the wheel, riders kept
## aboard through travel, cleaning hides on the move and private storage.
var scene
var session
var truck
var hunter
var walker
var checks: int=0
var failures: int=0
var sequence: int=90000
var walker_sequence: int=190000

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
func drive(vector: Vector2, count: int, braking: bool=false) -> void:
    for i in count:
        sequence+=1
        session._accept_input(1,{"seq":sequence,"direction":Vector3.ZERO,"drive":vector,"yaw":0.0,"pitch":0.0,"brake":braking})
        steer(Vector3.ZERO)
        await physics_frame
func steer(direction: Vector3, yaw: float=0.0) -> void:
    walker_sequence+=1
    session._accept_input(walker.peer_id,{"seq":walker_sequence,"direction":direction,"drive":Vector2.ZERO,"yaw":yaw,"pitch":0.0})
## Walks the walker through truck-local waypoints using the host's real movement.
func walk(route: Array, label: String) -> bool:
    for waypoint: Vector3 in route:
        var reached: bool=false
        for step in 900:
            var target: Vector3=truck.to_global(waypoint)
            var flat: Vector3=target-walker.global_position;flat.y=0
            if flat.length()<.3: reached=true;break
            steer(flat.normalized())
            await physics_frame
        if not reached:
            push_error("walk %s stuck before %s at %s" % [label,str(waypoint),str(truck.to_local(walker.global_position))])
            steer(Vector3.ZERO)
            return false
    steer(Vector3.ZERO);await physics(8)
    return true
func on_deck() -> bool:
    var local: Vector3=truck.to_local(walker.global_position)
    return absf(local.y-7.8)<.3 and absf(local.x)<1.6 and local.z>-1.05 and local.z<3.65

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    await frames(5)
    check(session.phase=="lobby","camp loaded")
    var lobby=scene.world_router.active
    truck=session.jeep
    hunter=session.local_hunter();hunter.set_physics_process(false);hunter.control_enabled=false
    hunter.global_position=Vector3(-6,.3,10)
    # The camp is a cozy fireplace with the truck parked beside it.
    check(lobby.has_node("CozyCamp") and not lobby.has_node("Camp/Tents") and not lobby.has_node("Camp/Shops") and not lobby.has_node("HideCleaner"),"camp is a cozy fireplace without tents or canvas stalls")
    check(lobby.get_node("CozyCamp").find_children("CampDog","Node3D",true,false).size()==1,"a camp dog sleeps by the fire")
    var fire: Vector3=lobby.get_node("Camp/GiantCampfire").global_position
    var gap: float=Vector2(truck.global_position.x-fire.x,truck.global_position.z-fire.z).length()
    check(gap>6.0 and gap<12.0,"the truck parks beside the fire (%.1f m)" % gap)
    var kinds: Array=[]
    for candidate in get_nodes_in_group("lobby_interactables"):
        if candidate.get("slogan_key")!=null:
            kinds.append(candidate.interaction_kind)
            check(candidate.get_parent()==truck,candidate.interaction_kind+" counter rides on the truck")
    kinds.sort()
    check(kinds==["backpacks","sell","storage","weapons"],"four counters aboard: "+str(kinds))
    for kind in ["weapons","backpacks","sell"]:
        check(truck.counters[kind].interaction_position().distance_to(fire)<truck.global_position.distance_to(fire),kind+" window faces the campfire")
    var crew: Array=truck.find_children("Keeper","",true,false)+truck.find_children("Nelu","",true,false)
    check(crew.is_empty() and not ResourceLoader.exists("res://actors/npc/shopkeeper.gd"),"no NPCs aboard the truck any more")
    check(truck.counters.storage.interaction_position().y>truck.global_position.y+3.0,"storage counter is upstairs in the cottage")
    check(is_instance_valid(truck.cleaner) and truck.cleaner.mounted and truck.cleaner.get_parent()==truck,"hide cleaner works inside the cottage")
    var paint:=0
    for child in truck.get_children():
        if child is MeshInstance3D and str(child.name).begins_with("Oak"):
            paint+=1
            if not child.has_meta("styled") or child.material_override.diffuse_mode!=BaseMaterial3D.DIFFUSE_TOON: paint=-999
    check(paint>10 and paint<90,"truck geometry merged into %d toon colour batches" % paint)
    check(truck.wheel_turns.size()==4 and truck.extra_spins.size()==2,"four physical wheels, rear pair drawn as a tandem")
    check(truck.SEATS.size()==1 and truck.occupants==[0],"the wheel is the only seat")
    # Parked without a driver: frozen, ramp down, porch gate open.
    await physics(80)
    check(truck.parked and truck.freeze and not truck.get_node("RampShape").disabled and truck.get_node("GateShape").disabled,"parked truck freezes, lowers its ramp and opens the gate")
    # A hunter walks up the ramp, across the porch and into the cottage.
    walker=session._spawn_player(2,"Walker");walker.world_ready=true
    walker.global_position=truck.to_global(Vector3(0,.4,13.0))
    await physics(10)
    var ok: bool=await walk([Vector3(0,0,11.0),Vector3(0,0,6.6),Vector3(0,0,4.0),Vector3(0,0,2.4),Vector3(.1,0,1.7)],"cottage")
    var local: Vector3=truck.to_local(walker.global_position)
    check(ok and absf(local.y-3.65)<.25,"hunter walks up the ramp into the cottage (y=%.2f)" % local.y)
    check(walker.riding,"standing in the cottage counts as riding the truck")
    check(session._at_stall(walker,"storage") and session._can_clean(walker.peer_id),"storage counter and hide cleaner in reach inside")
    check(not session._at_stall(walker,"weapons"),"the arsenal window is down at ground level")
    # The ladders: porch to terrace and back, rope ladder down and up again.
    ok=await walk([Vector3(0,0,2.6),Vector3(.6,0,3.9)],"porch")
    check(ok and session._at_stall(walker,"ladder_up"),"the porch ladder leads up to the terrace")
    session._action(walker.peer_id,"climb","ladder_up")
    await physics(4)
    check(on_deck() and walker.seat_index<0,"the ladder puts the hunter on his own feet on the terrace")
    ok=await walk([Vector3(-1.1,0,0.0),Vector3(1.1,0,-.6),Vector3(0,0,2.6)],"terrace")
    check(ok and on_deck(),"the hunter walks freely around the terrace")
    for i in 70:
        steer(truck.global_basis.x);await physics_frame
    steer(Vector3.ZERO);await physics(4)
    check(on_deck() and truck.to_local(walker.global_position).x<1.6,"the railing keeps him on the terrace")
    walker_sequence+=1
    session._accept_input(walker.peer_id,{"seq":walker_sequence,"direction":truck.global_basis.x,"drive":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"jump":true})
    await physics(20)
    var apex: float=truck.to_local(walker.global_position).y
    steer(Vector3.ZERO);await physics(90)
    check(apex>8.5 and on_deck(),"jumping at the railing does not throw him off (apex %.2f)" % apex)
    ok=await walk([Vector3(1.15,0,3.1)],"hatch")
    check(ok and session._at_stall(walker,"ladder_down"),"the ladder hatch is at the back of the terrace")
    session._action(walker.peer_id,"climb","ladder_down")
    await physics(4)
    check(absf(truck.to_local(walker.global_position).y-3.7)<.3,"climbing down puts him on the porch")
    ok=await walk([Vector3(1.3,0,5.0)],"rope ladder")
    check(ok and session._at_stall(walker,"alight"),"the rope ladder hangs from the porch")
    session._action(walker.peer_id,"climb","alight")
    await physics(30)
    check(truck.to_local(walker.global_position).y<1.2 and not walker.riding,"the rope ladder takes him down to the ground")
    check(session._at_stall(walker,"board"),"boarding from the ground at the rope ladder")
    session._action(walker.peer_id,"climb","board")
    await physics(4)
    check(on_deck() and walker.riding,"boarding goes straight up to the terrace")
    # The shops still answer only at their own windows.
    hunter.inventory.coins=2000
    hunter.global_position=truck.counters.weapons.interaction_position()+Vector3.UP*.1
    session.request_action("buy_weapon","beehive")
    check(hunter.inventory.owns_weapon(&"beehive") and hunter.inventory.coins==800,"arsenal window sells through the host")
    hunter.global_position=truck.counters.backpacks.interaction_position()+Vector3.UP*.1
    session.request_action("buy_weapon","old_rifle")
    check(not hunter.inventory.owns_weapon(&"old_rifle"),"the backpack window does not sell guns")
    # Private storage through the host's own actions.
    var inv=hunter.inventory
    inv.backpack_id=&"ranger";inv.items.clear();inv.stored.clear();inv.coins=0
    for id in ["rabbit_pelt__s5","deer_pelt__r3","boar_pelt__s2"]: inv.items.append(AnimalCatalog.loot(StringName(id)))
    hunter.global_position=Vector3(-6,.3,10)
    session.request_action("stash_deposit")
    check(inv.items.size()==3 and inv.stored.is_empty(),"storage refuses deposits away from the counter")
    hunter.global_position=truck.counters.storage.interaction_position()+Vector3.UP*.1
    session.request_action("stash_deposit")
    check(inv.items.is_empty() and inv.stored.size()==3,"backpack goes into storage at the counter")
    var copy=load("res://systems/inventory/hunter_inventory.gd").new();copy.apply_state(inv.export_state())
    check(copy.stored.size()==3 and copy.stored.any(func(item) -> bool: return item.id==&"deer_pelt__r3"),"stored loot keeps its grade through the profile state")
    copy.free()
    session.request_action("stash_withdraw","deer_pelt__r3")
    check(inv.items.size()==1 and inv.items[0].id==&"deer_pelt__r3" and inv.stored.size()==2,"take one kind back for the cleaner")
    session.request_action("stash_withdraw","not_a_loot")
    check(inv.items.size()==1 and inv.stored.size()==2,"unknown ids move nothing")
    session._action(walker.peer_id,"stash_withdraw","")
    check(walker.inventory.items.is_empty() and inv.stash_used()>0,"another hunter cannot empty my storage")
    var value: int=inv.stash_value()
    hunter.global_position=truck.counters.sell.interaction_position()+Vector3.UP*.1
    session.request_action("sell_stash")
    check(inv.coins==value and inv.stored.is_empty(),"buyer window pays the stored value once (%d)" % value)
    session.request_action("sell_stash")
    check(inv.coins==value,"repeated sale pays nothing")
    check(session._car_at_seller(),"cargo is always parked at the buyer's window")
    # Taking the wheel in camp opens the map; the host starts from the driver's seat.
    hunter.global_position=truck.exit_point(0)
    hunter.control_enabled=true
    check(truck.enter(1) and hunter.seat_index==0,"host takes the wheel")
    check(not truck.parked and truck.get_node("RampShape").disabled and not truck.get_node("GateShape").disabled,"a driver unparks the truck, stows the ramp and shuts the gate")
    await frames(3)
    check(not truck.freeze,"the truck simulates again once someone drives")
    check(scene.map_menu.is_open,"the map opens when the host sits at the wheel in camp")
    scene.map_menu.close();scene._on_continue()
    session._action(1,"start_hunt","forest")
    check(session.phase=="loading","the host starts the expedition from the wheel, not at the fire")
    session._accept_loaded(2,session.world_epoch)
    check(await loaded() and session.phase=="hunt","forest loads")
    await physics(4)
    check(truck.occupants[0]==1 and hunter.seat_index==0,"the driver arrives at the wheel")
    check(walker.seat_index<0 and walker.riding and on_deck(),"the rider arrives standing on the terrace")
    for a in session.animals.values(): a.set_physics_process(false)
    # Riders stay put on a moving truck, walk around on it and shoot from it.
    var before: Vector3=truck.to_local(walker.global_position)
    await drive(Vector2(0,-1),90)
    check(truck.speed>4.0,"truck drives through the forest (%.1f m/s)" % truck.speed)
    var after: Vector3=truck.to_local(walker.global_position)
    check(on_deck() and before.distance_to(after)<.35,"a rider standing still is carried with the truck (moved %.2f m on deck)" % before.distance_to(after))
    for i in 45:
        sequence+=1
        session._accept_input(1,{"seq":sequence,"direction":Vector3.ZERO,"drive":Vector2(.3,-1),"yaw":0.0,"pitch":0.0})
        steer(-truck.global_basis.z)
        await physics_frame
    var walked: Vector3=truck.to_local(walker.global_position)
    check(on_deck() and walked.z<after.z-1.0,"a rider walks forward on the deck while the truck turns (%.2f -> %.2f)" % [after.z,walked.z])
    var gunner_ammo: int=walker.inventory.ammunition()
    var origin: Vector3=walker.global_position+Vector3.UP*1.6
    session._shoot(walker.peer_id,origin,Vector3(0,-.2,1).normalized())
    check(walker.inventory.ammunition()==gunner_ammo-1,"a rider fires from the moving truck")
    var driver_ammo: int=hunter.inventory.ammunition()
    session.cooldowns.clear()
    session._shoot(1,hunter.global_position+Vector3.UP*1.4,Vector3.FORWARD)
    check(hunter.inventory.ammunition()==driver_ammo,"the driver cannot shoot")
    check(not session.jeep.exit_seat(1),"the driver cannot jump out of a moving truck")
    walker.global_position=truck.to_global(Vector3(1.15,7.85,3.1))
    session._action(walker.peer_id,"climb","ladder_down")
    check(absf(truck.to_local(walker.global_position).y-3.7)<.3,"the inside ladder works while driving")
    session._action(walker.peer_id,"climb","alight")
    check(walker.riding and truck.to_local(walker.global_position).y>3.0,"but nobody climbs off a moving truck")
    await drive(Vector2.ZERO,140,true)
    check(absf(truck.speed)<.6,"truck brakes to a stop")
    # The workshop keeps working while somebody drives.
    session.jeep.exit_seat(1)
    await physics(90)
    var heights: Array=[]
    for wheel in truck.WHEELS: var at: Vector3=truck.to_global(wheel);heights.append(snappedf(session.forest.height_at(at.x,at.z),.01))
    check(truck.parked and truck.freeze,"truck parks in the forest too (v %.2f, w %.2f, wheels %d, at %s, up %.3f, ground %s, walker %s)" % [truck.linear_velocity.length(),truck.angular_velocity.length(),truck.grounded_wheels,str(truck.global_position),truck.global_basis.y.dot(Vector3.UP),str(heights),str(truck.to_local(walker.global_position))])
    walker.global_position=truck.to_global(Vector3(0,3.75,.9))
    await physics(5)
    check(session._can_clean(walker.peer_id),"the workshop works out in the field")
    walker.inventory.items.clear();walker.inventory.items.append(AnimalCatalog.loot(&"rabbit_pelt__r4"))
    session._start_clean(walker.peer_id)
    check(session.is_cleaning(walker.peer_id),"a hunter cleans a hide in the cottage")
    hunter.global_position=truck.exit_point(0)
    check(truck.enter(1),"driver returns to the wheel")
    for i in 30:
        sequence+=1
        session._accept_input(1,{"seq":sequence,"direction":Vector3.ZERO,"drive":Vector2(0,-1),"yaw":0.0,"pitch":0.0})
        walker_sequence+=1
        session._accept_input(walker.peer_id,{"seq":walker_sequence,"direction":Vector3.ZERO,"drive":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"harvest":true})
        await physics_frame
    check(absf(truck.speed)>1.0 and session.is_cleaning(walker.peer_id) and walker.riding,"cleaning carries on while the truck drives")
    session._cancel_clean(walker.peer_id)
    check(walker.inventory.items.any(func(item) -> bool: return item.id==&"rabbit_pelt__r4"),"giving up gives the hide back")
    await drive(Vector2.ZERO,140,true)
    # Out hunting, the driver's map offers the way home; riders come along again.
    scene.map_menu.open()
    check(scene.map_menu.camp_button.visible and not scene.map_menu.start_button.visible,"the wheel's map offers the way back to camp")
    scene.map_menu.close()
    var cottage: Vector3=truck.to_local(walker.global_position)
    session.request_action("return_lobby")
    session._accept_loaded(2,session.world_epoch)
    check(await loaded() and session.phase=="lobby","truck brings the crew back to camp")
    await physics(4)
    check(truck.occupants[0]==1 and walker.riding and truck.to_local(walker.global_position).distance_to(cottage)<.6,"riders stay aboard on the way home, where they stood")
    # Truck labels and ladder prompts exist in both languages; the crew lines are gone.
    for locale in ["ro","en"]:
        var text: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/"+locale+".json"))
        var missing: Array=[]
        for key in ["storage","board","alight","ladder_up","ladder_down","TRUCK_TOO_FAST","BASE_NAME","BASE_HOUSE_SIGN","STORAGE_DESC","STASH_SUMMARY","SELL_STASH","STASH_FULL"]:
            if not text.has(key): missing.append(key)
        check(missing.is_empty(),locale+" has every truck label and ladder prompt "+str(missing))
        check(not text.keys().any(func(key) -> bool: return String(key).begins_with("NPC_")) and not text.has("SHOP_QUOTE") and not text.has("terrace"),locale+" no longer carries NPC lines or terrace posts")
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
