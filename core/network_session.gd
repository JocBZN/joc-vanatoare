extends Node
## Authority and transport boundary. Steam can supply a MultiplayerPeer via attach_peer.
signal changed
signal player_changed
signal trunk_changed
## The truck's upgrade levels changed (bought here, or replicated from the host).
signal truck_changed
const MAX_PLAYERS = 4
const TRUNK_CAPACITY = 120
var world
var players: Dictionary = {}
var animals: Dictionary = {}
var loot: Dictionary = {}
const CLIMB_ROUTES: Array=["board","alight","ladder_up","ladder_down","tower_up","tower_down","deck_down","deck_up","board_deck","sphere_down","sphere_up"]
var jeep
var forest
var mode: String = "solo"
var status_key: String = "NET_SOLO"
var status_args: Dictionary = {}
var nickname: String = "Hunter"
var profiles: Dictionary = {}
var identities: Dictionary = {}
var owner_names: Dictionary = {}
var trunk: Array = []
var trunk_view: Array = []
var next_animal: int = 1
var next_loot: int = 1
var tick: float = 0.0
var spawn_clock: float = 0.0
## Bosses: at most MAX_BOSSES alive per map, the next one after `boss_clock`.
const MAX_BOSSES: int = 2
var boss_clock: float = 0.0
var rng := RandomNumberGenerator.new()
var pending_peers: Dictionary = {}
var cooldowns: Dictionary = {}
var last_inputs: Dictionary = {}
var connect_clock: float = 0.0
var snapshot_sequence: int = 0
var roster_sequence: int = -1
var animal_sequences: Dictionary = {}
var phase: String = "lobby"
var world_id: String="lobby"
var world_epoch: int=0
var active_map_seed: int=0
var local_loaded_epoch: int=0
var loading_members: Array=[]
var ready_players: Dictionary={}
var loading_clock: float=0
var required_players: int=1
const REVIVE_SECONDS: float=3.0
var revive_jobs: Dictionary={}
var health_profiles: Dictionary={}
const MAX_CORPSES: int=80
var harvest_jobs: Dictionary={}
var harvest_views: Dictionary={}
var local_harvest_state: Dictionary={}
## Virtual blade driven by the local harvest panel. It is an intention only:
## the host re-derives every seam and flap and scores it, never trusting a result.
var local_blade: Vector2=Vector2(.5,.5)
var harvest_token: int=0
var harvest_sequence: int=0
var harvest_received_sequence: int=-1
## Camp cleaner jobs, mirroring the harvest jobs above.
var clean_jobs: Dictionary={}
var clean_views: Dictionary={}
var local_clean_state: Dictionary={}
var clean_token: int=0
var clean_sequence: int=0
var clean_received_sequence: int=-1
## Who rode the truck out of the last map (host only): the driver, and every
## hunter aboard on foot with their truck-local position.
var travel_driver: int=0
var travel_riders: Dictionary={}
## Shared upgrade levels of the Wandering Oak (see TruckUpgrades). The host is
## the authority; the truck snapshot carries them to everyone else.
var truck_state: Dictionary=TruckUpgrades.fresh()

func _ready() -> void:
    rng.seed=10337
    multiplayer.server_relay=false
    multiplayer.peer_connected.connect(_peer_connected)
    multiplayer.peer_disconnected.connect(_peer_disconnected)
    multiplayer.connected_to_server.connect(_connected)
    multiplayer.connection_failed.connect(_failed)
    multiplayer.server_disconnected.connect(_failed)

func is_host() -> bool:
    return mode!="client" and mode!="connecting"

func local_id() -> int:
    return multiplayer.get_unique_id()

func local_hunter():
    return players.get(local_id())

func configure(scene, map, vehicle, initial) -> void:
    world=scene
    forest=map
    jeep=vehicle
    initial.peer_id=1
    initial.local_player=true
    players[1]=initial
    identities[1]=LocaleSettings.profile_id
    owner_names[LocaleSettings.profile_id]=nickname
    initial.player_name=nickname
    phase="lobby"
    world_id="lobby"
    world_epoch=0
    local_loaded_epoch=0

func attach_peer(peer: MultiplayerPeer, hosting: bool) -> void:
    # All gameplay commands stay independent of ENet / future Steam transport.
    if not hosting: _clear_world();connect_clock=10
    multiplayer.multiplayer_peer=peer
    mode="host" if hosting else "connecting"

func host_game(name_value: String, port: int) -> Error:
    leave_game()
    nickname=_safe_name(name_value)
    var peer := ENetMultiplayerPeer.new()
    var error:=peer.create_server(clampi(port,1024,65535),3)
    if error!=OK:
        _status("NET_FAILED")
        return error
    attach_peer(peer,true)
    players[1].player_name=nickname
    owner_names[identities[1]]=nickname
    _status("NET_HOST",{"port":port,"n":1})
    changed.emit()
    return OK

func join_game(name_value: String, address: String, port: int) -> Error:
    leave_game()
    nickname=_safe_name(name_value)
    var peer := ENetMultiplayerPeer.new()
    var error:=peer.create_client(address.strip_edges(),clampi(port,1024,65535))
    if error!=OK: _status("NET_FAILED");return error
    _clear_world()
    attach_peer(peer,false)
    connect_clock=10
    _status("NET_CONNECTING")
    return OK

func leave_game() -> void:
    if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
    if world:
        _clear_world()
        mode="solo"
        _spawn_player(1,nickname)
        identities={1:LocaleSettings.profile_id}
        owner_names={LocaleSettings.profile_id:nickname}
        profiles.clear();health_profiles.clear();revive_jobs.clear()
        trunk.clear()
        trunk_view.clear()
        jeep.occupants=[0]
        world_id="lobby";world_epoch=0;local_loaded_epoch=0
        loading_members.clear();ready_players.clear()
        world.restore_lobby()
        _set_phase("lobby")
        player_changed.emit()
        trunk_changed.emit()
    mode="solo"
    pending_peers.clear()
    last_inputs.clear()
    cooldowns.clear()
    _status("NET_SOLO")

func _clear_world() -> void:
    if OS.get_environment("HUNT_NET_TRACE")=="1": print("TRACE clear world ",mode)
    _clear_harvests()
    _clear_cleans()
    for collection in [players,animals,loot]:
        for node in collection.values():
            node.get_parent().remove_child(node)
            node.queue_free()
        collection.clear()
    animal_sequences.clear()
    roster_sequence=-1

func _spawn_player(peer: int, player_name: String):
    if players.has(peer): return players[peer]
    var p=load("res://actors/hunter/hunter.tscn").instantiate()
    p.name="Peer"+str(peer)
    p.peer_id=peer
    p.player_name=player_name
    p.local_player=peer==local_id()
    p.world_ready=phase=="lobby"
    p.position=Vector3((players.size()%4)*2,.3,9)
    world.get_node("Players").add_child(p)
    players[peer]=p
    return p

func _peer_connected(peer: int) -> void:
    if is_host(): pending_peers[peer]=Time.get_ticks_msec()

func _peer_disconnected(peer: int) -> void:
    if OS.get_environment("HUNT_NET_TRACE")=="1": print("TRACE disconnected ",peer," mode ",mode)
    pending_peers.erase(peer)
    _cancel_harvest(peer,"cancelled",false)
    harvest_views.erase(peer)
    _cancel_clean(peer,false)
    clean_views.erase(peer)
    if players.has(peer):
        if is_host():
            profiles[identities.get(peer,"")]=players[peer].inventory.export_state()
            health_profiles[identities.get(peer,"")]=players[peer].health
            jeep.exit_seat(peer,true)
        players[peer].queue_free()
        players.erase(peer)
        identities.erase(peer)
        last_inputs.erase(peer)
        if is_host(): call_deferred("_publish_trunk")
        loading_members.erase(peer)
        ready_players.erase(peer)
        if is_host() and phase=="loading": call_deferred("_check_loaded")
        changed.emit()

func _connected() -> void:
    _register.rpc_id(1,nickname,LocaleSettings.profile_id)

func _failed() -> void:
    if OS.get_environment("HUNT_NET_TRACE")=="1": print("TRACE connection failed ",mode)
    leave_game()
    _status("NET_FAILED")

@rpc("any_peer","call_remote","reliable",0)
func _register(name_value: String, profile: String) -> void:
    if not is_host(): return
    var peer:=multiplayer.get_remote_sender_id()
    if not pending_peers.has(peer) or players.size()>=4: return
    if profile.length()!=32 or not profile.is_valid_hex_number(false) or identities.values().has(profile):
        multiplayer.multiplayer_peer.disconnect_peer(peer)
        return
    pending_peers.erase(peer)
    var p=_spawn_player(peer,_safe_name(name_value))
    identities[peer]=profile
    owner_names[profile]=p.player_name
    if profiles.has(profile): p.inventory.apply_state(profiles[profile])
    if health_profiles.has(profile): p.health=int(health_profiles[profile])
    p.world_ready=false
    if phase=="loading": loading_members.append(peer)
    snapshot_sequence+=1
    _welcome.rpc_id(peer,_snapshot(),_loot_state(),p.inventory.export_state(),_trunk_for(peer))
    _status("NET_HOST",{"port":status_args.get("port",24567),"n":players.size()})
    _publish_trunk()
    if phase=="loading": _publish_loading()

@rpc("authority","call_remote","reliable",0)
func _welcome(data: Dictionary, pickups: Array, inventory_data: Dictionary, cargo: Array) -> void:
    mode="client"
    world_id=data.get("world","lobby")
    world_epoch=int(data.get("epoch",0))
    active_map_seed=int(data.get("seed",0))
    local_loaded_epoch=-1
    _apply_snapshot(data)
    for item in pickups: _make_loot(item.id,item.kind,item.p)
    var p=local_hunter()
    if p: p.inventory.apply_state(inventory_data)
    trunk_view=cargo
    _status("NET_JOINED")
    player_changed.emit()
    trunk_changed.emit()
    if world:
        if world_id=="lobby" and phase!="loading" and world.world_router.active_id=="lobby":
            local_loaded_epoch=world_epoch
            _loaded_world.rpc_id(1,world_epoch)
        else:
            jeep.set_simulation(false)
            world.prepare_world(world_id,world_epoch,active_map_seed)

func _physics_process(delta: float) -> void:
    if not world: return
    tick+=delta
    if mode=="connecting":
        connect_clock-=delta
        if connect_clock<=0: _failed()
    if is_host():
        for peer in pending_peers.keys():
            if Time.get_ticks_msec()-pending_peers[peer]>10000:
                multiplayer.multiplayer_peer.disconnect_peer(peer)
                pending_peers.erase(peer)
        for peer in players:
            var p=players[peer]
            if peer!=1 and Time.get_ticks_msec()-int(p.command.get("time",0))>500: p.command={}
            if phase!="loading" and p.inventory.tick_reload(delta): _send_inventory(peer)
        _tick_harvests(delta)
        _tick_cleans(delta)
        _tick_revives(delta)
        if phase=="loading":
            loading_clock-=delta
            if loading_clock<=0:
                if WorldCatalog.is_hunt(world_id):
                    tell(1,"LOADING_FAILED")
                    _begin_loading("lobby")
                else:
                    for peer in loading_members.duplicate():
                        if peer!=1 and not ready_players.has(peer): multiplayer.multiplayer_peer.disconnect_peer(peer)
                    loading_clock=15
            _check_loaded()
        if phase=="hunt":
            spawn_clock-=delta
            if spawn_clock<=0:
                spawn_clock=8
                _spawn_near_player()
            _tick_bosses(delta)
        if mode=="host" and tick>=.05:
            snapshot_sequence+=1
            var state:=_snapshot()
            _broadcast(&"_state",[var_to_bytes({"players":state.players,"jeep":state.jeep,"phase":phase,"sequence":snapshot_sequence,"world":world_id,"epoch":world_epoch}).compress(FileAccess.COMPRESSION_DEFLATE)])
            for offset in range(0,state.animals.size(),6):
                var batch: Array=state.animals.slice(offset,offset+6)
                _broadcast(&"_wildlife_state",[var_to_bytes(batch).compress(FileAccess.COMPRESSION_DEFLATE),animals.keys(),snapshot_sequence,world_epoch])
            if state.animals.is_empty():
                # Removing the last harvested corpse still needs a roster update.
                _broadcast(&"_wildlife_state",[var_to_bytes([]).compress(FileAccess.COMPRESSION_DEFLATE),[],snapshot_sequence,world_epoch])
            for peer in harvest_jobs.keys()+harvest_views.keys():
                _send_harvest_state(peer,false)
            for peer in clean_jobs.keys()+clean_views.keys():
                _send_clean_state(peer,false)
    if tick>=.05:
        var p=local_hunter()
        if p: send_input(p.sample_input())
        tick=0

func send_input(data: Dictionary) -> void:
    if is_host(): _accept_input(1,data)
    elif mode=="client": _input_command.rpc_id(1,data)

@rpc("any_peer","call_remote","unreliable_ordered",2)
func _input_command(data: Dictionary) -> void:
    if is_host(): _accept_input(multiplayer.get_remote_sender_id(),data)

func _accept_input(peer: int, data: Dictionary) -> void:
    if not players.has(peer): return
    if phase=="loading" or not players[peer].world_ready or players[peer].health<=0: return
    if not data.get("direction",Vector3.ZERO) is Vector3 or not data.get("drive",Vector2.ZERO) is Vector2: return
    var direction: Vector3=data.direction
    var drive: Vector2=data.drive
    if not direction.is_finite() or not drive.is_finite(): return
    var yaw: float=float(data.get("yaw",0))
    var pitch: float=float(data.get("pitch",0))
    if not is_finite(yaw) or not is_finite(pitch): return
    var seq: int=int(data.get("seq",0))
    if seq<=int(last_inputs.get(peer,-1)): return
    last_inputs[peer]=seq
    var validated={"direction":direction.limit_length(),"drive":drive.limit_length(),"yaw":wrapf(yaw,-PI,PI),"pitch":clampf(pitch,-1.5,1.5),"sprint":bool(data.get("sprint",false)),"rotor":bool(data.get("rotor",false)),"aim":bool(data.get("aim",false)),"jump":bool(data.get("jump",false)),"brake":bool(data.get("brake",false)),"time":Time.get_ticks_msec(),"first":bool(data.get("first",false))}
    var target: int=data.get("revive",0) if data.get("revive",0) is int else 0
    validated["revive"]=target
    validated["harvest"]=bool(data.get("harvest",false))
    var blade=data.get("blade",null)
    if blade is Vector2 and blade.is_finite():
        validated["blade"]=Vector2(clampf(blade.x,-.5,1.5),clampf(blade.y,-.5,1.5))
        validated["bt"]=int(data.get("bt",0)) if data.get("bt",0) is int else 0
    if target>0:
        validated.direction=Vector3.ZERO;validated.drive=Vector2.ZERO;validated.jump=false;validated.aim=false
    if is_busy(peer):
        validated.direction=Vector3.ZERO;validated.drive=Vector2.ZERO;validated.jump=false;validated.aim=false;validated.revive=0
    players[peer].command=validated
    if validated.has("blade") and harvest_jobs.has(peer): _harvest_blade(peer,validated.blade,int(validated.bt))
    elif validated.has("blade") and clean_jobs.has(peer): _clean_blade(peer,validated.blade,int(validated.bt))
    if jeep.occupants[0]==peer: jeep.command=validated

func _snapshot() -> Dictionary:
    var roster: Array=[]
    for p in players.values(): roster.append(p.snapshot())
    var wildlife: Array=[]
    for a in animals.values(): wildlife.append(a.snapshot())
    return {"players":roster,"animals":wildlife,"jeep":jeep.snapshot(),"phase":phase,"sequence":snapshot_sequence,"world":world_id,"epoch":world_epoch,"seed":active_map_seed}

@rpc("authority","call_remote","unreliable_ordered",1)
func _state(packet: PackedByteArray) -> void:
    if mode=="client" and is_instance_valid(world):
        _apply_snapshot(bytes_to_var(packet.decompress_dynamic(16384,FileAccess.COMPRESSION_DEFLATE)))

@rpc("authority","call_remote","unreliable",3)
func _wildlife_state(packet: PackedByteArray, alive: Array, sequence: int, epoch: int) -> void:
    if mode!="client" or not is_instance_valid(world) or epoch!=world_epoch or local_loaded_epoch!=epoch or not WorldCatalog.is_hunt(world_id): return
    var records: Array=bytes_to_var(packet.decompress_dynamic(16384,FileAccess.COMPRESSION_DEFLATE))
    for entry in records:
        if sequence<=int(animal_sequences.get(entry.id,-1)): continue
        animal_sequences[entry.id]=sequence
        if not animals.has(entry.id): _make_animal(entry.id,entry.kind,entry.p)
        animals[entry.id].apply_snapshot(entry)
    for id in animals.keys():
        if not alive.has(id) and int(animal_sequences.get(id,0))<=sequence:
            animals[id].queue_free()
            animals.erase(id)

func _apply_snapshot(data: Dictionary) -> void:
    if int(data.get("epoch",world_epoch))!=world_epoch: return
    # Welcome and ordinary snapshots travel on different channels. Ignore a
    # roster generated before the welcome, which could remove the local hunter.
    var incoming_sequence: int=int(data.get("sequence",0))
    if incoming_sequence<roster_sequence: return
    if mode=="client":
        var contains_local:=false
        for entry in data.players:
            if entry.id==local_id(): contains_local=true
        if not contains_local: return
    roster_sequence=incoming_sequence
    if data.has("phase"): _set_phase(data.phase)
    var live: Array=[]
    for entry in data.players:
        live.append(entry.id)
        var p=_spawn_player(entry.id,entry.name)
        p.apply_snapshot(entry)
    for peer in players.keys():
        if not live.has(peer):
            if OS.get_environment("HUNT_NET_TRACE")=="1": print("TRACE roster removal ",peer," live ",live)
            players[peer].queue_free();players.erase(peer)
    var active: Array=[]
    for entry in data.get("animals",[]) if local_loaded_epoch==world_epoch else []:
        active.append(entry.id)
        if not animals.has(entry.id): _make_animal(entry.id,entry.kind,entry.p)
        animals[entry.id].apply_snapshot(entry)
    if data.has("animals"):
        for id in animals.keys():
            if not active.has(id): animals[id].queue_free();animals.erase(id)
    jeep.apply_snapshot(data.jeep)
    if mode=="client": status_key="NET_CLIENT";status_args={"n":players.size()}

func request_action(kind: String, value: String="") -> void:
    if is_host(): _action(1,kind,value)
    elif mode=="client": _action_command.rpc_id(1,kind,value)

@rpc("any_peer","call_remote","reliable",0)
func _action_command(kind: String, value: String) -> void:
    if is_host(): _action(multiplayer.get_remote_sender_id(),kind,value)

func _at_stall(p, kind: String) -> bool:
    for stall in get_tree().get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind==kind and stall.distance_from(p.global_position)<=stall.interaction_range+.4: return true
    return false

func _action(peer: int, kind: String, value: String) -> void:
    if not is_host() or not players.has(peer): return
    if kind.length()>40 or value.length()>160: return
    if kind in ["start_hunt","return_lobby","cancel_loading"]:
        if peer!=1 or not is_host(): return
        if kind=="start_hunt" and phase=="lobby":
            if not WorldCatalog.is_hunt(value): tell(peer,"MAP_UNAVAILABLE");return
            # The ocean can only be crossed by a truck that has been turned into a boat.
            if value=="ocean" and TruckUpgrades.level(truck_state,&"boat")<1: tell(peer,"OCEAN_NEEDS_BOAT");return
            var hunter=players[peer]
            if not hunter.world_ready or hunter.health<=0: return
            # The map is chosen from the truck's wheel (or, as before, beside the campfire).
            var at_wheel: bool=jeep.occupants[0]==peer
            if not at_wheel and (hunter.seat_index>=0 or not _at_stall(hunter,"expedition")): tell(peer,"MAP_AT_FIRE");return
            if not pending_peers.is_empty(): tell(peer,"WAIT_CONNECTIONS");return
            if mode=="host" and players.size()<required_players: tell(peer,"FULL_PARTY");return
            _begin_loading(value)
        elif kind=="return_lobby" and phase=="hunt": _begin_loading("lobby")
        elif kind=="cancel_loading" and phase=="loading" and WorldCatalog.is_hunt(world_id): _begin_loading("lobby")
        return
    if kind=="harvest_cancel":
        _cancel_harvest(peer)
        return
    if kind=="clean_cancel":
        _cancel_clean(peer)
        return
    if phase=="loading" or not players[peer].world_ready or players[peer].health<=0: return
    var p=players[peer]
    var inv=p.inventory
    if kind=="harvest_start":
        if value.is_valid_int(): _start_harvest(peer,int(value))
        return
    if kind=="clean_start":
        _start_clean(peer)
        return
    if is_harvesting(peer):
        if kind in ["reset","enter"]: _cancel_harvest(peer)
        else: return
    if is_cleaning(peer):
        if kind in ["reset","enter"]: _cancel_clean(peer)
        else: return
    match kind:
        "recover_vehicle":
            if jeep.recover(peer): tell(peer,"JEEP_RECOVERED")
            else: tell(peer,"JEEP_RECOVERY_DENIED")
        "reset":
            if p.seat_index<0: p.respawn()
        "reload":
            if p.seat_index!=0: inv.begin_reload()
        "equip":
            if _at_stall(p,"weapons"): inv.equip_weapon(StringName(value))
        "equip_slot":
            var slot_parts:=value.split(":")
            if slot_parts.size()==2 and _at_stall(p,"weapons"): inv.assign_slot(StringName(slot_parts[0]),int(slot_parts[1]))
        "slot":
            if p.seat_index!=0: inv.switch_slot(int(value))
        "debug_unlock_all":
            inv.debug_unlock_all()
        "buy_weapon":
            if _at_stall(p,"weapons"): inv.buy_weapon(StringName(value))
        "upgrade":
            var parts:=value.split(":")
            if parts.size()==2 and _at_stall(p,"weapons"): inv.buy_upgrade(StringName(parts[0]),parts[1])
        "bag":
            if _at_stall(p,"backpacks"): inv.buy_backpack(StringName(value))
        "truck_upgrade":
            if _at_stall(p,"garage"): buy_truck_upgrade(peer,StringName(value))
        "sell":
            if _at_stall(p,"sell"): inv.sell_all()
        "sell_stash":
            if _at_stall(p,"sell"): inv.sell_stash()
        "stash_deposit":
            if _at_stall(p,"storage"): inv.stash_deposit()
        "stash_withdraw":
            if _at_stall(p,"storage"): inv.stash_withdraw(StringName(value))
        "pickup":
            var id:=int(value)
            if loot.has(id) and loot[id].distance_from(p.global_position)<=2.7:
                if inv.collect(loot[id].loot_definition):
                    _erase_loot(id)
                    if mode=="host": _broadcast(&"_loot_removed",[id,world_epoch])
        "test_loot":
            if _at_stall(p,"test_loot"): inv.collect(EquipmentCatalog.TEST_LOOT)
        "enter": jeep.enter(peer)
        "climb":
            if value in CLIMB_ROUTES and _at_stall(p,value): jeep.climb(peer,value)
        "horn":
            if p.seat_index>=0 or p.riding: jeep.blast_horn(peer)
        "exit": jeep.exit_seat(peer)
        "deposit", "withdraw":
            if _at_stall(p,"trunk"): _move_cargo(peer,kind)
        "sell_trunk":
            if _at_stall(p,"sell"):
                if not _car_at_seller(): tell(peer,"PARK_TO_SELL")
                else:
                    var earned:=0
                    for i in range(trunk.size()-1,-1,-1):
                        if trunk[i].owner==identities[peer]:
                            earned+=AnimalCatalog.loot(trunk[i].kind).sell_value
                            trunk.remove_at(i)
                    inv.coins+=earned
                    inv.changed.emit()
                    tell(peer,"SOLD",{"n":earned})
                    _publish_trunk()
    _send_inventory(peer)

## Host: the buyer pays from their own wallet; the truck is shared by everyone.
func buy_truck_upgrade(peer: int,id: StringName) -> bool:
    if not is_host() or not players.has(peer): return false
    var reason: String=TruckUpgrades.blocker(truck_state,id)
    if reason=="TRUCK_NEEDS":
        tell(peer,"TRUCK_NEEDS",{"item_key":"TRUCK_UP_"+String(TruckUpgrades.requirement(id))})
        return false
    if not reason.is_empty():
        tell(peer,reason)
        return false
    var inv: HunterInventory=players[peer].inventory
    var cost: int=TruckUpgrades.next_cost(truck_state,id)
    if inv.coins<cost:
        tell(peer,"MISSING",{"n":cost-inv.coins})
        return false
    inv.coins-=cost
    inv.changed.emit()
    truck_state[String(id)]=TruckUpgrades.level(truck_state,id)+1
    jeep.set_upgrades(truck_state)
    tell(peer,"TRUCK_BOUGHT",{"item_key":"TRUCK_UP_"+String(id),"n":TruckUpgrades.level(truck_state,id)})
    truck_changed.emit()
    return true

func _set_phase(value: String) -> void:
    if phase==value: return
    phase=value
    changed.emit()

@rpc("authority","call_remote","reliable",0)
func _phase_changed(value: String) -> void:
    _set_phase(value)

func _clear_entities() -> void:
    _clear_harvests()
    _clear_cleans()
    for collection in [animals,loot]:
        for node in collection.values():
            node.get_parent().remove_child(node)
            node.queue_free()
        collection.clear()
    animal_sequences.clear()

func _begin_loading(id: String) -> void:
    if not is_host(): return
    world_epoch+=1
    var members: Array=players.keys()
    # A fresh random layout every expedition, chosen once by the host and broadcast so every
    # peer's terrain, lake and mountains end up byte-identical without anyone picking a seed.
    var map_seed: int=maxi(1,randi()) if WorldCatalog.is_hunt(id) else 0
    if mode=="host": _broadcast(&"_prepare_world",[id,world_epoch,members,map_seed])
    _prepare_world(id,world_epoch,members,map_seed)

@rpc("authority","call_remote","reliable",0)
func _prepare_world(id: String,epoch: int,members: Array,map_seed: int=0) -> void:
    if epoch<world_epoch or not WorldRouter.PATHS.has(id): return
    world_id=id;world_epoch=epoch;local_loaded_epoch=-1;active_map_seed=map_seed
    loading_members=members.duplicate();ready_players.clear();loading_clock=45
    _clear_entities()
    revive_jobs.clear()
    for hunter in players.values(): hunter.revive_progress=0;hunter.revive_helper=0
    forest=null
    if is_host():
        travel_driver=jeep.occupants[0];travel_riders.clear()
        for peer in players:
            var rider=players[peer]
            if rider.seat_index<0 and rider.world_ready and rider.riding and jeep.carries(rider.global_position): travel_riders[peer]=rider.ride_local()
    for p in players.values():
        p.world_ready=false;p.control_enabled=false;p.velocity=Vector3.ZERO
        p.set_seat(-1)
    jeep.occupants=[0]
    jeep.set_simulation(false)
    _set_phase("loading")
    world.prepare_world(id,epoch,map_seed)

func local_world_ready(epoch: int) -> void:
    if epoch!=world_epoch: return
    local_loaded_epoch=epoch
    if is_host(): _accept_loaded(1,epoch)
    else: _loaded_world.rpc_id(1,epoch)

@rpc("any_peer","call_remote","reliable",0)
func _loaded_world(epoch: int) -> void:
    if is_host(): _accept_loaded(multiplayer.get_remote_sender_id(),epoch)

func _accept_loaded(peer: int,epoch: int) -> void:
    if epoch!=world_epoch or not players.has(peer): return
    if phase=="loading":
        if not loading_members.has(peer): return
        ready_players[peer]=true
        _publish_loading()
        _check_loaded()
    else:
        var p=players[peer]
        if not p.world_ready:
            var point: Vector3=jeep.exit_point(1)+Vector3(0,.5,0) if phase=="hunt" else world.world_router.hunter_spawn(players.keys().find(peer))
            if phase=="hunt": point.y=forest.height_at(point.x,point.z)+1
            p.spawn_position=point;p.global_position=point;p.world_ready=true
        snapshot_sequence+=1
        if peer!=1: _commit_world.rpc_id(peer,_snapshot())

func _publish_loading() -> void:
    changed.emit()
    if mode=="host": _broadcast(&"_loading_status",[world_epoch,loading_members,ready_players.keys()])

@rpc("authority","call_remote","reliable",0)
func _loading_status(epoch: int,members: Array,ready: Array) -> void:
    if epoch!=world_epoch: return
    loading_members=members.duplicate();ready_players.clear()
    for peer in ready: ready_players[peer]=true
    changed.emit()

func _check_loaded() -> void:
    if phase!="loading" or not is_host() or not pending_peers.is_empty(): return
    for peer in loading_members:
        if not ready_players.has(peer): return
    if local_loaded_epoch!=world_epoch: return
    var index:=0
    for p in players.values():
        p.spawn_position=world.world_router.hunter_spawn(index)
        p.global_position=p.spawn_position;p.velocity=Vector3.ZERO
        p.target_position=p.global_position;p.respawn_clock=0
        p.world_ready=true;p.command={};p.visual.rotation=Vector3.ZERO
        if p.health<=0: p.life_pose_downed=false;p._life_pose()
        index+=1
    jeep.reset_state(world.world_router.jeep_spawn())
    jeep.set_simulation(true)
    # Whoever rode the truck out of the last map is still aboard when it arrives:
    # the driver at the wheel, riders where they stood on the deck or porch.
    if travel_driver!=0 and players.has(travel_driver) and players[travel_driver].health>0:
        jeep.occupants[0]=travel_driver;players[travel_driver].set_seat(0)
        players[travel_driver].global_position=jeep.to_global(jeep.SEATS[0])
    for rider in travel_riders:
        if players.has(rider) and players[rider].seat_index<0:
            players[rider].place_aboard(jeep.global_transform*(Vector3(travel_riders[rider])+Vector3.UP*.05))
            players[rider].target_position=players[rider].global_position
    travel_driver=0;travel_riders.clear()
    cooldowns.clear();last_inputs.clear()
    _set_phase("hunt" if WorldCatalog.is_hunt(world_id) else "lobby")
    if WorldCatalog.is_hunt(world_id):
        _populate();spawn_clock=8
    snapshot_sequence+=1
    if mode=="host": _broadcast(&"_commit_world",[_snapshot()])
    world.commit_world()

@rpc("authority","call_remote","reliable",0)
func _commit_world(data: Dictionary) -> void:
    if int(data.epoch)!=world_epoch or local_loaded_epoch!=world_epoch: return
    _apply_snapshot(data)
    var p=local_hunter()
    if p:
        p.global_position=p.target_position;p.world_ready=true
    jeep.global_position=jeep.target_position
    jeep.global_basis=Basis(jeep.target_rotation)
    jeep.set_simulation(true)
    world.commit_world()

func report_load_failure(epoch: int) -> void:
    if is_host(): _handle_load_failure(1,epoch)
    else: _load_failure.rpc_id(1,epoch)

@rpc("any_peer","call_remote","reliable",0)
func _load_failure(epoch: int) -> void:
    if is_host(): _handle_load_failure(multiplayer.get_remote_sender_id(),epoch)

func _handle_load_failure(peer: int,epoch: int) -> void:
    if epoch!=world_epoch or not players.has(peer): return
    tell(peer,"LOADING_FAILED")
    if phase=="loading" and WorldCatalog.is_hunt(world_id): _begin_loading("lobby")
    elif peer!=1 and mode=="host": multiplayer.multiplayer_peer.disconnect_peer(peer)

## Northern edge of the camp clearing for hunters on foot.
const LOBBY_NORTH_LIMIT: float=-19.0

func constrain_to_lobby(body: Node3D, vehicle: bool=false) -> void:
    if phase!="lobby": return
    var limit_x: float=18 if vehicle else 20
    var limit_z: float=17 if vehicle else 19
    var north: float=-limit_z if vehicle else LOBBY_NORTH_LIMIT
    var before: Vector3=body.global_position
    body.global_position.x=clampf(before.x,-limit_x,limit_x)
    body.global_position.z=clampf(before.z,north,limit_z)
    if vehicle and body.global_position!=before:
        body.speed=0
        body.velocity=Vector3.ZERO

func _car_at_seller() -> bool:
    for stall in get_tree().get_nodes_in_group("lobby_interactables"):
        if stall.interaction_kind=="sell" and stall.global_position.distance_to(jeep.global_position)<8: return true
    return false

func trunk_space() -> int:
    var used:=0
    for item in trunk: used+=AnimalCatalog.loot(item.kind).space
    return used

func _move_cargo(peer: int, kind: String) -> void:
    var inv=players[peer].inventory
    var moved:=0
    if kind=="deposit":
        for i in range(inv.items.size()-1,-1,-1):
            var item: LootDefinition=inv.items[i]
            if trunk_space()+item.space>TRUNK_CAPACITY: continue
            trunk.append({"kind":String(item.id),"owner":identities[peer]})
            inv.items.remove_at(i)
            moved+=1
    else:
        for i in range(trunk.size()-1,-1,-1):
            if trunk[i].owner!=identities[peer]: continue
            var item:=AnimalCatalog.loot(trunk[i].kind)
            if inv.used_space()+item.space>inv.capacity(): continue
            inv.items.append(item)
            trunk.remove_at(i)
            moved+=1
    inv.changed.emit()
    _publish_trunk()
    tell(peer,"TRUNK_MOVED",{"n":moved})

func _trunk_for(peer: int) -> Array:
    var result: Array=[]
    for item in trunk:
        result.append({"kind":item.kind,"owner":owner_names.get(item.owner,"Hunter"),"mine":item.owner==identities.get(peer,"")})
    return result

func _publish_trunk() -> void:
    trunk_view=_trunk_for(1)
    trunk_changed.emit()
    if mode=="host":
        for peer in players:
            if peer!=1 and _peer_ready(peer): _cargo.rpc_id(peer,_trunk_for(peer))

func _peer_ready(peer: int) -> bool:
    if not multiplayer.get_peers().has(peer): return false
    var transport:=multiplayer.multiplayer_peer
    if transport is ENetMultiplayerPeer:
        var connection: ENetPacketPeer=transport.get_peer(peer)
        return connection and connection.get_state()==ENetPacketPeer.STATE_CONNECTED
    return true

@rpc("authority","call_remote","reliable",0)
func _cargo(data: Array) -> void:
    trunk_view=data
    trunk_changed.emit()

func _send_inventory(peer: int) -> void:
    if mode=="host" and peer!=1: _inventory.rpc_id(peer,players[peer].inventory.export_state())

@rpc("authority","call_remote","reliable",0)
func _inventory(data: Dictionary) -> void:
    var p=local_hunter()
    if p: p.inventory.apply_state(data)

func tell(peer: int, key: String, args: Dictionary={}) -> void:
    if peer==local_id():
        if world: world._show_feedback(_message(key,args))
    elif mode=="host": _notice.rpc_id(peer,key,args)

@rpc("authority","call_remote","reliable",0)
func _notice(key: String, args: Dictionary) -> void:
    if world: world._show_feedback(_message(key,args))

func _message(key: String, args: Dictionary) -> String:
    var values:=args.duplicate()
    if values.has("item_key"): values["item"]=tr(values.item_key)
    if values.has("loot_id"):
        var item: LootDefinition=AnimalCatalog.loot(StringName(values.loot_id))
        if item: values["item"]=item.localized_name()
    return LocaleSettings.text(key,values)

func request_shot(origin: Vector3, direction: Vector3) -> void:
    if is_host(): _shoot(1,origin,direction)
    elif mode=="client": _shot_command.rpc_id(1,origin,direction)

@rpc("any_peer","call_remote","reliable",0)
func _shot_command(origin: Vector3, direction: Vector3) -> void:
    if is_host(): _shoot(multiplayer.get_remote_sender_id(),origin,direction)

func _shoot(peer: int, origin: Vector3, direction: Vector3) -> void:
    if not players.has(peer) or not origin.is_finite() or not direction.is_finite() or direction.length_squared()<.8: return
    var p=players[peer]
    if phase=="loading" or not p.world_ready or is_busy(peer): return
    # Gunners on the truck's terrace may shoot; the driver keeps both hands on the wheel.
    if p.seat_index==0 or p.health<=0 or int(p.command.get("revive",0))>0 or origin.distance_to(p.global_position)>8: return
    var now:=Time.get_ticks_msec()
    if now<int(cooldowns.get(peer,0)): return
    var weapon:=EquipmentCatalog.weapon(p.inventory.equipped_weapon_id)
    if p.inventory.reload_remaining>0: return
    if p.inventory.ammunition()<=0:
        p.inventory.begin_reload()
        _send_inventory(peer)
        return
    if not p.inventory.consume_round(): return
    cooldowns[peer]=now+int(p.inventory.weapon_cooldown(weapon.id)*1000)
    for animal in animals.values(): animal.hear_noise(p.global_position,90 if weapon.damage>=60 else 55)
    var target:=origin+direction.normalized()*110
    var result: Dictionary=p.combat.ray(origin,target)
    if not result.is_empty(): target=result.position
    var muzzle: Vector3=p.muzzle_position()
    if not p.local_player and bool(p.command.get("first",false)):
        var view_basis:=Basis(Vector3.UP,float(p.command.get("yaw",0)))*Basis(Vector3.RIGHT,float(p.command.get("pitch",0)))
        muzzle=origin+view_basis*Vector3(0,-.07,-.75)
    var aim: Vector3=(target-muzzle).normalized()
    var endpoints: Array=[]
    var damage:=0
    for pellet in weapon.pellets:
        var spread:=Vector3(rng.randf_range(-weapon.spread,weapon.spread),rng.randf_range(-weapon.spread,weapon.spread),rng.randf_range(-weapon.spread,weapon.spread))
        var end: Vector3=muzzle+(aim+spread).normalized()*110
        var hit: Dictionary=p.combat.ray(muzzle,end)
        if not hit.is_empty():
            end=hit.position
            if hit.collider is WildlifeAnimal:
                var amount:=damage_against(weapon,maxi(1,p.inventory.weapon_damage(weapon.id)/weapon.pellets),hit.collider)
                if hit.collider.take_damage(amount,p.global_position,peer): damage+=amount
        endpoints.append(end)
    _shot_fx(peer,String(weapon.id),muzzle,endpoints,damage)
    if mode=="host": _broadcast(&"_shot_fx",[peer,String(weapon.id),muzzle,endpoints,damage])
    _send_inventory(peer)

@rpc("authority","call_remote","reliable",0)
func _shot_fx(peer: int, weapon: String, muzzle: Vector3, endpoints: Array, damage: int) -> void:
    if players.has(peer): players[peer].combat.present_shot(weapon,muzzle,endpoints,damage)

## A weapon's damage to one animal: the harpoon does double to anything that swims.
static func damage_against(weapon: WeaponDefinition,amount: int,animal) -> int:
    if weapon.marine_bonus>0.0 and animal is WildlifeAnimal and animal.definition.swimmer: return maxi(1,roundi(float(amount)*(1.0+weapon.marine_bonus)))
    return amount

func _populate() -> void:
    if world_id=="ocean":
        # A crowded sea: schools of barracuda and eels about the reefs, sharks further out,
        # nothing near the camp island, and a boss that wakes somewhere far off.
        var placed: int=0
        for attempt in 240:
            if placed>=64: break
            var angle: float=rng.randf()*TAU
            var distance: float=rng.randf_range(170,1000)
            var point:=Vector3(sin(angle)*distance,0,cos(angle)*distance)
            var made=spawn_animal(AnimalCatalog.roll(rng,world_id).id,point)
            if made and Vector2(made.global_position.x,made.global_position.z).length()<160.0: remove_animal(made.animal_id);made=null
            if made: placed+=1
        spawn_boss();spawn_boss()
        boss_clock=rng.randf_range(120,200)
        return
    if world_id=="swamp":
        for index in 4: spawn_animal(AnimalCatalog.SWAMP_ANIMALS[index].id,Vector3(62+index*12,0,-70-index*22))
        var guardian=spawn_animal(&"ancient_crocodile",Vector3(170,0,-330))
        guardian.set_meta("lair_guard",true)
    for i in (19 if world_id=="swamp" else 24):
        var angle:=rng.randf()*TAU
        var distance:=rng.randf_range(45,170)
        spawn_animal(AnimalCatalog.roll(rng,world_id).id,Vector3(sin(angle)*distance,0,cos(angle)*distance))
    # The first boss wakes somewhere far off at once; a second may follow later.
    spawn_boss()
    boss_clock=rng.randf_range(90,150)

func living_bosses() -> Array:
    var result: Array=[]
    for animal in animals.values():
        if animal.definition.boss and not animal.dead: result.append(animal)
    return result

func _tick_bosses(delta: float) -> void:
    boss_clock-=delta
    if boss_clock>0: return
    boss_clock=rng.randf_range(150,260)
    if living_bosses().size()<MAX_BOSSES: spawn_boss()

## Host: a boss appears at a random spot on the map, far from every hunter and
## from the truck, and everyone hears about it.
func spawn_boss():
    if not is_host() or phase!="hunt" or not is_instance_valid(forest) or living_bosses().size()>=MAX_BOSSES: return null
    # Choose among the map's bosses, preferring one that is not already out there.
    var options: Array[AnimalDefinition]=AnimalCatalog.bosses_for(world_id)
    var entry: AnimalDefinition=options[rng.randi()%options.size()]
    for candidate in options:
        var alive: bool=false
        for other in living_bosses():
            if other.definition.id==candidate.id: alive=true
        if not alive: entry=candidate;break
    var span: float=ForestMap.LIMIT-60
    for attempt in 40:
        var point:=Vector3(rng.randf_range(-span,span),0,rng.randf_range(-span,span))
        if Vector2(point.x,point.z).length()<260: continue
        var clear: bool=not is_instance_valid(jeep) or jeep.global_position.distance_to(point)>=260
        for hunter in players.values():
            if hunter.global_position.distance_to(point)<260: clear=false
        for other in living_bosses():
            if other.global_position.distance_to(point)<400: clear=false
        if not clear: continue
        if entry.aquatic!=(forest.water_depth(point)>.3): continue
        var boss=spawn_animal(entry.id,point)
        if boss:
            for peer in players: tell(peer,"BOSS_SPAWNED",{"item_key":entry.display_name})
        return boss
    return null

## Host: a boss went down. Its trophies scatter around the body and the next
## boss is a few minutes away.
func boss_defeated(boss) -> void:
    if not is_host() or not is_instance_valid(boss): return
    var trophies: Array=boss.definition.trophies
    for index in trophies.size():
        var angle: float=TAU*index/float(maxi(1,trophies.size()))+rng.randf_range(-.2,.2)
        var reach: float=boss.definition.width*.5+1.2+rng.randf_range(0,1.2)
        var point: Vector3=boss.global_position+Vector3(sin(angle),0,cos(angle))*reach
        point.y=forest.height_at(point.x,point.z)+.05 if is_instance_valid(forest) else boss.global_position.y
        spawn_loot(trophies[index],point)
    for peer in players: tell(peer,"BOSS_DOWN",{"item_key":boss.definition.display_name,"n":trophies.size()})
    boss_clock=maxf(boss_clock,rng.randf_range(150,240))

func _spawn_near_player() -> void:
    if players.is_empty(): return
    var p=players.values()[rng.randi_range(0,players.size()-1)]
    var angle:=rng.randf()*TAU
    var point: Vector3=p.global_position+Vector3(sin(angle),0,cos(angle))*rng.randf_range(55,145)
    point.x=clampf(point.x,-ForestMap.LIMIT+10,ForestMap.LIMIT-10)
    point.z=clampf(point.z,-ForestMap.LIMIT+10,ForestMap.LIMIT-10)
    if Vector2(point.x,point.z).length()<40: point.z-=65
    for id in animals.keys():
        var a=animals[id]
        var nearby:=false
        for hunter in players.values():
            if a.global_position.distance_to(hunter.global_position)<(900 if world_id=="ocean" else 280): nearby=true;break
        if not nearby and not a.dead and not a.get_meta("lair_guard",false) and not a.definition.boss: remove_animal(id)
    var living: int=0
    for animal in animals.values():
        if not animal.dead: living+=1
    if living<(84 if world_id=="ocean" else 40): spawn_animal(AnimalCatalog.roll(rng,world_id).id,point)

func spawn_animal(kind: StringName, point: Vector3):
    if not is_instance_valid(forest): return null
    var entry=AnimalCatalog.animal(kind)
    if not entry: return null
    if forest.has_method("animal_spawn"): point=forest.animal_spawn(entry,point)
    else: point.y=forest.height_at(point.x,point.z)+.15
    var a=_make_animal(next_animal,String(kind),point)
    next_animal+=1
    return a

func _make_animal(id: int, kind: String, point: Vector3):
    var a:=WildlifeAnimal.new()
    a.definition=AnimalCatalog.animal(StringName(kind))
    a.animal_id=id
    a.position=point
    world.get_node("Wildlife").add_child(a)
    animals[id]=a
    return a

func remove_animal(id: int) -> void:
    if not animals.has(id): return
    for peer in harvest_jobs.keys():
        if int(harvest_jobs[peer].id)==id: _cancel_harvest(peer)
    var interaction=animals[id].get_node_or_null("HarvestInteraction")
    if interaction: interaction.remove_from_group("lobby_interactables")
    animals[id].queue_free()
    animals.erase(id)

func spawn_loot(kind: StringName, point: Vector3) -> void:
    if not is_host() or phase=="loading": return
    if world_id=="swamp": point.y=maxf(point.y,maxf(.18,forest.height_at(point.x,point.z)+.18))
    _make_loot(next_loot,String(kind),point)
    if mode=="host": _broadcast(&"_loot_added",[next_loot,String(kind),point,world_epoch])
    next_loot+=1

func _make_loot(id: int, kind: String, point: Vector3) -> void:
    if loot.has(id): return
    var pickup=load("res://world/pickups/deer_loot.tscn").instantiate()
    pickup.loot_definition=AnimalCatalog.loot(StringName(kind))
    pickup.network_id=id
    pickup.position=point
    world.get_node("Loot").add_child(pickup)
    loot[id]=pickup

func _loot_state() -> Array:
    var result: Array=[]
    for id in loot: result.append({"id":id,"kind":String(loot[id].loot_definition.id),"p":loot[id].global_position})
    return result

@rpc("authority","call_remote","reliable",0)
func _loot_added(id: int, kind: String, point: Vector3, epoch: int) -> void:
    if epoch!=world_epoch or phase=="loading": return
    _make_loot(id,kind,point)

@rpc("authority","call_remote","reliable",0)
func _loot_removed(id: int,epoch: int) -> void:
    if epoch!=world_epoch: return
    _erase_loot(id)

## The Loot Hoover: pulls a pickup into a hunter's pack from afar (host only).
func vacuum_pickup(id: int,peer: int) -> bool:
    var p=players.get(peer)
    if not is_host() or not loot.has(id) or not p: return false
    if not p.inventory.collect(loot[id].loot_definition): return false
    _erase_loot(id)
    if mode=="host": _broadcast(&"_loot_removed",[id,world_epoch])
    return true

func _erase_loot(id: int) -> void:
    if loot.has(id):
        loot[id].remove_from_group("lobby_interactables")
        loot[id].queue_free()
        loot.erase(id)

func _safe_name(value: String) -> String:
    var result:=value.strip_edges().replace("\n","").replace("\r","").replace("[","").replace("]","").left(24)
    return "Hunter" if result.is_empty() else result

func _status(key: String, args: Dictionary={}) -> void:
    status_key=key
    status_args=args
    changed.emit()

func _broadcast(method: StringName, args: Array) -> void:
    for peer in players:
        if peer!=1 and _peer_ready(peer): callv("rpc_id",[peer,method]+args)

func status_text() -> String:
    return LocaleSettings.text(status_key,status_args)

## Harvest jobs are authoritative and private. Corpse progress stays on the animal,
## so cancelling, switching players or reconnecting never repairs a damaged hide.
func is_harvesting(peer: int) -> bool:
    return harvest_jobs.has(peer) if is_host() else peer==local_id() and bool(local_harvest_state.get("active",false))

func harvest_state(peer: int) -> Dictionary:
    if not is_host(): return local_harvest_state.duplicate(true) if peer==local_id() else {}
    if not harvest_jobs.has(peer): return harvest_views.get(peer,{}).duplicate(true)
    var job: Dictionary=harvest_jobs[peer]
    var animal=animals.get(int(job.id))
    if not is_instance_valid(animal): return {}
    var item: LootDefinition=AnimalCatalog.raw_hide(animal.definition.loot_id,animal.harvest_wear)
    # Streamed unreliably at 20 Hz, so it must stay under one MTU: only the live
    # counters and the tuning the current wave actually needs travel with it.
    var quirks: PackedStringArray=job.quirks
    var state: Dictionary={"id":int(job.id),"token":int(job.token),"round":int(job.round),"completed":animal.harvest_completed,"required":int(job.required),
        "stars":item.stars,"sell_value":item.sell_value,"clean_value":AnimalCatalog.cleaned_hide(item,1.0).sell_value,
        "animal_kind":String(animal.definition.id),"feedback":String(job.feedback),"fx":int(job.fx),"fx_pos":Vector2(job.fx_pos),"combo":int(job.combo),
        "active":true,"wear":animal.harvest_wear,"step":int(job.step),"move_time":float(job.move_time),"quirks":quirks,"blade":Vector2(job.blade),"hp":Array(job.hp).duplicate()}
    var keys: Array=["difficulty","pressure","seams","seam_length","perfect_band","min_speed","directional","seam_hp"]
    if quirks.has("twitch"): keys.append("twitch_period")
    if quirks.has("chomp"): keys.append("jaw_period")
    if quirks.has("ticks") or quirks.has("bees"):
        keys.append("hazards");state["dead"]=int(job.dead)
    for key in keys: state[key]=job.tuning[key]
    return state

## Lays out the next slash wave on the corpse. Geometry is regenerated from the
## body id and step on every peer, so only seam health travels over the network.
func _prepare_harvest_move(job: Dictionary, animal) -> void:
    var tuning: Dictionary=animal.definition.harvest_tuning(animal.harvest_completed,int(job.required))
    var id: int=int(job.id)
    job.tuning=tuning
    job.step=animal.harvest_completed
    job.move_time=0.0;job.dead=0;job.hp=[]
    var jaw: int=HarvestPattern.jaw_side(id) if job.quirks.has("chomp") else 0
    job.seams=HarvestPattern.seams(id,int(job.step),int(tuning.seams),float(tuning.seam_length),jaw)
    for seam in job.seams: job.hp.append(int(tuning.seam_hp))

func _harvest_point(animal) -> Vector3:
    var interaction=animal.get_node_or_null("HarvestInteraction")
    return interaction.interaction_position() if interaction else animal.global_position+Vector3.UP*minf(.45,animal.definition.height*.35)

func _can_harvest(peer: int, animal) -> bool:
    if not is_host() or phase!="hunt" or not players.has(peer) or not is_instance_valid(animal): return false
    var hunter=players[peer]
    if not animal.dead or animal.harvested or (animal.harvest_owner!=0 and animal.harvest_owner!=peer): return false
    if not hunter.world_ready or hunter.health<=0 or hunter.seat_index>=0: return false
    var point: Vector3=_harvest_point(animal)
    if hunter.global_position.distance_to(point)>AnimalHarvestInteractable.reach(animal.definition): return false
    var ray:=PhysicsRayQueryParameters3D.create(hunter.global_position+Vector3.UP*.9,point+Vector3.UP*.1,1|16,[hunter.get_rid(),animal.get_rid()])
    return hunter.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _start_harvest(peer: int, id: int) -> void:
    if harvest_jobs.has(peer): return
    var animal=animals.get(id)
    if not _can_harvest(peer,animal):
        tell(peer,"HARVEST_UNAVAILABLE")
        return
    var strokes: int=clampi(animal.definition.harvest_strokes,2,16)
    var required: int=HarvestPattern.total_steps(strokes)
    var item: LootDefinition=AnimalCatalog.raw_hide(animal.definition.loot_id,animal.harvest_wear)
    var hunter=players[peer]
    if not hunter.inventory.can_collect(item): tell(peer,"FULL_BAG");return
    harvest_token+=1
    harvest_jobs[peer]={"id":id,"token":harvest_token,"round":0,"required":required,"strokes":strokes,"epoch":world_epoch,"damage":hunter.damage_version,
        "feedback":"","feedback_time":0.0,"focus_grace":.75,"fx":0,"fx_pos":Vector2(.5,.5),"combo":0,"best_combo":0,"combo_clock":9.0,
        "blade":Vector2(.5,.5),"bt":0,"speed":0.0,"chomp_cycle":-1,"quirks":PackedStringArray(animal.definition.harvest_quirks)}
    _prepare_harvest_move(harvest_jobs[peer],animal)
    harvest_views.erase(peer)
    animal.harvest_owner=peer
    hunter.harvest_target=id
    hunter.command["harvest"]=true
    hunter.command["direction"]=Vector3.ZERO;hunter.command["drive"]=Vector2.ZERO
    hunter.command["jump"]=false;hunter.command["revive"]=0;hunter.revive_target=0
    hunter.velocity.x=0;hunter.velocity.z=0
    _send_harvest_state(peer,true)
    if animal.harvest_completed>=int(harvest_jobs[peer].required): _complete_harvest(peer)

## Clients stream only the raw blade position and their own sample clock; the
## host owns every seam and bug and decides each cut itself.
func _harvest_blade(peer: int, point: Vector2, stamp: int=0) -> void:
    if not harvest_jobs.has(peer): return
    var job: Dictionary=harvest_jobs[peer]
    if int(job.epoch)!=world_epoch: return
    var animal=animals.get(int(job.id))
    if not _can_harvest(peer,animal) or players[peer].damage_version!=int(job.damage): _cancel_harvest(peer);return
    var motion: Array=_blade_motion(job,point,stamp)
    if motion.is_empty(): return
    var bitten: bool=_harvest_hazards(job,animal,motion[0],motion[1])
    if not _harvest_slash(peer,job,animal,motion[0],motion[1]) and bitten: _send_harvest_state(peer,true)

## Shared by skinning and cleaning: moves the job's blade and returns the metric
## motion [from, to], or [] for a stale sample. Speed uses the sender's own
## sample clock, so network jitter cannot turn a clean flick into a snag.
func _blade_motion(job: Dictionary, point: Vector2, stamp: int) -> Array:
    var delta: float=.05
    if stamp>0:
        if stamp<=int(job.bt): return []
        if int(job.bt)>0: delta=clampf(float(stamp-int(job.bt))/1000.0,.01,.35)
        job.bt=stamp
    var a: Vector2=HarvestPattern.metric(job.blade)
    var b: Vector2=HarvestPattern.metric(point)
    job.blade=point
    job.speed=a.distance_to(b)/delta
    return [a,b]

## Ticks and bees are only hurt by a moving knife; a hovering blade passes over.
func _harvest_hazards(job: Dictionary, animal, a: Vector2, b: Vector2) -> bool:
    if float(job.speed)<HarvestPattern.HOVER_SPEED: return false
    var ticks: bool=job.quirks.has("ticks")
    if not ticks and not job.quirks.has("bees"): return false
    var count: int=int(job.tuning.hazards)
    var bugs: PackedVector2Array=HarvestPattern.ticks(int(job.id),int(job.step),float(job.move_time),count) if ticks else HarvestPattern.bees(int(job.id),int(job.step),float(job.move_time),count)
    var hit: bool=false
    for i in bugs.size():
        if int(job.dead)&(1<<i): continue
        if HarvestPattern.segment_distance(a,b,HarvestPattern.metric(bugs[i]))>HarvestPattern.HAZARD_RADIUS: continue
        job.dead=int(job.dead)|(1<<i)
        _harvest_penalty(animal,job,35 if ticks else 45,"splat" if ticks else "sting",bugs[i])
        hit=true
    return hit

## A flick through a seam cuts it. Too slow snags, the wrong way tears, and a
## kicking corpse throws the blade. Returns whether anything was decided.
func _harvest_slash(peer: int, job: Dictionary, animal, a: Vector2, b: Vector2) -> bool:
    var speed: float=float(job.speed)
    if speed<HarvestPattern.HOVER_SPEED: return false
    var tuning: Dictionary=job.tuning
    var id: int=int(job.id)
    var time: float=float(job.move_time)
    var kicking: bool=job.quirks.has("twitch") and HarvestPattern.spasm(id,time,float(tuning.twitch_period))==2
    var changed: bool=false
    for i in job.seams.size():
        if int(job.hp[i])<=0: continue
        var seam: Dictionary=job.seams[i]
        var offset: Vector2=HarvestPattern.drift(job.quirks,id,time,seam.c)
        var hit: Array=HarvestPattern.crossing(a,b,HarvestPattern.seam_ends(seam,float(tuning.seam_length),offset))
        if hit.is_empty(): continue
        var at: Vector2=Vector2(seam.c)+offset
        changed=true
        if kicking:
            # Cutting into a kicking corpse: the blade skids right across the hide.
            _harvest_penalty(animal,job,40,"spasm",at)
            break
        if speed<float(tuning.min_speed):
            _harvest_penalty(animal,job,10,"snag",at)
            continue
        if bool(tuning.directional) and (b-a).dot(HarvestPattern.seam_normal(seam))<0.0:
            _harvest_penalty(animal,job,20,"wrong_way",at)
            continue
        job.hp[i]=int(job.hp[i])-1
        _harvest_combo(job)
        if int(job.hp[i])>0:
            _harvest_fx(job,"crack",at)
            continue
        var edge: float=absf(float(hit[0]))
        var band: float=float(tuning.perfect_band)
        if edge<=band: _harvest_fx(job,"perfect",at)
        else:
            _harvest_tear(animal,job,int(round(lerpf(4.0,20.0,(edge-band)/maxf(.01,1.0-band)))))
            _harvest_fx(job,"cut",at)
    if not changed: return false
    for value in job.hp:
        if int(value)>0:
            _send_harvest_state(peer,true)
            return true
    _finish_harvest_step(peer,job,animal)
    return true

func _harvest_combo(job: Dictionary) -> void:
    job.combo=int(job.combo)+1 if float(job.combo_clock)<=HarvestPattern.COMBO_WINDOW else 1
    job.combo_clock=0.0
    job.best_combo=maxi(int(job.best_combo),int(job.combo))

## Every visible event gets a fresh counter so the panel pops it exactly once.
func _harvest_fx(job: Dictionary, feedback: String, at: Vector2) -> void:
    job.feedback=feedback;job.feedback_time=.8
    job.fx=int(job.fx)+1;job.fx_pos=at

func _harvest_penalty(animal, job: Dictionary, amount: int, feedback: String, at: Vector2) -> void:
    _harvest_tear(animal,job,amount)
    animal.harvest_mistakes+=1
    job.combo=0
    _harvest_fx(job,feedback,at)

func _harvest_tear(animal, job: Dictionary, amount: int) -> void:
    if amount<=0: return
    animal.harvest_wear=clampi(animal.harvest_wear+amount,0,1000)

## One slash wave finished. Progress lives on the corpse so
## handing the body over never rewinds or repairs the work.
func _finish_harvest_step(peer: int, job: Dictionary, animal) -> void:
    animal.harvest_completed+=1
    job.round=int(job.round)+1
    if animal.harvest_completed>=int(job.required):
        _complete_harvest(peer)
        return
    _prepare_harvest_move(job,animal)
    _send_harvest_state(peer,true)

func _complete_harvest(peer: int) -> void:
    if not harvest_jobs.has(peer): return
    var job: Dictionary=harvest_jobs[peer]
    var animal=animals.get(int(job.id))
    if not _can_harvest(peer,animal) or players[peer].damage_version!=int(job.damage): _cancel_harvest(peer);return
    if animal.harvest_completed<int(job.required): return
    var item: LootDefinition=AnimalCatalog.raw_hide(animal.definition.loot_id,animal.harvest_wear)
    if not players[peer].inventory.can_collect(item):
        tell(peer,"FULL_BAG");_cancel_harvest(peer,"full_bag");return
    var finished: Dictionary=harvest_state(peer)
    # Commit corpse consumption before the inventory signal, so repeated requests
    # can never award the same hide twice. Existing cargo uses the same quality ID.
    animal.harvested=true;animal.harvest_owner=0
    harvest_jobs.erase(peer)
    players[peer].harvest_target=0;players[peer].command["harvest"]=false
    players[peer].inventory.collect(item)
    _send_inventory(peer)
    finished["active"]=false;finished["feedback"]="complete";finished["feedback_time"]=1.2
    finished["remaining"]=1.2;finished["fx"]=int(finished.get("fx",0))+1;finished["fx_pos"]=Vector2(.5,.5)
    harvest_views[peer]=finished
    _send_harvest_state(peer,true)
    remove_animal(animal.animal_id)

func _cancel_harvest(peer: int, feedback: String="cancelled", publish: bool=true) -> void:
    if not harvest_jobs.has(peer):
        if players.has(peer): players[peer].harvest_target=0
        return
    var finished: Dictionary=harvest_state(peer)
    var animal=animals.get(int(harvest_jobs[peer].id))
    if is_instance_valid(animal) and animal.harvest_owner==peer: animal.harvest_owner=0
    harvest_jobs.erase(peer)
    if players.has(peer):
        players[peer].harvest_target=0;players[peer].command["harvest"]=false
    if publish:
        finished["active"]=false;finished["feedback"]=feedback;finished["feedback_time"]=1.2;finished["remaining"]=1.2
        harvest_views[peer]=finished
        _send_harvest_state(peer,true)

func _clear_harvests() -> void:
    for peer in harvest_jobs.keys(): _cancel_harvest(peer,"cancelled",false)
    harvest_jobs.clear();harvest_views.clear();local_harvest_state.clear()
    harvest_received_sequence=-1
    local_blade=Vector2(.5,.5)
    for hunter in players.values(): hunter.harvest_target=0

func _tick_harvests(delta: float) -> void:
    if not is_host(): return
    for peer in harvest_views.keys():
        harvest_views[peer].remaining=float(harvest_views[peer].remaining)-delta
        if float(harvest_views[peer].remaining)<=0:
            harvest_views.erase(peer);_send_harvest_state(peer,true)
    for peer in harvest_jobs.keys():
        var job: Dictionary=harvest_jobs[peer]
        var hunter=players.get(peer)
        var animal=animals.get(int(job.id))
        if int(job.epoch)!=world_epoch or not _can_harvest(peer,animal) or hunter.damage_version!=int(job.damage):
            _cancel_harvest(peer);continue
        job.focus_grace=maxf(0.0,float(job.focus_grace)-delta)
        if not _harvest_focus_valid(peer,job) and float(job.focus_grace)<=0.0:
            _cancel_harvest(peer);continue
        job.move_time=float(job.move_time)+delta
        job.combo_clock=float(job.combo_clock)+delta
        job.feedback_time=maxf(0.0,float(job.feedback_time)-delta)
        if float(job.feedback_time)<=0.0: job.feedback=""
        _tick_harvest_move(peer,job,animal)

## The crocodile's reflex bite judges the blade where the host last saw it, so
## resting in the jaw zone is exactly as dangerous as swiping through it.
func _tick_harvest_move(peer: int, job: Dictionary, animal) -> void:
    if not job.quirks.has("chomp"): return
    var id: int=int(job.id)
    var period: float=float(job.tuning.jaw_period)
    var time: float=float(job.move_time)
    if HarvestPattern.jaw_state(id,time,period)==2 and HarvestPattern.in_jaw(job.blade,HarvestPattern.jaw_side(id)):
        var cycle: int=HarvestPattern.jaw_cycle(id,time,period)
        if cycle!=int(job.chomp_cycle):
            job.chomp_cycle=cycle
            _harvest_penalty(animal,job,70,"chomp",job.blade)
            _send_harvest_state(peer,true)

func _harvest_focus_valid(peer: int, job: Dictionary) -> bool:
    var hunter=players.get(peer)
    if not is_instance_valid(hunter): return false
    if hunter.local_player: return hunter.control_enabled and hunter.harvest_target==int(job.id)
    return bool(hunter.command.get("harvest",false)) and Time.get_ticks_msec()-int(hunter.command.get("time",0))<=500

func _send_harvest_state(peer: int, reliable: bool) -> void:
    if mode!="host" or peer==local_id() or not _peer_ready(peer): return
    harvest_sequence+=1
    var data: Dictionary=harvest_state(peer)
    if reliable: _harvest_changed.rpc_id(peer,data,world_epoch,harvest_sequence)
    else: _harvest_progress.rpc_id(peer,data,world_epoch,harvest_sequence)

@rpc("authority","call_remote","reliable",0)
func _harvest_changed(data: Dictionary, epoch: int, sequence: int) -> void:
    _apply_harvest_state(data,epoch,sequence)

@rpc("authority","call_remote","unreliable_ordered",1)
func _harvest_progress(data: Dictionary, epoch: int, sequence: int) -> void:
    _apply_harvest_state(data,epoch,sequence)

func _apply_harvest_state(data: Dictionary, epoch: int, sequence: int) -> void:
    if mode!="client" or epoch!=world_epoch or local_loaded_epoch!=epoch or phase!="hunt" or sequence<=harvest_received_sequence: return
    harvest_received_sequence=sequence
    local_harvest_state=data.duplicate(true)
    if not local_harvest_state.is_empty(): local_harvest_state["received_at"]=Time.get_ticks_msec()/1000.0
    var hunter=local_hunter()
    if hunter: hunter.harvest_target=int(data.get("id",0)) if bool(data.get("active",false)) else 0

## --- Camp hide cleaner -------------------------------------------------------
## A cleaning job borrows one raw hide from the hunter's bag for one drum
## session. Cancelling gives the very same hide back; finishing swaps it for the
## cleaned hide, graded by CleaningPattern from what was sliced and what landed.
func is_cleaning(peer: int) -> bool:
    return clean_jobs.has(peer) if is_host() else peer==local_id() and bool(local_clean_state.get("active",false))

## Drops any knife work a hunter is doing (boarding or riding the truck).
func release_jobs(peer: int) -> void:
    if is_harvesting(peer): _cancel_harvest(peer)
    if is_cleaning(peer): _cancel_clean(peer)

func is_busy(peer: int) -> bool:
    return is_harvesting(peer) or is_cleaning(peer)

func clean_state(peer: int) -> Dictionary:
    if not is_host(): return local_clean_state.duplicate(true) if peer==local_id() else {}
    if not clean_jobs.has(peer): return clean_views.get(peer,{}).duplicate(true)
    var job: Dictionary=clean_jobs[peer]
    var item: LootDefinition=job.item
    var clean: float=CleaningPattern.cleanliness(int(job.dirt),int(job.junk))
    return {"token":int(job.token),"item":String(item.id),"kind":String(job.kind),"seed":int(job.seed),"difficulty":float(job.difficulty),"fatty":bool(job.fatty),
        "time":float(job.time),"duration":float(job.duration),"done":int(job.done),"cracked":int(job.cracked),"dirt":int(job.dirt),"junk":int(job.junk),"cleaned":int(job.cleaned),
        "clean":clean,"raw_stars":item.stars,"stars":CleaningPattern.final_stars(item.stars,clean),"raw_value":item.sell_value,"value":AnimalCatalog.cleaned_hide(item,clean).sell_value,
        "feedback":String(job.feedback),"fx":int(job.fx),"fx_pos":Vector2(job.fx_pos),"combo":int(job.combo),"active":true,"blade":Vector2(job.blade)}

## The most valuable raw hide in the bag goes into the drum first.
func _raw_hide_index(inventory) -> int:
    var best: int=-1
    for index in inventory.items.size():
        var item: LootDefinition=inventory.items[index]
        if item.raw and (best<0 or item.stars>inventory.items[best].stars): best=index
    return best

func _can_clean(peer: int) -> bool:
    # The workshop rides in the truck's cottage, so it works in camp and out hunting.
    if not is_host() or phase=="loading" or not players.has(peer): return false
    var hunter=players[peer]
    return hunter.world_ready and hunter.health>0 and hunter.seat_index<0 and _at_stall(hunter,"cleaner")

func _start_clean(peer: int) -> void:
    if clean_jobs.has(peer) or harvest_jobs.has(peer) or not players.has(peer): return
    var hunter=players[peer]
    if not _can_clean(peer): tell(peer,"CLEAN_UNAVAILABLE");return
    var index: int=_raw_hide_index(hunter.inventory)
    if index<0: tell(peer,"CLEAN_NOTHING");return
    var item: LootDefinition=hunter.inventory.items[index]
    hunter.inventory.items.remove_at(index)
    hunter.inventory.changed.emit();_send_inventory(peer)
    var animal: AnimalDefinition=AnimalCatalog.animal_for_loot(item.base_id)
    var difficulty: float=animal.harvest_difficulty() if animal else 0.0
    var fatty: bool=animal!=null and animal.harvest_quirks.has("fat")
    clean_token+=1
    var seed: int=clean_token*7919+peer*31+item.stars
    var pieces: Array=CleaningPattern.pieces(seed,difficulty,fatty)
    clean_jobs[peer]={"token":clean_token,"item":item,"kind":String(animal.id) if animal else "rabbit","seed":seed,"difficulty":difficulty,"fatty":fatty,"pieces":pieces,
        "time":0.0,"duration":CleaningPattern.duration(pieces),"done":0,"cracked":0,"dirt":0,"junk":CleaningPattern.junk_count(pieces),"cleaned":0,
        "feedback":"","feedback_time":0.0,"fx":0,"fx_pos":Vector2(.5,.5),"combo":0,"best_combo":0,"combo_clock":9.0,
        "blade":Vector2(.5,.5),"bt":0,"speed":0.0,"focus_grace":.75,"epoch":world_epoch}
    clean_views.erase(peer)
    hunter.cleaning=true
    hunter.command["harvest"]=true;hunter.command["direction"]=Vector3.ZERO;hunter.command["drive"]=Vector2.ZERO
    hunter.command["jump"]=false;hunter.command["revive"]=0;hunter.revive_target=0
    hunter.velocity.x=0;hunter.velocity.z=0
    _send_clean_state(peer,true)

## A flick through anything in the air: junk is cleaned off, stones chip the
## blade and the hide itself gets cut. The host also probes slightly older
## positions so a lagging client still hits what it saw under its knife.
func _clean_blade(peer: int, point: Vector2, stamp: int=0) -> void:
    if not clean_jobs.has(peer): return
    var job: Dictionary=clean_jobs[peer]
    if int(job.epoch)!=world_epoch: return
    if not _can_clean(peer): _cancel_clean(peer);return
    var motion: Array=_blade_motion(job,point,stamp)
    if motion.is_empty() or float(job.speed)<CleaningPattern.MIN_SPEED: return
    var hit: bool=false
    for index in job.pieces.size():
        if int(job.done)&(1<<index): continue
        var piece: Dictionary=job.pieces[index]
        var reach: float=float(CleaningPattern.RADIUS[int(piece.kind)])+.01
        for probe in CleaningPattern.LAG_PROBES:
            var time: float=float(job.time)-float(probe)
            if not CleaningPattern.airborne(piece,time): continue
            var at: Vector2=CleaningPattern.position(piece,time)
            if HarvestPattern.segment_distance(motion[0],motion[1],HarvestPattern.metric(at))>reach: continue
            _clean_hit(job,index,int(piece.kind),at)
            hit=true
            break
    if hit: _send_clean_state(peer,true)

func _clean_hit(job: Dictionary, index: int, kind: int, at: Vector2) -> void:
    var bit: int=1<<index
    match kind:
        CleaningPattern.STONE:
            job.done=int(job.done)|bit;job.dirt=int(job.dirt)+CleaningPattern.DIRT_STONE;job.combo=0
            _harvest_fx(job,"clang",at)
        CleaningPattern.PELT:
            job.done=int(job.done)|bit;job.dirt=int(job.dirt)+CleaningPattern.DIRT_PELT;job.combo=0
            _harvest_fx(job,"tear",at)
        _:
            _harvest_combo(job)
            if kind==CleaningPattern.JUNK_SINEW and not int(job.cracked)&bit:
                job.cracked=int(job.cracked)|bit
                _harvest_fx(job,"chop",at)
                return
            job.done=int(job.done)|bit;job.cleaned=int(job.cleaned)+1
            _harvest_fx(job,["flesh","fat","burr","sinew"][kind],at)

func _tick_cleans(delta: float) -> void:
    if not is_host(): return
    for peer in clean_views.keys():
        clean_views[peer].remaining=float(clean_views[peer].remaining)-delta
        if float(clean_views[peer].remaining)<=0:
            clean_views.erase(peer);_send_clean_state(peer,true)
    for peer in clean_jobs.keys():
        var job: Dictionary=clean_jobs[peer]
        if int(job.epoch)!=world_epoch or not _can_clean(peer):
            _cancel_clean(peer);continue
        job.focus_grace=maxf(0.0,float(job.focus_grace)-delta)
        if not _clean_focus_valid(peer) and float(job.focus_grace)<=0.0:
            _cancel_clean(peer);continue
        job.time=float(job.time)+delta
        job.combo_clock=float(job.combo_clock)+delta
        job.feedback_time=maxf(0.0,float(job.feedback_time)-delta)
        if float(job.feedback_time)<=0.0: job.feedback=""
        # Junk nobody sliced falls back onto the hide and stays there.
        var splashed: bool=false
        for index in job.pieces.size():
            var bit: int=1<<index
            if int(job.done)&bit or not CleaningPattern.landed(job.pieces[index],float(job.time)): continue
            job.done=int(job.done)|bit
            if CleaningPattern.is_junk(int(job.pieces[index].kind)):
                job.dirt=int(job.dirt)+CleaningPattern.DIRT_MISSED;job.combo=0
                _harvest_fx(job,"missed",Vector2(CleaningPattern.position(job.pieces[index],float(job.time)).x,.92))
                splashed=true
        if float(job.time)>=float(job.duration): _finish_clean(peer)
        elif splashed: _send_clean_state(peer,true)

func _clean_focus_valid(peer: int) -> bool:
    var hunter=players.get(peer)
    if not is_instance_valid(hunter): return false
    if hunter.local_player: return hunter.control_enabled and hunter.cleaning
    return bool(hunter.command.get("harvest",false)) and Time.get_ticks_msec()-int(hunter.command.get("time",0))<=500

func _finish_clean(peer: int) -> void:
    if not clean_jobs.has(peer): return
    var job: Dictionary=clean_jobs[peer]
    var finished: Dictionary=clean_state(peer)
    var result: LootDefinition=AnimalCatalog.cleaned_hide(job.item,float(finished.clean))
    _release_clean(peer,result if result else job.item)
    finished["active"]=false;finished["feedback"]="complete";finished["fx"]=int(finished.fx)+1;finished["fx_pos"]=Vector2(.5,.45)
    finished["result"]=String(result.id) if result else "";finished["remaining"]=2.5
    clean_views[peer]=finished
    _send_clean_state(peer,true)

## Leaving the drum, for any reason, always gives the bag its hide back.
func _cancel_clean(peer: int, publish: bool=true) -> void:
    if not clean_jobs.has(peer):
        if players.has(peer): players[peer].cleaning=false
        return
    var finished: Dictionary=clean_state(peer)
    _release_clean(peer,clean_jobs[peer].item)
    if publish:
        finished["active"]=false;finished["feedback"]="cancelled";finished["remaining"]=1.2
        clean_views[peer]=finished
        _send_clean_state(peer,true)

func _release_clean(peer: int, item: LootDefinition) -> void:
    clean_jobs.erase(peer)
    if not players.has(peer): return
    var hunter=players[peer]
    hunter.cleaning=false;hunter.command["harvest"]=false
    # The slot was freed when the raw hide went in, so the hide always fits back.
    hunter.inventory.items.append(item)
    hunter.inventory.changed.emit()
    _send_inventory(peer)

func _clear_cleans() -> void:
    for peer in clean_jobs.keys(): _cancel_clean(peer,false)
    clean_jobs.clear();clean_views.clear();local_clean_state.clear()
    clean_received_sequence=-1

func _send_clean_state(peer: int, reliable: bool) -> void:
    if mode!="host" or peer==local_id() or not _peer_ready(peer): return
    clean_sequence+=1
    var data: Dictionary=clean_state(peer)
    if reliable: _clean_changed.rpc_id(peer,data,world_epoch,clean_sequence)
    else: _clean_progress.rpc_id(peer,data,world_epoch,clean_sequence)

@rpc("authority","call_remote","reliable",0)
func _clean_changed(data: Dictionary, epoch: int, sequence: int) -> void:
    _apply_clean_state(data,epoch,sequence)

@rpc("authority","call_remote","unreliable_ordered",1)
func _clean_progress(data: Dictionary, epoch: int, sequence: int) -> void:
    _apply_clean_state(data,epoch,sequence)

func _apply_clean_state(data: Dictionary, epoch: int, sequence: int) -> void:
    if mode!="client" or epoch!=world_epoch or local_loaded_epoch!=epoch or sequence<=clean_received_sequence: return
    clean_received_sequence=sequence
    local_clean_state=data.duplicate(true)
    if not local_clean_state.is_empty(): local_clean_state["received_at"]=Time.get_ticks_msec()/1000.0
    var hunter=local_hunter()
    if hunter: hunter.cleaning=bool(data.get("active",false))

func animal_died() -> void:
    if not is_host(): return
    var corpses: Array=[]
    var total: int=0
    for animal in animals.values():
        if not animal.dead: continue
        total+=1
        if animal.harvest_owner==0: corpses.append(animal)
    corpses.sort_custom(func(a,b) -> bool: return a.death_clock>b.death_clock)
    while total>MAX_CORPSES and not corpses.is_empty():
        var oldest=corpses.pop_front()
        remove_animal(oldest.animal_id)
        total-=1

func _can_revive(helper, target) -> bool:
    if phase=="loading" or not is_instance_valid(helper) or not is_instance_valid(target): return false
    if helper==target or helper.health<=0 or target.health>0 or helper.seat_index>=0: return false
    if is_busy(helper.peer_id): return false
    if not helper.world_ready or not target.world_ready: return false
    var point: Vector3=target.get_node("ReviveInteraction").interaction_position()
    if helper.global_position.distance_to(point)>3: return false
    var ray:=PhysicsRayQueryParameters3D.create(helper.global_position+Vector3.UP*.9,point+Vector3.UP*.2,1|16,[helper.get_rid(),target.get_rid()])
    return helper.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _tick_revives(delta: float) -> void:
    if phase=="loading": return
    var claimed: Dictionary={}
    for peer in players:
        var helper=players[peer]
        var target_id: int=int(helper.command.get("revive",0))
        var target=players.get(target_id)
        # A local frame hitch must not look like a lost network input packet.
        var held_here: bool=helper.local_player and helper.control_enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("interact")
        if target_id==0 or (not held_here and Time.get_ticks_msec()-int(helper.command.get("time",0))>300) or not _can_revive(helper,target): continue
        if claimed.has(target_id): continue
        if revive_jobs.has(target_id) and revive_jobs[target_id].helper!=peer and players.has(revive_jobs[target_id].helper):
            var previous=players[revive_jobs[target_id].helper]
            if int(previous.command.get("revive",0))==target_id and _can_revive(previous,target): continue
        claimed[target_id]=peer
        if not revive_jobs.has(target_id) or revive_jobs[target_id].helper!=peer:
            revive_jobs[target_id]={"helper":peer,"elapsed":0.0,"damage":helper.damage_version}
        var job: Dictionary=revive_jobs[target_id]
        if job.damage!=helper.damage_version: job.elapsed=0;job.damage=helper.damage_version
        else: job.elapsed+=delta
        helper.velocity.x=0;helper.velocity.z=0
        target.revive_helper=peer;target.revive_progress=minf(1,job.elapsed/REVIVE_SECONDS)
        if job.elapsed>=REVIVE_SECONDS:
            target.revive();helper.command["revive"]=0;helper.revive_target=0
            revive_jobs.erase(target_id)
            tell(peer,"REVIVE_DONE",{"name":target.player_name})
    for target_id in revive_jobs.keys():
        if claimed.has(target_id): continue
        if players.has(target_id): players[target_id].revive_progress=0;players[target_id].revive_helper=0
        revive_jobs.erase(target_id)
