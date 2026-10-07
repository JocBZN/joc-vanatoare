class_name Hunter
extends CharacterBody3D
## Hunter movement, replicated life state and local camera input.

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 8.5
@export var aim_speed: float = 3.5
@export var acceleration: float = 22.0
@export var jump_speed: float = 6.0
@export var turn_speed: float = 14.0
@export var spawn_position: Vector3 = Vector3(0.0, 0.1, 6.0)

@onready var camera_rig: HunterCameraRig = $CameraRig
@onready var visual: Node3D = $Visual
@onready var inventory: HunterInventory = $Inventory

var peer_id: int = 1
var local_player: bool = true
var player_name: String = "Hunter"
var health: int = 100
var seat_index: int = -1
var respawn_clock: float = 0.0
var harvest_target: int=0
## Working the camp hide cleaner; locks the hunter in place like skinning.
var cleaning: bool=false
var harvest_input_guard: bool=false
var revive_target: int=0
var revive_progress: float=0
var revive_helper: int=0
var damage_version: int=0
var life_pose_downed: bool=false
var name_tag: Label3D
var command: Dictionary = {}
var world_ready: bool=true
var input_sequence: int = 0
var jump_pending: bool = false
var target_position := Vector3.ZERO
var target_yaw: float = 0.0
var _weapon_visual: Node3D
var _backpack_visual: Node3D
var _shown_weapon: StringName
var _shown_backpack: StringName
var control_enabled: bool = false
var combat: HunterCombat
## Aboard the truck on foot: carried with it every physics frame, so a rider
## walks, turns and shoots relative to the deck while somebody drives.
var riding: bool=false
## The truck pose this hunter's position was last consistent with.
var _ride_from:=Transform3D.IDENTITY
var _ride_frame: int=-10
## Replicated truck-local position and yaw of a rider (from host snapshots).
var ride_target:=Vector3.ZERO
var ride_yaw: float=0.0
var ride_target_valid: bool=false
var _shown_local:=Vector3.ZERO
var _shown_riding: bool=false
var _arm_ignores_truck: bool=false

## Ocean map: hunters swim in 3D, dive with the camera's pitch, and wear a diving
## suit. `swimming` is the simulated state (host, and the local hunter); replicas
## show the same pose from their replicated position.
const DivingSuit:=preload("res://art/diving_suit.gd")
const SWIM_ENTER: float=1.05
const SWIM_EXIT: float=.55
const SWIM_REST: float=-1.18
const SWIM_SPEED: float=4.3
const SWIM_FAST: float=6.6
var swimming: bool=false
var _swim_lean: float=0.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _stride_time: float = 0.0


func _ready() -> void:
    load("res://art/hunter_details.gd").apply(visual)
    camera_rig.spring_arm.add_excluded_object(get_rid())
    # The camera also stops at the truck's walls when walking through the cottage.
    camera_rig.spring_arm.collision_mask=1|16
    # Riding is handled explicitly (see _carry), so the truck must not also act
    # as a built-in moving platform that adds its velocity a second time.
    platform_floor_layers=0xFFFFFFFF & ~16
    platform_on_leave=CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
    spawn_position = global_position
    target_position = global_position
    camera_rig.enabled=local_player
    camera_rig.camera.current=local_player
    camera_rig.camera.far=900
    $CollisionShape3D.shape=$CollisionShape3D.shape.duplicate()
    var use=load("res://world/interactables/revive_interactable.gd").new();use.name="ReviveInteraction";add_child(use)
    var tag:=Label3D.new();name_tag=tag
    tag.text=player_name
    tag.position.y=2.3
    tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    tag.font_size=24
    tag.pixel_size=.009
    tag.visibility_range_end=70
    tag.visible=not local_player
    add_child(tag)
    LocaleSettings.changed.connect(_update_name_tag)
    _update_name_tag()
    inventory.changed.connect(_update_equipment)
    _update_equipment()
    combat = HunterCombat.new()
    combat.name = "Combat"
    add_child(combat)


## Hands full with a knife: skinning a corpse or working the camp cleaner.
func busy() -> bool:
    return harvest_target>0 or cleaning

func sample_input() -> Dictionary:
    input_sequence+=1
    var active:=local_player and control_enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and health>0 and not busy()
    var stick:=Input.get_vector("move_left","move_right","move_forward","move_backward") if active else Vector2.ZERO
    var result={"direction":camera_rig.movement_direction(stick),"drive":stick,"sprint":active and Input.is_action_pressed("sprint"),"rotor":active and Input.is_action_pressed("rotor"),"jump":jump_pending,"aim":camera_rig.aiming,"yaw":camera_rig.rotation.y,"pitch":camera_rig.rotation.x,"brake":active and Input.is_action_pressed("jump"),"seq":input_sequence,"first":camera_rig.is_first_person()}
    revive_target=0
    if active and Input.is_action_pressed("interact") and NetworkSession.world.nearby and NetworkSession.world.nearby.interaction_kind=="revive":
        revive_target=NetworkSession.world.nearby.target_peer()
    result["harvest"]=busy()
    if busy():
        result["blade"]=NetworkSession.local_blade
        result["bt"]=Time.get_ticks_msec()
    if harvest_input_guard: result.jump=false
    result["revive"]=revive_target
    if revive_target>0 or busy():
        result.direction=Vector3.ZERO;result.drive=Vector2.ZERO;result.jump=false;result.aim=false
    jump_pending=false
    return result

func _physics_process(delta: float) -> void:
    if NetworkSession.phase=="loading" or not world_ready or (local_player and NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch):
        velocity=Vector3.ZERO
        riding=false;ride_target_valid=false
        return
    _sync_costume()
    if local_player and not busy() and not Input.is_action_pressed("fire") and not Input.is_action_pressed("jump"):
        harvest_input_guard=false
    if local_player and control_enabled and not busy() and Input.is_action_just_pressed("reset_player"): NetworkSession.request_action("reset")
    if local_player and control_enabled and not busy() and not harvest_input_guard and Input.is_action_just_pressed("jump"): jump_pending=true
    if seat_index==0:
        riding=false;_ride_frame=-10
        _update_visual(delta,0)
        $Visual/LeftLeg.rotation.x=-1.2
        $Visual/RightLeg.rotation.x=-1.2
        return
    # The host moves every hunter, a client only its own living hunter; replicas follow snapshots.
    var simulated: bool=NetworkSession.is_host() or (local_player and health>0)
    if simulated: _carry()
    _life_pose()
    if health<=0:
        velocity.x=0;velocity.z=0
        if NetworkSession.is_host():
            velocity.y=0 if is_on_floor() else velocity.y-_gravity*delta
            move_and_slide()
        else: _follow_replica(delta)
        return
    if not simulated:
        _follow_replica(delta)
        _update_visual(delta,minf(velocity.length()/walk_speed,1))
        return
    if local_player: _frame_camera()
    if busy():
        velocity.x=0;velocity.z=0;jump_pending=false;revive_target=0
        command["jump"]=false
        # Skinning something at sea: the diver hangs in the water instead of sinking.
        var hovering: bool=NetworkSession.world_id=="ocean" and is_instance_valid(NetworkSession.forest) and NetworkSession.forest.water_submersion(global_position)>.55
        if hovering: velocity.y=0
        else: velocity.y=0 if is_on_floor() else velocity.y-_gravity*delta
        move_and_slide()
        _update_visual(delta,0)
        return
    var data: Dictionary=command
    if local_player:
        var active:=control_enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and revive_target==0
        var stick:=Input.get_vector("move_left","move_right","move_forward","move_backward") if active and revive_target==0 else Vector2.ZERO
        data={"direction":camera_rig.movement_direction(stick),"sprint":active and Input.is_action_pressed("sprint"),"jump":active and not harvest_input_guard and Input.is_action_just_pressed("jump"),"aim":camera_rig.aiming,"yaw":camera_rig.rotation.y,"first":camera_rig.is_first_person(),
            "stick":stick,"pitch":camera_rig.rotation.x,"ascend":active and not harvest_input_guard and Input.is_action_pressed("jump")}
    var direction: Vector3=data.get("direction",Vector3.ZERO)
    var aiming: bool=bool(data.get("aim",false))
    var speed:=aim_speed if aiming else sprint_speed if data.get("sprint",false) else walk_speed
    var contact_depth: float=0.0
    if NetworkSession.phase=="hunt" and is_instance_valid(NetworkSession.forest):
        contact_depth=NetworkSession.forest.water_submersion(global_position)
    var pace_factor: float=WaterInteraction.wading_factor(contact_depth)
    if NetworkSession.world_id=="swamp" and is_instance_valid(NetworkSession.forest):
        pace_factor=minf(pace_factor,lerpf(1,.52,NetworkSession.forest.mud_factor(global_position)))
    speed*=pace_factor
    var water_acceleration: float=acceleration*lerpf(1.0,.62,smoothstep(.08,1.15,contact_depth))
    swimming=NetworkSession.world_id=="ocean" and not riding and (contact_depth>=SWIM_ENTER or (swimming and contact_depth>SWIM_EXIT))
    if swimming:
        _swim_move(delta,data)
    else:
        velocity.x=move_toward(velocity.x,direction.x*speed,water_acceleration*delta)
        velocity.z=move_toward(velocity.z,direction.z*speed,water_acceleration*delta)
        if not is_on_floor(): velocity.y-=_gravity*delta
        elif data.get("jump",false): velocity.y=jump_speed*lerpf(1.0,.85,smoothstep(.15,1.15,contact_depth))
    command["jump"]=false
    move_and_slide()
    if not riding:
        NetworkSession.constrain_to_lobby(self)
        global_position.x=clampf(global_position.x,-ForestMap.LIMIT,ForestMap.LIMIT)
        global_position.z=clampf(global_position.z,-ForestMap.LIMIT,ForestMap.LIMIT)
    if not local_player:
        camera_rig.aiming=aiming;camera_rig.rotation.x=float(data.get("pitch",0))
    if aiming or data.get("first",false): visual.rotation.y=lerp_angle(visual.rotation.y,float(data.get("yaw",0)),1-exp(-turn_speed*delta))
    elif direction.length_squared()>.01: visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),1-exp(-turn_speed*delta))
    _update_visual(delta,direction.length())
    if NetworkSession.is_host() and global_position.y < -20: respawn()

## Free 3D swimming: the stick moves you along the camera's view, so looking down
## and pushing forward dives; Space rises; Shift kicks hard. Idle near the surface
## you drift up and float with your head in the air; deeper down you hang neutral.
func _swim_move(delta: float,data: Dictionary) -> void:
    var stick: Vector2=data.get("stick",data.get("drive",Vector2.ZERO))
    var yaw: float=float(data.get("yaw",0.0));var pitch: float=float(data.get("pitch",0.0))
    var view:=Basis.from_euler(Vector3(pitch,yaw,0.0))
    var wish: Vector3=view*Vector3(stick.x,0.0,stick.y)
    if wish.length_squared()>1.0: wish=wish.normalized()
    var target: Vector3=wish*(SWIM_FAST if bool(data.get("sprint",false)) else SWIM_SPEED)
    var ascending: bool=bool(data.get("ascend",data.get("brake",false)))
    if ascending: target.y=maxf(target.y,3.4)
    elif wish.length_squared()<.04 and global_position.y>SWIM_REST-2.2: target.y=clampf((SWIM_REST-global_position.y)*1.1,-1.2,1.2)
    velocity=velocity.move_toward(target,11.0*delta)
    # Water swallows a plunge: a jump from the deck ends within a metre or so.
    if velocity.y<target.y-2.0: velocity.y=move_toward(velocity.y,target.y-2.0,40.0*delta)
    # The head stays in the air: you cannot swim up out of the sea.
    if global_position.y>SWIM_REST+.12 and velocity.y>0.0: velocity.y=minf(velocity.y,(SWIM_REST-global_position.y)*3.0)

## The diving suit goes on in the ocean and comes off everywhere else.
func _sync_costume() -> void:
    var want: bool=NetworkSession.world_id=="ocean" and NetworkSession.phase!="lobby"
    if want!=DivingSuit.is_dressed(visual):
        if want: DivingSuit.dress(visual,peer_id)
        else: DivingSuit.undress(visual)
    if want:
        var depth: float=0.0
        if is_instance_valid(NetworkSession.forest) and NetworkSession.forest.water_depth(global_position)>0.0: depth=-global_position.y
        DivingSuit.update(visual,depth)

## Prone, kicking, pivoting about the hips; upright treading water when still.
func _update_swim_pose(delta: float) -> void:
    var wet: bool=NetworkSession.world_id=="ocean" and health>0 and seat_index<0 and not riding and is_instance_valid(NetworkSession.forest) and NetworkSession.forest.water_submersion(global_position)>.7
    var speed: float=velocity.length()
    var target: float=0.0
    if wet: target=-.14 if speed<.45 else clampf(-1.2+velocity.y*.16,-1.5,-.45)
    _swim_lean=lerpf(_swim_lean,target,1.0-exp(-6.0*delta))
    if not wet and absf(_swim_lean)<.02:
        if _swim_lean!=0.0: _swim_lean=0.0;visual.rotation.x=0.0;visual.position.x=0.0;visual.position.z=0.0
        return
    visual.rotation.x=_swim_lean
    var pivot:=Vector3(0,.95,0)
    visual.position=pivot-visual.basis*pivot
    var kick: float=sin(_stride_time*.62)*clampf(speed/3.0,0.0,1.0)*.75
    $Visual/LeftLeg.rotation.x=kick+.12
    $Visual/RightLeg.rotation.x=-kick+.12
    $Visual/LeftLeg/Knee.rotation.x=maxf(0.0,-kick)*.5
    $Visual/RightLeg/Knee.rotation.x=maxf(0.0,kick)*.5
    $Visual/LeftArm.rotation.x=.25+sin(_stride_time*.31)*.12*clampf(speed/3.0,0.0,1.0)
    if not camera_rig.aiming: $Visual/RightArm.rotation.x=.25-sin(_stride_time*.31)*.12*clampf(speed/3.0,0.0,1.0)

## Carries a rider by exactly the truck's motion since the last physics frame
## (translation and turn), before the hunter's own movement is applied.
func _carry() -> void:
    var truck=NetworkSession.jeep
    var frame: int=Engine.get_physics_frames()
    if not is_instance_valid(truck) or not truck.enabled:
        riding=false;_ride_frame=-10;return
    var now: Transform3D=truck.global_transform
    if riding and _ride_frame==frame-1:
        global_position=now*(_ride_from.affine_inverse()*global_position)
        var turn: float=wrapf(now.basis.get_euler().y-_ride_from.basis.get_euler().y,-PI,PI)
        visual.rotation.y+=turn
        if local_player: camera_rig.rotation.y+=turn
    _ride_from=now;_ride_frame=frame
    riding=truck.carries(global_position)

## Truck-local position of a rider, in the frame its world position matches.
func ride_local() -> Vector3:
    return _ride_from.affine_inverse()*global_position

## Puts the hunter on the truck at `point` (world) without breaking the ride:
## the next carry starts from the truck's current pose, whether this is called
## from a network action between frames or from inside a physics frame.
func place_aboard(point: Vector3) -> void:
    global_position=point;velocity=Vector3.ZERO
    var truck=NetworkSession.jeep
    if not is_instance_valid(truck): return
    _ride_from=truck.global_transform
    _ride_frame=Engine.get_physics_frames()-(1 if Engine.is_in_physics_frame() else 0)
    riding=truck.carries(point)

## Replicas ride in truck space so they stay put on a moving deck.
func _follow_replica(delta: float) -> void:
    var weight: float=1-exp(-12*delta)
    var truck=NetworkSession.jeep
    if ride_target_valid and is_instance_valid(truck):
        var frame: Transform3D=truck.global_transform
        if not _shown_riding: _shown_local=frame.affine_inverse()*global_position;_shown_riding=true
        _shown_local=_shown_local.lerp(ride_target,weight)
        global_position=frame*_shown_local
        visual.rotation.y=lerp_angle(visual.rotation.y,frame.basis.get_euler().y+ride_yaw,weight)
        return
    _shown_riding=false
    global_position=global_position.lerp(target_position,weight)
    visual.rotation.y=lerp_angle(visual.rotation.y,target_yaw,weight)

## On the open terrace the camera ignores the truck, so it never snaps into the
## railing; inside the cottage it still stops at the log walls.
func _frame_camera() -> void:
    var truck=NetworkSession.jeep
    if not is_instance_valid(truck): return
    var on_deck: bool=riding and ride_local().y>6.5
    if on_deck==_arm_ignores_truck: return
    _arm_ignores_truck=on_deck
    if on_deck: camera_rig.spring_arm.add_excluded_object(truck.get_rid())
    else: camera_rig.spring_arm.remove_excluded_object(truck.get_rid())

func snapshot() -> Dictionary:
    var data: Dictionary={"id":peer_id,"name":player_name,"p":global_position,"v":velocity,"yaw":visual.rotation.y,"hp":health,"down":respawn_clock,"seat":seat_index,"weapon":String(inventory.equipped_weapon_id),"bag":String(inventory.backpack_id),"levels":inventory.weapon_upgrades.get(String(inventory.equipped_weapon_id),{}),"ammo":inventory.ammunition(),"reload":inventory.reload_remaining,"ready":world_ready,"spawn":spawn_position,"revive":revive_progress,"helper":revive_helper,"harvest_target":harvest_target,"cleaning":cleaning,"pitch":camera_rig.rotation.x,"aim":camera_rig.aiming}
    if riding and seat_index<0:
        data["lp"]=ride_local()
        data["ly"]=wrapf(visual.rotation.y-_ride_from.basis.get_euler().y,-PI,PI)
    return data

func apply_snapshot(data: Dictionary) -> void:
    health=data.hp
    world_ready=bool(data.get("ready",true))
    spawn_position=data.get("spawn",spawn_position)
    respawn_clock=0
    revive_progress=float(data.get("revive",0));revive_helper=int(data.get("helper",0))
    harvest_target=int(data.get("harvest_target",0))
    cleaning=bool(data.get("cleaning",false))
    velocity=data.v
    target_position=data.p
    target_yaw=data.yaw
    ride_target_valid=data.get("lp") is Vector3
    if ride_target_valid: ride_target=data.lp;ride_yaw=float(data.get("ly",0))
    if health<=0:
        visual.rotation.y=target_yaw
        life_pose_downed=false
        _life_pose()
    if not local_player:
        camera_rig.rotation.x=float(data.get("pitch",0));camera_rig.aiming=bool(data.get("aim",false))
    set_seat(data.seat)
    inventory.weapon_upgrades[data.weapon]=data.get("levels",{}).duplicate()
    inventory.magazines[data.weapon]=int(data.get("ammo",8))
    inventory.reload_remaining=float(data.get("reload",0))
    if local_player and seat_index<0 and health>0:
        # Riders are reconciled in truck space: the replica truck lags the host's.
        var truck=NetworkSession.jeep
        var goal: Vector3=target_position
        if ride_target_valid and is_instance_valid(truck): goal=(_ride_from if riding else truck.global_transform)*ride_target
        var gap: float=global_position.distance_to(goal)
        if gap>.8:
            var fixed: Vector3=global_position.lerp(goal,.45) if gap<4 else goal
            if ride_target_valid and is_instance_valid(truck): place_aboard(fixed)
            else: global_position=fixed
    if inventory.equipped_weapon_id!=StringName(data.weapon) or inventory.backpack_id!=StringName(data.bag):
        inventory.equipped_weapon_id=StringName(data.weapon)
        inventory.backpack_id=StringName(data.bag)
        inventory.changed.emit()

func set_seat(index: int) -> void:
    var was_seated:=seat_index>=0
    seat_index=index
    collision_layer=0 if index>=0 else 2
    collision_mask=0 if index>=0 else 1|16
    if index<0 and health>0:
        visual.rotation.x=0
        visual.rotation.z=0
    camera_rig.enabled=local_player and index!=0 and not busy()
    if index>=0: riding=false;_ride_frame=-10
    var menu_open: bool=NetworkSession.world!=null and NetworkSession.world.menu.is_open
    if local_player and index<0 and was_seated and not menu_open: camera_rig.camera.current=true

func take_damage(amount: int) -> void:
    if not NetworkSession.is_host() or health<=0: return
    health=maxi(0,health-amount);damage_version+=1
    if health==0:
        respawn_clock=0;command={};revive_target=0
        if seat_index>=0: NetworkSession.jeep.exit_seat(peer_id,true)
        _life_pose()

func _update_visual(delta: float, movement_amount: float) -> void:
    _stride_time += delta * (11.0 if not camera_rig.aiming else 7.0)
    var swing := sin(_stride_time) * movement_amount * 0.32
    $Visual/LeftLeg.rotation.x = swing
    $Visual/RightLeg.rotation.x = -swing
    $Visual/LeftLeg/Knee.rotation.x=maxf(0,-sin(_stride_time))*.55*movement_amount
    $Visual/RightLeg/Knee.rotation.x=maxf(0,sin(_stride_time))*.55*movement_amount
    $Visual/RightArm/Elbow.rotation.x=-1.1 if camera_rig.aiming else -.6
    $Visual/LeftArm.rotation.x = -swing * 0.6
    $Visual/RightArm.rotation.x = -0.7 if camera_rig.aiming else swing * 0.3 - 0.2
    if _weapon_visual:
        var pitch := camera_rig.rotation.x if camera_rig.aiming else -0.25
        _weapon_visual.rotation.x = lerpf(_weapon_visual.rotation.x, pitch - combat.recoil, 1.0 - exp(-12.0 * delta))
    visual.position.y = absf(sin(_stride_time)) * movement_amount * 0.035
    _update_swim_pose(delta)


## Steps off the truck (or anywhere) to a world point.
func respawn_at(point: Vector3) -> void:
    riding=false;_ride_frame=-10
    global_position=point;velocity=Vector3.ZERO

func respawn() -> void:
    riding=false;_ride_frame=-10
    global_position = spawn_position
    velocity = Vector3.ZERO
    visual.rotation = Vector3.ZERO
    camera_rig.reset_view()

func muzzle_position() -> Vector3:
    if local_player and camera_rig.is_first_person() and is_instance_valid(camera_rig.view_model.model):
        var first_marker=camera_rig.view_model.model.get_node_or_null("Muzzle")
        if first_marker: return first_marker.global_position
    var marker := _weapon_visual.get_node_or_null("Muzzle") as Node3D
    return marker.global_position if marker else $Visual/WeaponMount.global_position


func _update_equipment() -> void:
    if _shown_weapon != inventory.equipped_weapon_id:
        if is_instance_valid(_weapon_visual):
            _weapon_visual.get_parent().remove_child(_weapon_visual)
            _weapon_visual.queue_free()
        var weapon := EquipmentCatalog.weapon(inventory.equipped_weapon_id)
        _weapon_visual = load(weapon.model_path).instantiate()
        $Visual/WeaponMount.add_child(_weapon_visual)
        GameArt.dress_scene(_weapon_visual,"weapon")
        _weapon_visual.visible=health>0
        _shown_weapon = inventory.equipped_weapon_id
    if _shown_backpack != inventory.backpack_id:
        if is_instance_valid(_backpack_visual):
            _backpack_visual.get_parent().remove_child(_backpack_visual)
            _backpack_visual.queue_free()
        var backpack := EquipmentCatalog.backpack(inventory.backpack_id)
        _backpack_visual = load(backpack.model_path).instantiate()
        $Visual/BackpackMount.add_child(_backpack_visual)
        GameArt.dress_scene(_backpack_visual,"backpack")
        _shown_backpack = inventory.backpack_id

func _life_pose() -> void:
    var downed:=health<=0
    if downed==life_pose_downed: return
    life_pose_downed=downed
    if downed:
        visual.rotation.x=-PI*.5;visual.rotation.z=0;visual.position.y=.36
        for limb in ["LeftLeg","RightLeg","LeftArm","RightArm"]: visual.get_node(limb).rotation=Vector3.ZERO
        $CollisionShape3D.position=Basis(Vector3.UP,visual.rotation.y)*Vector3(0,.36,-.85)
        $CollisionShape3D.rotation=Vector3(-PI*.5,visual.rotation.y,0)
    else:
        visual.rotation.x=0;visual.rotation.z=0;visual.position.y=0
        $CollisionShape3D.position=Vector3(0,.875,0);$CollisionShape3D.rotation=Vector3.ZERO
    if is_instance_valid(_weapon_visual): _weapon_visual.visible=not downed
    _update_name_tag()
    name_tag.position=Vector3(0,.9,-.8) if downed else Vector3(0,2.3,0)
    name_tag.modulate=Color("ff8b71") if downed else Color.WHITE
    name_tag.visible=not local_player or downed

func _update_name_tag() -> void:
    if not is_instance_valid(name_tag): return
    name_tag.text=player_name+(" · "+tr("DOWNED_TAG") if health<=0 else "")

func revive() -> void:
    if not NetworkSession.is_host() or health>0: return
    health=50;revive_progress=0;revive_helper=0;velocity=Vector3.ZERO;command={}
    _life_pose()
