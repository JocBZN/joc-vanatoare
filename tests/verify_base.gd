extends SceneTree
## The Mammoth base: structure, a real hunter walking every floor through the
## host's own movement, the counters' authority checks, private storage and the
## crew's localized lines.
var scene
var session
var base
var hunter
var walker
var checks: int=0
var failures: int=0
var sequence: int=90000

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks+=1
    if ok: print("PASS ",message)
    else: failures+=1;push_error("FAIL "+message)
func frames(count: int) -> void:
    for i in count: await process_frame
func physics(count: int) -> void:
    for i in count: await physics_frame
func local(point: Vector3) -> Vector3:
    return base.to_global(point)
func floor_height(x: float, z: float, from_y: float) -> float:
    var space: PhysicsDirectSpaceState3D=base.get_world_3d().direct_space_state
    var start: Vector3=local(Vector3(x,from_y,z))
    var query:=PhysicsRayQueryParameters3D.create(start,start+Vector3.DOWN*from_y*2.0,1)
    var hit: Dictionary=space.intersect_ray(query)
    return hit.position.y if not hit.is_empty() else -INF
func steer(direction: Vector3) -> void:
    sequence+=1
    session._accept_input(walker.peer_id,{"seq":sequence,"direction":direction,"drive":Vector2.ZERO,"yaw":0.0,"pitch":0.0})
## Walks the walker to each base-local waypoint with the host's real movement code.
func walk(route: Array, label: String) -> bool:
    for waypoint: Vector3 in route:
        var target: Vector3=local(waypoint)
        var reached: bool=false
        for step in 900:
            var flat: Vector3=target-walker.global_position;flat.y=0
            if flat.length()<.35: reached=true;break
            steer(flat.normalized())
            await physics_frame
        if not reached:
            push_error("walk %s stuck before %s at %s" % [label,str(waypoint),str(base.to_local(walker.global_position))])
            steer(Vector3.ZERO)
            return false
    steer(Vector3.ZERO);await physics(8)
    return true

func run() -> void:
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession");scene.menu.resume()
    await frames(5)
    check(session.phase=="lobby","camp loaded")
    base=scene.world_router.active.get_node_or_null("MegaBase")
    check(base!=null,"the Mammoth base stands in the camp")
    if base==null: quit(1);return
    hunter=session.local_hunter();hunter.set_physics_process(false)
    hunter.global_position=Vector3(6,.3,12)
    # Structure and crew.
    var kinds: Array=[]
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.has_method("greet_customer"): kinds.append(stall.interaction_kind)
    kinds.sort()
    check(kinds==["backpacks","sell","storage","weapons"],"four counters aboard: "+str(kinds))
    var old_stalls:=0
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind in ["weapons","backpacks","sell","storage"] and not stall.has_method("greet_customer"): old_stalls+=1
    check(old_stalls==0,"the old canvas stalls are gone")
    for kind in ["weapons","backpacks","sell","storage"]:
        var counter=base.counters[kind]
        var npc_id: String=NpcCatalog.for_kind(kind)
        check(is_instance_valid(counter.keeper) and counter.keeper.npc_id==npc_id,kind+" counter staffed by "+npc_id)
    check(base.keepers.has("nelu") and base.keepers.nelu.pose=="lounge","the driver lounges on the roof")
    var paint:=0
    for child in base.get_children():
        if child is MeshInstance3D and str(child.name).begins_with("Paint"):
            paint+=1
            if not child.has_meta("styled") or child.material_override.diffuse_mode!=BaseMaterial3D.DIFFUSE_TOON: paint=-999
    check(paint>5 and paint<90,"static geometry merged into %d toon colour batches" % paint)
    var shapes: int=base.get_node("Collision").get_child_count()
    check(shapes>60,"base has %d collision shapes" % shapes)
    await physics(3)
    # Floors where the plan says they are.
    check(absf(floor_height(-7.0,.5,20)-(base.global_position.y+base.F3))<.05,"roof deck at %.1f m" % base.F3)
    check(absf(floor_height(-7.0,.5,base.F3-.5)-base.F2)<.05,"bus floor at %.1f m" % base.F2)
    check(absf(floor_height(-7.0,.5,base.F2-.5)-base.F1)<.05,"bazaar deck at %.1f m" % base.F1)
    check(absf(floor_height(-16.0,-3.6,base.F2-.5)-base.F1)<.05 and absf(floor_height(-18.0,5.6,base.F3-.5)-base.F2)<.05,"scaffold landings line up with the floors")
    var mid_ramp: float=floor_height(-16.0,2.0,base.F2-.6)
    check(mid_ramp>.8 and mid_ramp<base.F1,"first ramp climbs (%.2f m halfway)" % mid_ramp)
    # A real hunter climbs all the way up through the host simulation.
    walker=session._spawn_player(2,"Walker")
    walker.world_ready=true
    walker.global_position=local(Vector3(-16,.3,10.5))
    await physics(10)
    var ok: bool=await walk([Vector3(-16,0,7.5),Vector3(-16,0,-2.0),Vector3(-16,0,-3.6),Vector3(-12.5,0,-3.4),Vector3(-12.5,0,.4),Vector3(-7.0,0,-.25)],"bazaar")
    check(ok and absf(walker.global_position.y-base.F1)<.2,"hunter walks up the first ramp into the bazaar (y=%.2f)" % walker.global_position.y)
    check(session._at_stall(walker,"weapons") and not session._at_stall(walker,"storage"),"arsenal counter in reach on floor 1, storage is not")
    ok=await walk([Vector3(-12.5,0,-3.4),Vector3(-16,0,-3.6),Vector3(-18,0,-3.6),Vector3(-18,0,5.6),Vector3(-16,0,5.6),Vector3(-13.4,0,5.6),Vector3(-13.4,0,2.0),Vector3(-3.0,0,-.25)],"storage")
    check(ok and absf(walker.global_position.y-base.F2)<.2,"hunter switches back to the bus floor (y=%.2f)" % walker.global_position.y)
    check(session._at_stall(walker,"storage") and not session._at_stall(walker,"weapons"),"storage counter in reach on floor 2 only")
    ok=await walk([Vector3(-13.4,0,2.0),Vector3(-13.4,0,5.6),Vector3(-16,0,5.6),Vector3(-16,0,-3.6),Vector3(-12.0,0,-3.6),Vector3(-4.0,0,1.0)],"roof")
    check(ok and absf(walker.global_position.y-base.F3)<.2,"hunter reaches the roof (y=%.2f)" % walker.global_position.y)
    var edge_before: Vector3=walker.global_position
    for i in 120:
        steer(Vector3.BACK);await physics_frame
    check(walker.global_position.y>base.F3-.2 and base.to_local(walker.global_position).z<base.W,"roof railing holds a hunter walking into it")
    steer(Vector3.ZERO)
    session.players.erase(2);walker.queue_free()
    # Bounds: the base fills the north edge, nothing beyond it.
    hunter.global_position=Vector3(35,1,-80);session.constrain_to_lobby(hunter)
    check(hunter.global_position.z==session.LOBBY_NORTH_LIMIT and hunter.global_position.x==20,"lobby limit reaches the base's back wall")
    # Private storage through the host's own actions.
    var inv=hunter.inventory
    inv.backpack_id=&"ranger";inv.items.clear();inv.stored.clear();inv.coins=0
    for id in ["rabbit_pelt__s5","deer_pelt__r3","boar_pelt__s2"]: inv.items.append(AnimalCatalog.loot(StringName(id)))
    hunter.global_position=Vector3(0,.3,9)
    session.request_action("stash_deposit")
    check(inv.items.size()==3 and inv.stored.is_empty(),"storage refuses deposits away from the counter")
    hunter.global_position=base.counters.storage.interaction_position()+Vector3.UP*.1
    session.request_action("stash_deposit")
    check(inv.items.is_empty() and inv.stored.size()==3,"backpack goes into storage at the counter")
    var saved: Dictionary=inv.export_state()
    var copy=load("res://systems/inventory/hunter_inventory.gd").new();copy.apply_state(saved)
    check(copy.stored.size()==3 and copy.stored.any(func(item) -> bool: return item.id==&"deer_pelt__r3"),"stored loot keeps its grade through the profile state")
    copy.free()
    session.request_action("stash_withdraw","deer_pelt__r3")
    check(inv.items.size()==1 and inv.items[0].id==&"deer_pelt__r3" and inv.stored.size()==2,"take one kind back for the cleaner")
    session.request_action("stash_withdraw","not_a_loot")
    check(inv.items.size()==1 and inv.stored.size()==2,"unknown ids move nothing")
    session.request_action("stash_withdraw","")
    check(inv.items.size()==3 and inv.stored.is_empty(),"take everything back")
    inv.items.clear()
    for i in 40: inv.items.append(AnimalCatalog.loot(&"bear_pelt__s5"))
    var space: int=AnimalCatalog.loot(&"bear_pelt__s5").space
    inv.backpack_id=&"hoarder"
    session.request_action("stash_deposit")
    check(inv.stash_used()<=inv.STASH_CAPACITY and inv.stash_used()+space>inv.STASH_CAPACITY,"storage stops at its capacity (%d / %d)" % [inv.stash_used(),inv.STASH_CAPACITY])
    inv.items.clear()
    var other=session._spawn_player(3,"Other");other.world_ready=true
    other.global_position=hunter.global_position
    session._action(3,"stash_withdraw","")
    check(other.inventory.items.is_empty() and inv.stash_used()>0,"another hunter cannot empty my storage")
    session.players.erase(3);other.queue_free()
    var value: int=inv.stash_value()
    session.request_action("sell_stash")
    check(inv.coins==0 and not inv.stored.is_empty(),"stored goods only sell at the buyer")
    hunter.global_position=base.counters.sell.interaction_position()+Vector3.UP*.1
    session.request_action("sell_stash")
    check(inv.coins==value and inv.stored.is_empty(),"buyer pays the stored value once (%d)" % value)
    session.request_action("sell_stash")
    check(inv.coins==value,"repeated sale pays nothing")
    # The jeep fits beside the drive-through window the way the other suites park it.
    for offset in [3.0,4.0]:
        session.jeep.reset_state(Transform3D(Basis.IDENTITY,base.counters.sell.global_position+Vector3(offset,.6,0)))
        await physics(40)
        var drift: float=session.jeep.global_position.distance_to(base.counters.sell.global_position+Vector3(offset,0,0))
        check(drift<1.0 and session._car_at_seller(),"jeep parks %.0f m beside the buyer without hitting the truck (drift %.2f)" % [offset,drift])
    # Shop window greets with the keeper's line.
    hunter.global_position=base.counters.weapons.interaction_position()+Vector3.UP*.1
    hunter.control_enabled=true
    scene.interact_nearby()
    check(scene.shop.is_open and scene.shop.kind=="weapons","E at the arsenal opens the weapon shop")
    var keeper=base.counters.weapons.keeper
    check(scene.shop._quote.visible and keeper.display_name() in scene.shop._quote.text and keeper.is_talking(),"Gică shouts a line that heads the shop window")
    scene.shop.close()
    hunter.global_position=base.counters.storage.interaction_position()+Vector3.UP*.1
    scene.interact_nearby()
    check(scene.shop.is_open and scene.shop.kind=="storage" and scene.shop._title.text==tr("storage"),"storage window opens at Moș Debara")
    scene.shop.close()
    # Every crew line exists in both languages and the user's line is in Gică's mouth.
    for locale in ["ro","en"]:
        var text: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/"+locale+".json"))
        var missing: Array=[]
        for npc_id in NpcCatalog.CREW:
            if not text.has(NpcCatalog.name_key(npc_id)): missing.append(NpcCatalog.name_key(npc_id))
            for index in NpcCatalog.line_count(npc_id):
                if not text.has(NpcCatalog.line_key(npc_id,index)): missing.append(NpcCatalog.line_key(npc_id,index))
        for key in ["storage","BASE_NAME","BASE_TAGLINE","BASE_FLOOR_1","BASE_FLOOR_2","BASE_FLOOR_3","BASE_STAIRS","SHOP_PROMPT","SHOP_QUOTE","STORAGE_DESC","STASH_SUMMARY","SELL_STASH","STASH_FULL"]:
            if not text.has(key): missing.append(key)
        check(missing.is_empty(),locale+" has every crew line and base label "+str(missing))
        if locale=="ro": check(text.NPC_GICA_1=="Hai să cumperi de aici în rasa ta!","Gică opens with the requested line")
    var seen: Dictionary={}
    for i in 40: seen[keeper.say()]=true
    check(seen.size()>=5 and not seen.has(""),"keeper varies his lines (%d distinct)" % seen.size())
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8);quit(1 if failures else 0)
