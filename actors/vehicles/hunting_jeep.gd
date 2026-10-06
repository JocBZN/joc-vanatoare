class_name HuntingJeep
extends RigidBody3D
## The Wandering Oak: the crew's truck and moving base. Host-only rigid-body
## simulation with four raycast suspension / tire contacts (the rear pair is
## drawn as a tandem). Seat 0 is the driver in the cab; seats 1-3 are gunner
## posts on the lookout terrace, where hunters keep their own camera and can
## shoot while someone drives. Parked without a driver, the truck freezes, lowers
## its ramp and becomes solid ground for walking up to the cottage.
const SEATS=[Vector3(-.62,1.3,-3.7),Vector3(-.95,7.8,-.2),Vector3(.95,7.8,-.2),Vector3(0,7.8,2.7)]
const WHEELS=[Vector3(-1.35,1.32,-5.3),Vector3(1.35,1.32,-5.3),Vector3(-1.75,1.32,3.6),Vector3(1.75,1.32,3.6)]
## Hull box (truck-local) for boarding distance and for securing riders.
const HULL_MIN:=Vector3(-2.1,0,-7.0)
const HULL_MAX:=Vector3(2.1,9.0,6.1)
const CAMERA_HEIGHT: float=4.2
const PARK_SECONDS: float=.8
## Stowed, the ramp slides flat under the trailer between the frame rails.
const RAMP_STOWED:=Transform3D(Basis(Vector3.UP,PI),Vector3(0,.5,6.3))
const Model:=preload("res://actors/vehicles/oak_truck_model.gd")
@export var chassis_mass: float=3600
@export var wheel_radius: float=.78
@export var suspension_rest: float=.62
@export var suspension_travel: float=.9
@export var spring_stiffness: float=125000
@export var damping: float=15500
@export var tire_friction: float=1.3
@export var engine_force: float=24000
@export var max_forward_speed: float=19
@export var max_reverse_speed: float=6
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
var spring_lengths: Array=[.62,.62,.62,.62]
var wheel_turns: Array[Node3D]=[]
var wheel_spins: Array[Node3D]=[]
var extra_spins: Array[Node3D]=[]
var enabled: bool=true
var pending_reset: bool=false
var reset_pose:=Transform3D.IDENTITY
var recovery_time: int=-5000
var camera_input_time: int=0
## Parked: frozen on the host, ramp down and walkable. Replicated to clients.
var parked: bool=false
var counters: Dictionary={}
var keepers: Dictionary={}
var cleaner: Node3D
var _parked_clock: float=0.0
var _ramp: Node3D
var _ramp_shape: CollisionShape3D
var _ramp_down: float=.58
var _ramp_lowered:=Transform3D.IDENTITY
var _ramp_blend: float=0.0
var _puffs: Array=[]
var _labels: Dictionary={}
var _clock: float=0.0

func _ready() -> void:
    collision_layer=16
    # Hunters collide with the truck, but the truck ignores them: a hunter is a
    # kinematic body, and one stepping off a terrace post is teleported metres in
    # a single frame, which the physics engine would turn into a huge shove.
    collision_mask=1|16
    mass=chassis_mass
    center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass=Vector3(0,1.0,-.3)
    continuous_cd=true
    contact_monitor=true
    max_contacts_reported=12
    can_sleep=false
    linear_damp=.03
    angular_damp=.6
    physics_material_override=PhysicsMaterial.new()
    physics_material_override.friction=.65
    physics_material_override.bounce=.02
    var parts: Dictionary=Model.new().build(self,WHEELS,wheel_radius)
    for node in parts.turns: wheel_turns.append(node)
    for node in parts.spins: wheel_spins.append(node)
    for node in parts.extra_spins: extra_spins.append(node)
    _ramp=parts.ramp;_ramp_shape=parts.ramp_shape;_ramp_down=parts.ramp_down
    _ramp_lowered=Transform3D(Basis(Vector3.RIGHT,_ramp_down),_ramp.position)
    _ramp.transform=RAMP_STOWED
    _puffs=parts.puffs;_labels=parts.labels
    counters=parts.counters;keepers=parts.keepers;cleaner=parts.cleaner
    orbit=Node3D.new();add_child(orbit)
    orbit.top_level=true
    orbit.position=global_position+Vector3.UP*CAMERA_HEIGHT
    orbit.rotation.x=-.24
    var arm:=SpringArm3D.new();arm.spring_length=12.5;arm.collision_mask=1|16
    orbit.add_child(arm);arm.add_excluded_object(get_rid())
    camera=Camera3D.new();camera.far=900;camera.fov=70;arm.add_child(camera)
    for x in [-.88,.88]:
        var light:=SpotLight3D.new();light.position=Vector3(x,2.05,-6.95)
        light.light_color=Color("ffe8c0");light.light_energy=3;light.spot_range=55
        light.spot_angle=32;light.shadow_enabled=true;add_child(light)
    LocaleSettings.changed.connect(_localize)
    _localize()
    target_position=global_position
    set_simulation(true)

func _localize() -> void:
    for label in _labels: label.text=tr(_labels[label]).to_upper() if _labels[label]=="trunk" else tr(_labels[label])

func set_simulation(value: bool) -> void:
    enabled=value
    _set_parked(false)
    freeze=not value or not NetworkSession.is_host()
    if not value: command={};linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO;speed=0

func reset_state(pose: Transform3D) -> void:
    command={};speed=0;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
    _set_parked(false)
    if NetworkSession.is_host(): freeze=not enabled
    reset_pose=pose;pending_reset=NetworkSession.is_host()
    global_transform=pose
    target_position=pose.origin;target_rotation=pose.basis.get_rotation_quaternion()
    orbit.global_position=pose.origin+Vector3.UP*CAMERA_HEIGHT
    orbit.rotation.y=pose.basis.get_euler().y

func _set_parked(value: bool) -> void:
    parked=value
    _parked_clock=0.0
    if is_instance_valid(_ramp_shape): _ramp_shape.disabled=not value

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
    var max_angle: float=lerpf(.62,.17,clampf(absf(speed)/max_forward_speed,0,1))
    steering=move_toward(steering,-input.x*max_angle,state.step*1.8)
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
        # Forces act at axle height rather than the contact patch, so the tall body does not tip on turns.
        state.apply_force(side*tire_force.x+wheel_forward*tire_force.y,offset-up*.15)
    var horizontal:=state.linear_velocity.slide(Vector3.UP)
    state.apply_central_force(-horizontal*(mass/1250.0)*(35+2*horizontal.length()+mud*95))
    # Extra roll damping keeps the cottage upright over bumps.
    var roll: float=state.angular_velocity.dot(forward)
    state.apply_torque(-forward*roll*mass*1.6)
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
    for corner in [Vector3(-1.1,.8,-5.6),Vector3(1.1,.8,-5.6),Vector3(-1.2,.8,4.4),Vector3(1.2,.8,4.4)]:
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
    if local.seat_index==0 and event is InputEventMouseMotion:
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
        var payload: float=chassis_mass+85*(4-occupants.count(0))+2*NetworkSession.trunk_space()
        if absf(mass-payload)>.1: mass=payload
        _update_parking(delta)
        freeze=not enabled or parked
        if enabled and not parked and occupants[0]!=0 and NetworkSession.phase!="loading":
            var input: Vector2=command.get("drive",Vector2.ZERO)
            if absf(speed)>.5 or absf(input.y)>.1: secure_riders()
    for i in 4:
        wheel_turns[i].position.y=WHEELS[i].y-float(spring_lengths[i])
        wheel_turns[i].rotation.y=steering if i<2 else 0
        wheel_spins[i].rotation.x+=speed*delta/wheel_radius
        var p=NetworkSession.players.get(occupants[i])
        if not is_instance_valid(p): continue
        p.seat_index=i;p.global_position=to_global(SEATS[i]);p.velocity=linear_velocity
        if i==0: p.visual.global_basis=global_basis
    for spin in extra_spins: spin.rotation.x+=speed*delta/wheel_radius
    orbit.global_position=orbit.global_position.lerp(global_position+Vector3.UP*CAMERA_HEIGHT,1-exp(-12*delta))
    var local=NetworkSession.local_hunter()
    if local and local.seat_index==0 and NetworkSession.phase!="loading":
        if Time.get_ticks_msec()-camera_input_time>1800: orbit.rotation.y=lerp_angle(orbit.rotation.y,rotation.y,1-exp(-1.8*delta))
        camera.fov=lerpf(camera.fov,70+minf(absf(speed)*.3,8),1-exp(-3*delta))
        if not NetworkSession.world.menu.is_open: camera.current=true

## Host: freeze once the truck has stood still without a driver for a moment.
func _update_parking(delta: float) -> void:
    if not enabled or NetworkSession.phase=="loading" or pending_reset:
        if parked: _set_parked(false)
        return
    if parked:
        if occupants[0]!=0: _set_parked(false)
        return
    var resting: bool=occupants[0]==0 and linear_velocity.length()<.25 and angular_velocity.length()<.25 and grounded_wheels>=3
    _parked_clock=_parked_clock+delta if resting else 0.0
    if _parked_clock>=PARK_SECONDS:
        linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO;speed=0
        _set_parked(true)

## Host: when the truck pulls away, anyone still walking on it takes a terrace
## post (or steps off beside it if every post is taken).
func secure_riders() -> void:
    for peer in NetworkSession.players:
        var p=NetworkSession.players[peer]
        if not is_instance_valid(p) or p.seat_index>=0 or not p.world_ready: continue
        var local: Vector3=to_local(p.global_position)
        if local.y<1.0 or local.x<HULL_MIN.x or local.x>HULL_MAX.x or local.z<HULL_MIN.z or local.z>HULL_MAX.z or local.y>HULL_MAX.y+1.5: continue
        NetworkSession.release_jobs(peer)
        var seat:=-1
        if p.health>0:
            for index in [1,2,3]:
                if occupants[index]==0: seat=index;break
        if seat>0:
            occupants[seat]=peer;p.set_seat(seat)
            NetworkSession.tell(peer,"RIDER_SECURED")
        else:
            p.global_position=exit_point(1);p.velocity=Vector3.ZERO

func _process(delta: float) -> void:
    _clock+=delta
    if is_instance_valid(_ramp):
        _ramp_blend=move_toward(_ramp_blend,1.0 if parked else 0.0,delta*1.4)
        var blend: float=smoothstep(0.0,1.0,_ramp_blend)
        _ramp.transform=Transform3D(Basis(RAMP_STOWED.basis.get_rotation_quaternion().slerp(_ramp_lowered.basis.get_rotation_quaternion(),blend)),RAMP_STOWED.origin.lerp(_ramp_lowered.origin,blend))
    for puff in _puffs:
        var phase: float=fmod(_clock*(.32+absf(speed)*.03)+float(puff.get_meta("phase")),1.0)
        var source: Vector3=puff.get_meta("source")
        # Smoke leans out to the right so it trails past the terrace, not across it.
        puff.position=source+Vector3(phase*1.3,phase*2.0,phase*(.4+absf(speed)*.35))
        puff.scale=Vector3.ONE*(.3+phase*.9)
        puff.visible=phase<.9

func snapshot() -> Dictionary:
    return {"p":global_position,"q":global_basis.get_rotation_quaternion(),"v":linear_velocity,"s":speed,"seats":occupants.duplicate(),"steer":steering,"springs":spring_lengths.duplicate(),"contacts":grounded_wheels,"parked":parked}

func apply_snapshot(data: Dictionary) -> void:
    target_position=data.p;target_rotation=data.q;target_velocity=data.v
    speed=data.s;occupants=data.seats;steering=data.steer
    spring_lengths=data.springs;grounded_wheels=data.contacts
    var now_parked: bool=bool(data.get("parked",false))
    if now_parked!=parked: _set_parked(now_parked)

## Distance from a point to the truck's hull box, in metres.
func hull_distance(point: Vector3) -> float:
    var local: Vector3=to_local(point)
    return local.distance_to(local.clamp(HULL_MIN,HULL_MAX))

## Ground point beside the truck where a seat's hunter steps off.
func exit_point(index: int) -> Vector3:
    var offset:=Vector3(-2.75,1.0,-3.7) if index==0 else Vector3(2.85,1.0,5.6-float(index-1)*1.3)
    return global_position+Basis(Vector3.UP,rotation.y)*offset

## Seat 0 is the wheel; `gunner` prefers a terrace post.
func enter(peer: int, gunner: bool=false) -> bool:
    var p=NetworkSession.players.get(peer)
    if not enabled or not p or p.seat_index>=0 or p.health<=0 or linear_velocity.length()>2 or hull_distance(p.global_position)>3.4: return false
    var index:=-1
    for seat in ([1,2,3,0] if gunner else [0,1,2,3]):
        if occupants[seat]==0: index=seat;break
    if index<0: NetworkSession.tell(peer,"SEATS_FULL");return false
    NetworkSession.release_jobs(peer)
    occupants[index]=peer;p.set_seat(index)
    p.global_position=to_global(SEATS[index]);p.velocity=Vector3.ZERO
    if index==0: _set_parked(false)
    return true

func exit_seat(peer: int,force: bool=false) -> bool:
    var index:=occupants.find(peer)
    if index<0: return false
    if not force and linear_velocity.length()>2: NetworkSession.tell(peer,"STOP_TO_EXIT");return false
    occupants[index]=0
    var p=NetworkSession.players.get(peer)
    if p:
        p.set_seat(-1)
        p.global_position=exit_point(index)
        p.velocity=Vector3.ZERO
    if index==0: command={}
    return true

func recover(peer: int) -> bool:
    var p=NetworkSession.players.get(peer)
    if not p or (p.seat_index<0 and hull_distance(p.global_position)>8) or linear_velocity.length()>2 or Time.get_ticks_msec()-recovery_time<5000: return false
    if global_basis.y.dot(Vector3.UP)>.45 and global_position.y>-20: return false
    var point:=global_position
    point.y=(NetworkSession.forest.height_at(point.x,point.z) if is_instance_valid(NetworkSession.forest) else 0)+.6
    reset_state(Transform3D(Basis(Vector3.UP,rotation.y),point));recovery_time=Time.get_ticks_msec()
    return true
