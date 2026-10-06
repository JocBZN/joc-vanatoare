extends SceneTree
var failures: int=0
var checks: int=0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, description: String) -> void:
    checks+=1
    if condition: print("PASS ",description)
    else: failures+=1;push_error("FAIL "+description)
func frames(count: int) -> void:
    for i in count: await physics_frame
func run() -> void:
    var scene=load("res://game/main.tscn").instantiate()
    root.add_child(scene);current_scene=scene
    var session=root.get_node("NetworkSession")
    scene.menu.resume()
    await frames(8)
    var p=scene.hunter
    var inv=p.inventory
    check(session.phase=="lobby" and session.animals.is_empty(),"forest waits for host Start")
    var free_dispenser:=false
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="test_loot": free_dispenser=true
    check(not free_dispenser,"production economy has no unlimited free loot dispenser")
    check(scene.world_router.active_id=="lobby" and session.forest==null,"lobby scenery separate from forest")
    p.global_position=Vector3(35,1,-80)
    session.constrain_to_lobby(p)
    check(p.global_position.x<=20 and p.global_position.z>=session.LOBBY_NORTH_LIMIT,"hunter cannot bypass lobby boundary")
    session.jeep.global_position=Vector3(0,1,-55);session.jeep.speed=12
    session.constrain_to_lobby(session.jeep,true)
    check(session.jeep.global_position.z>=-17 and session.jeep.speed==0,"jeep also waits in lobby")
    session.jeep.reset_state(scene.world_router.jeep_spawn())
    var other=session._spawn_player(2,"Other")
    session._action(2,"start_hunt","")
    check(session.phase=="lobby","client cannot start expedition")
    check(inv.owned_weapons==[&"rusty_pistol"] and inv.coins==0,"fresh hunter starts with rusty pistol only")
    check(not inv.equip_weapon(&"thunder_tube"),"unowned weapon cannot equip")
    check(not inv.buy_weapon(&"old_rifle") and inv.coins==0,"insufficient money purchase is atomic")
    inv.coins=2000
    p.global_position=Vector3(0,1,0)
    session.request_action("buy_weapon","beehive")
    check(not inv.owns_weapon(&"beehive") and inv.coins==2000,"server rejects purchase away from stall")
    var seller
    for stall in get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="weapons": seller=stall
    p.global_position=seller.interaction_position()
    session.request_action("buy_weapon","beehive")
    check(inv.owns_weapon(&"beehive") and inv.coins==800,"server commits weapon purchase price")
    check(inv.equipped_weapon_id==&"beehive" and inv.ammunition()==40,"purchased weapon equipped with correct magazine")
    session.request_action("buy_weapon","beehive")
    check(inv.coins==800,"repeated purchase cannot charge again")
    var original_damage: int=inv.weapon_damage(&"beehive")
    var original_rate: float=inv.weapon_cooldown(&"beehive")
    session.request_action("upgrade","beehive:damage")
    check(inv.coins==540 and inv.weapon_damage(&"beehive")>original_damage,"damage upgrade charges and changes damage")
    check(inv.weapon_cooldown(&"beehive")==original_rate,"damage upgrade does not change cadence")
    session.request_action("upgrade","beehive:rate")
    check(inv.coins==306 and inv.weapon_cooldown(&"beehive")<original_rate,"rate upgrade reduces server cooldown")
    session.request_action("upgrade","beehive:magazine")
    check(inv.coins==98 and inv.magazine_capacity(&"beehive")==50,"magazine upgrade expands capacity")
    check(inv.ammunition()==40,"capacity upgrade does not grant free ammunition")
    check(other.inventory.coins==0 and not other.inventory.owns_weapon(&"beehive"),"purchases leave other hunter untouched")
    var before: Dictionary=inv.export_state().duplicate(true)
    session.request_action("upgrade","beehive:banana")
    session.request_action("upgrade","unknown:damage")
    check(inv.export_state()==before,"unknown upgrade commands do not mutate state")
    session.request_action("upgrade","beehive:damage")
    check(inv.export_state()==before,"insufficient money upgrade is atomic")
    inv.coins=10000
    for i in 3: inv.buy_upgrade(&"beehive","damage")
    var cap_coins: int=inv.coins
    check(inv.upgrade_level(&"beehive","damage")==3,"upgrade stops at level three")
    check(not inv.buy_upgrade(&"beehive","damage") and inv.coins==cap_coins,"max upgrade never charges")
    var restored=load("res://systems/inventory/hunter_inventory.gd").new()
    scene.add_child(restored)
    restored.apply_state(inv.export_state())
    check(restored.owned_weapons==inv.owned_weapons and restored.weapon_upgrades==inv.weapon_upgrades,"owned weapons and separate upgrades round-trip")
    check(restored.magazines==inv.magazines,"magazine ammunition round-trips")
    session._peer_disconnected(2)
    start_forest()
    await frames(2)
    for i in 2400:
        if session.phase!="loading": break
        await process_frame
    check(session.phase=="hunt" and session.animals.size()>=24,"host Start loads expedition before spawning")
    check(scene.world_router.active_id=="forest" and not scene.world_router.active.has_node("Camp"),"Start unloads lobby scenery")
    var count: int=session.animals.size()
    start_forest()
    check(session.animals.size()==count,"double Start cannot duplicate wildlife")
    p.global_position=Vector3(0,.2,-90);p.visual.rotation.y=0
    inv.equip_weapon(&"rusty_pistol")
    inv.buy_upgrade(&"rusty_pistol","damage")
    var a=session.spawn_animal(&"bear",Vector3(0,0,-96));a.set_physics_process(false)
    await frames(12)
    var hp: int=a.health
    var ammo: int=inv.ammunition()
    var origin: Vector3=p.global_position+Vector3(0,1.4,0)
    var direction: Vector3=(a.global_position+Vector3(0,1,0)-origin).normalized()
    session._shoot(1,origin,direction)
    check(a.health==hp-inv.weapon_damage(&"rusty_pistol"),"server ray uses upgraded damage")
    check(inv.ammunition()==ammo-1,"a shot consumes one round")
    hp=a.health
    session._shoot(1,origin,direction)
    check(a.health==hp and inv.ammunition()==ammo-1,"cooldown blocks damage and ammunition consumption")
    inv.magazines["rusty_pistol"]=0;session.cooldowns.clear()
    session._shoot(1,origin,direction)
    check(inv.reload_remaining>0 and a.health==hp,"empty magazine starts reload without damage")
    session._shoot(1,origin,direction)
    check(a.health==hp,"cannot fire during reload")
    inv.tick_reload(2)
    check(inv.reload_remaining==0 and inv.ammunition()==inv.magazine_capacity(&"rusty_pistol"),"reload fills actual magazine")
    inv.consume_round();inv.begin_reload();inv.equip_weapon(&"beehive")
    check(inv.reload_remaining==0,"changing weapon cancels active reload")
    scene._open_shop("weapons")
    await frames(4)
    check(scene.shop.preview.model!=null and scene.shop.preview.viewport.own_world_3d,"shop has isolated live 3D preview")
    check(not scene.shop._scroll.visible and scene.shop._catalog.visible,"weapon shop uses carousel")
    scene.shop.browse(-1)
    check(scene.shop._selected_index==EquipmentCatalog.WEAPONS.size()-1,"left arrow wraps to last weapon")
    scene.shop.browse(1)
    check(scene.shop._selected_index==0,"right arrow wraps to first weapon")
    var preview=scene.shop.preview
    var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
    preview._gui_input(click)
    var yaw: float=preview.pivot.rotation.y
    var motion:=InputEventMouseMotion.new();motion.relative=Vector2(80,20)
    preview._gui_input(motion)
    check(preview.pivot.rotation.y!=yaw and preview.manipulated,"mouse drag rotates preview model")
    click.pressed=false;preview._gui_input(click)
    check(not preview.dragging,"mouse release ends rotation")
    root.get_node("LocaleSettings").set_language("en")
    check(scene.shop._rotate_hint.text==TranslationServer.translate("ROTATE_HINT"),"carousel language updates live")
    scene.shop.close()
    scene._open_shop("backpacks")
    scene.shop.browse(2)
    check(scene.shop._selected_index==2 and scene.shop.preview.model!=null,"backpack carousel previews selected bag")
    scene.shop.close()
    await frames(2)
    check(scene.shop.preview.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"closed shop stops preview rendering")
    for entry in EquipmentCatalog.WEAPONS:
        check(ResourceLoader.exists(entry.model_path) and ResourceLoader.exists(entry.fire_sound),"model and sound exist "+String(entry.id))
    print("RESULT ",checks," checks, ",failures," failures")
    scene.queue_free();await frames(8)
    quit(1 if failures else 0)

func start_forest() -> void:
    var session=root.get_node("NetworkSession")
    if session.phase=="lobby" and session.is_host():
        var fire=session.world.world_router.active.get_node("Camp/GiantCampfire/Expedition")
        session.local_hunter().global_position=fire.global_position+Vector3(0,.5,3.4)
    session.request_action("start_hunt","forest")
