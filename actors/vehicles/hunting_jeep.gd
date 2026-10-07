class_name HuntingJeep
extends RigidBody3D
## The Wandering Oak: the crew's truck and moving base. Host-only rigid-body
## simulation with four raycast suspension / tire contacts (the rear pair is
## drawn as a tandem). The only seat is the driver's, in the cab. Everyone else
## rides on foot: whoever stands on the truck (porch, cottage or the lookout
## terrace) is carried with it every physics frame and can walk, turn, aim and
## shoot while someone drives. Parked without a driver, the truck freezes,
## lowers its ramp and the porch gate opens for walking up to the cottage.
const SEATS=[Vector3(-.62,1.3,-3.7)]
const WHEELS=[Vector3(-1.35,1.32,-5.3),Vector3(1.35,1.32,-5.3),Vector3(-1.75,1.32,3.6),Vector3(1.75,1.32,3.6)]
## Hull box (truck-local) for boarding distance.
const HULL_MIN:=Vector3(-2.1,0,-7.0)
const HULL_MAX:=Vector3(2.1,9.0,6.1)
## Anyone whose feet are inside this box rides along with the truck.
const RIDE_MIN:=Vector3(-2.35,.9,-7.1)
const RIDE_MAX:=Vector3(2.35,10.5,6.25)
## Where the ladders put a hunter: on the terrace a step in from the ladder
## hatch, and on the middle of the porch (both just out of reach of the
## ladders' own prompts, so nobody climbs straight back by accident).
const DECK_LANDING:=Vector3(.95,7.85,2.3)
const PORCH_LANDING:=Vector3(.4,3.7,4.8)
## Fastest the truck may roll while someone climbs on or off from the ground.
const BOARD_SPEED: float=2.0
const CAMERA_HEIGHT: float=4.2
const PARK_SECONDS: float=.8
## Stowed, the ramp slides flat under the trailer between the frame rails.
const RAMP_STOWED:=Transform3D(Basis(Vector3.UP,PI),Vector3(0,.5,6.3))
const Model:=preload("res://actors/vehicles/oak_truck_model.gd")
const Builds:=preload("res://actors/vehicles/truck_builds.gd")
## Boat kit: hull sample points (truck-local, at keel height) and the stern thrust point.
const Extras:=preload("res://actors/vehicles/truck_extras.gd")
## The Galleon's hull: ten points round its outline (the bow narrows), at keel height.
const BOAT_POINTS: Array[Vector3]=[Vector3(-1.2,0,-9.6),Vector3(1.2,0,-9.6),Vector3(-3.3,0,-4.6),Vector3(3.3,0,-4.6),Vector3(-3.5,0,-.3),Vector3(3.5,0,-.3),Vector3(-3.5,0,5.0),Vector3(3.5,0,5.0),Vector3(-3.2,0,10.6),Vector3(3.2,0,10.6)]
const BOAT_DRAFT: float=.75
const BOAT_PROPELLER:=Vector3(0,.5,13.3)

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
var occupants: Array=[0]
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
var cleaner: Node3D
## Shared upgrade levels (TruckUpgrades), the fitted builds and their effects.
var upgrades: Dictionary=TruckUpgrades.fresh()
var kits: Dictionary={}
var kit_parts: Dictionary={}
var kit_shapes: Dictionary={}
var ride_min:=RIDE_MIN
var ride_max:=RIDE_MAX
var hull_min:=HULL_MIN
var hull_max:=HULL_MAX
## Nitro tank 0..1, whether the boosters are burning, and whether the hull floats.
var nitro: float=1.0
var boosting: bool=false
var floating: bool=false
var _bar_hits: Dictionary={}
var _prop_spin: float=0.0
## The boat kit unfolds the moment the hull touches water: 0 folded away, 1 fully deployed.
## The host drives it; every peer eases its own drawing toward it.
var boat_deploy: float=0.0
var _deploy_shown: float=0.0
var _dry_clock: float=0.0
var _builder
var _extras
## Absurd extras: rotor fuel and state, the horn's cooldown and blast counter, the hoover and the
## grill's activity, and how far the glass sphere is lowered.
var rotor_fuel: float=1.0
var rotor_on: bool=false
var horn_cooldown: float=0.0
var horn_count: int=0
var vacuum_active: bool=false
var grill_active: bool=false
var sphere_deploy: float=0.0
var _sphere_shown: float=0.0
var _horn_age: float=-1.0
var _horn_seen: int=0
var _vac_clock: float=0.0
var _vac_glow: float=0.0
var _heal_carry: Dictionary={}
var _deck_open: bool=false
var _sphere_open: bool=false
var _kit_clock: float=0.0
var _parked_clock: float=0.0
var _ramp: Node3D
var _ramp_shape: CollisionShape3D
var _gate_shape: CollisionShape3D
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
    # Replicas move before the hunters riding them, so riders stay glued on.
    process_physics_priority=-10
    mass=chassis_mass
    center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    # Low and a little forward: the cottage is heavy up high, but a truck that tips on a
    # turn is no fun, so the simulated centre of mass stays near the axles.
    center_of_mass=Vector3(0,.65,-.3)
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
    _ramp=parts.ramp;_ramp_shape=parts.ramp_shape;_ramp_down=parts.ramp_down;_gate_shape=parts.gate_shape
    _ramp_lowered=Transform3D(Basis(Vector3.RIGHT,_ramp_down),_ramp.position)
    _ramp.transform=RAMP_STOWED
    _puffs=parts.puffs;_labels=parts.labels
    counters=parts.counters;cleaner=parts.cleaner
    _build_kits()
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

## Builds the four optional kits once, hidden; set_upgrades switches them on.
func _build_kits() -> void:
    var builder:=Builds.new()
    _builder=builder
    kits=builder.build_all(self)
    kit_parts=builder.parts
    kit_shapes=builder.shapes
    # The five absurd extras live in their own builder; their kits, parts and colliders are merged in.
    _extras=Extras.new()
    var more: Dictionary=_extras.build_all(self)
    for id in more: kits[id]=more[id]
    for key in _extras.parts: kit_parts[key]=_extras.parts[key]
    for key in _extras.shapes: kit_shapes[key]=_extras.shapes[key]
    builder.animate_boat(0.0,0.0,0.0,false)
    _extras.animate_sphere(0.0,0.0,0.0)
    set_upgrades(upgrades)

## Applies a (host-authoritative) upgrade dictionary: top speed and engine push,
## the fitted builds, their colliders and the boarding / riding boxes.
func set_upgrades(state: Dictionary) -> void:
    upgrades=TruckUpgrades.sanitize(state)
    max_forward_speed=19.0*TruckUpgrades.top_speed_multiplier(upgrades)
    engine_force=24000.0*TruckUpgrades.engine_multiplier(upgrades)
    for id in TruckUpgrades.BUILDS:
        var fitted: bool=TruckUpgrades.level(upgrades,id)>0
        if kits.has(id): kits[id].visible=fitted
        # The sphere's floor and walls only exist once it is lowered (see _update_kits).
        if id!=&"sphere": for shape in kit_shapes.get(id,[]): shape.disabled=not fitted
    _set_prompts(&"tower_prompts",TruckUpgrades.level(upgrades,&"tower")>0)
    _set_prompts(&"deck_prompts",_deck_open and TruckUpgrades.level(upgrades,&"boat")>0)
    _set_prompts(&"sphere_prompts",_sphere_open and TruckUpgrades.level(upgrades,&"sphere")>0)
    _refresh_boxes()
    NetworkSession.truck_changed.emit()

func _set_prompts(key: StringName,on: bool) -> void:
    for prompt in kit_parts.get(key,[]):
        if on: prompt.add_to_group("lobby_interactables")
        else: prompt.remove_from_group("lobby_interactables")

## The riding and boarding boxes follow what is fitted: the tower raises them, the unfolded
## galleon widens and lengthens them, the stem of the bull head pushes the front out.
func _refresh_boxes() -> void:
    var tower: bool=TruckUpgrades.level(upgrades,&"tower")>0
    var boat: bool=TruckUpgrades.level(upgrades,&"boat")>0
    var wide: bool=boat and _deck_open
    ride_min=Vector3(-3.95 if wide else RIDE_MIN.x,RIDE_MIN.y,RIDE_MIN.z)
    ride_max=Vector3(3.95 if wide else RIDE_MAX.x,14.9 if tower else RIDE_MAX.y,14.3 if wide else RIDE_MAX.z)
    hull_max=Vector3(4.3 if boat else HULL_MAX.x,14.0 if tower else HULL_MAX.y,14.8 if boat else HULL_MAX.z)
    hull_min=Vector3(-4.3 if boat else HULL_MIN.x,HULL_MIN.y,-11.0 if boat else -10.4 if TruckUpgrades.level(upgrades,&"bar")>0 else HULL_MIN.z)

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
    # The porch gate closes whenever the ramp is up, so riders cannot step off the back.
    if is_instance_valid(_gate_shape): _gate_shape.disabled=value

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
    # Nitro: hold Shift while accelerating. The tank drains while burning and refills when idle.
    boosting=TruckUpgrades.level(upgrades,&"nitro")>0 and throttle>.2 and bool(command.get("sprint",false)) and occupants[0]!=0 and fresh and nitro>.02
    if boosting: nitro=maxf(0.0,nitro-state.step/TruckUpgrades.NITRO_BURN)
    else: nitro=minf(1.0,nitro+state.step/TruckUpgrades.NITRO_REFILL)
    var push: float=TruckUpgrades.NITRO_FORCE if boosting else 1.0
    var top_speed: float=max_forward_speed*(TruckUpgrades.NITRO_SPEED if boosting else 1.0)
    var max_angle: float=lerpf(.62,.17,clampf(absf(speed)/max_forward_speed,0,1))
    # Past the stock top speed (upgrades, nitro) the wheel gets much gentler, so a hard
    # turn at 40 m/s is a wide arc instead of a rollover.
    max_angle/=1.0+maxf(0.0,absf(speed)-20.0)*.07
    if boosting: max_angle*=.7
    steering=move_toward(steering,-input.x*max_angle,state.step*1.8)
    var mud: float=NetworkSession.forest.mud_factor(state.transform.origin) if NetworkSession.world_id=="swamp" and is_instance_valid(NetworkSession.forest) else 0
    grounded_wheels=0
    var ground_up:=Vector3.ZERO
    for i in 4:
        var offset: Vector3=basis_value*WHEELS[i]
        var from: Vector3=state.transform.origin+offset
        var ray:=PhysicsRayQueryParameters3D.create(from,from-up*(suspension_travel+wheel_radius),1,[get_rid()])
        var hit:=state.get_space_state().intersect_ray(ray)
        spring_lengths[i]=suspension_travel
        if hit.is_empty() or hit.normal.dot(up)<.35: continue
        grounded_wheels+=1
        ground_up+=hit.normal
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
        # The boost is not sent through the tyres (see below): it would eat all their grip.
        var longitudinal: float=throttle*engine_force*.25*lerpf(1,.82,mud)
        if throttle*speed>(top_speed if throttle>0 else max_reverse_speed): longitudinal=0
        var wheel_speed: float=local_velocity.dot(wheel_forward)
        if brake:
            longitudinal=-wheel_speed*mass*.25/state.step*.35-state.total_gravity.dot(wheel_forward)*mass*.25
        else:
            longitudinal-=wheel_speed*mass*.004
            # Drive never takes more than ~3/4 of a tyre's grip, so steering keeps its share.
            longitudinal=clampf(longitudinal,-grip_limit*.78,grip_limit*.78)
        # A friction circle keeps steering and braking within available traction.
        var tire_force:=Vector2(side_force,longitudinal).limit_length(grip_limit)
        # Forces act at axle height rather than the contact patch, so the tall body does not tip on turns.
        state.apply_force(side*tire_force.x+wheel_forward*tire_force.y,offset-up*.15)
    var horizontal:=state.linear_velocity.slide(Vector3.UP)
    state.apply_central_force(-horizontal*(mass/1250.0)*(35+2*horizontal.length()+mud*95))
    # Extra roll damping keeps the cottage upright over bumps.
    var roll: float=state.angular_velocity.dot(forward)
    state.apply_torque(-forward*roll*mass*1.6)
    # Nitro: a push at the centre of mass along the ground, so it cannot lever the nose up.
    if boosting and grounded_wheels>0 and speed<top_speed:
        var along: Vector3=forward.slide(ground_up.normalized()).normalized()
        state.apply_central_force(along*engine_force*(push-1.0)*throttle*(float(grounded_wheels)/4.0))
    # Stabilisers: relative to the ground the truck cannot rear up or lean over far, and in
    # the air it levels itself out and stops tumbling, so a jump lands on its wheels.
    var right: Vector3=basis_value.x
    if grounded_wheels>0:
        var level: Vector3=ground_up.normalized()
        var pitch_err: float=asin(clampf(forward.dot(level),-1.0,1.0))
        var roll_err: float=asin(clampf(right.dot(level),-1.0,1.0))
        var pitch_gain: float=30.0+(35.0 if boosting else 0.0)
        state.apply_torque(-right*(pitch_err*mass*pitch_gain+state.angular_velocity.dot(right)*mass*7.0)-forward*roll_err*mass*38.0)
    elif not floating:
        # Airborne: level out and stop tumbling (but leave the turn rate alone).
        var tilt: Vector3=up.cross(Vector3.UP)
        var spin: Vector3=state.angular_velocity-up*state.angular_velocity.dot(up)
        state.apply_torque(tilt*mass*14.0-spin*mass*2.5)
    # Flying Oak: the rotor key lifts the whole truck; the throttle then pushes it along and the wheel turns it.
    rotor_on=TruckUpgrades.level(upgrades,&"rotor")>0 and bool(command.get("rotor",false)) and occupants[0]!=0 and fresh and rotor_fuel>.02
    if rotor_on: rotor_fuel=maxf(0.0,rotor_fuel-state.step/TruckUpgrades.ROTOR_BURN)
    elif grounded_wheels>=2 or floating: rotor_fuel=minf(1.0,rotor_fuel+state.step/TruckUpgrades.ROTOR_REFILL)
    if rotor_on:
        var origin:=state.transform.origin
        var hit:=state.get_space_state().intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*(TruckUpgrades.ROTOR_CEILING+40.0),1,[get_rid()]))
        var clearance: float=origin.y-hit.position.y if not hit.is_empty() else 0.0
        var lift: float=TruckUpgrades.ROTOR_LIFT*(1.0-smoothstep(TruckUpgrades.ROTOR_CEILING-8.0,TruckUpgrades.ROTOR_CEILING,clearance)*.6)
        state.apply_central_force(Vector3.UP*mass*9.8*lift)
        # Vertical drag turns the lift into a steady climb that hangs at a hover, not a rocket.
        state.apply_central_force(Vector3.UP*-state.linear_velocity.y*mass*.8)
        if grounded_wheels==0:
            var planar_forward: Vector3=forward.slide(Vector3.UP).normalized()
            state.apply_central_force(planar_forward*throttle*engine_force*.7)
            var turn_rate: Vector3=state.angular_velocity
            turn_rate.y=move_toward(turn_rate.y,-input.x*1.0,state.step*2.2)
            state.angular_velocity=turn_rate
    if TruckUpgrades.level(upgrades,&"boat")>0: _apply_boat_forces(state,basis_value,throttle,input,push)
    else:
        floating=false
        _apply_water_forces(state,basis_value)
    if NetworkSession.phase=="lobby":
        var p:=state.transform.origin
        if absf(p.x)>18 or absf(p.z)>17:
            p.x=clampf(p.x,-18,18);p.z=clampf(p.z,-17,17)
            var constrained:=state.transform;constrained.origin=p;state.transform=constrained
            state.linear_velocity=Vector3.ZERO;state.angular_velocity=Vector3.ZERO
    if state.transform.origin.y < -30 or absf(state.transform.origin.x)>ForestMap.LIMIT+5 or absf(state.transform.origin.z)>ForestMap.LIMIT+5:
        state.transform=NetworkSession.world.world_router.jeep_spawn()
        state.linear_velocity=Vector3.ZERO;state.angular_velocity=Vector3.ZERO

## Host: with the boat kit the hull floats on any water. Eight points along the
## pontoons push up in proportion to how deep they are, a propeller at the stern
## pushes forward and a yaw rate follows the wheel. Water drag grows with speed,
## so the engine upgrades raise the boat's top speed as well.
func _apply_boat_forces(state: PhysicsDirectBodyState3D,basis_value: Basis,throttle: float,input: Vector2,push: float) -> void:
    floating=false
    if not NetworkSession.is_host() or NetworkSession.phase!="hunt" or not is_instance_valid(NetworkSession.forest):
        boat_deploy=move_toward(boat_deploy,0.0,state.step*.8)
        return
    var map=NetworkSession.forest
    var depths: Array[float]=[]
    var touching: bool=false
    for local in BOAT_POINTS:
        var depth: float=map.water_submersion(state.transform.origin+basis_value*local)
        depths.append(depth)
        if depth>0.02: touching=true
    # Touch the water and the kit unfolds; stay out of it for a moment and it folds away.
    if touching:
        _dry_clock=0.0
        boat_deploy=move_toward(boat_deploy,1.0,state.step*1.25)
    else:
        _dry_clock+=state.step
        if _dry_clock>1.2 and grounded_wheels>=2: boat_deploy=move_toward(boat_deploy,0.0,state.step*.75)
    var hull: float=lerpf(.5,1.0,boat_deploy)
    var stiffness: float=mass*9.8/(BOAT_POINTS.size()*BOAT_DRAFT)*hull
    var damper: float=2.0*.55*sqrt(stiffness*mass/BOAT_POINTS.size())
    var immersion: float=0.0
    for i in BOAT_POINTS.size():
        var depth: float=depths[i]
        if depth<=0.0: continue
        var offset: Vector3=basis_value*BOAT_POINTS[i]
        immersion+=clampf(depth/BOAT_DRAFT,0.0,1.0)/BOAT_POINTS.size()
        var local_velocity: Vector3=state.linear_velocity+state.angular_velocity.cross(offset-basis_value*center_of_mass)
        var lift: float=maxf(0.0,clampf(depth,0.0,2.4)*stiffness-local_velocity.y*damper)
        state.apply_force(Vector3.UP*lift,offset)
    if immersion<=.12: return
    floating=immersion>.3
    var forward: Vector3=-basis_value.z
    var planar: Vector3=forward.slide(Vector3.UP).normalized()
    var horizontal: Vector3=state.linear_velocity.slide(Vector3.UP)
    var water: float=clampf(immersion*1.6,0.0,1.0)
    var thrust: float=throttle*engine_force*TruckUpgrades.top_speed_multiplier(upgrades)*push*(1.0 if throttle>0 else .4)*clampf((boat_deploy-.35)/.5,0.0,1.0)
    state.apply_force(planar*thrust*water,basis_value*BOAT_PROPELLER)
    # Hull drag: linear plus quadratic, strong sideways so the boat tracks like a keel.
    var side: Vector3=planar.cross(Vector3.UP).normalized()
    var sideways: float=horizontal.dot(side)
    state.apply_central_force(-horizontal*mass*water*(.22+.04*horizontal.length())-side*sideways*mass*water*1.4)
    var roll_pitch: Vector3=state.angular_velocity-Vector3.UP*state.angular_velocity.y
    state.apply_torque(-roll_pitch*mass*water*2.2)
    var yaw_target: float=-input.x*.7*clampf(horizontal.length()/4.0,.25,1.0)*(-1.0 if speed<-.5 else 1.0)
    if occupants[0]==0: yaw_target=0.0
    var turn: Vector3=state.angular_velocity
    turn.y=move_toward(turn.y,yaw_target,state.step*1.6*water)
    state.angular_velocity=turn
    # Nobody at the helm: the boat drifts to a stop instead of coasting forever.
    if occupants[0]==0: state.apply_central_force(-horizontal*mass*water*1.2)

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
    if event.is_action_pressed("horn") and local.seat_index>=0: NetworkSession.request_action("horn")
    if local.seat_index==0 and event is InputEventMouseMotion:
        camera_input_time=Time.get_ticks_msec()
        orbit.rotation.y-=event.relative.x*.0025
        orbit.rotation.x=clampf(orbit.rotation.x-event.relative.y*.0025,-1.3,1.3)

func _physics_process(delta: float) -> void:
    if not NetworkSession.is_host():
        freeze=true
        if enabled:
            global_position=target_position if global_position.distance_to(target_position)>12 else global_position.lerp(target_position,1-exp(-14*delta))
            global_basis=Basis(global_basis.get_rotation_quaternion().slerp(target_rotation,1-exp(-14*delta)))
            linear_velocity=target_velocity
    else:
        var payload: float=chassis_mass+85*(1-occupants.count(0))+2*NetworkSession.trunk_space()
        if absf(mass-payload)>.1: mass=payload
        _update_parking(delta)
        _host_extras(delta)
        # A parked (frozen) truck runs no forces, so the boat kit folds away from here.
        if parked and boat_deploy>0.0: boat_deploy=move_toward(boat_deploy,0.0,delta*.75)
        freeze=not enabled or parked
    for i in 4:
        wheel_turns[i].position.y=WHEELS[i].y-float(spring_lengths[i])
        wheel_turns[i].rotation.y=steering if i<2 else 0
        wheel_spins[i].rotation.x+=speed*delta/wheel_radius
    var driver=NetworkSession.players.get(occupants[0])
    if is_instance_valid(driver):
        driver.seat_index=0;driver.global_position=to_global(SEATS[0]);driver.velocity=linear_velocity
        driver.visual.global_basis=global_basis
    for spin in extra_spins: spin.rotation.x+=speed*delta/wheel_radius
    if NetworkSession.is_host(): _bar_attack(delta)
    _update_kits(delta)
    orbit.global_position=orbit.global_position.lerp(global_position+Vector3.UP*CAMERA_HEIGHT,1-exp(-12*delta))
    var local=NetworkSession.local_hunter()
    if local and local.seat_index==0 and NetworkSession.phase!="loading":
        if Time.get_ticks_msec()-camera_input_time>1800: orbit.rotation.y=lerp_angle(orbit.rotation.y,rotation.y,1-exp(-1.8*delta))
        camera.fov=lerpf(camera.fov,70+minf(absf(speed)*.3,8),1-exp(-3*delta))
        if not NetworkSession.world.menu.is_open: camera.current=true

## Host: the bull bar hurts animals it meets at speed. Each animal is struck at most
## once every 0.8 s, so ploughing through a pack costs them, not an instant wipe.
func _bar_attack(delta: float) -> void:
    if TruckUpgrades.level(upgrades,&"bar")<1 or NetworkSession.phase!="hunt" or not enabled: return
    for id in _bar_hits.keys(): _bar_hits[id]=float(_bar_hits[id])-delta
    var forward_speed: float=linear_velocity.dot(-global_basis.z)
    if forward_speed<TruckUpgrades.BAR_MIN_SPEED: return
    for animal in NetworkSession.animals.values():
        if animal.dead or float(_bar_hits.get(animal.animal_id,0.0))>0.0: continue
        var local: Vector3=to_local(animal.global_position)
        if absf(local.x)>2.4 or local.z>-5.4 or local.z<-9.6 or absf(local.y)>3.5: continue
        _bar_hits[animal.animal_id]=.8
        var damage: int=int(forward_speed*TruckUpgrades.BAR_DAMAGE_PER_SPEED)
        animal.take_damage(damage,global_position,occupants[0] if occupants[0]!=0 else 1)

## Flames, propeller and bow spray, drawn from replicated state (no extra traffic).
func _update_kits(delta: float) -> void:
    _kit_clock+=delta
    if TruckUpgrades.level(upgrades,&"bar")>0: _builder.animate_bar(speed,_kit_clock)
    if TruckUpgrades.level(upgrades,&"tower")>0: _builder.animate_tower(_kit_clock,delta)
    if TruckUpgrades.level(upgrades,&"nitro")>0 and kit_parts.has(&"flames"):
        var burn: float=1.0 if boosting else 0.0
        for flame in kit_parts[&"flames"]:
            flame.scale=flame.scale.lerp(Vector3.ONE*maxf(burn,.001),1-exp(-14*delta))
            flame.visible=flame.scale.x>.05
        var light: OmniLight3D=kit_parts[&"flame_light"]
        light.light_energy=lerpf(light.light_energy,burn*4.0,1-exp(-14*delta))
    var boat: bool=TruckUpgrades.level(upgrades,&"boat")>0
    if boat:
        _deploy_shown=move_toward(_deploy_shown,boat_deploy,delta*1.6)
        _builder.animate_boat(_deploy_shown,_kit_clock,speed,floating)
        if kit_parts.has(&"propeller"):
            _prop_spin+=delta*(8.0+absf(speed)*3.0)*(1.0 if floating else .15)
            kit_parts[&"propeller"].rotation.z=_prop_spin
    # The aft deck, its stairs and the porch gate are solid only while the galleon is unfolded.
    var open: bool=boat and _deploy_shown>.92
    if open!=_deck_open:
        _deck_open=open
        for shape in kit_shapes.get(&"boat_deck",[]): shape.disabled=not open
        _set_prompts(&"deck_prompts",open)
        if is_instance_valid(_gate_shape): _gate_shape.disabled=parked or open
        _refresh_boxes()
    # The glass sphere winches down once the boat is afloat.
    var sphere: bool=TruckUpgrades.level(upgrades,&"sphere")>0
    _sphere_shown=move_toward(_sphere_shown,sphere_deploy if sphere else 0.0,delta*2.0)
    if sphere: _extras.animate_sphere(_sphere_shown,_kit_clock,speed)
    var sphere_up: bool=sphere and _sphere_shown>.92
    if sphere_up!=_sphere_open:
        _sphere_open=sphere_up
        for shape in kit_shapes.get(&"sphere",[]): shape.disabled=not sphere_up
        _set_prompts(&"sphere_prompts",sphere_up)
    if TruckUpgrades.level(upgrades,&"grill")>0: _extras.animate_grill(delta,_kit_clock,grill_active)
    if TruckUpgrades.level(upgrades,&"vacuum")>0: _extras.animate_hoover(_kit_clock,vacuum_active,delta)
    if TruckUpgrades.level(upgrades,&"horn")>0:
        if _horn_age>=0.0: _horn_age+=delta
        if _horn_age>2.5: _horn_age=-1.0
        _extras.animate_horn(_kit_clock,_horn_age,delta)
    if TruckUpgrades.level(upgrades,&"rotor")>0: _extras.animate_rotor(delta,1.0 if rotor_on else 0.0)

## Host: the grill heals everyone aboard, the hoover sweeps up loot, the sphere lowers and the
## horn recharges. Nothing here needs the physics step, so it also runs while the truck is parked.
func _host_extras(delta: float) -> void:
    horn_cooldown=maxf(0.0,horn_cooldown-delta)
    var want_sphere: bool=TruckUpgrades.level(upgrades,&"sphere")>0 and boat_deploy>.95 and floating
    sphere_deploy=move_toward(sphere_deploy,1.0 if want_sphere else 0.0,delta*.45)
    grill_active=false
    if TruckUpgrades.level(upgrades,&"grill")>0 and NetworkSession.phase=="hunt":
        for peer in NetworkSession.players:
            var p=NetworkSession.players[peer]
            if not is_instance_valid(p) or p.health<=0 or p.health>=100 or not (p.riding or p.seat_index>=0): continue
            var carry: float=float(_heal_carry.get(peer,0.0))+TruckUpgrades.GRILL_HEAL*delta
            var whole: int=int(carry)
            _heal_carry[peer]=carry-whole
            if whole>0: p.health=mini(100,p.health+whole)
            grill_active=true
    _vac_clock-=delta
    if _vac_clock<=0.0:
        _vac_clock=TruckUpgrades.VACUUM_PERIOD
        _sweep_loot()
    _vac_glow=maxf(0.0,_vac_glow-delta)
    vacuum_active=_vac_glow>0.0

## The hoover: any loot within reach flies into the pack of whoever is aboard and has room.
func _sweep_loot() -> void:
    if TruckUpgrades.level(upgrades,&"vacuum")<1 or NetworkSession.phase!="hunt": return
    for id in NetworkSession.loot.keys():
        var pickup=NetworkSession.loot[id]
        if not is_instance_valid(pickup) or pickup.global_position.distance_to(global_position)>TruckUpgrades.VACUUM_RADIUS: continue
        var best=null;var best_distance: float=INF
        for p in NetworkSession.players.values():
            if not is_instance_valid(p) or p.health<=0 or not (p.riding or p.seat_index>=0): continue
            if not p.inventory.can_collect(pickup.loot_definition): continue
            var d: float=p.global_position.distance_to(pickup.global_position)
            if d<best_distance: best=p;best_distance=d
        if best and NetworkSession.vacuum_pickup(id,best.peer_id): _vac_glow=.7

## Host: somebody aboard leans on the gramophone. Everything within range bolts for a few seconds.
func blast_horn(peer: int) -> bool:
    var p=NetworkSession.players.get(peer)
    if TruckUpgrades.level(upgrades,&"horn")<1 or not p or p.health<=0 or horn_cooldown>0.0: return false
    if not (p.riding or p.seat_index>=0): return false
    horn_cooldown=TruckUpgrades.HORN_COOLDOWN
    horn_count+=1;_horn_seen=horn_count;_horn_age=0.0
    if _extras: _extras.fire_horn()
    for animal in NetworkSession.animals.values():
        if animal.dead or animal.global_position.distance_to(global_position)>TruckUpgrades.HORN_RADIUS: continue
        animal.scare(global_position,TruckUpgrades.HORN_SCARE)
    return true
## Host: freeze once the truck has stood still without a driver for a moment.
func _update_parking(delta: float) -> void:
    if not enabled or NetworkSession.phase=="loading" or pending_reset:
        if parked: _set_parked(false)
        return
    if parked:
        if occupants[0]!=0: _set_parked(false)
        return
    var resting: bool=occupants[0]==0 and linear_velocity.length()<.25 and angular_velocity.length()<.25 and grounded_wheels>=3 and not floating
    _parked_clock=_parked_clock+delta if resting else 0.0
    if _parked_clock>=PARK_SECONDS:
        linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO;speed=0
        _set_parked(true)

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
    return {"p":global_position,"q":global_basis.get_rotation_quaternion(),"v":linear_velocity,"s":speed,"seats":occupants.duplicate(),"steer":steering,"springs":spring_lengths.duplicate(),"contacts":grounded_wheels,"parked":parked,"up":upgrades,"nitro":nitro,"boost":boosting,"float":floating,"dep":boat_deploy,"sph":sphere_deploy,"rot":rotor_fuel,"rotor":rotor_on,"hcd":horn_cooldown,"hc":horn_count,"gr":grill_active,"vac":vacuum_active}

func apply_snapshot(data: Dictionary) -> void:
    target_position=data.p;target_rotation=data.q;target_velocity=data.v
    speed=data.s;occupants=data.seats;steering=data.steer
    spring_lengths=data.springs;grounded_wheels=data.contacts
    nitro=float(data.get("nitro",nitro));boosting=bool(data.get("boost",false));floating=bool(data.get("float",false));boat_deploy=float(data.get("dep",boat_deploy))
    sphere_deploy=float(data.get("sph",sphere_deploy));rotor_fuel=float(data.get("rot",rotor_fuel));rotor_on=bool(data.get("rotor",false))
    horn_cooldown=float(data.get("hcd",horn_cooldown));grill_active=bool(data.get("gr",false));vacuum_active=bool(data.get("vac",false))
    var blasts: int=int(data.get("hc",horn_count))
    if blasts!=horn_count:
        horn_count=blasts
        if blasts>_horn_seen: _horn_seen=blasts;_horn_age=0.0;if _extras: _extras.fire_horn()
    if data.get("up") is Dictionary and data.up!=upgrades: set_upgrades(data.up)
    var now_parked: bool=bool(data.get("parked",false))
    if now_parked!=parked: _set_parked(now_parked)

## Distance from a point to the truck's hull box, in metres.
func hull_distance(point: Vector3) -> float:
    var local: Vector3=to_local(point)
    return local.distance_to(local.clamp(hull_min,hull_max))

## Whether a hunter standing at `point` is aboard and rides along.
func carries(point: Vector3) -> bool:
    var local: Vector3=global_transform.affine_inverse()*point
    if local.x>=ride_min.x and local.x<=ride_max.x and local.y>=ride_min.y and local.y<=ride_max.y and local.z>=ride_min.z and local.z<=ride_max.z: return true
    # Inside the lowered glass sphere under the hull.
    if _sphere_open:
        var c: Vector3=Extras.SPHERE_CENTER
        return absf(local.x-c.x)<1.9 and local.z>c.z-1.9 and local.z<c.z+1.9 and local.y>c.y-2.2 and local.y<.9
    return false

## Ground point beside the truck: 0 by the cab door, anything else by the rope
## ladder on the right of the porch.
func exit_point(index: int) -> Vector3:
    var offset:=Vector3(-2.75,1.0,-3.7) if index==0 else Vector3(2.85,1.0,5.6)
    return global_position+Basis(Vector3.UP,rotation.y)*offset

## The only seat: the wheel.
func enter(peer: int) -> bool:
    var p=NetworkSession.players.get(peer)
    if not enabled or not p or p.seat_index>=0 or p.health<=0 or linear_velocity.length()>BOARD_SPEED or hull_distance(p.global_position)>3.4: return false
    if occupants[0]!=0: NetworkSession.tell(peer,"SEATS_FULL");return false
    NetworkSession.release_jobs(peer)
    occupants[0]=peer;p.set_seat(0)
    p.global_position=to_global(SEATS[0]);p.velocity=Vector3.ZERO
    _set_parked(false)
    return true

## Host: the ladders. "board" climbs the rope ladder from the ground straight to
## the terrace, "ladder_up"/"ladder_down" go between porch and terrace (fine while
## driving), "alight" climbs back down to the ground. The caller has already
## checked the hunter stands at that ladder.
func climb(peer: int, route: String) -> bool:
    var p=NetworkSession.players.get(peer)
    if not enabled or not p or p.seat_index>=0 or p.health<=0: return false
    var slow: bool=linear_velocity.length()<=BOARD_SPEED
    match route:
        "board":
            if not slow: NetworkSession.tell(peer,"TRUCK_TOO_FAST");return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(DECK_LANDING))
        "ladder_up": NetworkSession.release_jobs(peer);p.place_aboard(to_global(DECK_LANDING))
        "ladder_down": NetworkSession.release_jobs(peer);p.place_aboard(to_global(PORCH_LANDING))
        "deck_down":
            if not _deck_open: return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(Builds.AFT_LANDING))
        "deck_up":
            if not _deck_open: return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(Builds.AFT_PORCH))
        "board_deck":
            if not _deck_open: return false
            if linear_velocity.length()>8.0: NetworkSession.tell(peer,"TRUCK_TOO_FAST");return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(Builds.AFT_LANDING))
        "sphere_down":
            if not _sphere_open: return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(Extras.SPHERE_LANDING))
        "sphere_up":
            if not _sphere_open: return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(Builds.AFT_PORCH))
        "tower_up":
            if TruckUpgrades.level(upgrades,&"tower")<1: return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(Builds.TOWER_LANDING))
        "tower_down":
            if TruckUpgrades.level(upgrades,&"tower")<1: return false
            NetworkSession.release_jobs(peer);p.place_aboard(to_global(Builds.TOWER_DECK_LANDING))
        "alight":
            if not slow: NetworkSession.tell(peer,"STOP_TO_EXIT");return false
            NetworkSession.release_jobs(peer)
            p.respawn_at(exit_point(1))
        _: return false
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
