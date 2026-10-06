extends SceneTree
## Controlled geometry verifies water contact, actual movement and host rigid-body forces.
var checks: int = 0
var failures: int = 0
var scene
var session

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if ok: print("PASS ", message)
    else: failures += 1; push_error("FAIL " + message)
func frames(count: int) -> void:
    for i in count: await physics_frame
func active_ripples(interaction) -> int:
    var count: int = 0
    for event in interaction.ripple_events:
        if event.w > 0.0: count += 1
    return count
func coast(jeep, point: Vector3) -> float:
    jeep.reset_state(Transform3D(Basis.IDENTITY, point))
    jeep.occupants[0] = 1
    session.local_hunter().set_seat(0)
    for i in 90:
        jeep.command = {"drive": Vector2.ZERO, "brake": false, "time": Time.get_ticks_msec()}
        await frames(1)
    print("SETTLE water_coast ", jeep.global_position, " contacts=", jeep.grounded_wheels, " up=", jeep.global_basis.y.dot(Vector3.UP))
    jeep.linear_velocity = Vector3(0, 0, -6)
    for i in 30:
        jeep.command = {"drive": Vector2.ZERO, "brake": false, "time": Time.get_ticks_msec()}
        await frames(1)
    return jeep.linear_velocity.slide(Vector3.UP).length()

func run() -> void:
    scene = load("res://game/main.tscn").instantiate()
    root.add_child(scene); current_scene = scene
    session = root.get_node("NetworkSession")
    await frames(4)
    session.set_physics_process(false)
    session.local_hunter().set_physics_process(false)
    session.local_hunter().control_enabled = false
    session.jeep.set_simulation(false)
    var forest = load("res://world/forest/forest_map.gd").new(); scene.add_child(forest)
    session.forest = forest; session.world_id = "forest"; session.phase = "hunt"
    var center: Vector3 = Vector3(forest.LAKE_CENTER.x, forest.LAKE_LEVEL - forest.LAKE_DEPTH, forest.LAKE_CENTER.y)
    check(is_equal_approx(forest.water_depth(center), 1.15), "forest basin has a real shallow water column")
    check(is_equal_approx(forest.water_submersion(center), 1.15), "submerged feet have contact depth")
    check(forest.water_submersion(center + Vector3.UP * 2.0) == 0.0, "above-water hunters and raised decks receive no water drag")
    check(forest.water_depth(Vector3(50, -4.15, 160)) == 0.0, "low ground outside the lake has no water")
    var seed_safe: bool = true
    var shallow_rim: bool = true
    for seed_value in [111111, 222222, 333333, 444444]:
        forest.set_seed(seed_value)
        seed_safe = seed_safe and is_equal_approx(forest.water_depth(center), 1.15) and forest.water_depth(Vector3.ZERO) == 0.0
        for angle in 24:
            var edge: Vector2 = forest.LAKE_CENTER + Vector2.from_angle(angle * TAU / 24.0) * (forest.LAKE_RADIUS + forest.LAKE_SHORE + 1.0)
            seed_safe = seed_safe and forest.water_depth(Vector3(edge.x, -5, edge.y)) == 0.0
            shallow_rim = shallow_rim and forest.height_at(edge.x, edge.y) > forest.LAKE_LEVEL
            for radius in range(0, 98, 7):
                var sample: Vector2 = forest.LAKE_CENTER + Vector2.from_angle(angle * TAU / 24.0) * radius
                shallow_rim = shallow_rim and forest.water_depth(Vector3(sample.x, -5, sample.y)) <= forest.LAKE_DEPTH + .001
    check(seed_safe, "water extent and dry arrival remain deterministic across seeds")
    check(shallow_rim, "random lowlands preserve a dry lake rim and shallow walkable basin")
    var twin = load("res://world/forest/forest_map.gd").new(); scene.add_child(twin); twin.set_seed(forest.current_seed)
    check(is_equal_approx(twin.height_at(center.x + 65, center.z), forest.height_at(center.x + 65, center.z)), "matching expedition seed reproduces the changed basin on a late-joining peer")
    twin.queue_free()

    var interaction = load("res://world/effects/water_interaction.gd").new(); interaction.configure(forest, null)
    interaction.observe(2, center, true)
    check(active_ripples(interaction) == 1, "water entry emits one ripple")
    interaction.advance(.3); interaction.observe(2, center, true)
    check(active_ripples(interaction) == 1, "standing in water emits no continuous ripple")
    interaction.observe(2, center + Vector3.RIGHT, true)
    check(active_ripples(interaction) == 2, "actual submerged movement emits a finite wake")
    interaction.observe(2, center + Vector3(2, 2, 0), true)
    interaction.observe(2, center + Vector3(4, 2, 0), true)
    check(active_ripples(interaction) == 2, "airborne movement above water emits no ripple")
    interaction.observe(3, Vector3(50, -4.15, 160), true)
    interaction.observe(3, Vector3(52, -4.15, 160), true)
    check(active_ripples(interaction) == 2, "dry movement emits no ripple")
    interaction.observe(4, center, false)
    check(active_ripples(interaction) == 2, "seated or unloaded actors emit no foot ripple")
    interaction.advance(5.1)
    check(active_ripples(interaction) == 0, "all ripple events expire after their finite lifetime")
    interaction.observe(2, center, true)
    session.phase = "loading"; interaction.update(.1)
    check(active_ripples(interaction) == 0 and interaction.tracked.is_empty(), "world loading clears local water trails")
    session.phase = "hunt"

    # A flat pad at the nominal lake floor isolates depth drag from terrain slope.
    var pad := StaticBody3D.new(); var collision := CollisionShape3D.new(); var box := BoxShape3D.new()
    box.size = Vector3(300, 1, 180); collision.shape = box; pad.add_child(collision)
    pad.position = Vector3(145, center.y - .5, center.z); scene.add_child(pad)
    var walker = session._spawn_player(2, "Water tester"); walker.local_player = false; walker.world_ready = true
    walker.global_position = Vector3(50, center.y + .03, center.z); walker.velocity = Vector3.ZERO
    walker.command = {}; await frames(15)
    var start: Vector3 = walker.global_position
    walker.command = {"direction": Vector3.RIGHT}
    await frames(60)
    var dry_distance: float = walker.global_position.x - start.x
    walker.global_position = center + Vector3.UP * .03; walker.velocity = Vector3.ZERO
    walker.command = {}; await frames(15); start = walker.global_position
    walker.command = {"direction": Vector3.RIGHT}
    await frames(60)
    var wet_distance: float = walker.global_position.x - start.x
    print("WADING dry=", dry_distance, " lake=", wet_distance)
    check(wet_distance > 1.5 and wet_distance < dry_distance * .72, "actual forest movement slows progressively while remaining walkable")
    walker.set_physics_process(false)

    var swamp = load("res://world/swamp/swamp_map.gd").new(); scene.add_child(swamp)
    var wet := Vector3.ZERO
    for x in range(40, 250, 10):
        for z in range(-240, -40, 10):
            var point := Vector3(x, swamp.height_at(x, z), z)
            if swamp.water_depth(point) > .75: wet = point; break
        if wet != Vector3.ZERO: break
    check(wet != Vector3.ZERO and swamp.water_submersion(wet) > .75, "swamp exposes the same depth-aware water contact interface")
    check(swamp.water_submersion(Vector3(wet.x, 2, wet.z)) == 0.0 and swamp.mud_factor(Vector3(wet.x, 2, wet.z)) == 0.0, "swamp boardwalks retain dry movement and traction")
    swamp.queue_free()

    var jeep = session.jeep; jeep.set_simulation(true)
    var dry_speed: float = await coast(jeep, Vector3(50, center.y + .12, center.z))
    var wet_speed: float = await coast(jeep, center + Vector3.UP * .12)
    print("COAST dry=", dry_speed, " lake=", wet_speed)
    check(wet_speed < dry_speed * .95, "submerged hull drag measurably slows the actual jeep")
    check(jeep.global_basis.y.dot(Vector3.UP) > .95 and jeep.grounded_wheels >= 2, "modest buoyancy preserves grounded stable jeep support")
    jeep.occupants[0] = 0; pad.queue_free(); await frames(2)
    jeep.reset_state(Transform3D(Basis.IDENTITY, Vector3(50, center.y, center.z)))
    await frames(12); var dry_fall: float = center.y - jeep.global_position.y
    jeep.reset_state(Transform3D(Basis.IDENTITY, center))
    await frames(12); var wet_fall: float = center.y - jeep.global_position.y
    print("BUOYANCY dry_fall=", dry_fall, " wet_fall=", wet_fall)
    check(wet_fall >= 0.0 and wet_fall < dry_fall * .85, "distributed buoyancy reduces actual descent without floating a jeep above water")
    var replica_point: Vector3 = center
    session.mode = "client"; jeep.target_position = replica_point; jeep.target_velocity = Vector3.ZERO
    jeep.global_position = replica_point; jeep.set_simulation(true)
    await frames(30)
    check(jeep.freeze and jeep.global_position.distance_to(replica_point) < .001, "client jeep remains frozen and receives no local water forces")
    session.mode = "solo"; jeep.set_simulation(false)
    session.forest = null; scene.queue_free(); await process_frame; await process_frame
    print("RESULT ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
