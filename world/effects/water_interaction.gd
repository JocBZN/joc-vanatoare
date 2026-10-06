class_name WaterInteraction
extends RefCounted
## Local presentation reconstructed from replicated positions; no water RPCs or gameplay state.
const MAX_RIPPLES: int = 8
const RIPPLE_LIFETIME: float = 5.0
const MIN_CONTACT_DEPTH: float = .045
var elapsed: float = 0.0
var ripple_events := PackedVector4Array()
var tracked: Dictionary = {}
var next_ripple: int = 0
var map: Node3D
var material: ShaderMaterial

func configure(water_map: Node3D, water_material: ShaderMaterial) -> void:
    map = water_map
    material = water_material
    ripple_events.resize(MAX_RIPPLES)
    clear()

func clear() -> void:
    tracked.clear()
    next_ripple = 0
    for i in MAX_RIPPLES: ripple_events[i] = Vector4.ZERO
    _send_material()

func advance(delta: float) -> void:
    elapsed += delta
    for i in MAX_RIPPLES:
        if ripple_events[i].w > 0.0 and elapsed - ripple_events[i].z > RIPPLE_LIFETIME:
            ripple_events[i] = Vector4.ZERO

func update(delta: float) -> void:
    advance(delta)
    if NetworkSession.phase != "hunt" or NetworkSession.forest != map:
        if not tracked.is_empty(): clear()
        _send_material()
        return
    var observed: Dictionary = {}
    for hunter in NetworkSession.players.values():
        if not is_instance_valid(hunter): continue
        observed[hunter.peer_id] = true
        observe(hunter.peer_id, hunter.global_position, hunter.world_ready and hunter.health > 0 and hunter.seat_index < 0)
    var jeep = NetworkSession.jeep
    if is_instance_valid(jeep):
        observed[-1] = true
        observe(-1, jeep.global_position, jeep.enabled, true)
    for id in tracked.keys():
        if not observed.has(id): tracked.erase(id)
    _send_material()

## Reconstructed footsteps and tire wakes also work for remote interpolated actors.
## An airborne hunter or a hunter on a raised boardwalk has no water contact.
func observe(id: int, point: Vector3, enabled: bool, vehicle: bool = false) -> void:
    var wet: bool = enabled and map.water_submersion(point) > MIN_CONTACT_DEPTH
    var previous: Dictionary = tracked.get(id, {})
    var distance: float = 0.0
    if not previous.is_empty():
        distance = Vector2(point.x, point.z).distance_to(Vector2(previous.point.x, previous.point.z))
    # A reset, map spawn or replica correction must never draw a wake across the map.
    var teleported: bool = distance > 8.0
    var travelled: float = float(previous.get("travelled", 0.0)) + distance if not teleported else 0.0
    var last_event: float = float(previous.get("last_event", -1.0))
    var entered: bool = wet and not bool(previous.get("wet", false))
    var stride: float = 1.3 if vehicle else .75
    var moved: bool = wet and not teleported and distance > .0001 and travelled >= stride and elapsed - last_event >= .2
    if entered or moved:
        emit_ripple(point, (.085 if vehicle else .05) if entered else (.06 if vehicle else .032))
        travelled = 0.0
        last_event = elapsed
    if not wet: travelled = 0.0
    tracked[id] = {"point": point, "wet": wet, "travelled": travelled, "last_event": last_event}

func emit_ripple(point: Vector3, amplitude: float) -> void:
    ripple_events[next_ripple] = Vector4(point.x, point.z, elapsed, amplitude)
    next_ripple = (next_ripple + 1) % MAX_RIPPLES

func _send_material() -> void:
    if material == null: return
    material.set_shader_parameter("wave_time", elapsed)
    material.set_shader_parameter("ripple_events", ripple_events)

## Depth controls wading without introducing a full swimming controller.
static func wading_factor(depth: float) -> float:
    return lerpf(1.0, .55, smoothstep(.08, 1.15, depth))

## Four distributed hull samples give modest support and damping, without making
## a road vehicle an amphibious boat. The caller applies these only on the host.
static func hull_force(depth: float, vertical_speed: float, body_mass: float, gravity: float) -> float:
    if depth <= 0.0: return 0.0
    var immersion: float = clampf(depth / .8, 0.0, 1.0)
    var lift: float = body_mass * gravity * .25 * .8 * immersion
    var damping: float = -vertical_speed * body_mass * .25 * 1.8 * immersion
    return clampf(lift + damping, 0.0, body_mass * gravity * .25 * 1.25)
