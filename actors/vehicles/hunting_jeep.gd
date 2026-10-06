class_name HuntingJeep
extends RigidBody3D
## Host-only rigid-body simulation with four raycast suspension / tire contacts.
const SEATS=[Vector3(-.52,.8,.05),Vector3(.52,.8,.05),Vector3(-.52,.8,1.02),Vector3(.52,.8,1.02)]
const WHEELS=[Vector3(-1.12,1,-1.21),Vector3(1.12,1,-1.21),Vector3(-1.12,1,1.21),Vector3(1.12,1,1.21)]
@export var chassis_mass: float=1250
@export var wheel_radius: float=.52
@export var suspension_rest: float=.52
@export var suspension_travel: float=.74
@export var spring_stiffness: float=42000
@export var damping: float=5500
@export var tire_friction: float=1.25
@export var engine_force: float=7200
@export var max_forward_speed: float=22
@export var max_reverse_speed: float=7
var occupants: Array=[0,0,0,0]
var command: Dictionary={}
var speed: float=0
var velocity: Vector3:
    get: return linear_velocity
    set(value): linear_velocity=value
var target_position:=Vector3.ZERO
var target_rotation:=Quaternion.IDENTITY
var target_velocity:=Vector3.ZERO
var camera: Camera3D
var orbit: Node3D
var steering: float=0
var grounded_wheels: int=0
var spring_lengths: Array=[.52,.52,.52,.52]
var wheel_turns: Array[Node3D]=[]
var wheel_spins: Array[Node3D]=[]
var enabled: bool=true
var pending_reset: bool=false
var reset_pose:=Transform3D.IDENTITY
var recovery_time: int=-5000
var camera_input_time: int=0

func _ready() -> void:
    collision_layer=16
    collision_mask=1|2|16
    mass=chassis_mass
    center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass=Vector3(0,.75,0)
    continuous_cd=true
    contact_monitor=true
    max_contacts_reported=12
    can_sleep=false
    linear_damp=.03
    angular_damp=.5
    physics_material_override=PhysicsMaterial.new()
    physics_material_override.friction=.65
    physics_material_override.bounce=.02
    var collision:=CollisionShape3D.new()
    var shape:=BoxShape3D.new();shape.size=Vector3(2.05,.65,3.65)
    collision.shape=shape;collision.position.y=1.05;add_child(collision)
    var cabin:=CollisionShape3D.new()
    var cabin_shape:=BoxShape3D.new();cabin_shape.size=Vector3(1.85,.75,1.75)
    cabin.shape=cabin_shape;cabin.position=Vector3(0,1.72,.2);add_child(cabin)
    var model=load("res://actors/vehicles/jeep_model.tscn").instantiate()
    add_child(model)
    var names=[["Wheel","WheelHub"],["Wheel3","WheelHub3"],["Wheel2","WheelHub2"],["Wheel4","WheelHub4"]]
    for i in 4:
        var turn:=Node3D.new();turn.name="Suspension"+str(i);add_child(turn)
        turn.position=WHEELS[i]-Vector3.UP*suspension_rest
        var spin:=Node3D.new();turn.add_child(spin)
        wheel_turns.append(turn);wheel_spins.append(spin)
        for name_value in names[i]:
            var visual=model.get_node(name_value)
            visual.reparent(spin,false);visual.position=Vector3.ZERO
    for x in [-.48,.48]:
        var rear=model.get_node("Seat").duplicate()
        rear.position=Vector3(x,1.57,1.15)
        model.add_child(rear)
    orbit=Node3D.new();add_child(orbit)
    orbit.top_level=true
    orbit.position=global_position+Vector3.UP*1.8
    orbit.rotation.x=-.23
    var arm:=SpringArm3D.new();arm.spring_length=7;arm.collision_mask=1|16
    orbit.add_child(arm);arm.add_excluded_object(get_rid())
    camera=Camera3D.new();camera.far=900;camera.fov=70;arm.add_child(camera)
    for kind in ["jeep","trunk"]:
        var use:=LobbyInteractable.new();use.interaction_kind=kind;use.interaction_range=3.2
        use.position=Vector3(-1.5,0,-.65) if kind=="jeep" else Vector3(0,0,2.55)
        add_child(use)
    for x in [-.7,.7]:
        var light:=SpotLight3D.new();light.position=Vector3(x,1.2,-2)
        light.light_color=Color("ffe8c0");light.light_energy=3;light.spot_range=50
        light.spot_angle=32;light.shadow_enabled=true;add_child(light)
    var chest:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(1.55,.65,.65)
    chest.mesh=box;chest.position=Vector3(0,1.15,1.72)
    var material:=ShaderMaterial.new();material.shader=load("res://world/effects/camo.gdshader")
    chest.material_override=material;add_child(chest)
    var tag:=Label3D.new();tag.text="120";tag.font_size=28;tag.position=Vector3(0,1.25,2.06)
    tag.rotation.y=PI;tag.pixel_size=.007;add_child(tag)
    GameArt.dress_scene(self,"vehicle")
    target_position=global_position
    set_simulation(true)

func set_simulation(value: bool) -> void:
    enabled=value
    freeze=not value or not NetworkSession.is_host()
    if not value: command={};linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO;speed=0

func reset_state(pose: Transform3D) -> void:
    command={};speed=0;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
    reset_pose=pose;pending_reset=NetworkSession.is_host()
    global_transform=pose
    target_position=pose.origin;target_rotation=pose.basis.get_rotation_quaternion()
    orbit.global_position=pose.origin+Vector3.UP*1.8
    orbit.rotation.y=pose.basis.get_euler().y

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    if not enabled or not NetworkSession.is_host(): return
    if pending_reset:
        state.transform=reset_pose;state.linear_velocity=Vector3.ZERO;state.angular_velocity=Vector3.ZERO
        pending_reset=false
    if NetworkSession.phase=="loading": return
    var basis_value:=state.transform.basis.orthonormalized()
    var up:=basis_value.y
    var forward: Vector3=-basis_value.z
    speed=state.linear_velocity.dot(forward)
    var fresh:=Time.get_ticks_msec()-int(command.get("time",0))<=500
    var input: Vector2=command.get("drive",Vector2.ZERO) if occupants[0]!=0 and fresh else Vector2.ZERO
    var throttle: float=-input.y
    var brake: bool=bool(command.get("brake",false)) or occupants[0]==0 or not fresh
    if throttle*speed<-.6: brake=true;throttle=0
    var max_angle: float=lerpf(.55,.20,clampf(absf(speed)/max_forward_speed,0,1))
    steering=move_toward(steering,-input.x*max_angle,state.step*1.7)
    var mud: float=NetworkSession.forest.mud_factor(state.transform.origin) if NetworkSession.world_id=="swamp" and is_instance_valid(NetworkSession.forest) else 0
    grounded_wheels=0
    for i in 4:
        var offset: Vector3=basis_value*WHEELS[i]
        var from: Vector3=state.transform.origin+offset
        var ray:=PhysicsRayQueryParameters3D.create(from,from-up*(suspension_travel+wheel_radius),1,[get_rid()])
        var hit:=state.get_space_state().intersect_ray(ray)
        spring_lengths[i]=suspension_travel
        if hit.is_empty() or hit.normal.dot(up)<.35: continue
        grounded_wheels+=1
        var length:=clampf(from.distance_to(hit.position)-wheel_radius,.08,suspension_travel)
        spring_lengths[i]=length
        var local_velocity:=state.linear_velocity+state.angular_velocity.cross(offset-basis_value*center_of_mass)
        var normal: Vector3=hit.normal
        var load_force:=clampf((suspension_rest-length)*spring_stiffness-local_velocity.dot(up)*damping,0,mass*12)
        state.apply_force(normal*load_force,offset)
        var wheel_forward:=forward.rotated(up,steering if i<2 else 0)
        wheel_forward=wheel_forward.slide(normal).normalized()
        var side:=wheel_forward.cross(normal).normalized()
        var grip_limit: float=load_force*tire_friction*lerpf(1,.68,mud)
        var side_force: float=-local_velocity.dot(side)*mass*.25/state.step*.18
        side_force-=state.total_gravity.dot(side)*mass*.25
        var longitudinal: float=throttle*engine_force*.25*lerpf(1,.82,mud)
        if throttle*speed>(max_forward_speed if throttle>0 else max_reverse_speed): longitudinal=0
        var wheel_speed: float=local_velocity.dot(wheel_forward)
        if brake:
            longitudinal=-wheel_speed*mass*.25/state.step*.35-state.total_gravity.dot(wheel_forward)*mass*.25
        else:
            longitudinal-=wheel_speed*mass*.004
        # A friction circle keeps steering and braking within available traction.
        var tire_force:=Vector2(side_force,longitudinal).limit_length(grip_limit)
        state.apply_force(side*tire_force.x+wheel_forward*tire_force.y,offset-up*.28)
    var horizontal:=state.linear_velocity.slide(Vector3.UP)
    state.apply_central_force(-horizontal*(35+2*horizontal.length()+mud*95))
    _apply_water_forces(state,basis_value)
    if NetworkSession.phase=="lobby":
        var p:=state.transform.origin
        if absf(p.x)>18 or absf(p.z)>17:
            p.x=clampf(p.x,-18,18);p.z=clampf(p.z,-17,17)
            var constrained:=state.transform;constrained.origin=p;state.transform=constrained
            state.linear_velocity=Vector3.ZERO;state.angular_velocity=Vector3.ZERO
    if state.transform.origin.y < -30 or absf(state.transform.origin.x)>595 or absf(state.transform.origin.z)>595:
        state.transform=NetworkSession.world.world_router.jeep_spawn()
        state.linear_velocity=Vector3.ZERO;state.angular_velocity=Vector3.ZERO

func _apply_water_forces(state: PhysicsDirectBodyState3D, basis_value: Basis) -> void:
    if not NetworkSession.is_host() or NetworkSession.phase!="hunt" or not is_instance_valid(NetworkSession.forest): return
    var immersion: float=0.0
    for corner in [Vector3(-.85,.65,-1.35),Vector3(.85,.65,-1.35),Vector3(-.85,.65,1.35),Vector3(.85,.65,1.35)]:
        var offset: Vector3=basis_value*corner
        var point: Vector3=state.transform.origin+offset
        var depth: float=NetworkSession.forest.water_submersion(point)
        if depth<=0.0: continue
        var local_velocity: Vector3=state.linear_velocity+state.angular_velocity.cross(offset-basis_value*center_of_mass)
        var lift: float=WaterInteraction.hull_force(depth,local_velocity.y,mass,state.total_gravity.length())
        state.apply_force(Vector3.UP*lift,offset)
        immersion+=clampf(depth/.8,0.0,1.0)*.25
    if immersion<=0.0: return
    var horizontal: Vector3=state.linear_velocity.slide(Vector3.UP)
    # Opposes movement continuously and scales with submerged hull volume.
    state.apply_central_force(-horizontal*mass*immersion*(.35+.055*horizontal.length()))
    state.apply_torque(-state.angular_velocity*mass*immersion*.6)

func _unhandled_input(event: InputEvent) -> void:
    var local=NetworkSession.local_hunter()
    if not local or not local.control_enabled: return
    if event.is_action_pressed("recover_vehicle"): NetworkSession.request_action("recover_vehicle")
    if local.seat_index>=0 and event is InputEventMouseMotion:
        camera_input_time=Time.get_ticks_msec()
        orbit.rotation.y-=event.relative.x*.0025
        orbit.rotation.x=clampf(orbit.rotation.x-event.relative.y*.0025,-.7,.15)

func _physics_process(delta: float) -> void:
    if not NetworkSession.is_host():
        freeze=true
        if enabled:
            global_position=target_position if global_position.distance_to(target_position)>12 else global_position.lerp(target_position,1-exp(-14*delta))
            global_basis=Basis(global_basis.get_rotation_quaternion().slerp(target_rotation,1-exp(-14*delta)))
            linear_velocity=target_velocity
    else:
        freeze=not enabled
        var payload: float=chassis_mass+85*(4-occupants.count(0))+2*NetworkSession.trunk_space()
        if absf(mass-payload)>.1: mass=payload
    for i in 4:
        wheel_turns[i].position.y=WHEELS[i].y-float(spring_lengths[i])
        wheel_turns[i].rotation.y=steering if i<2 else 0
        wheel_spins[i].rotation.x+=speed*delta/wheel_radius
        var p=NetworkSession.players.get(occupants[i])
        if not is_instance_valid(p): continue
        p.seat_index=i;p.global_position=to_global(SEATS[i]);p.visual.global_basis=global_basis;p.velocity=linear_velocity
    orbit.global_position=orbit.global_position.lerp(global_position+Vector3.UP*1.8,1-exp(-12*delta))
    var local=NetworkSession.local_hunter()
    if local and local.seat_index>=0 and NetworkSession.phase!="loading":
        if Time.get_ticks_msec()-camera_input_time>1800: orbit.rotation.y=lerp_angle(orbit.rotation.y,rotation.y,1-exp(-1.8*delta))
        camera.fov=lerpf(camera.fov,70+minf(absf(speed)*.3,8),1-exp(-3*delta))
        if not NetworkSession.world.menu.is_open: camera.current=true

func snapshot() -> Dictionary:
    return {"p":global_position,"q":global_basis.get_rotation_quaternion(),"v":linear_velocity,"s":speed,"seats":occupants.duplicate(),"steer":steering,"springs":spring_lengths.duplicate(),"contacts":grounded_wheels}

func apply_snapshot(data: Dictionary) -> void:
    target_position=data.p;target_rotation=data.q;target_velocity=data.v
    speed=data.s;occupants=data.seats;steering=data.steer
    spring_lengths=data.springs;grounded_wheels=data.contacts

func enter(peer: int) -> bool:
    var p=NetworkSession.players.get(peer)
    if not enabled or not p or p.seat_index>=0 or linear_velocity.length()>2 or p.global_position.distance_to(global_position)>5: return false
    var index:=occupants.find(0)
    if index<0: NetworkSession.tell(peer,"SEATS_FULL");return false
    occupants[index]=peer;p.set_seat(index);return true

func exit_seat(peer: int,force: bool=false) -> bool:
    var index:=occupants.find(peer)
    if index<0: return false
    if not force and linear_velocity.length()>2: NetworkSession.tell(peer,"STOP_TO_EXIT");return false
    occupants[index]=0
    var p=NetworkSession.players.get(peer)
    if p:
        p.set_seat(-1)
        p.global_position=global_position+Basis(Vector3.UP,rotation.y)*Vector3(-2.6 if index%2==0 else 2.6,1,0)
        p.velocity=Vector3.ZERO
    if index==0: command={}
    return true

func recover(peer: int) -> bool:
    var p=NetworkSession.players.get(peer)
    if not p or (p.seat_index<0 and p.global_position.distance_to(global_position)>10) or linear_velocity.length()>2 or Time.get_ticks_msec()-recovery_time<5000: return false
    if global_basis.y.dot(Vector3.UP)>.45 and global_position.y>-20: return false
    var point:=global_position
    point.y=(NetworkSession.forest.height_at(point.x,point.z) if is_instance_valid(NetworkSession.forest) else 0)+.8
    reset_state(Transform3D(Basis(Vector3.UP,rotation.y),point));recovery_time=Time.get_ticks_msec()
    return true
