extends Node
## UI never pauses the shared simulation.
var hunter: Hunter
var inventory: HunterInventory
@onready var shop: ShopUI = $ShopUI
@onready var menu: CampMenu = $CampMenu
@onready var hud: Control = $HUD/Root
@onready var crosshair: Control = $HUD/Root/Crosshair
## The drawn HUD (ui/hud/hud_view.gd): vitals, weapon, prompt, toasts, boss bar.
var hud_view
## The animal under the crosshair, for the HUD's target readout.
var target_animal: WildlifeAnimal
var harvest_panel
var cleaning_panel
var _clean_pending_time: float=0
var _harvest_camera: Camera3D
var _harvest_tool
var _harvest_focus_hunter: Hunter
var _harvest_pending_time: float=0
var _harvest_ignored_id: int=0
var nearby: LobbyInteractable
var _menu_camera: Camera3D
var world_router: WorldRouter
var loading_screen: LoadingScreen
var map_menu
var minimap
var _last_seat: int=-1

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
    harvest_panel=load("res://ui/harvest/harvest_panel.gd").new();add_child(harvest_panel)
    harvest_panel.cancel_requested.connect(_cancel_harvest)
    cleaning_panel=load("res://ui/cleaning/cleaning_panel.gd").new();add_child(cleaning_panel)
    cleaning_panel.cancel_requested.connect(_cancel_clean)
    _harvest_camera=Camera3D.new();_harvest_camera.name="HarvestCamera";add_child(_harvest_camera)
    _harvest_camera.near=.05;_harvest_camera.fov=67;_harvest_camera.far=900
    _harvest_tool=load("res://actors/hunter/harvest_tool.gd").new();_harvest_camera.add_child(_harvest_tool)
    hud_view=load("res://ui/hud/hud_view.gd").new();hud_view.name="HudView";hud_view.main=self
    hud.add_child(hud_view);hud.move_child(hud_view,0)
    minimap=load("res://ui/hud/minimap.gd").new();minimap.name="Minimap";hud.add_child(minimap)
    _bind_player()
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
    _bind_player()
    menu.resume()

func restore_lobby() -> void:
    _cancel_harvest()
    _cancel_clean()
    world_router.restore_lobby()
    NetworkSession.forest=null
    if is_instance_valid(loading_screen): loading_screen.finish()
    if is_instance_valid(map_menu): map_menu.close()
    NetworkSession.jeep.reset_state(world_router.jeep_spawn())
    NetworkSession.jeep.set_simulation(true)
    _localize()

func _bind_player() -> void:
    _release_harvest_focus()
    hunter=NetworkSession.local_hunter()
    if not is_instance_valid(hunter): return
    if shop.is_open: shop.close()
    inventory=hunter.inventory
    if not hunter.combat.hit.is_connected(_on_hit): hunter.combat.hit.connect(_on_hit)
    if not hunter.combat.fired.is_connected(_on_fired): hunter.combat.fired.connect(_on_fired)
    if not inventory.changed.is_connected(_update_hud): inventory.changed.connect(_update_hud)
    if not inventory.feedback.is_connected(_show_feedback): inventory.feedback.connect(_show_feedback)
    if DisplayServer.get_name()!="headless": inventory.debug_unlock_all() # DEBUG: convenience for interactive play; skipped headless so economy tests stay exact
    _update_hud()
    if not menu.is_open: _on_continue()

func _process(delta: float) -> void:
    _update_harvest(delta)
    _update_clean(delta)
    if NetworkSession.phase=="loading" or NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch: return
    if not is_instance_valid(hunter):
        hud.hide()
        return
    crosshair.visible=hunter.control_enabled and not hunter.busy() and hunter.seat_index!=0 and hunter.health>0 and not (hunter.camera_rig.is_first_person() and hunter.camera_rig.aiming)
    _update_nearby()
    _update_target()
    _watch_seat()

func _update_nearby() -> void:
    nearby=null
    if is_instance_valid(harvest_panel) and (harvest_panel.is_open() or cleaning_panel.is_open()): return
    var nearest: float=INF
    var seated: bool=is_instance_valid(hunter) and hunter.seat_index>=0
    for candidate in [] if seated else get_tree().get_nodes_in_group("lobby_interactables"):
        if not is_instance_valid(candidate) or not candidate.can_interact(): continue
        var distance: float=candidate.distance_from(hunter.global_position)
        if distance<=candidate.interaction_range and distance<nearest:
            nearby=candidate
            nearest=distance

func _update_target() -> void:
    target_animal=null
    if not hunter.control_enabled or hunter.seat_index==0 or hunter.busy(): return
    var camera:=hunter.camera_rig.camera
    var center:=get_viewport().get_visible_rect().size*.5
    var origin:=camera.project_ray_origin(center)
    var result:=hunter.combat.ray(origin,origin+camera.project_ray_normal(center)*110)
    if not result.is_empty() and result.collider is WildlifeAnimal and not result.collider.dead:
        target_animal=result.collider

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
        elif event.is_action_pressed("expedition_map") and hunter.seat_index==0:
            open_map_menu()
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("minimap_detail") and is_instance_valid(minimap):
            minimap.toggle_detail()
            get_viewport().set_input_as_handled()
        elif event is InputEventMouseButton and event.pressed and is_instance_valid(minimap) and minimap.detail and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            minimap.zoom_full(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1)
            get_viewport().set_input_as_handled()

func interact_nearby() -> void:
    if is_instance_valid(harvest_panel) and harvest_panel.is_open(): _cancel_harvest();return
    if is_instance_valid(cleaning_panel) and cleaning_panel.is_open(): _cancel_clean();return
    if hunter.seat_index>=0: NetworkSession.request_action("exit");return
    _update_nearby()
    if not nearby or shop.is_open or menu.is_open or map_menu.is_open or not hunter.control_enabled or hunter.health<=0: return
    if nearby is LootPickup: NetworkSession.request_action("pickup",str(nearby.network_id))
    elif nearby.interaction_kind=="test_loot": NetworkSession.request_action("test_loot")
    elif nearby.interaction_kind=="jeep": NetworkSession.request_action("enter")
    elif nearby.interaction_kind in ["board","alight","ladder_up","ladder_down"]: NetworkSession.request_action("climb",nearby.interaction_kind)
    elif nearby.interaction_kind=="revive": return
    elif nearby.interaction_kind=="harvest": _begin_harvest(nearby.get_parent() as WildlifeAnimal)
    elif nearby.interaction_kind=="cleaner": _begin_clean()
    elif nearby.interaction_kind=="expedition": open_map_menu()
    else: _open_shop(nearby.interaction_kind)

## The expedition map: from the truck's wheel (Tab, or straight away when the
## host takes the wheel in camp) or beside the campfire.
func open_map_menu() -> void:
    if map_menu.is_open or shop.is_open or menu.is_open: return
    if is_instance_valid(minimap): minimap.close_detail()
    map_menu.open()
    _set_capture(false);hud.hide()

func _watch_seat() -> void:
    var seat: int=hunter.seat_index
    if seat==_last_seat: return
    _last_seat=seat
    if seat==0 and NetworkSession.phase=="lobby" and NetworkSession.is_host() and hunter.control_enabled: open_map_menu()

func _open_shop(kind: String) -> void:
    if is_instance_valid(minimap): minimap.close_detail()
    shop.open_for(kind,inventory,kind)
    _set_capture(false)

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
    if hunter.seat_index==0: NetworkSession.jeep.camera.current=true
    else: hunter.camera_rig.camera.current=true
    hud.show()
    _set_capture(true)

func _localize() -> void:
    if not is_node_ready(): return
    $Cinematic/Effect.visible=LocaleSettings.cinematic
    $Cinematic/Effect.material.set_shader_parameter("glow_strength",.55 if world_router.active_id=="lobby" else .08)
    if is_instance_valid(hud_view): hud_view.queue_redraw()

## The drawn HUD reads the inventory every frame; this only nudges a redraw.
func _update_hud() -> void:
    if is_instance_valid(hud_view): hud_view.queue_redraw()

func _show_feedback(message: String) -> void:
    if is_instance_valid(map_menu) and map_menu.is_open: map_menu.show_message(message)
    if is_instance_valid(hud_view): hud_view.toast(message)

func _on_hit(damage: int) -> void:
    if is_instance_valid(hud_view): hud_view.hit(damage)
    crosshair.flash()

func _on_fired() -> void:
    crosshair.kick()

func _set_capture(captured: bool) -> void:
    if not captured: _cancel_harvest();_cancel_clean()
    if is_instance_valid(hunter): hunter.control_enabled=captured
    Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _begin_harvest(animal: WildlifeAnimal) -> void:
    if not is_instance_valid(animal) or not animal.dead or animal.harvested: return
    if animal.harvest_owner>0 and animal.harvest_owner!=hunter.peer_id:
        _show_feedback(tr("HARVEST_BUSY"));return
    _harvest_ignored_id=0
    if is_instance_valid(minimap): minimap.close_detail()
    _harvest_pending_time=1.5
    hunter.harvest_target=animal.animal_id;hunter.harvest_input_guard=true;hunter.jump_pending=false;hunter.revive_target=0
    harvest_panel.begin_harvest(animal.animal_id,String(animal.definition.id))
    _hold_harvest_focus(animal.animal_id)
    NetworkSession.request_action("harvest_start",str(animal.animal_id))

func _update_harvest(delta: float) -> void:
    if not is_instance_valid(harvest_panel): return
    var unavailable: bool=not is_instance_valid(hunter) or NetworkSession.phase!="hunt" or NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch
    unavailable=unavailable or shop.is_open or menu.is_open or map_menu.is_open
    if is_instance_valid(hunter): unavailable=unavailable or hunter.health<=0 or hunter.seat_index>=0 or not hunter.control_enabled
    if unavailable:
        if harvest_panel.is_open() or is_instance_valid(_harvest_focus_hunter): _cancel_harvest()
        harvest_panel.close()
        return
    var state: Dictionary=NetworkSession.harvest_state(hunter.peer_id)
    if state.is_empty():
        _harvest_ignored_id=0
        if harvest_panel.pending:
            _harvest_pending_time=maxf(0,_harvest_pending_time-delta)
            hunter.harvest_target=int(harvest_panel.state.get("id",0))
            if _harvest_pending_time<=0: _cancel_harvest()
        elif harvest_panel.is_open():
            harvest_panel.close();_release_harvest_focus()
        return
    if bool(state.get("active",false)):
        if int(state.get("id",0))==_harvest_ignored_id:
            hunter.harvest_target=0
            return
        hunter.harvest_target=int(state.id)
        _hold_harvest_focus(hunter.harvest_target)
        harvest_panel.show_state(state)
        _harvest_tool.observe(state)
    else:
        if int(state.get("id",0))!=_harvest_ignored_id: harvest_panel.show_state(state)
        if state.get("feedback","")=="complete" and is_instance_valid(_harvest_focus_hunter):
            _harvest_tool.observe(state)
            if _harvest_tool.is_finishing():
                hunter.harvest_target=int(state.get("id",0))
                return
        _release_harvest_focus()

func _hold_harvest_focus(id: int) -> void:
    if not is_instance_valid(hunter): return
    if _harvest_focus_hunter!=hunter:
        _release_harvest_focus()
        _harvest_focus_hunter=hunter
        var animal=NetworkSession.animals.get(id)
        _harvest_camera.global_position=hunter.global_position+Vector3.UP*1.3
        if is_instance_valid(animal):
            var target: Vector3=_harvest_surface_point(animal)
            var approach: Vector3=hunter.global_position-target;approach.y=0
            if approach.length_squared()<.01: approach=Vector3.BACK
            _harvest_camera.global_position=target+approach.normalized()*.90+Vector3.UP*.52
            if _harvest_camera.global_position.distance_squared_to(target)>.01: _harvest_camera.look_at(target)
            _harvest_tool.configure_surface(_harvest_camera.to_local(target),animal.definition.id)
    hunter.camera_rig.enabled=false;hunter.camera_rig.set_process(false)
    hunter.camera_rig.set_aiming(false)
    hunter.camera_rig.view_model.hide();hunter.camera_rig.scope_overlay.hide();hunter.visual.hide()
    _harvest_camera.current=true
    _harvest_tool.set_active(true)
    target_animal=null;crosshair.hide()

func _harvest_surface_point(animal: WildlifeAnimal) -> Vector3:
    # Follow the posed torso rather than the upright collision box of a dead animal.
    for skeleton: Skeleton3D in animal.model.find_children("*","Skeleton3D",true,false):
        for index in skeleton.get_bone_count():
            var bone: String=skeleton.get_bone_name(index).to_lower()
            if "spine" in bone or "chest" in bone or bone=="body":
                var point: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
                return point+Vector3.UP*.12
    return animal.global_position+Vector3.UP*minf(animal.definition.height*.3,.65)

func _release_harvest_focus() -> void:
    if is_instance_valid(_harvest_tool): _harvest_tool.set_active(false)
    if not is_instance_valid(_harvest_focus_hunter): _harvest_focus_hunter=null;return
    var previous: Hunter=_harvest_focus_hunter
    _harvest_focus_hunter=null
    previous.harvest_target=0;previous.harvest_input_guard=true;previous.jump_pending=false
    previous.camera_rig.enabled=previous.local_player and previous.seat_index!=0
    previous.camera_rig.set_process(true)
    previous.visual.visible=not previous.camera_rig.is_first_person()
    if previous==hunter and previous.control_enabled and not menu.is_open:
        previous.camera_rig.camera.current=true

func _cancel_harvest() -> void:
    if not is_instance_valid(harvest_panel): return
    var needs_cancel: bool=harvest_panel.is_open() or is_instance_valid(_harvest_focus_hunter)
    if needs_cancel:
        _harvest_ignored_id=int(harvest_panel.state.get("id",0))
        NetworkSession.request_action("harvest_cancel")
    harvest_panel.close();_release_harvest_focus()
    if is_instance_valid(hunter): hunter.harvest_target=0;hunter.jump_pending=false

## The camp cleaner: no camera change, the hunter just stands at the machine
## while the panel owns the mouse. The host picks the best raw hide in the bag.
func _begin_clean() -> void:
    var raw: LootDefinition=null
    for item in inventory.items:
        if item.raw and (raw==null or item.stars>raw.stars): raw=item
    if raw==null: _show_feedback(tr("CLEAN_NOTHING"));return
    if is_instance_valid(minimap): minimap.close_detail()
    _clean_pending_time=1.5
    hunter.cleaning=true;hunter.harvest_input_guard=true;hunter.jump_pending=false;hunter.revive_target=0
    hunter.camera_rig.set_aiming(false)
    cleaning_panel.begin_cleaning(String(raw.id))
    NetworkSession.request_action("clean_start")

func _update_clean(delta: float) -> void:
    if not is_instance_valid(cleaning_panel): return
    var unavailable: bool=not is_instance_valid(hunter) or NetworkSession.phase=="loading" or NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch
    unavailable=unavailable or shop.is_open or menu.is_open or map_menu.is_open
    if is_instance_valid(hunter): unavailable=unavailable or hunter.health<=0 or hunter.seat_index>=0 or not hunter.control_enabled
    if unavailable:
        if cleaning_panel.is_open(): _cancel_clean()
        return
    var state: Dictionary=NetworkSession.clean_state(hunter.peer_id)
    if bool(state.get("active",false)):
        hunter.cleaning=true
        cleaning_panel.show_state(state)
    elif cleaning_panel.pending:
        _clean_pending_time=maxf(0,_clean_pending_time-delta)
        if _clean_pending_time<=0: _cancel_clean()
    else:
        hunter.cleaning=false
        if not state.is_empty(): cleaning_panel.show_state(state)

func _cancel_clean() -> void:
    if not is_instance_valid(cleaning_panel): return
    if cleaning_panel.is_open(): NetworkSession.request_action("clean_cancel")
    cleaning_panel.close()
    if is_instance_valid(hunter): hunter.cleaning=false;hunter.jump_pending=false

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
