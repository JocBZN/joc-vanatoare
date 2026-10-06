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

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _stride_time: float = 0.0


func _ready() -> void:
    load("res://art/hunter_details.gd").apply(visual)
    camera_rig.spring_arm.add_excluded_object(get_rid())
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


func sample_input() -> Dictionary:
    input_sequence+=1
    var active:=local_player and control_enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and health>0 and harvest_target==0
    var stick:=Input.get_vector("move_left","move_right","move_forward","move_backward") if active else Vector2.ZERO
    var result={"direction":camera_rig.movement_direction(stick),"drive":stick,"sprint":active and Input.is_action_pressed("sprint"),"jump":jump_pending,"aim":camera_rig.aiming,"yaw":camera_rig.rotation.y,"pitch":camera_rig.rotation.x,"brake":active and Input.is_action_pressed("jump"),"seq":input_sequence,"first":camera_rig.is_first_person()}
    revive_target=0
    if active and Input.is_action_pressed("interact") and NetworkSession.world.nearby and NetworkSession.world.nearby.interaction_kind=="revive":
        revive_target=NetworkSession.world.nearby.target_peer()
    result["harvest"]=harvest_target>0
    if harvest_target>0:
        result["blade"]=NetworkSession.local_blade
        result["bt"]=Time.get_ticks_msec()
    if harvest_input_guard: result.jump=false
    result["revive"]=revive_target
    if revive_target>0 or harvest_target>0:
        result.direction=Vector3.ZERO;result.drive=Vector2.ZERO;result.jump=false;result.aim=false
    jump_pending=false
    return result

func _physics_process(delta: float) -> void:
    if NetworkSession.phase=="loading" or not world_ready or (local_player and NetworkSession.local_loaded_epoch!=NetworkSession.world_epoch):
        velocity=Vector3.ZERO
        return
    if local_player and harvest_target==0 and not Input.is_action_pressed("fire") and not Input.is_action_pressed("jump"):
        harvest_input_guard=false
    if local_player and control_enabled and harvest_target==0 and Input.is_action_just_pressed("reset_player"): NetworkSession.request_action("reset")
    if local_player and control_enabled and harvest_target==0 and not harvest_input_guard and Input.is_action_just_pressed("jump"): jump_pending=true
    if seat_index>=0:
        _update_visual(delta,0)
        $Visual/LeftLeg.rotation.x=-1.2
        $Visual/RightLeg.rotation.x=-1.2
        return
    _life_pose()
    if health<=0:
        velocity.x=0;velocity.z=0
        if NetworkSession.is_host():
            velocity.y=0 if is_on_floor() else velocity.y-_gravity*delta
            move_and_slide()
        else: global_position=global_position.lerp(target_position,1-exp(-12*delta))
        return
    if not NetworkSession.is_host() and not local_player:
        global_position=global_position.lerp(target_position,1-exp(-12*delta))
        visual.rotation.y=lerp_angle(visual.rotation.y,target_yaw,1-exp(-12*delta))
        _update_visual(delta,minf(velocity.length()/walk_speed,1))
        return
    if harvest_target>0:
        velocity.x=0;velocity.z=0;jump_pending=false;revive_target=0
        command["jump"]=false
        velocity.y=0 if is_on_floor() else velocity.y-_gravity*delta
        move_and_slide()
        _update_visual(delta,0)
        return
    var data: Dictionary=command
    if local_player:
        var active:=control_enabled and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and revive_target==0
        var stick:=Input.get_vector("move_left","move_right","move_forward","move_backward") if active and revive_target==0 else Vector2.ZERO
        data={"direction":camera_rig.movement_direction(stick),"sprint":active and Input.is_action_pressed("sprint"),"jump":active and not harvest_input_guard and Input.is_action_just_pressed("jump"),"aim":camera_rig.aiming,"yaw":camera_rig.rotation.y,"first":camera_rig.is_first_person()}
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
    velocity.x=move_toward(velocity.x,direction.x*speed,water_acceleration*delta)
    velocity.z=move_toward(velocity.z,direction.z*speed,water_acceleration*delta)
    if not is_on_floor(): velocity.y-=_gravity*delta
    elif data.get("jump",false): velocity.y=jump_speed*lerpf(1.0,.85,smoothstep(.15,1.15,contact_depth))
    command["jump"]=false
    move_and_slide()
    NetworkSession.constrain_to_lobby(self)
    global_position.x=clampf(global_position.x,-590,590)
    global_position.z=clampf(global_position.z,-590,590)
    if not local_player:
        camera_rig.aiming=aiming;camera_rig.rotation.x=float(data.get("pitch",0))
    if aiming or data.get("first",false): visual.rotation.y=lerp_angle(visual.rotation.y,float(data.get("yaw",0)),1-exp(-turn_speed*delta))
    elif direction.length_squared()>.01: visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-direction.x,-direction.z),1-exp(-turn_speed*delta))
    _update_visual(delta,direction.length())
    if NetworkSession.is_host() and global_position.y < -20: respawn()

func snapshot() -> Dictionary:
    return {"id":peer_id,"name":player_name,"p":global_position,"v":velocity,"yaw":visual.rotation.y,"hp":health,"down":respawn_clock,"seat":seat_index,"weapon":String(inventory.equipped_weapon_id),"bag":String(inventory.backpack_id),"levels":inventory.weapon_upgrades.get(String(inventory.equipped_weapon_id),{}),"ammo":inventory.ammunition(),"reload":inventory.reload_remaining,"ready":world_ready,"spawn":spawn_position,"revive":revive_progress,"helper":revive_helper,"harvest_target":harvest_target,"pitch":camera_rig.rotation.x,"aim":camera_rig.aiming}

func apply_snapshot(data: Dictionary) -> void:
    health=data.hp
    world_ready=bool(data.get("ready",true))
    spawn_position=data.get("spawn",spawn_position)
    respawn_clock=0
    revive_progress=float(data.get("revive",0));revive_helper=int(data.get("helper",0))
    harvest_target=int(data.get("harvest_target",0))
    velocity=data.v
    target_position=data.p
    target_yaw=data.yaw
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
    if local_player and seat_index<0 and global_position.distance_to(target_position)>.8:
        global_position=global_position.lerp(target_position,.45) if global_position.distance_to(target_position)<4 else target_position
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
    camera_rig.enabled=local_player and index<0 and harvest_target==0
    if local_player and was_seated and index<0 and not NetworkSession.world.menu.is_open: camera_rig.camera.current=true

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


func respawn() -> void:
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
