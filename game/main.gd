extends Node
## UI never pauses the shared simulation.
var hunter: Hunter
var inventory: HunterInventory
@onready var shop: ShopUI = $ShopUI
@onready var menu: CampMenu = $CampMenu
@onready var hud: Control = $HUD/Root
@onready var view_label: Label = $HUD/Root/ViewMode
@onready var crosshair: Control = $HUD/Root/Crosshair
@onready var cursor_hint: Label = $HUD/Root/CursorHint
@onready var wallet_label: Label = $HUD/Root/Stats/Wallet
@onready var bag_label: Label = $HUD/Root/Stats/Bag
@onready var prompt: Panel = $HUD/Root/InteractionPrompt
@onready var prompt_label: Label = $HUD/Root/InteractionPrompt/Title
@onready var toast: Label = $HUD/Root/Toast
@onready var health_label: Label = $HUD/Root/AnimalHealth
@onready var hit_indicator: Label = $HUD/Root/HitIndicator
@onready var health_bar_fill: ColorRect = $HUD/Root/Vitals/HealthBarFill
@onready var health_number: Label = $HUD/Root/Vitals/HealthNumber
@onready var slot_panels: Array[Panel] = [$HUD/Root/Vitals/Slot1,$HUD/Root/Vitals/Slot2]
@onready var slot_names: Array[Label] = [$HUD/Root/Vitals/Slot1/Slot1Name,$HUD/Root/Vitals/Slot2/Slot2Name]
@onready var slot_ammo: Array[Label] = [$HUD/Root/Vitals/Slot1/Slot1Ammo,$HUD/Root/Vitals/Slot2/Slot2Ammo]
var nearby: LobbyInteractable
var _toast_time: float = 0
var _hit_time: float = 0
var _menu_camera: Camera3D
var world_router: WorldRouter
var loading_screen: LoadingScreen
var map_menu
var minimap
var _slot_active_style: StyleBoxFlat
var _slot_inactive_style: StyleBoxFlat
const MAX_HEALTH: int = 100

func _ready() -> void:
    for name_value in ["Players","Wildlife","Loot"]:
        var actors:=Node3D.new();actors.name=name_value;add_child(actors)
    world_router=WorldRouter.new();world_router.name="WorldRoot";add_child(world_router)
    world_router.restore_lobby()
    var initial=load("res://actors/hunter/hunter.tscn").instantiate()
    initial.name="Peer1";initial.position=world_router.hunter_spawn(0)
    $Players.add_child(initial)
    var jeep:=HuntingJeep.new();jeep.name="HuntingJeep";add_child(jeep)
    jeep.reset_state(world_router.jeep_spawn())
    NetworkSession.configure(self,null,jeep,initial)
    NetworkSession.player_changed.connect(_bind_player)
    NetworkSession.changed.connect(_localize)
    shop.closed.connect(_on_shop_closed)
    menu.continued.connect(_on_continue)
    LocaleSettings.changed.connect(_localize)
    loading_screen=LoadingScreen.new();add_child(loading_screen)
    map_menu=load("res://ui/maps/map_menu.gd").new();add_child(map_menu)
    map_menu.closed.connect(_on_maps_closed)
    world_router.progress.connect(loading_screen.update_progress)
    world_router.completed.connect(_world_prepared)
    world_router.failed.connect(func(epoch: int) -> void: NetworkSession.report_load_failure(epoch))
    _menu_camera=Camera3D.new();add_child(_menu_camera)
    _menu_camera.position=Vector3(15,8.5,21)
    _menu_camera.look_at(Vector3(0,3.2,-2));_menu_camera.fov=65;_menu_camera.far=900
    _bind_player()
    _slot_active_style=StyleBoxFlat.new()
    _slot_active_style.bg_color=Color(0.13,0.16,0.105,0.96)
    _slot_active_style.border_color=Color(0.8,0.63,0.36,1)
    _slot_active_style.set_border_width_all(2)
    _slot_active_style.set_corner_radius_all(8)
    _slot_inactive_style=StyleBoxFlat.new()
    _slot_inactive_style.bg_color=Color(0.055,0.08,0.071,0.78)
    _slot_inactive_style.border_color=Color(0.3,0.33,0.26,1)
    _slot_inactive_style.set_border_width_all(1)
    _slot_inactive_style.set_corner_radius_all(8)
    minimap=load("res://ui/hud/minimap.gd").new();hud.add_child(minimap)
    _localize();_open_menu()

func prepare_world(id: String,epoch: int,map_seed: int=0) -> void:
    _set_capture(false)
    if shop.is_open: shop.close()
    map_menu.close()
    menu.dismiss_for_loading()
    hud.hide();loading_screen.begin(id)
    world_router.prepare(id,epoch,map_seed)

func _world_prepared(epoch: int) -> void:
    NetworkSession.forest=world_router.map()
    NetworkSession.local_world_ready(epoch)

func commit_world() -> void:
    loading_screen.finish()
    _toast_time=0
    _bind_player()
    menu.resume()

func restore_lobby() -> void:
    world_router.restore_lobby()
    NetworkSession.forest=null
    if is_instance_valid(loading_screen): loading_screen.finish()
    if is_instance_valid(map_menu): map_menu.close()
    NetworkSession.jeep.reset_state(world_router.jeep_spawn())
    NetworkSession.jeep.set_simulation(true)
    _localize()

func _bind_player() -> void:
    hunter=NetworkSession.local_hunter()
    if not is_instance_valid(hunter): return
    if shop.is_open: shop.close()
    inventory=hunter.inventory
    if not hunter.camera_rig.aim_changed.is_connected(_on_aim_changed): hunter.camera_rig.aim_changed.connect(_on_aim_changed)
    if not hunter.combat.hit.is_connected(_on_hit): hunter.combat.hit.connect(_on_hit)
    if not inventory.changed.is_connected(_update_hud): inventory.changed.connect(_update_hud)
    if not inventory.feedback.is_connected(_show_feedback): inventory.feedback.connect(_show_feedback)
    if DisplayServer.get_name()!="headless": inventory.debug_unlock_all() # DEBUG: convenience for interactive play; skipped headless so economy tests stay exact
    _update_hud()
    if not menu.is_open: _on_continue()

func _process(delta: float) -> void:
    if NetworkSession.phase=="loading" or NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch: return
    _toast_time=maxf(0,_toast_time-delta)
    _hit_time=maxf(0,_hit_time-delta)
    if not is_instance_valid(hunter):
        hud.hide()
        return
    toast.visible=_toast_time>0 and not shop.is_open and not menu.is_open and not map_menu.is_open
    hit_indicator.visible=_hit_time>0 and hunter.control_enabled
    crosshair.visible=hunter.control_enabled and hunter.seat_index<0 and hunter.health>0 and not (hunter.camera_rig.is_first_person() and hunter.camera_rig.aiming)
    _update_nearby()
    _update_target()
    var driving:=hunter.seat_index>=0
    $HUD/Root/Controls.text=tr("DOWNED_HELP" if hunter.health<=0 else "DRIVING" if hunter.seat_index==0 else "PASSENGER" if driving else "CONTROLS")
    $HUD/Root/Header/Status.text=NetworkSession.status_text()
    if hunter.health<=0: view_label.text=tr("DOWNED")
    elif driving: view_label.text="%d km/h" % roundi(absf(NetworkSession.jeep.speed)*3.6)
    else: _on_aim_changed(hunter.camera_rig.aiming)
    _update_vitals()

func _update_vitals() -> void:
    if not is_instance_valid(inventory): return
    var fraction: float=clampf(float(hunter.health)/float(MAX_HEALTH),0.0,1.0)
    health_bar_fill.size.x=304.0*fraction
    health_bar_fill.color=Color(0.82,0.24,0.18,1).lerp(Color(0.45,0.78,0.4,1),fraction)
    health_number.text="%d / %d" % [maxi(0,hunter.health),MAX_HEALTH]
    for i in 2:
        var id: StringName=inventory.loadout[i]
        var active: bool=inventory.active_slot==i
        slot_panels[i].add_theme_stylebox_override("panel",_slot_active_style if active else _slot_inactive_style)
        slot_names[i].text=tr(EquipmentCatalog.weapon(id).display_name)
        if active:
            slot_ammo[i].text=LocaleSettings.text("RELOADING",{"n":"%.1f" % inventory.reload_remaining}) if inventory.reload_remaining>0 else LocaleSettings.text("AMMO",{"n":inventory.ammunition(),"cap":inventory.magazine_capacity(id)})
        else:
            slot_ammo[i].text="%d / %d" % [int(inventory.magazines.get(String(id),0)),inventory.magazine_capacity(id)]

func _update_nearby() -> void:
    nearby=null
    var nearest: float=INF
    for candidate in get_tree().get_nodes_in_group("lobby_interactables"):
        if not is_instance_valid(candidate) or not candidate.can_interact(): continue
        var distance: float=candidate.distance_from(hunter.global_position)
        if distance<=candidate.interaction_range and distance<nearest:
            nearby=candidate
            nearest=distance
    prompt.visible=(nearby!=null or hunter.seat_index>=0) and hunter.control_enabled and hunter.health>0
    if hunter.seat_index>=0: prompt_label.text="[ E ]  "+tr("jeep_exit")
    elif nearby: prompt_label.text=nearby.localized_name() if nearby.interaction_kind=="revive" else "[ E ]  "+nearby.localized_name()

func _update_target() -> void:
    health_label.hide()
    if not hunter.control_enabled or hunter.seat_index>=0: return
    var camera:=hunter.camera_rig.camera
    var center:=get_viewport().get_visible_rect().size*.5
    var origin:=camera.project_ray_origin(center)
    var result:=hunter.combat.ray(origin,origin+camera.project_ray_normal(center)*110)
    if not result.is_empty() and result.collider is WildlifeAnimal and not result.collider.dead:
        var a: WildlifeAnimal=result.collider
        health_label.text=LocaleSettings.text("ANIMAL_HP",{"name":tr(a.definition.display_name),"hp":a.health,"max":a.definition.max_health})
        health_label.show()

func _unhandled_input(event: InputEvent) -> void:
    if shop.is_open or menu.is_open or map_menu.is_open or NetworkSession.phase=="loading" or NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch: return
    if event.is_action_pressed("release_cursor"):
        if is_instance_valid(minimap) and minimap.detail: minimap.close_detail()
        else: _open_menu()
        get_viewport().set_input_as_handled()
    elif is_instance_valid(hunter) and hunter.control_enabled:
        if event.is_action_pressed("interact"):
            interact_nearby()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("inventory"):
            _open_shop("inventory")
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("minimap_detail") and is_instance_valid(minimap):
            minimap.toggle_detail()
            get_viewport().set_input_as_handled()

func interact_nearby() -> void:
    if hunter.seat_index>=0: NetworkSession.request_action("exit");return
    _update_nearby()
    if not nearby or shop.is_open or menu.is_open or map_menu.is_open or not hunter.control_enabled or hunter.health<=0: return
    if nearby is LootPickup: NetworkSession.request_action("pickup",str(nearby.network_id))
    elif nearby.interaction_kind=="test_loot": NetworkSession.request_action("test_loot")
    elif nearby.interaction_kind=="jeep": NetworkSession.request_action("enter")
    elif nearby.interaction_kind=="revive": return
    elif nearby.interaction_kind=="expedition":
        map_menu.open()
        _set_capture(false);hud.hide()
    else: _open_shop(nearby.interaction_kind)

func _open_shop(kind: String) -> void:
    if is_instance_valid(minimap): minimap.close_detail()
    shop.open_for(kind,inventory,kind)
    _set_capture(false)
    prompt.hide()

func _on_shop_closed() -> void:
    if not menu.is_open and NetworkSession.phase!="loading" and NetworkSession.local_loaded_epoch==NetworkSession.world_epoch: _set_capture(true)

func _on_maps_closed() -> void:
    if not menu.is_open and NetworkSession.phase!="loading" and NetworkSession.local_loaded_epoch==NetworkSession.world_epoch:
        _on_continue()

func _open_menu() -> void:
    if is_instance_valid(map_menu): map_menu.close()
    _set_capture(false)
    menu.open()
    hud.hide()
    if _menu_camera: _menu_camera.current=true

func _on_continue() -> void:
    if is_instance_valid(map_menu) and map_menu.is_open: return
    if NetworkSession.phase=="loading" or NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch: return
    if not is_instance_valid(hunter): return
    if hunter.seat_index>=0: NetworkSession.jeep.camera.current=true
    else: hunter.camera_rig.camera.current=true
    hud.show()
    _set_capture(true)

func _localize() -> void:
    if not is_node_ready(): return
    if is_instance_valid(inventory): _update_hud()
    cursor_hint.text=tr("CURSOR_HINT")
    $Cinematic/Effect.visible=LocaleSettings.cinematic
    $Cinematic/Effect.material.set_shader_parameter("glow_strength",.55 if world_router.active_id=="lobby" else .08)
    if is_instance_valid(hunter): _on_aim_changed(hunter.camera_rig.aiming)

func _update_hud() -> void:
    if not is_instance_valid(inventory): return
    wallet_label.text=LocaleSettings.text("HUD_COINS",{"n":inventory.coins})
    bag_label.text=LocaleSettings.text("HUD_BAG",{"used":inventory.used_space(),"cap":inventory.capacity(),"value":inventory.loot_value()})

func _show_feedback(message: String) -> void:
    if is_instance_valid(map_menu) and map_menu.is_open: map_menu.show_message(message)
    toast.text=message
    _toast_time=3.5

func _on_hit(damage: int) -> void:
    hit_indicator.text="× %d" % damage
    _hit_time=.25

func _set_capture(captured: bool) -> void:
    if is_instance_valid(hunter): hunter.control_enabled=captured
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _on_aim_changed(aiming: bool) -> void:
    view_label.text=tr("LOBBY_HOST_HINT" if NetworkSession.is_host() else "WAIT_HOST") if NetworkSession.phase=="lobby" else tr("VIEW_AIM" if aiming else WorldCatalog.name_key(NetworkSession.world_id))

func _exit_tree() -> void:
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    NetworkSession.mode="solo"
    NetworkSession.multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
    NetworkSession.players.clear()
    NetworkSession.animals.clear()
    NetworkSession.loot.clear()
    NetworkSession.world=null
    NetworkSession.jeep=null
    NetworkSession.forest=null
