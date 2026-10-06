extends SceneTree
## Renders the Wandering Oak truck in camp, its shop windows, cottage, terrace
## and out on the forest road with a hunter riding the terrace.
## Usage: godot --path . --script res://tests/preview_base.gd -- [output_dir]
var scene
var session
var camera: Camera3D
var truck
var out: String="res://docs"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
    for i in count: await process_frame
func capture(name_value: String) -> void:
    await frames(12)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(out+"/"+name_value+".png")
    print("BASE_SHOT ",name_value)
## Camera placed and aimed in truck-local coordinates.
func shot(name_value: String, from: Vector3, to: Vector3) -> void:
    camera.current=true
    camera.global_position=truck.to_global(from);camera.look_at(truck.to_global(to),Vector3.UP)
    await capture(name_value)
func run() -> void:
    var args:=OS.get_cmdline_user_args()
    if not args.is_empty(): out=args[0]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
    scene=load("res://game/main.tscn").instantiate();root.add_child(scene);current_scene=scene
    session=root.get_node("NetworkSession")
    await frames(15);scene.menu.resume();scene.hud.hide()
    var hunter=scene.hunter
    hunter.control_enabled=false;hunter.set_physics_process(false)
    truck=session.jeep
    camera=Camera3D.new();scene.add_child(camera);camera.current=true;camera.far=700;camera.fov=62
    for i in 90: await physics_frame
    hunter.global_position=Vector3(-30,0,30)
    camera.global_position=Vector3(-7,6.5,13);camera.look_at(Vector3(3.5,2.2,-3),Vector3.UP)
    await capture("base_camp")
    hunter.global_position=truck.counters.weapons.interaction_position()
    await shot("base_front",Vector3(-7.5,4.2,-11.5),Vector3(0,3.2,0))
    await shot("base_shops",Vector3(-7.2,2.6,1.2),Vector3(0,2.6,1.2))
    hunter.global_position=truck.counters.sell.interaction_position()
    await shot("base_sell",Vector3(-4.6,2.3,5.4),Vector3(-1.2,2.4,3.6))
    hunter.global_position=Vector3(-30,0,30)
    await shot("base_house",Vector3(5.5,7.2,13.5),Vector3(0,5.2,2.5))
    hunter.global_position=truck.counters.storage.interaction_position()
    await shot("base_workshop",Vector3(.9,5.4,2.85),Vector3(-.4,4.4,-1.4))
    hunter.global_position=Vector3(-30,0,30)
    await shot("base_terrace",Vector3(-4.5,10.8,-5.5),Vector3(0,7.9,1.2))
    # Out in the forest: the host chooses the map from the wheel, then hands the
    # wheel to a friend and climbs up to ride on the terrace.
    hunter.set_physics_process(true)
    hunter.global_position=truck.exit_point(0)
    truck.enter(1)
    session.request_action("start_hunt","forest")
    for i in 3600:
        if session.phase=="hunt": break
        await process_frame
    if session.phase!="hunt": push_error("forest did not load");quit(1);return
    for a in session.animals.values(): a.set_physics_process(false)
    var friend=session._spawn_player(2,"Friend");friend.world_ready=true
    truck.exit_seat(1,true)
    friend.global_position=truck.exit_point(0);truck.enter(2)
    hunter.place_aboard(truck.to_global(truck.DECK_LANDING))
    for i in 150:
        session._accept_input(2,{"seq":60000+i,"direction":Vector3.ZERO,"drive":Vector2(0,-1),"yaw":0,"pitch":0})
        await physics_frame
    scene.hud.show();hunter.camera_rig.rotation=Vector3(-.12,.6,0)
    hunter.camera_rig.camera.current=true
    for i in 6:
        session._accept_input(2,{"seq":61000+i,"direction":Vector3.ZERO,"drive":Vector2(0,-1),"yaw":0,"pitch":0})
        await physics_frame
    await capture("base_rider")
    scene.hud.hide()
    for i in 30:
        session._accept_input(2,{"seq":62000+i,"direction":Vector3.ZERO,"drive":Vector2(.35,-1),"yaw":0,"pitch":0})
        await physics_frame
    await shot("base_drive",Vector3(-10,6.5,9),Vector3(0,3.5,-1))
    print("BASE_PREVIEW_DONE speed=",snappedf(truck.speed,.1)," seats=",truck.occupants," rider=",truck.to_local(hunter.global_position).snapped(Vector3.ONE*.01))
    scene.queue_free();await frames(5);quit()
