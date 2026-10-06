extends SceneTree
## The Wandering Oak truck as the crew's moving base: cozy camp layout, the
## shops, cottage and workshop aboard, walking up the ramp through the host's
## own movement, terrace gunners shooting while someone drives, choosing the map
## from the wheel, riders kept aboard through travel, and private storage.
const Crew:=preload("res://data/npc_catalog.gd")
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
        if candidate.has_method("greet_customer"):
            kinds.append(candidate.interaction_kind)
            check(candidate.get_parent()==truck,candidate.interaction_kind+" counter rides on the truck")
    kinds.sort()
    check(kinds==["backpacks","sell","storage","weapons"],"four counters aboard: "+str(kinds))
    for kind in ["weapons","backpacks","sell"]:
        var window=truck.counters[kind]
        check(window.interaction_position().distance_to(fire)<truck.global_position.distance_to(fire),kind+" window faces the campfire")
        check(window.keeper.npc_id==Crew.for_kind(kind) and window.keeper.position.x>1.0,kind+" keeper stands inside the hollow log")
    check(truck.counters.storage.interaction_position().y>truck.global_position.y+3.0,"storage counter is upstairs in the cottage")
    check(truck.keepers.has("nelu") and truck.keepers.nelu.pose=="sit","Nelu rocks on the porch")
    check(is_instance_valid(truck.cleaner) and truck.cleaner.mounted and truck.cleaner.get_parent()==truck,"hide cleaner works inside the cottage")
    var paint:=0
    for child in truck.get_children():
        if child is MeshInstance3D and str(child.name).begins_with("Oak"):
            paint+=1
            if not child.has_meta("styled") or child.material_override.diffuse_mode!=BaseMaterial3D.DIFFUSE_TOON: paint=-999
    check(paint>10 and paint<90,"truck geometry merged into %d toon colour batches" % paint)
    check(truck.wheel_turns.size()==4 and truck.extra_spins.size()==2,"four physical wheels, rear pair drawn as a tandem")
    # Parked without a driver: frozen, ramp down.
    await physics(80)
    check(truck.parked and truck.freeze and not truck.get_node("RampShape").disabled,"parked truck freezes and lowers its ramp")
    # A hunter walks up the ramp, across the porch and into the cottage.
    walker=session._spawn_player(2,"Walker");walker.world_ready=true
    walker.global_position=truck.to_global(Vector3(0,.4,13.0))
    await physics(10)
    var ok: bool=await walk([Vector3(0,0,11.0),Vector3(0,0,6.6),Vector3(0,0,4.0),Vector3(0,0,2.4),Vector3(.1,0,1.7)],"cottage")
    var local: Vector3=truck.to_local(walker.global_position)
    check(ok and absf(local.y-3.65)<.25,"hunter walks up the ramp into the cottage (y=%.2f)" % local.y)
    check(session._at_stall(walker,"storage") and session._can_clean(walker.peer_id),"storage counter and hide cleaner in reach inside")
    check(not session._at_stall(walker,"weapons"),"the arsenal window is down at ground level")
    ok=await walk([Vector3(0,0,2.6),Vector3(0,0,4.6),Vector3(.9,0,4.6)],"porch")
    check(ok and session._at_stall(walker,"terrace"),"the porch ladder leads to the terrace")
    session._action(walker.peer_id,"enter","terrace")
    check(walker.seat_index>0 and walker.global_position.distance_to(truck.to_global(truck.SEATS[walker.seat_index]))<.05,"climbing the ladder takes a terrace post")
    check(walker.global_position.y>truck.global_position.y+7.5,"the terrace sits above the tiled roof")
    session._action(walker.peer_id,"exit","")
    check(walker.seat_index<0 and truck.hull_distance(walker.global_position)<1.0 and truck.to_local(walker.global_position).y<1.5,"leaving a post puts the hunter on the ground beside the truck")
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
    check(not truck.parked and truck.get_node("RampShape").disabled,"a driver unparks the truck and stows the ramp")
    await frames(3)
    check(not truck.freeze,"the truck simulates again once someone drives")
    check(scene.map_menu.is_open,"the map opens when the host sits at the wheel in camp")
    scene.map_menu.close();scene._on_continue()
    walker.global_position=truck.exit_point(1);session._action(walker.peer_id,"enter","terrace")
    check(walker.seat_index>0,"a friend boards the terrace from the ground (seat %d, hull %.2f, speed %.2f)" % [walker.seat_index,truck.hull_distance(walker.global_position),truck.linear_velocity.length()])
    var post: int=walker.seat_index
    session._action(1,"start_hunt","forest")
    check(session.phase=="loading","the host starts the expedition from the wheel, not at the fire")
    session._accept_loaded(2,session.world_epoch)
    check(await loaded() and session.phase=="hunt","forest loads")
    check(truck.occupants[0]==1 and hunter.seat_index==0 and truck.occupants[post]==walker.peer_id and walker.seat_index==post,"driver and gunner arrive aboard the truck")
    for a in session.animals.values(): a.set_physics_process(false)
    # Gunners shoot from the terrace while the host drives; the driver cannot.
    await drive(Vector2(0,-1),90)
    check(truck.speed>4.0,"truck drives through the forest (%.1f m/s)" % truck.speed)
    var gunner_ammo: int=walker.inventory.ammunition()
    var origin: Vector3=walker.global_position+Vector3.UP*1.6
    session._shoot(walker.peer_id,origin,Vector3(0,-.2,1).normalized())
    check(walker.inventory.ammunition()==gunner_ammo-1,"terrace gunner fires while moving")
    var driver_ammo: int=hunter.inventory.ammunition()
    session.cooldowns.clear()
    session._shoot(1,hunter.global_position+Vector3.UP*1.4,Vector3.FORWARD)
    check(hunter.inventory.ammunition()==driver_ammo,"the driver cannot shoot")
    for i in 30:
        steer(Vector3.ZERO,1.2);await physics_frame
    check(absf(angle_difference(walker.visual.rotation.y,1.2))<.15,"the gunner turns with his aim")
    check(not session.jeep.exit_seat(walker.peer_id),"cannot jump off a moving truck")
    await drive(Vector2.ZERO,140,true)
    check(absf(truck.speed)<.6,"truck brakes to a stop")
    # Park in the forest, walk up to the workshop, then the driver pulls away.
    session._action(walker.peer_id,"exit","")
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
    await drive(Vector2(0,-1),20)
    check(walker.seat_index>0 and not session.is_cleaning(walker.peer_id),"pulling away moves the worker up to a terrace post")
    check(walker.inventory.items.any(func(item) -> bool: return item.id==&"rabbit_pelt__r4"),"the interrupted hide goes back to the bag")
    await drive(Vector2.ZERO,140,true)
    # Out hunting, the driver's map offers the way home; riders come along again.
    scene.map_menu.open()
    check(scene.map_menu.camp_button.visible and not scene.map_menu.start_button.visible,"the wheel's map offers the way back to camp")
    scene.map_menu.close()
    session.request_action("return_lobby")
    session._accept_loaded(2,session.world_epoch)
    check(await loaded() and session.phase=="lobby","truck brings the crew back to camp")
    check(truck.occupants[0]==1 and walker.seat_index>0,"riders stay aboard on the way home")
    # Crew lines exist in both languages; Gică still opens with the requested line.
    for locale in ["ro","en"]:
        var text: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/"+locale+".json"))
        var missing: Array=[]
        for npc_id in Crew.CREW:
            if not text.has(Crew.name_key(npc_id)): missing.append(Crew.name_key(npc_id))
            for index in Crew.line_count(npc_id):
                if not text.has(Crew.line_key(npc_id,index)): missing.append(Crew.line_key(npc_id,index))
        for key in ["storage","terrace","terrace_exit","RIDER_SECURED","BASE_NAME","BASE_HOUSE_SIGN","SHOP_PROMPT","SHOP_QUOTE","STORAGE_DESC","STASH_SUMMARY","SELL_STASH","STASH_FULL"]:
            if not text.has(key): missing.append(key)
        check(missing.is_empty(),locale+" has every crew line and truck label "+str(missing))
        if locale=="ro": check(text.NPC_GICA_1=="Hai să cumperi de aici în rasa ta!","Gică opens with the requested line")
    var keeper=truck.counters.weapons.keeper
    var seen: Dictionary={}
    for i in 40: seen[keeper.say()]=true
    check(seen.size()>=5 and not seen.has(""),"keeper varies his lines (%d distinct)" % seen.size())
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
