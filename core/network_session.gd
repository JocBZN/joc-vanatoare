extends Node
## Authority and transport boundary. Steam can supply a MultiplayerPeer via attach_peer.
signal changed
signal player_changed
signal trunk_changed
const MAX_PLAYERS = 4
const TRUNK_CAPACITY = 120
var world
var players: Dictionary = {}
var animals: Dictionary = {}
var loot: Dictionary = {}
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
var local_loaded_epoch: int=0
var loading_members: Array=[]
var ready_players: Dictionary={}
var loading_clock: float=0
var required_players: int=1
const REVIVE_SECONDS: float=3.0
var revive_jobs: Dictionary={}
var health_profiles: Dictionary={}

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
        jeep.occupants=[0,0,0,0]
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
            world.prepare_world(world_id,world_epoch)

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
        if mode=="host" and tick>=.05:
            snapshot_sequence+=1
            var state:=_snapshot()
            _broadcast(&"_state",[var_to_bytes({"players":state.players,"jeep":state.jeep,"phase":phase,"sequence":snapshot_sequence,"world":world_id,"epoch":world_epoch}).compress(FileAccess.COMPRESSION_DEFLATE)])
            for offset in range(0,state.animals.size(),6):
                var batch: Array=state.animals.slice(offset,offset+6)
                _broadcast(&"_wildlife_state",[var_to_bytes(batch).compress(FileAccess.COMPRESSION_DEFLATE),animals.keys(),snapshot_sequence,world_epoch])
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
    var validated={"direction":direction.limit_length(),"drive":drive.limit_length(),"yaw":wrapf(yaw,-PI,PI),"pitch":clampf(pitch,-1,.5),"sprint":bool(data.get("sprint",false)),"aim":bool(data.get("aim",false)),"jump":bool(data.get("jump",false)),"brake":bool(data.get("brake",false)),"time":Time.get_ticks_msec(),"first":bool(data.get("first",false))}
    var target: int=data.get("revive",0) if data.get("revive",0) is int else 0
    validated["revive"]=target
    if target>0:
        validated.direction=Vector3.ZERO;validated.drive=Vector2.ZERO;validated.jump=false;validated.aim=false
    players[peer].command=validated
    if jeep.occupants[0]==peer: jeep.command=validated

func _snapshot() -> Dictionary:
    var roster: Array=[]
    for p in players.values(): roster.append(p.snapshot())
    var wildlife: Array=[]
    for a in animals.values(): wildlife.append(a.snapshot())
    return {"players":roster,"animals":wildlife,"jeep":jeep.snapshot(),"phase":phase,"sequence":snapshot_sequence,"world":world_id,"epoch":world_epoch}

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
    if not players.has(peer): return
    if kind in ["start_hunt","return_lobby","cancel_loading"]:
        if peer!=1 or not is_host(): return
        if kind=="start_hunt" and phase=="lobby":
            if not WorldCatalog.is_hunt(value): tell(peer,"MAP_UNAVAILABLE");return
            var hunter=players[peer]
            if not hunter.world_ready or hunter.health<=0 or hunter.seat_index>=0: return
            if not _at_stall(hunter,"expedition"): tell(peer,"MAP_AT_FIRE");return
            if not pending_peers.is_empty(): tell(peer,"WAIT_CONNECTIONS");return
            if mode=="host" and players.size()<required_players: tell(peer,"FULL_PARTY");return
            _begin_loading(value)
        elif kind=="return_lobby" and phase=="hunt": _begin_loading("lobby")
        elif kind=="cancel_loading" and phase=="loading" and WorldCatalog.is_hunt(world_id): _begin_loading("lobby")
        return
    if phase=="loading" or not players[peer].world_ready or players[peer].health<=0: return
    var p=players[peer]
    var inv=p.inventory
    match kind:
        "recover_vehicle":
            if jeep.recover(peer): tell(peer,"JEEP_RECOVERED")
            else: tell(peer,"JEEP_RECOVERY_DENIED")
        "reset":
            if p.seat_index<0: p.respawn()
        "reload":
            if p.seat_index<0: inv.begin_reload()
        "equip":
            if _at_stall(p,"weapons"): inv.equip_weapon(StringName(value))
        "buy_weapon":
            if _at_stall(p,"weapons"): inv.buy_weapon(StringName(value))
        "upgrade":
            var parts:=value.split(":")
            if parts.size()==2 and _at_stall(p,"weapons"): inv.buy_upgrade(StringName(parts[0]),parts[1])
        "bag":
            if _at_stall(p,"backpacks"): inv.buy_backpack(StringName(value))
        "sell":
            if _at_stall(p,"sell"): inv.sell_all()
        "pickup":
            var id:=int(value)
            if loot.has(id) and loot[id].distance_from(p.global_position)<=2.7:
                if inv.collect(loot[id].loot_definition):
                    _erase_loot(id)
                    if mode=="host": _broadcast(&"_loot_removed",[id,world_epoch])
        "test_loot":
            if _at_stall(p,"test_loot"): inv.collect(EquipmentCatalog.TEST_LOOT)
        "enter": jeep.enter(peer)
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

func _set_phase(value: String) -> void:
    if phase==value: return
    phase=value
    changed.emit()

@rpc("authority","call_remote","reliable",0)
func _phase_changed(value: String) -> void:
    _set_phase(value)

func _clear_entities() -> void:
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
    if mode=="host": _broadcast(&"_prepare_world",[id,world_epoch,members])
    _prepare_world(id,world_epoch,members)

@rpc("authority","call_remote","reliable",0)
func _prepare_world(id: String,epoch: int,members: Array) -> void:
    if epoch<world_epoch or not WorldRouter.PATHS.has(id): return
    world_id=id;world_epoch=epoch;local_loaded_epoch=-1
    loading_members=members.duplicate();ready_players.clear();loading_clock=45
    _clear_entities()
    revive_jobs.clear()
    for hunter in players.values(): hunter.revive_progress=0;hunter.revive_helper=0
    forest=null
    for p in players.values():
        p.world_ready=false;p.control_enabled=false;p.velocity=Vector3.ZERO
        p.set_seat(-1)
    jeep.occupants=[0,0,0,0]
    jeep.set_simulation(false)
    _set_phase("loading")
    world.prepare_world(id,epoch)

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
            var point: Vector3=jeep.global_position+Vector3(3,1.5,2) if phase=="hunt" else world.world_router.hunter_spawn(players.keys().find(peer))
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

func constrain_to_lobby(body: Node3D, vehicle: bool=false) -> void:
    if phase!="lobby": return
    var limit_x: float=18 if vehicle else 20
    var limit_z: float=17 if vehicle else 19
    var before: Vector3=body.global_position
    body.global_position.x=clampf(before.x,-limit_x,limit_x)
    body.global_position.z=clampf(before.z,-limit_z,limit_z)
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
    if phase=="loading" or not p.world_ready: return
    if p.seat_index>=0 or p.health<=0 or int(p.command.get("revive",0))>0 or origin.distance_to(p.global_position)>8: return
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
                var amount:=maxi(1,p.inventory.weapon_damage(weapon.id)/weapon.pellets)
                if hit.collider.take_damage(amount,p.global_position,peer): damage+=amount
        endpoints.append(end)
    _shot_fx(peer,String(weapon.id),muzzle,endpoints,damage)
    if mode=="host": _broadcast(&"_shot_fx",[peer,String(weapon.id),muzzle,endpoints,damage])
    _send_inventory(peer)

@rpc("authority","call_remote","reliable",0)
func _shot_fx(peer: int, weapon: String, muzzle: Vector3, endpoints: Array, damage: int) -> void:
    if players.has(peer): players[peer].combat.present_shot(weapon,muzzle,endpoints,damage)

func _populate() -> void:
    if world_id=="swamp":
        for index in 4: spawn_animal(AnimalCatalog.SWAMP_ANIMALS[index].id,Vector3(62+index*12,0,-70-index*22))
        var guardian=spawn_animal(&"ancient_crocodile",Vector3(170,0,-330))
        guardian.set_meta("lair_guard",true)
    for i in (19 if world_id=="swamp" else 24):
        var angle:=rng.randf()*TAU
        var distance:=rng.randf_range(45,170)
        spawn_animal(AnimalCatalog.roll(rng,world_id).id,Vector3(sin(angle)*distance,0,cos(angle)*distance))

func _spawn_near_player() -> void:
    if players.is_empty(): return
    var p=players.values()[rng.randi_range(0,players.size()-1)]
    var angle:=rng.randf()*TAU
    var point: Vector3=p.global_position+Vector3(sin(angle),0,cos(angle))*rng.randf_range(55,145)
    point.x=clampf(point.x,-580,580)
    point.z=clampf(point.z,-580,580)
    if Vector2(point.x,point.z).length()<40: point.z-=65
    for id in animals.keys():
        var a=animals[id]
        var nearby:=false
        for hunter in players.values():
            if a.global_position.distance_to(hunter.global_position)<280: nearby=true;break
        if not nearby and not a.dead and not a.get_meta("lair_guard",false): remove_animal(id)
    if animals.size()<40: spawn_animal(AnimalCatalog.roll(rng,world_id).id,point)

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

func _can_revive(helper, target) -> bool:
    if phase=="loading" or not is_instance_valid(helper) or not is_instance_valid(target): return false
    if helper==target or helper.health<=0 or target.health>0 or helper.seat_index>=0: return false
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
